"""ASM Synthesizer - Compare and merge specialized ASM generators.

Provides:
- Side-by-side comparison of samples from different generators
- Quality metrics for each generator type
- Unified dataset creation with task type labels
- A/B testing support for prompt variations

Target: Compare sample quality across euclid-asm task types
"""

from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

from agents.training.base import TrainingSample

logger = logging.getLogger(__name__)


@dataclass
class GeneratorComparison:
    """Results from comparing generators on the same source item."""

    item_name: str
    item_address: str
    samples: dict[str, Optional[TrainingSample]] = field(default_factory=dict)
    generation_times: dict[str, float] = field(default_factory=dict)
    quality_scores: dict[str, float] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "item": {"name": self.item_name, "address": self.item_address},
            "samples": {
                task: sample.to_dict() if sample else None
                for task, sample in self.samples.items()
            },
            "generation_times": self.generation_times,
            "quality_scores": self.quality_scores,
        }


@dataclass
class SynthesisResult:
    """Results from synthesizing multiple generators."""

    total_items: int = 0
    samples_by_type: dict[str, int] = field(default_factory=dict)
    success_rates: dict[str, float] = field(default_factory=dict)
    avg_quality: dict[str, float] = field(default_factory=dict)
    comparisons: list[GeneratorComparison] = field(default_factory=list)
    duration_seconds: float = 0.0

    def summary(self) -> str:
        lines = [
            "=" * 60,
            "ASM SYNTHESIS RESULTS",
            "=" * 60,
            f"Total items processed: {self.total_items}",
            f"Duration: {self.duration_seconds:.1f}s",
            "",
            "Samples by Type:",
        ]
        for task, count in sorted(self.samples_by_type.items()):
            rate = self.success_rates.get(task, 0) * 100
            quality = self.avg_quality.get(task, 0)
            lines.append(f"  {task}: {count} samples ({rate:.1f}% success, {quality:.2f} avg quality)")

        return "\n".join(lines)


class AsmSynthesizer:
    """Synthesize and compare samples from multiple ASM generators.

    Can run generators in parallel and compare their outputs on the
    same source items to evaluate sample quality and diversity.
    """

    GENERATOR_CLASSES = {
        "base": "hafs_scawful.generators.asm_generator:AsmDataGenerator",
        "debug": "hafs_scawful.generators.asm_debug_generator:AsmDebugGenerator",
        "optimize": "hafs_scawful.generators.asm_optimize_generator:AsmOptimizeGenerator",
        "hook": "hafs_scawful.generators.asm_hook_generator:AsmHookGenerator",
        "doc": "hafs_scawful.generators.asm_doc_generator:AsmDocGenerator",
    }

    def __init__(self, generator_types: Optional[list[str]] = None):
        """Initialize synthesizer with specified generator types.

        Args:
            generator_types: List of generator types to use. If None, uses all.
                Options: base, debug, optimize, hook, doc
        """
        self.generator_types = generator_types or list(self.GENERATOR_CLASSES.keys())
        self.generators: dict[str, Any] = {}
        self._setup_complete = False

    def _load_generator_class(self, type_key: str):
        """Dynamically load a generator class."""
        module_path, class_name = self.GENERATOR_CLASSES[type_key].rsplit(":", 1)
        module = __import__(module_path, fromlist=[class_name])
        return getattr(module, class_name)

    async def setup(self):
        """Initialize all generators."""
        if self._setup_complete:
            return

        for gen_type in self.generator_types:
            try:
                GenClass = self._load_generator_class(gen_type)
                gen = GenClass()
                await gen.setup()
                self.generators[gen_type] = gen
                logger.info(f"Loaded generator: {gen_type}")
            except Exception as e:
                logger.error(f"Failed to load {gen_type} generator: {e}")

        self._setup_complete = True

    async def compare_on_item(self, item) -> GeneratorComparison:
        """Run all generators on a single item and compare results."""
        import time

        comparison = GeneratorComparison(
            item_name=item.name,
            item_address=item.address,
        )

        for gen_type, generator in self.generators.items():
            start = time.time()
            try:
                sample = await generator.generate_sample(item)
                comparison.samples[gen_type] = sample
                comparison.generation_times[gen_type] = time.time() - start

                # Simple quality heuristics
                if sample:
                    quality = self._score_sample_quality(sample, gen_type)
                    comparison.quality_scores[gen_type] = quality
                else:
                    comparison.quality_scores[gen_type] = 0.0

            except Exception as e:
                logger.warning(f"[{gen_type}] Failed on {item.name}: {e}")
                comparison.samples[gen_type] = None
                comparison.quality_scores[gen_type] = 0.0

        return comparison

    def _score_sample_quality(self, sample: TrainingSample, gen_type: str) -> float:
        """Score sample quality (0-1) based on heuristics."""
        score = 0.5  # Base score

        # Instruction quality
        if len(sample.instruction) > 20:
            score += 0.1
        if len(sample.instruction) > 50:
            score += 0.1
        if '?' in sample.instruction:  # Has question format
            score += 0.05

        # Output quality
        if '```asm' in sample.output or '```' in sample.output:
            score += 0.1  # Has code block
        if ';' in sample.output:
            score += 0.1  # Has comments

        # Length checks
        if len(sample.output) > 200:
            score += 0.1

        # Task-specific bonuses
        if gen_type == "debug" and any(x in sample.output.lower() for x in ['bug', 'fix', 'cause', 'issue']):
            score += 0.1
        if gen_type == "optimize" and any(x in sample.output.lower() for x in ['cycle', 'faster', 'optimize']):
            score += 0.1
        if gen_type == "hook" and any(x in sample.output.lower() for x in ['jsl', 'freespace', 'hook', 'patch']):
            score += 0.1
        if gen_type == "doc" and any(x in sample.output.lower() for x in ['purpose', 'parameter', 'return']):
            score += 0.1

        return min(1.0, score)

    async def run_comparison(
        self,
        limit: int = 10,
        parallel: bool = True,
    ) -> SynthesisResult:
        """Run all generators on shared items and compare.

        Args:
            limit: Maximum items to process
            parallel: Whether to run generators in parallel per item

        Returns:
            SynthesisResult with comparison data
        """
        import time
        start_time = time.time()

        await self.setup()

        # Get items from any generator (they share the same source)
        first_gen = next(iter(self.generators.values()))
        items = await first_gen.extract_source_items()
        items = items[:limit]

        result = SynthesisResult(total_items=len(items))

        for i, item in enumerate(items):
            logger.info(f"Processing {i+1}/{len(items)}: {item.name}")
            comparison = await self.compare_on_item(item)
            result.comparisons.append(comparison)

            # Update counts
            for gen_type, sample in comparison.samples.items():
                if sample:
                    result.samples_by_type[gen_type] = result.samples_by_type.get(gen_type, 0) + 1

        # Calculate success rates and average quality
        for gen_type in self.generators.keys():
            total = len(result.comparisons)
            successes = result.samples_by_type.get(gen_type, 0)
            result.success_rates[gen_type] = successes / total if total > 0 else 0

            qualities = [c.quality_scores.get(gen_type, 0) for c in result.comparisons if c.quality_scores.get(gen_type)]
            result.avg_quality[gen_type] = sum(qualities) / len(qualities) if qualities else 0

        result.duration_seconds = time.time() - start_time
        return result

    async def generate_unified_dataset(
        self,
        output_dir: Path,
        limit_per_type: int = 500,
        include_types: Optional[list[str]] = None,
    ) -> dict[str, int]:
        """Generate a unified dataset with samples from all generators.

        Args:
            output_dir: Directory to save output files
            limit_per_type: Max samples per generator type
            include_types: Which types to include (None = all)

        Returns:
            Dict mapping type to sample count
        """
        await self.setup()

        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)

        include_types = include_types or list(self.generators.keys())
        counts = {}

        # Generate samples for each type
        for gen_type in include_types:
            if gen_type not in self.generators:
                continue

            generator = self.generators[gen_type]
            items = await generator.extract_source_items()

            # Apply task-specific filtering if available
            if hasattr(generator, 'filter_items_for_task'):
                items = generator.filter_items_for_task(items)

            items = items[:limit_per_type]

            output_file = output_dir / f"asm_{gen_type}.jsonl"
            sample_count = 0

            with open(output_file, 'w') as f:
                for i, item in enumerate(items):
                    if i % 50 == 0:
                        logger.info(f"[{gen_type}] Progress: {i}/{len(items)}")

                    try:
                        sample = await generator.generate_sample(item)
                        if sample:
                            f.write(json.dumps(sample.to_dict()) + '\n')
                            sample_count += 1
                    except Exception as e:
                        logger.warning(f"[{gen_type}] Failed on {item.name}: {e}")

            counts[gen_type] = sample_count
            logger.info(f"[{gen_type}] Generated {sample_count} samples -> {output_file}")

        # Also create merged file
        merged_file = output_dir / "asm_all_types.jsonl"
        total = 0
        with open(merged_file, 'w') as out:
            for gen_type in include_types:
                type_file = output_dir / f"asm_{gen_type}.jsonl"
                if type_file.exists():
                    with open(type_file, 'r') as f:
                        for line in f:
                            out.write(line)
                            total += 1

        logger.info(f"Merged {total} samples -> {merged_file}")
        counts['_merged'] = total

        return counts

    def print_comparison_report(self, result: SynthesisResult, detailed: bool = False):
        """Print a formatted comparison report."""
        print(result.summary())

        if detailed and result.comparisons:
            print("\n" + "=" * 60)
            print("DETAILED COMPARISONS (first 3 items)")
            print("=" * 60)

            for comp in result.comparisons[:3]:
                print(f"\n--- {comp.item_name} ({comp.item_address}) ---")
                for gen_type, sample in comp.samples.items():
                    quality = comp.quality_scores.get(gen_type, 0)
                    time_ms = comp.generation_times.get(gen_type, 0) * 1000
                    if sample:
                        print(f"\n[{gen_type}] (quality: {quality:.2f}, time: {time_ms:.0f}ms)")
                        print(f"  Instruction: {sample.instruction[:80]}...")
                    else:
                        print(f"\n[{gen_type}] FAILED")


async def run_quick_comparison():
    """Quick test comparing all generators on 5 items."""
    synth = AsmSynthesizer()
    result = await synth.run_comparison(limit=5)
    synth.print_comparison_report(result, detailed=True)
    return result


async def generate_full_dataset(output_path: str = None):
    """Generate full unified dataset with all task types."""
    if output_path is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = Path.home() / ".context" / "training" / "datasets" / f"asm_unified_{timestamp}"

    synth = AsmSynthesizer()
    counts = await synth.generate_unified_dataset(
        output_dir=Path(output_path),
        limit_per_type=300,  # 300 per type = 1500 total
    )

    print("\nDataset Generation Complete!")
    for gen_type, count in counts.items():
        print(f"  {gen_type}: {count} samples")

    return counts


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--full":
        # Full dataset generation
        asyncio.run(generate_full_dataset())
    else:
        # Quick comparison
        asyncio.run(run_quick_comparison())

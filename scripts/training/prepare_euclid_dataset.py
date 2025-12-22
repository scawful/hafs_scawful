#!/usr/bin/env python3
"""Prepare euclid-asm training dataset by merging all ASM samples.

This script:
1. Collects samples from multiple generation runs
2. Deduplicates based on instruction similarity
3. Splits into train/val/test (80/10/10)
4. Exports in Unsloth-compatible format

Usage:
    python prepare_euclid_dataset.py --output ~/training_data/euclid_asm
"""

import argparse
import json
import random
import hashlib
from pathlib import Path
from datetime import datetime
from collections import defaultdict


def load_jsonl(path: Path) -> list[dict]:
    """Load samples from a JSONL file."""
    samples = []
    if not path.exists():
        return samples
    with open(path, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    samples.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return samples


def hash_instruction(instruction: str) -> str:
    """Create a hash of the instruction for deduplication."""
    # Normalize whitespace and lowercase for comparison
    normalized = ' '.join(instruction.lower().split())
    return hashlib.md5(normalized.encode()).hexdigest()[:16]


def deduplicate_samples(samples: list[dict], similarity_threshold: float = 0.9) -> list[dict]:
    """Remove duplicate samples based on instruction similarity."""
    seen_hashes = set()
    unique_samples = []

    for sample in samples:
        instruction = sample.get('instruction', '')
        h = hash_instruction(instruction)

        if h not in seen_hashes:
            seen_hashes.add(h)
            unique_samples.append(sample)

    return unique_samples


def convert_to_alpaca(sample: dict) -> dict:
    """Convert sample to Alpaca instruction format."""
    return {
        "instruction": sample.get("instruction", ""),
        "input": sample.get("input", ""),
        "output": sample.get("output", ""),
    }


def split_dataset(samples: list[dict], train_ratio: float = 0.8, val_ratio: float = 0.1):
    """Split samples into train/val/test sets."""
    random.shuffle(samples)

    n = len(samples)
    train_end = int(n * train_ratio)
    val_end = train_end + int(n * val_ratio)

    return {
        "train": samples[:train_end],
        "val": samples[train_end:val_end],
        "test": samples[val_end:],
    }


def save_jsonl(samples: list[dict], path: Path):
    """Save samples to JSONL file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w') as f:
        for sample in samples:
            f.write(json.dumps(sample) + '\n')


def main():
    parser = argparse.ArgumentParser(description="Prepare euclid-asm training dataset")
    parser.add_argument("--output", type=str, required=True, help="Output directory")
    parser.add_argument("--datasets-dir", type=str,
                       default=str(Path.home() / ".context" / "training" / "datasets"),
                       help="Directory containing generated datasets")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    args = parser.parse_args()

    random.seed(args.seed)
    output_dir = Path(args.output)
    datasets_dir = Path(args.datasets_dir)

    print("=" * 60)
    print("EUCLID-ASM DATASET PREPARATION")
    print("=" * 60)
    print(f"Datasets directory: {datasets_dir}")
    print(f"Output directory: {output_dir}")
    print()

    # Collect all samples
    all_samples = []
    stats = defaultdict(int)

    # Find all dataset directories
    for dataset_path in sorted(datasets_dir.iterdir()):
        if not dataset_path.is_dir():
            continue

        # Look for JSONL files
        for jsonl_file in dataset_path.glob("*.jsonl"):
            samples = load_jsonl(jsonl_file)

            # Filter for ASM-related samples
            asm_samples = [s for s in samples if 'asm' in s.get('domain', '').lower()
                          or 'asm' in jsonl_file.stem.lower()]

            if asm_samples:
                print(f"  {jsonl_file.name}: {len(asm_samples)} ASM samples")
                all_samples.extend(asm_samples)
                stats[dataset_path.name] += len(asm_samples)

    # Also check for standalone synthesis outputs
    synthesis_patterns = [
        "asm_unified_*",
        "asm_base.jsonl",
        "asm_debug.jsonl",
        "asm_optimize.jsonl",
        "asm_hook.jsonl",
        "asm_doc.jsonl",
        "asm_all_types.jsonl",
    ]

    for pattern in synthesis_patterns:
        for jsonl_file in datasets_dir.glob(f"**/{pattern}"):
            if jsonl_file.is_file() and jsonl_file.suffix == '.jsonl':
                samples = load_jsonl(jsonl_file)
                if samples:
                    print(f"  {jsonl_file.relative_to(datasets_dir)}: {len(samples)} samples")
                    all_samples.extend(samples)
                    stats[str(jsonl_file.relative_to(datasets_dir))] += len(samples)

    print()
    print(f"Total samples collected: {len(all_samples)}")

    # Deduplicate
    print("\nDeduplicating...")
    unique_samples = deduplicate_samples(all_samples)
    print(f"After deduplication: {len(unique_samples)} samples")
    print(f"Removed {len(all_samples) - len(unique_samples)} duplicates")

    # Convert to Alpaca format
    print("\nConverting to Alpaca format...")
    alpaca_samples = [convert_to_alpaca(s) for s in unique_samples]

    # Filter out empty samples
    valid_samples = [s for s in alpaca_samples
                    if s['instruction'].strip() and s['output'].strip()]
    print(f"Valid samples (non-empty): {len(valid_samples)}")

    # Split dataset
    print("\nSplitting dataset (80/10/10)...")
    splits = split_dataset(valid_samples)

    print(f"  Train: {len(splits['train'])} samples")
    print(f"  Val:   {len(splits['val'])} samples")
    print(f"  Test:  {len(splits['test'])} samples")

    # Save splits
    print(f"\nSaving to {output_dir}/")
    for split_name, split_samples in splits.items():
        save_jsonl(split_samples, output_dir / f"{split_name}.jsonl")
        print(f"  Saved {split_name}.jsonl")

    # Save metadata
    metadata = {
        "created": datetime.now().isoformat(),
        "model": "euclid-asm",
        "total_samples": len(valid_samples),
        "splits": {k: len(v) for k, v in splits.items()},
        "sources": dict(stats),
        "deduplication": {
            "original": len(all_samples),
            "after": len(unique_samples),
            "removed": len(all_samples) - len(unique_samples),
        },
    }

    with open(output_dir / "metadata.json", 'w') as f:
        json.dump(metadata, f, indent=2)
    print("  Saved metadata.json")

    print()
    print("=" * 60)
    print("DATASET READY FOR TRAINING")
    print("=" * 60)
    print(f"Location: {output_dir}")
    print(f"Train: {len(splits['train'])} | Val: {len(splits['val'])} | Test: {len(splits['test'])}")
    print()
    print("Next steps:")
    print(f"  1. Copy to medical-mechanica:")
    print(f"     scp -r {output_dir} scawful@100.104.53.21:D:/training/")
    print(f"  2. Run training:")
    print(f"     python train_euclid_asm.py --dataset D:/training/{output_dir.name}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Quick dataset generation test - 50 samples only."""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "hafs" / "src"))

from agents.training.curator import DataCurator


async def main():
    print("Quick Dataset Generation Test (50 samples)")
    print("=" * 60)

    curator = DataCurator()
    await curator.setup()
    print("✓ Curator initialized")

    # Just use ASM generator with templates
    from hafs_scawful.generators.asm_generator import AsmDataGenerator
    asm_gen = AsmDataGenerator(use_template_variation=True)
    await asm_gen.setup()
    curator.register_generator("asm", asm_gen)
    print("✓ ASM generator registered")

    # Try Zelda3 generator
    try:
        from hafs_scawful.generators.zelda3_generator import Zelda3DisasmGenerator
        zelda3_gen = Zelda3DisasmGenerator(use_template_variation=True)
        await zelda3_gen.setup()
        curator.register_generator("zelda3", zelda3_gen)
        print("✓ Zelda3 generator registered")
    except Exception as e:
        print(f"⚠ Zelda3 generator failed: {e}")

    print("\nGenerating 50 samples...")
    result = await curator.curate_dataset(
        domains=curator.list_domains(),
        target_count=50,
        quality_threshold=None,
        balance_domains=True,
        output_name="quick_test",
        resume=False,
    )

    print("\nResults:")
    print(f"  Total Generated: {result.stats.total_generated}")
    print(f"  Passed Quality:  {result.stats.passed_quality}")
    print(f"  Augmented:       {result.stats.augmented}")
    print(f"  Final Count:     {result.stats.final_count}")
    print(f"  Duration:        {result.stats.duration_seconds:.1f}s")

    if result.stats.total_generated > 0:
        acceptance = (result.stats.passed_quality / result.stats.total_generated) * 100
        rejection = 100 - acceptance
        print(f"\n  Acceptance Rate: {acceptance:.1f}%")
        print(f"  Rejection Rate:  {rejection:.1f}% (baseline: 85%, target: <20%)")

    print(f"\nOutput: {result.output_dir}")


if __name__ == "__main__":
    asyncio.run(main())

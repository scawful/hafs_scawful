#!/usr/bin/env python3
"""Check what files we have from zelda3."""

import asyncio
from collections import Counter

from hafs_scawful.scripts.bootstrap import ensure_hafs_on_path

ensure_hafs_on_path()

from agents.training.resource_discovery import ZeldaResourceIndexer


async def main():
    indexer = ZeldaResourceIndexer()
    result = indexer.load_index()

    # Get zelda3 files
    zelda3_files = [f for f in indexer._files if "zelda3" in f.source_dir]

    print(f"Total zelda3 files: {len(zelda3_files)}")
    print()

    # By type
    by_type = Counter(f.file_type for f in zelda3_files)
    print("By type:")
    for ftype, count in by_type.most_common():
        print(f"  {ftype:15s}: {count:4d} files")
    print()

    # Show some examples
    print("Example files:")
    for i, f in enumerate(zelda3_files[:15], 1):
        print(f"{i}. [{f.file_type}] {f.relative_path}")


if __name__ == "__main__":
    asyncio.run(main())

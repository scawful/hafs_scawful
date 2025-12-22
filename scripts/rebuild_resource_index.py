#!/usr/bin/env python3
"""Rebuild the Zelda resource index used by HAFS Studio."""

from __future__ import annotations

import asyncio
import importlib.util
from pathlib import Path


HAFS_SRC = Path.home() / "Code" / "hafs" / "src"
RESOURCE_DISCOVERY_PATH = HAFS_SRC / "agents" / "training" / "resource_discovery.py"


async def main() -> int:
    if not RESOURCE_DISCOVERY_PATH.exists():
        raise FileNotFoundError(f"Missing resource_discovery.py at {RESOURCE_DISCOVERY_PATH}")

    spec = importlib.util.spec_from_file_location("resource_discovery", RESOURCE_DISCOVERY_PATH)
    if not spec or not spec.loader:
        raise RuntimeError("Failed to load resource_discovery module spec")

    module = importlib.util.module_from_spec(spec)
    import sys
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    ZeldaResourceIndexer = module.ZeldaResourceIndexer

    indexer = ZeldaResourceIndexer()
    result = await indexer.discover_and_index()

    print("Indexed {} files from {} sources".format(result.total_files, len(result.by_source)))
    for name, count in sorted(result.by_source.items(), key=lambda item: item[1], reverse=True)[:10]:
        print("  {}: {}".format(name, count))
    print("Index saved to {}".format(indexer.index_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))

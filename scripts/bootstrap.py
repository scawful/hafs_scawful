"""Script bootstrap helpers for hafs_scawful."""

from __future__ import annotations

import os
import sys
from pathlib import Path


def ensure_hafs_on_path() -> None:
    """Ensure the hafs core src/ directory is on sys.path."""
    candidates: list[Path] = []
    env_root = os.environ.get("HAFS_ROOT")
    if env_root:
        candidates.append(Path(env_root).expanduser() / "src")

    # Assume sibling checkout (../hafs)
    candidates.append(Path(__file__).resolve().parents[2] / "hafs" / "src")

    for candidate in candidates:
        if candidate.exists() and str(candidate) not in sys.path:
            sys.path.insert(0, str(candidate))
            return

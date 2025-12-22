#!/usr/bin/env python3
"""Build a curated hack summary JSON for HAFS Studio review."""

from __future__ import annotations

import fnmatch
import json
import random
import re
from datetime import datetime, timezone
from pathlib import Path


CONFIG_PATH = Path.home() / "Code" / "hafs_scawful" / "config" / "curated_hacks.toml"
OVERRIDE_PATH = (
    Path.home() / "Code" / "hafs_scawful" / "config" / "curated_hacks_overrides.toml"
)
OUTPUT_PATH = Path.home() / ".context" / "training" / "curated_hacks.json"


ORG_PATTERN = re.compile(r"\borg\b", re.IGNORECASE)
ADDR_PATTERN = re.compile(r"(\$[0-9A-Fa-f]{2}:[0-9A-Fa-f]{4}|\$[0-9A-Fa-f]{4,6})")


def _is_excluded(path: Path, exclude_globs: list[str]) -> bool:
    path_str = str(path)
    return any(fnmatch.fnmatch(path_str, pattern) for pattern in exclude_globs)


def _matches_globs(rel_path: str, globs: list[str]) -> bool:
    return any(fnmatch.fnmatch(rel_path, pattern) for pattern in globs)


def _load_config() -> dict:
    import tomllib

    if not CONFIG_PATH.exists():
        raise FileNotFoundError(f"Config not found: {CONFIG_PATH}")

    with CONFIG_PATH.open("rb") as f:
        config = tomllib.load(f)

    if OVERRIDE_PATH.exists():
        with OVERRIDE_PATH.open("rb") as f:
            overrides = tomllib.load(f)
        _apply_overrides(config, overrides)

    return config


def _apply_overrides(config: dict, overrides: dict) -> None:
    if not overrides:
        return

    curated_overrides = overrides.get("curated_hacks")
    if isinstance(curated_overrides, dict):
        config.setdefault("curated_hacks", {}).update(
            {k: v for k, v in curated_overrides.items() if v is not None}
        )

    base_hacks = config.setdefault("hack", [])
    base_by_name = {
        str(h.get("name", "")).lower(): h for h in base_hacks if h.get("name")
    }

    for override in overrides.get("hack", []):
        name = str(override.get("name", "")).strip()
        if not name:
            continue

        key = name.lower()
        target = base_by_name.get(key)
        if not target:
            base_hacks.append(override)
            base_by_name[key] = override
            continue

        for field in (
            "path",
            "authors",
            "notes",
            "weight",
            "include_globs",
            "exclude_globs",
            "review_status",
        ):
            if field not in override:
                continue
            value = override.get(field)
            if value is None:
                continue
            if isinstance(value, list) and not value:
                continue
            target[field] = value


def _scan_hack(
    hack: dict,
    allowed_exts: set[str],
    global_excludes: list[str],
    max_items: int,
) -> dict:
    name = hack.get("name", "unknown")
    hack_path = Path(str(hack.get("path", ""))).expanduser()
    weight = float(hack.get("weight", 1.0))
    include_globs = hack.get("include_globs", []) or []
    exclude_globs = hack.get("exclude_globs", []) or []

    entry = {
        "name": name,
        "path": str(hack_path),
        "authors": hack.get("authors", []),
        "notes": hack.get("notes", ""),
        "review_status": hack.get("review_status", ""),
        "weight": weight,
        "include_globs": include_globs,
        "exclude_globs": exclude_globs,
        "eligible_files": 0,
        "selected_files": 0,
        "org_ratio": 0.0,
        "address_ratio": 0.0,
        "avg_comment_ratio": 0.0,
        "sample_files": [],
        "status": "ok",
        "error": "",
    }

    if not hack_path.exists():
        entry["status"] = "missing"
        entry["error"] = "path_not_found"
        return entry

    eligible = []
    content_cache: dict[Path, str] = {}
    for path in hack_path.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in allowed_exts:
            continue
        if _is_excluded(path, global_excludes):
            continue

        rel_path = path.relative_to(hack_path).as_posix()
        if include_globs and not _matches_globs(rel_path, include_globs):
            continue
        if exclude_globs and _matches_globs(rel_path, exclude_globs):
            continue

        try:
            content = path.read_text(errors="ignore")
        except Exception:
            continue

        if not ORG_PATTERN.search(content) and not ADDR_PATTERN.search(content):
            continue

        content_cache[path] = content
        eligible.append(path)

    eligible = sorted(eligible)
    entry["eligible_files"] = len(eligible)

    capped = eligible[:max_items] if max_items and len(eligible) > max_items else eligible

    if weight < 1.0 and capped:
        target = max(1, int(len(capped) * weight))
        rng = random.Random(name)
        selected = rng.sample(capped, target) if target < len(capped) else capped
    else:
        selected = capped

    entry["selected_files"] = len(selected)
    entry["sample_files"] = [
        path.relative_to(hack_path).as_posix() for path in selected[:5]
    ]

    if not selected:
        return entry

    org_hits = 0
    addr_hits = 0
    comment_ratio_sum = 0.0

    for path in selected:
        text = content_cache.get(path)
        if text is None:
            try:
                text = path.read_text(errors="ignore")
            except Exception:
                continue

        if ORG_PATTERN.search(text):
            org_hits += 1
        if ADDR_PATTERN.search(text):
            addr_hits += 1

        lines = text.splitlines()
        if not lines:
            continue
        comment_lines = sum(1 for line in lines if line.strip().startswith(";"))
        comment_ratio_sum += comment_lines / max(len(lines), 1)

    total = max(len(selected), 1)
    entry["org_ratio"] = org_hits / total
    entry["address_ratio"] = addr_hits / total
    entry["avg_comment_ratio"] = comment_ratio_sum / total

    return entry


def main() -> int:
    config = _load_config()

    curated = config.get("curated_hacks", {})
    allowed_exts = {ext.lower() for ext in curated.get("extensions", [".asm", ".inc"])}
    global_excludes = curated.get("exclude_globs", [])
    max_items = int(curated.get("max_items_per_hack", 250))

    hacks = config.get("hack", [])
    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "config_path": str(CONFIG_PATH),
        "output_path": str(OUTPUT_PATH),
        "hacks": [
            _scan_hack(hack, allowed_exts, global_excludes, max_items)
            for hack in hacks
        ],
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(summary, indent=2))
    print(f"Wrote curated hack summary to {OUTPUT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

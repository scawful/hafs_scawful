#!/usr/bin/env python3
"""Send agent notifications via Halext and/or terminal mail."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tomllib
import urllib.error
import urllib.request
from pathlib import Path


def load_config(config_path: Path) -> dict:
    if not config_path.exists():
        return {}
    with config_path.open("rb") as handle:
        return tomllib.load(handle)


def get_flag(value: bool | None, default: bool) -> bool:
    if value is None:
        return default
    return value


def send_halext(message: str, subject: str, config: dict, dry_run: bool) -> bool:
    halext = config.get("notify", {}).get("halext", {})
    if not get_flag(None, bool(halext.get("enabled", False))):
        return False

    api_base = halext.get("api_base", "").rstrip("/")
    sender = halext.get("sender_username")
    target = halext.get("target_username")
    token = halext.get("token") or os.environ.get(halext.get("token_env", ""))

    if not api_base or not sender or not target or not token:
        print("Halext notify missing api_base/sender/target/token; skipping.", file=sys.stderr)
        return False

    payload = {
        "username": target,
        "content": f"{subject}\n\n{message}".strip(),
        "model": None,
    }
    url = f"{api_base}/messages/quick"
    if dry_run:
        print(f"[dry-run] POST {url} -> {payload}")
        return True

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status >= 200 and resp.status < 300:
                return True
    except urllib.error.HTTPError as exc:
        print(f"Halext notify failed: {exc}", file=sys.stderr)
    except urllib.error.URLError as exc:
        print(f"Halext notify error: {exc}", file=sys.stderr)
    return False


def send_mail(message: str, subject: str, config: dict, dry_run: bool) -> bool:
    mail_cfg = config.get("notify", {}).get("terminal_mail", {})
    if not get_flag(None, bool(mail_cfg.get("enabled", False))):
        return False

    command = mail_cfg.get("command", "mail")
    recipient = mail_cfg.get("to")
    if not recipient:
        print("Terminal mail missing recipient; skipping.", file=sys.stderr)
        return False

    if dry_run:
        print(f"[dry-run] {command} -s '{subject}' {recipient}")
        return True

    try:
        subprocess.run(
            [command, "-s", subject, recipient],
            input=message.encode("utf-8"),
            check=True,
        )
        return True
    except (OSError, subprocess.CalledProcessError) as exc:
        print(f"Terminal mail failed: {exc}", file=sys.stderr)
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Send hAFS agent notifications.")
    parser.add_argument("message", nargs="+", help="Message body")
    parser.add_argument("--subject", default="hAFS Agent Message", help="Message subject")
    parser.add_argument("--config", dest="config_path", default=None, help="Path to plugin config.toml")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be sent")
    args = parser.parse_args()

    config_path = Path(
        args.config_path
        or os.environ.get("HAFS_PLUGIN_CONFIG", "")
        or Path(__file__).resolve().parents[1] / "config.toml"
    )
    config = load_config(config_path)

    message = " ".join(args.message).strip()
    if not message:
        print("Message cannot be empty.", file=sys.stderr)
        return 1

    sent = False
    sent |= send_halext(message, args.subject, config, args.dry_run)
    sent |= send_mail(message, args.subject, config, args.dry_run)

    if not sent:
        print("No notifications sent (check config).", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

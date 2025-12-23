# hafs_scawful

Machine-specific plugin repo for your hafs setup. This keeps hostnames, paths,
credentials, and operational scripts out of the main `hafs` repo.

## Layout

```
hafs_scawful/
├── config/                  # Machine-specific configurations
│   ├── config.toml          # Main plugin config
│   ├── training_paths.toml  # Source paths for generators
│   ├── training_resources.toml
│   └── curated_hacks.toml   # ROM hack allowlist
├── generators/              # Domain-specific training generators
│   ├── asm_generator.py     # ALTTP ASM from KB
│   ├── zelda3_generator.py  # Vanilla disassembly
│   ├── oracle_generator.py  # Oracle-of-Secrets
│   ├── curated_hack_generator.py
│   └── ...
├── scripts/                 # Deployment and workflow scripts
├── docs/                    # Personal docs and runbooks
│   └── infrastructure/      # Machine setup docs
├── config.toml              # Single-source plugin config (paths/hosts/env)
├── aliases.sh               # Shell aliases (loads config.toml)
├── install.sh               # Optional install helper
└── README.md
```

## Install

```bash
mkdir -p ~/.config/hafs/plugins
ln -s ~/Code/hafs_scawful ~/.config/hafs/plugins/hafs_scawful
```

## Usage

Most scripts assume you run from the main repo:

```bash
cd ~/Code/hafs
PYTHONPATH=src .venv/bin/python -m agents.background.website_health_monitor \
    --config ~/Code/hafs_scawful/config/website_monitoring_agents.toml
```

Load aliases and env:

```bash
source ~/.config/hafs/plugins/hafs_scawful/aliases.sh
```

## Agent Quickstart

- See `AGENTS.md` for host inventory, paths, and aliases.
- Host summary lives in `docs/MEDICAL_MECHANICA_SETUP_SUMMARY.md`.

Mobile SSH shorthands (examples):
```bash
hc        # chat with agents
htw       # watch training status
hn        # node health
hsvc      # services list
hmsg "Training finished"   # send agent message
hpsync    # sync plugin to halext + Windows
```

## Sync to Hosts

Push plugin configs/docs to halext-server and the Windows GPU host:

```bash
~/Code/hafs_scawful/scripts/publish_plugin_configs.sh
```

Options:
- `DRY_RUN=1` to preview changes
- `SYNC_ITEMS=config,docs,config.toml,aliases.sh` to choose what syncs
- `SYNC_ALL=1` to include scripts
- `USE_MOUNTS=1` to copy via `~/Mounts` (default), set `USE_MOUNTS=0` for SSH
 - `PLUGIN_CONFIG=~/Code/hafs_scawful/config.toml` to override sync settings

## Agent Messaging

`scripts/notify_agent_message.py` can deliver agent messages to Halext (iOS app)
and/or your terminal mail system. Configure the `[notify]` section in
`config.toml`, then use:

```bash
hmsg "Campaign finished with 1.2K samples"
```

## Notes

- Keep this repo private.
- Update configs here, not in `~/Code/hafs`.

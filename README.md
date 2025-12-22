# hafs_scawful

Machine-specific plugin repo for your hafs setup. This keeps hostnames, paths,
credentials, and operational scripts out of the main `hafs` repo.

## Layout

```
hafs_scawful/
├── config/                  # Machine-specific configurations
├── scripts/                 # Deployment and workflow scripts
├── docs/                    # Personal docs and runbooks
├── aliases.sh               # Optional shell aliases
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

## Notes

- Keep this repo private.
- Update configs here, not in `~/Code/hafs`.

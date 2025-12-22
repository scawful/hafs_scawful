# Agent Message Routing (scawful)

This plugin wires hAFS agent updates into Halext (iOS app) and local terminal mail.

## Current Wiring

- **Sender account:** `hafs-agent`
- **Target account:** `scawful`
- **API base:** `https://api.halext.org`
- **Token env:** `HALEXT_AGENT_TOKEN`

## Usage

```bash
hmsg "Campaign finished with 1.2K samples"
```

## Token Setup

Set a Bearer token for the `hafs-agent` account:

```bash
export HALEXT_AGENT_TOKEN="eyJhbGciOi..."
```

## Terminal Mail

Uses the `mail` command with recipient `scawful`. Update the `[notify.terminal_mail]`
block in `config.toml` if you want a different mail command or recipient.

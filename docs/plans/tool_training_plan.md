# Tool Training Plan

**Status:** Draft
**Date:** 2025-12-22
**Context:** Improving agent tool proficiency for `z3ed` and `hafs`.

## Overview
Current training focuses on Domain Knowledge (ASM, ROM hacking). We need to add a "Tooling" domain to teach agents how to correctly invoke the CLI tools and workflows specific to this environment.

## 1. Z3ed Tooling (Paused)
*Note: Paused pending binary refactoring.*

**Goal:** Teach agents to use `z3ed` CLI for ROM editing and querying.
**Data Sources:**
*   `yaze/docs/public/reference/z3ed-command-reference.md`
*   `yaze/docs/public/usage/z3ed-cli.md`
*   `yaze/docs/public/guides/z3ed-workflows.md`
*   `yaze/src/app/test/z3ed_test_suite.cc` (C++ test cases as usage examples)

**Generator Strategy:**
*   Parse Markdown command references into `(instruction, command)` pairs.
*   Use "Self-Play/Teacher" model to generate natural language variations of commands.
*   Extract workflow scripts into multi-turn samples.

## 2. AFS (Agentic File System) Tooling (Implemented)
**Goal:** Teach agents to use the `hafs` ecosystem, `ctx` context tools, and local aliases.

**Data Sources:**
*   **Documentation:** `hafs/README.md`, `hafs_scawful/README.md`.
*   **Scripts:** `hafs/scripts/`, `hafs_scawful/scripts/`.
*   **Aliases:** `hafs_scawful/aliases.sh`.
*   **Config:** `hafs.toml` (understanding project structure).

**Generator:** `HafsSystemGenerator`
**Location:** `hafs_scawful/generators/hafs_generator.py`
**Status:** Implemented and Verified (2025-12-22).

### Data Extraction Strategy
1.  **Alias Expansion:**
    *   Input: "Check the status of the training."
    *   Output: `htw` (which maps to `watch ...`).
    *   Method: Hardcoded alias map in generator.

2.  **Script Usage:**
    *   Input: "Sync plugin configs to the Windows node."
    *   Output: `~/Code/hafs_scawful/scripts/publish_plugin_configs.sh`
    *   Method: Manual selection of high-value scripts.

3.  **Context Management:**
    *   Input: "I need to look at the ASM knowledge base."
    *   Output: `ctx mount knowledge/asm`
    *   Method: Conceptual mapping in generator.

4.  **Knowledge & Search:**
    *   Input: "Search history for 'database migration'."
    *   Output: `hafs-cli history search "database migration"`
    *   Method: Added specific tools for history, context, memory, and Hyrule Historian.

## Implementation Steps
1.  **Analyze Sources:** [Complete] Scan `hafs` scripts and `aliases.sh` to inventory capabilities.
2.  **Build Generator:** [Complete] Implement `HafsSystemGenerator` in `hafs_scawful`.
3.  **Generate Samples:** [Complete] Run generator to create `hafs_tooling_dataset.jsonl` (26 samples).
4.  **Train:** [Pending] Fine-tune the model (e.g., Qwen-Coder) on this new dataset.

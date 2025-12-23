# master-sword: Unified Model Plan (hafs_scawful)

Updated: 2025-12-22
Status: Active (small-model first)
Canonical: This doc is the source of truth for training plans in hafs_scawful.

## Goals
- Build reliable small specialists first (tool-use, ASM, LSP).
- Use oracle-council routing to combine specialists and MoE outputs.
- Keep a clear path toward unified models without blocking near-term delivery.

## Model Hierarchy

oracle-council (router)
  oracle-din (Power, technical)
    - euclid-asm
    - seph-tilesmith
    - koume-compress
    - kotake-decompress
    - agahnim-patcher
  oracle-nayru (Wisdom, knowledge)
    - kaepora-teacher
    - nayru-lorekeeper
    - gossip-stone (code intelligence and lookup)
  oracle-farore (Courage, creation)
    - farore-questweaver
    - saria-voice
    - zelda-scribe

MoE systems:
- oracle-moe (oracle-din / oracle-nayru / oracle-farore)
- triforce-moe (goddess-din / goddess-nayru / goddess-farore)

Unified models:
- master-sword (mid-term unified model)
- fierce-deity (long-term unified model, ambitious parameter size)

Naming rule: submodels never include the oracle- prefix. goddess-* are MoE experts.

## Near-Term Priorities (Small Models)
1) Tool-use specialist (3B)
2) ASM specialist: euclid-asm (1.5B)
3) LSP / code-intel specialist (1.5B or 3B)

Base model sizes:
- 1.5B for euclid-asm
- 3B for tool-use and LSP

## Domain Taxonomy (Canonical)
- asm_core
- asm_debug
- asm_optimize
- asm_hook
- asm_doc
- alttp_historical
- oracle_mod
- yaze_cpp
- tools_hafs
- tools_yaze_mcp
- tools_z3ed
- code_intel_lsp
- docs_explain (optional)

## Data Sources and Focus
- Primary ASM banks: 00, 01, 02, 07, and sprite logic banks.
- Data-only banks: use for embeddings, knowledge, and preprocessing only.
- Rename gigaleak -> alttp_historical in docs and future datasets.

## Dataset Sizing (Small Models First)
Pilot: 3k-5k samples
First real run: 12k samples
  - ASM (all asm_*): 8k
  - Tool-use: 2k
  - LSP: 2k

Large campaigns: >=15k samples and use autonomous pipeline.

## Validation Strategy
ASM domains:
- AsmPreprocessor enrichment
- AsarValidator syntax checks
- Optional behavioral validation for high-value routines

Tool-use and LSP domains:
- Schema checks
- Deterministic replay of tool calls
- Argument extraction tests

## Storage Layout (Windows)
Root: D:\hafs_training

Suggested structure:
```
D:\hafs_training\
  datasets\
    raw\
      asm\
      alttp_historical\
      oracle_mod\
      tools\
      lsp\
    curated\
      asm\
      tools\
      lsp\
    exports\
      qwen\
      phi\
  runs\
    2025-12-xx_asm_12k\
    2025-12-xx_tools_2k\
  models\
    adapters\
    merged\
  eval\
    benchmarks\
    reports\
  logs\
```

## MoE vs Unified Usage
- Use oracle-council routing for most tasks until unified models are ready.
- Use oracle-moe for blended tasks across oracle families.
- Use triforce-moe for goddess-variant synthesis.
- Use master-sword for cross-domain tasks when it is trained.
- fierce-deity is the long-term successor for full integration.

## Roadmap
Phase 1: Small models (current)
- Train euclid-asm (1.5B)
- Train tool-use specialist (3B)
- Train LSP specialist (1.5B or 3B)

Phase 2: Expand specialists
- seph-tilesmith
- compression specialists
- lore and documentation specialists
- oracle-moe assembly
- goddess-din / goddess-nayru / goddess-farore
- triforce-moe assembly

Phase 3: Unified model
- master-sword (unified mid-term)

Phase 4: Long-term unified model
- fierce-deity (successor to master-sword)

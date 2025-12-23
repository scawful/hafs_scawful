# Master Sword Plan (hafs_scawful)

Updated: 2025-12-23
Status: Active (small-model first)
Canonical: This doc is the source of truth for training plans in hafs_scawful.

## Goals
- Build reliable small specialists first (tool-use, ASM, LSP).
- Use oracle-council selections to combine specialists and MoE outputs.
- Keep a clear path toward master-sword without blocking near-term delivery.

## The Three Families (Tiers)

### 1. Oracle Family (Small)
Small-parameter specialists managed by the council.
- **Council**: `oracle-council` selections.
- **Technical**: `euclid-asm`, `seph-tilesmith`.
- **Knowledge**: `impa-scribe`, `kaepora-teacher`.
- **Creation**: `farore-questweaver`, `ocarina-maestro`, `wind-waker`.

### 2. ALTTP Family (Medium)
Integrated ROM hacking models focused on technical depth.
- **Primary Path**: Din-specialist data + `alttp_historical`.
- **Primary Model**: **master-sword**.

### 3. Masks Family (Large)
Narrative-heavy models focused on complex lore and world-building.
- **Primary Path**: Nayru/Farore data + Masks-series material.
- **Primary Models**: **majora-mask**, **fierce-deity**.

Naming rule: specialists (submodels) never include the oracle- prefix. goddess-* are MoE experts.

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
- oracle_secrets_hack
- yaze_cpp
- tools_hafs
- tools_yaze_mcp
- tools_z3ed
- code_intel_lsp
- docs_explain (optional)

## Data Sources and Focus
- Primary ASM banks: 00, 01, 02, 07, and sprite logic banks.
- Data-only banks: use for embeddings, knowledge, and preprocessing only.
- Rename alttp_historical -> alttp_historical in docs and future datasets.

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
      oracle_secrets_hack\
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

## Usage
- Use oracle-council for most tasks until master-sword is ready.
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

Phase 3: Master Sword
- master-sword (integrated mid-term)

Phase 4: Final Stage
- fierce-deity (successor to master-sword)

# Model Catalog (hafs_scawful)

Updated: 2025-12-22
Purpose: align naming, active plans, and idea pools under the new model paradigm.

## Naming Rules
- **Oracle (Small)**: Families use the oracle- prefix; specialists do not.
- **Master Sword (Medium)**: Named directly (e.g., master-sword).
- **Fierce Deity (Large)**: Named directly (e.g., fierce-deity, majora-mask).
- MoE names end with -moe; goddess-* are reserved for triforce-moe.

## System Layer (Routing + MoE)
- oracle-council: router and policy model.
- oracle-moe: MoE over oracle-din / oracle-nayru / oracle-farore.
  - oracle-din: technical expert routing.
  - oracle-nayru: knowledge expert routing.
  - oracle-farore: creation expert routing.
- triforce-moe: MoE over goddess-din / goddess-nayru / goddess-farore.
  - goddess-din: technical expert.
  - goddess-nayru: knowledge expert.
  - goddess-farore: creation expert.

## The Three Families (Tiers)

### 1. Oracle Family (Small/Specialist)
- **Hierarchy**: `oracle-council` -> `oracle-din/nayru/farore` -> Specialists.
- **Focus**: Fast, domain-specific execution (1.5B - 7B).
- **Components**: `euclid-asm`, `impa-scribe`, `sheikah-slate`, etc.

### 2. ALTTP Family (Medium/Integrated)
- **Primary Model**: **master-sword**.
- **Focus**: Cross-domain synthesis and technical-heavy ROM hacking (7B - 14B).
- **Progression**: Leverages Din-family and alttp_historical data.

### 3. Masks Family (Large/Narrative)
- **Primary Models**: **majora-mask**, **fierce-deity**.
- **Focus**: Narrative depth, complex lore, and full-spectrum reasoning (30B+).
- **Progression**: Leverages Nayru/Farore knowledge and Masks-series data.

## Near-Term Small Models (Priority)
- euclid-asm (1.5B): 65816 ASM specialist.
- sheikah-slate (3B): tool-use specialist for hafs, yaze-mcp, z3ed.
- gossip-stone (1.5B or 3B): LSP / code-intel (symbols, xrefs, jumps).
- impa-scribe (1.5B or 3B): fast documentation updates.

## Specialist Pool (Planned)
Technical (oracle-din):
- euclid-asm: ASM generation and debugging.
- seph-tilesmith: tiles, sprites, palettes.
- koume-compress: compression (LC_LZ2 and related).
- kotake-decompress: decompression pipelines.
- agahnim-patcher: IPS/BPS and patch workflows.
- hookshot: hook/patch planning and freespace safety.
- hook-warden: validates bank allocation and org safety for patches.
- ocarina: music and audio tooling (SPC700, sequencing).

Knowledge (oracle-nayru):
- kaepora-teacher: code explanation and teaching.
- nayru-lorekeeper: lore and canon.
- impa-scribe: documentation updates.
- gossip-stone: quick lookup and code intelligence.
- compass: cross-repo navigation and definition lookup.
- minish-cap: compact summarizer for plan diffs and status.

Creation (oracle-farore):
- farore-questweaver: quest design and puzzle logic.
- ocarina-maestro: music, audio tooling, and SPC700 sequencing.
- wind-waker: dynamic event scripting and flag management.
- zelda-scribe: UI copy, item text, and quest logs.

## Idea Pools (Unassigned Names)
Tool-use:
- rune-bridge
- toolwright
- gatekeeper

LSP / code-intel:
- map-keeper
- indexer

## Alternative Names (Unassigned)
- sageblade
- light-arrow
- hyrule-sage
- majoras-mask

Fairy guardrail (error-avoidance):
- navi: preflight warnings and missed checks.
- tattle: highlights contradictions and naming drift.
- tael: flags risky changes and unverified claims.
- lens-of-truth: detects hallucinations and unstated assumptions.

Mask model ideas (Majora's Mask):
- mask-of-truth: verifier for claims and references.
- bunny-hood: speed-focused doc edits and quick fixes.
- keaton-mask: playful QA for inconsistencies.
- gibdo-mask: strict formatting and error-only summaries.
- garo-mask: stealth auditor for hidden contradictions.
- stone-mask: background watcher for drift.
- all-night-mask: long-context review for large docs.
- romani-mask: checklist enforcement and reliability.
- captains-hat: legacy doc navigation and deprecation tracking.
- deku-mask: lightweight rapid edits and structure fixes.
- goron-mask: stability and resilience checks.
- zora-mask: flow and readability tuning.
- fierce-deity: assigned master-sword name (listed here for theme continuity).

ALTTP themed ideas:
- ice-palace: precision validator for registers and addresses.
- turtle-rock: performance and cycle-count optimization.
- sanctuary: safe fallback responder for uncertain tasks.
- misery-mire: debugging and error forensics.
- light-world: clarity and instruction polish.
- dark-world: adversarial testing and edge cases.

## Legacy Names (Do Not Use)
- triforce-sage (replaced by master-sword)
- gigaleak (use alttp_historical for domain naming)
- rauru (replaced by euclid-asm)
- impa-archivist (replaced by impa-scribe)

# Model Training Plan

NOTE: This document is being consolidated. Source of truth:
- docs/training/oracle_farore_secrets_plan.md
- docs/training/model_catalog.md

**Updated**: 2025-12-22
**Status**: Active Development

---

## Architecture Overview

```
                    ┌─────────────────────────────────────┐
                    │          oracle-council              │
                    │    (Gemini Flash + MoE Router)       │
                    └──────────────┬──────────────────────┘
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         │                         │                         │
    ┌────▼────┐              ┌─────▼─────┐             ┌─────▼─────┐
    │oracle-  │              │ oracle-   │             │ oracle-   │
    │  din    │              │  nayru    │             │  farore   │
    │ (Power) │              │ (Wisdom)  │             │ (Courage) │
    └────┬────┘              └─────┬─────┘             └─────┬─────┘
         │                         │                         │
    ┌────▼──────────┐        ┌─────▼───────┐          ┌──────▼──────┐
    │ euclid-asm    │        │ docs/lore   │          │ oracle-of-  │
    │ seph-tilesmith│        │ explanation │          │ secrets     │
    │ koume-compress│        │ teaching    │          │ narrative   │
    └───────────────┘        └─────────────┘          └─────────────┘

                    ┌─────────────────────────────────────┐
                    │         master-sword                │
                    │   (Unified North Star Model)        │
                    │  Combines all domains in one 32B    │
                    └─────────────────────────────────────┘
```

---

## Naming Convention

### The Three Oracles (Top-Level Categories)

| Oracle | Aspect | Domain | Description |
|--------|--------|--------|-------------|
| `oracle-din` | Power | Technical Execution | ROM tooling, ASM, raw technical work |
| `oracle-nayru` | Wisdom | Knowledge | Documentation, lore, understanding |
| `oracle-farore` | Courage | Creation | Story design, quest creation, narrative |

### Specialized Models (Honoring Community)

**Under oracle-din (Power/Technical):**
| Model | Namesake | Purpose |
|-------|----------|---------|
| `euclid-asm` | ALTTP hacker Euclid | 65816 assembly, hooks, patches |
| `seph-tilesmith` | Parallel Worlds creator Seph | Tiles, sprites, graphics |
| `koume-compress` | Twinrova (Koume) | LC_LZ2 compression |
| `kotake-decompress` | Twinrova (Kotake) | Decompression pipelines |
| `agahnim-patcher` | ALTTP antagonist | IPS/BPS patch management |

**Under oracle-nayru (Wisdom/Knowledge):**
| Model | Purpose |
|-------|---------|
| `nayru-lorekeeper` | Canon, timeline, continuity |
| `impa-archivist` | Consistency checks, citations |
| `kaepora-teacher` | Code explanation, documentation |

**Under oracle-farore (Courage/Creation):**
| Model | Purpose |
|-------|---------|
| `farore-questweaver` | Quest design, world layout |
| `saria-voice` | Dialogue, character voice |
| `zelda-scribe` | UI copy, item text, quest logs |

### System Models

| Model | Purpose |
|-------|---------|
| `oracle-council` | MoE router + Gemini Flash classifier |
| `master-sword` | Unified mid-term model |
| `fierce-deity` | Long-term unified successor |

---

## Wave 1: Foundation Models (Current)

### euclid-asm (ASM Expert)

```
Full name:    euclid-asm-qwen-coder-1.5b
Base model:   Qwen2.5-Coder-1.5B
Purpose:      65816 assembly routines, hooks, patches, optimization

Task Types:
- asm_base     - General code generation
- asm_debug    - Crash analysis, debugging
- asm_optimize - Cycle counting, performance
- asm_hook     - JSL hooks, freespace patches
- asm_doc      - Code explanation, documentation
```

**Training Data:**
| Source | Samples | Description |
|--------|---------|-------------|
| ALTTP Vanilla | 1,300 | Disassembly routines |
| ALTTP historical | 2,000 | Nintendo original source |
| Oracle of Secrets | 500 | ROM hack code |
| Task Variants | 2,000 | debug/optimize/hook/doc |
| **Total** | **~6,000** | Split 80/10/10 |

**Training Config:**
```python
model = "Qwen/Qwen2.5-Coder-1.5B"
lora_rank = 16
batch_size = 4
epochs = 3
training_time = "~2 hours"
```

### seph-tilesmith (Graphics Expert)

```
Full name:    seph-tilesmith-qwen-coder-1.5b
Base model:   Qwen2.5-Coder-1.5B
Purpose:      Tiles, palettes, sprite graphics, bpp conversion
```

**Training Data:**
| Source | Samples |
|--------|---------|
| YAZE graphics API | 1,500 |
| Tile format conversions | 1,000 |
| Palette manipulation | 500 |
| **Total** | **~3,000** |

---

## Wave 2: Knowledge Models (Planned)

### kaepora-teacher (Documentation)

```
Full name:    kaepora-teacher-gemma-4b
Base model:   Gemma3-4B-it
Purpose:      Code explanation, teaching, documentation
```

Uses `asm_doc` samples from euclid-asm generator.

### nayru-lorekeeper (Lore)

```
Full name:    nayru-lorekeeper-gemma-4b
Base model:   Gemma3-4B-it
Purpose:      Zelda lore, timeline, canon consistency
```

Requires manual curation of lore dataset.

---

## Wave 3: Creation Models (Future)

### farore-questweaver (Quest Design)

```
Full name:    farore-questweaver-gemma-4b
Base model:   Gemma3-4B-it
Purpose:      Quest design, pacing, world layout
```

Requires Oracle of Secrets story dataset.

---

## Unified Model: master-sword

The unified model combining all domains.

```
Full name:    master-sword-qwen-32b
Successor:    fierce-deity
Base model:   Qwen2.5-Coder-32B (or Magistral-24B)
Purpose:      Cross-domain reasoning, unified ROM hacking assistant
```

**When to use master-sword vs MoE:**
- Use **MoE** for pure tasks (ASM-only, graphics-only)
- Use **master-sword** for cross-domain tasks (quest → implementation)

See `oracle_farore_secrets_plan.md` for detailed roadmap.

---

## Training Infrastructure

### Hardware: medical-mechanica

```
GPU:      RTX 5060 Ti (16GB VRAM)
IP:       100.104.53.21:11434
Platform: Windows + Ollama + WSL2
```

### Small Models (1.5B-4B)

```
VRAM Budget:
  Model (FP16):     ~3GB
  LoRA adapters:    ~0.5GB
  Optimizer:        ~1GB
  Batch:            ~1GB
  ────────────────────────
  TOTAL:            ~6GB (fits easily)
```

### Large Models (24B-32B)

```
VRAM Budget (4-bit + ZeRO-3):
  Model:            ~10GB (offloaded)
  LoRA adapters:    ~4GB
  Optimizer:        ~2GB (offloaded)
  ────────────────────────
  TOTAL:            ~16GB (tight fit)
```

---

## Quality Thresholds

```python
DOMAIN_THRESHOLDS = {
    # Technical domains
    "asm_base": 0.4,
    "asm_debug": 0.4,
    "asm_optimize": 0.45,
    "asm_hook": 0.4,
    "asm_doc": 0.5,
    "alttp_historical": 0.5,
    "yaze": 0.5,

    # Knowledge domains
    "lore": 0.6,
    "docs": 0.55,

    # Creative domains
    "narrative": 0.5,
    "dialogue": 0.55,
}
```

---

## Generator Infrastructure

### Available Generators (hafs_scawful plugin)

| Generator | Domain | Samples/Run |
|-----------|--------|-------------|
| AsmDataGenerator | asm_base | ~1,300 |
| AsmDebugGenerator | asm_debug | ~900 |
| AsmOptimizeGenerator | asm_optimize | ~900 |
| AsmHookGenerator | asm_hook | ~800 |
| AsmDocGenerator | asm_doc | ~1,000 |
| GigaleakDataGenerator | alttp_historical | ~2,000 |
| OracleDataGenerator | oracle | ~500 |
| Zelda3DisasmGenerator | zelda3 | ~1,500 |
| CppDataGenerator | yaze | ~1,500 |

### AsmSynthesizer

Compare and merge all ASM generators:

```python
from hafs_scawful.generators.asm_synthesizer import AsmSynthesizer

# Quick comparison
synth = AsmSynthesizer()
result = await synth.run_comparison(limit=10)
synth.print_comparison_report(result)

# Generate unified dataset
await synth.generate_unified_dataset(
    output_dir=Path("~/.context/training/datasets/asm_unified"),
    limit_per_type=500,
)
```

---

## Roadmap

### Phase 1: Small Specialists (Current)
- [x] Generator infrastructure
- [x] Specialized ASM generators (debug/optimize/hook/doc)
- [ ] Train euclid-asm-1.5b
- [ ] Train seph-tilesmith-1.5b
- [ ] Validate on test sets

### Phase 2: Knowledge Layer
- [ ] Train kaepora-teacher-4b
- [ ] Curate lore dataset
- [ ] Train nayru-lorekeeper-4b

### Phase 3: Creative Layer
- [ ] Oracle of Secrets story dataset
- [ ] Train farore-questweaver-4b
- [ ] Train saria-voice-4b

### Phase 4: Unified Model
- [ ] Combine all datasets
- [ ] Train master-sword-32b
- [ ] A/B test vs MoE system

---

## Future Expansion

The naming convention leaves room for growth:

**More specialists under oracle-din:**
- `lens-of-truth` - Debugging/tracing specialist
- `cane-of-byrna` - Compression expert
- `hookshot` - Hook/patch specialist

**More specialists under oracle-nayru:**
- `book-of-mudora` - Translation/explanation
- `gossip-stone` - Quick answers

**More specialists under oracle-farore:**
- `ocarina` - Music/audio creation
- `wind-waker` - Dynamic event scripting

**Community honorees:**
- `kan-mapper` - Map editing (honors Kan)
- `jigglysaint-` - Sprite work (honors JigglySaint)
- Add more as the project grows!

---

## Quick Reference

```bash
# Generate ASM samples (all task types)
PYTHONPATH="src:$HOME/Code" .venv/bin/python -c "
from hafs_scawful.generators.asm_synthesizer import generate_full_dataset
import asyncio
asyncio.run(generate_full_dataset())
"

# Compare generators
PYTHONPATH="src:$HOME/Code" .venv/bin/python -c "
from hafs_scawful.generators.asm_synthesizer import run_quick_comparison
import asyncio
asyncio.run(run_quick_comparison())
"

# Train model (on medical-mechanica)
python train_euclid_asm.py \
    --dataset ~/.context/training/datasets/asm_unified \
    --base-model Qwen/Qwen2.5-Coder-1.5B \
    --output euclid-asm-v1
```

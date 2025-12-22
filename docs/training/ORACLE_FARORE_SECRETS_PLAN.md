# triforce-sage: The North Star Model

**Created**: 2025-12-22
**Updated**: 2025-12-22
**Status**: PLANNED
**Purpose**: Ultimate integration of narrative design + ROM hacking in a single model

---

## Naming Clarification

This document was previously titled "oracle-farore-secrets" but has been renamed to align with the new model hierarchy:

```
oracle-council (Router)
    ├── oracle-din (Power)      → Technical: euclid-asm, seph-tilesmith
    ├── oracle-nayru (Wisdom)   → Knowledge: kaepora-teacher, nayru-lorekeeper
    └── oracle-farore (Courage) → Creation: farore-questweaver, saria-voice

triforce-sage (Unified North Star)
    └── Combines ALL domains in one 32B model
    └── Alias: master-sword (production name)
```

**triforce-sage** is the unified model. **oracle-farore** remains a category for creation/narrative specialists.

---

## Vision

**triforce-sage** is the pinnacle model - a unified expert that combines:
- **oracle-din** capabilities (65816 ASM, ROM tooling, YAZE)
- **oracle-nayru** capabilities (documentation, lore, teaching)
- **oracle-farore** capabilities (narrative design, quest creation)

This model represents the **north star** for our training efforts - a single model that can:
1. Design quest narratives with proper pacing and reveals
2. Implement them in ROM using YAZE and ASM
3. Balance mechanics and difficulty
4. Validate against canon and technical constraints

---

## Why This Is The Goal

### Current State: Fragmented Expertise

**Problem**: We have separate experts:
- `euclid-asm` understands 65816 but not narrative pacing
- `farore-questweaver` understands story but not ROM limitations
- MoE synthesis via `oracle-council` adds latency and complexity

**triforce-sage solves this** by embedding **all domains** in a single model.

### Advantages Over MoE

**MoE** (oracle-council + specialists):
- ✅ Modular, easier to train individual experts
- ✅ Can swap experts independently
- ✅ Smaller models (1.5B-4B each) are cheap to run
- ❌ Requires routing/classification overhead
- ❌ Synthesis step can lose context
- ❌ Higher inference latency (3-5 seconds)
- ❌ Harder to maintain cross-domain reasoning

**triforce-sage** (Unified Model):
- ✅ Single-shot reasoning across domains
- ✅ Lower inference latency (1-2 seconds)
- ✅ Natural cross-domain synthesis
- ❌ Harder to train (needs diverse dataset)
- ❌ Larger model required (24B-32B parameters)
- ❌ More expensive to fine-tune

### When to Use Each

**Use oracle-council + MoE When**:
- Tasks are clearly separable (pure ASM vs pure lore)
- Need to update one domain without retraining everything
- Running on limited hardware

**Use triforce-sage When**:
- Tasks require cross-domain reasoning (quest → implementation)
- Latency matters (real-time assistance)
- Want seamless integration without synthesis step

**Recommendation**: Train **both**:
1. Small specialists (euclid-asm, seph-tilesmith, etc.) for focused tasks
2. triforce-sage for integrated workflows
3. oracle-council routes between them intelligently

---

## Model Specifications

### Base Model Options

**Option 1: Qwen2.5-Coder-32B** (RECOMMENDED)
```
Parameters: 32B
Context:    32K tokens
Strengths:  Code + reasoning, multilingual
VRAM:       ~20GB (4-bit quantization)
Training:   Possible on medical-mechanica with DeepSpeed ZeRO-3
Why:        Best balance of code and natural language
```

**Option 2: Magistral-24B**
```
Parameters: 24B
Context:    32K tokens
Strengths:  Creative writing, synthesis
VRAM:       ~15GB (4-bit)
Training:   Easier fit on medical-mechanica
Why:        Excellent for narrative + code fusion
```

**Option 3: DeepSeek-R1-32B**
```
Parameters: 32B
Context:    64K tokens
Strengths:  Reasoning, planning
VRAM:       ~20GB (4-bit)
Why:        Strong reasoning chains for complex tasks
```

**Chosen**: **Qwen2.5-Coder-32B** (code-first with strong reasoning)

### Training Configuration

```python
model = "Qwen/Qwen2.5-Coder-32B"
quantization = "4-bit"  # Fits in 16GB with ZeRO-3
lora_rank = 32          # Higher rank for complex task
lora_alpha = 64
batch_size = 1
gradient_accumulation = 8  # Effective batch = 8
epochs = 3
learning_rate = 2e-5
warmup_steps = 100
optimizer = "AdamW"
scheduler = "cosine"
```

**VRAM Budget**:
```
Model (4-bit + ZeRO-3):    ~10GB (offloaded)
LoRA adapters:             ~4GB
Optimizer states:          ~2GB (offloaded)
Batch processing:          ~2GB
──────────────────────────────
TOTAL:                     ~18GB (fits in 16GB with offloading)
```

---

## Dataset Construction

### Total Dataset Size: ~60,000 Samples

#### oracle-din Domain (30,000 samples) ✅ MOSTLY READY

| Source | Samples | Status | Generator |
|--------|---------|--------|-----------|
| ALTTP ASM (base) | 1,300 | ✅ Ready | AsmDataGenerator |
| ALTTP ASM (debug) | 900 | ✅ Ready | AsmDebugGenerator |
| ALTTP ASM (optimize) | 900 | ✅ Ready | AsmOptimizeGenerator |
| ALTTP ASM (hook) | 800 | ✅ Ready | AsmHookGenerator |
| ALTTP ASM (doc) | 1,000 | ✅ Ready | AsmDocGenerator |
| Gigaleak | 8,000 | ✅ Ready | GigaleakDataGenerator |
| Oracle of Secrets | 500 | ✅ Ready | OracleDataGenerator |
| YAZE C++ | 7,000 | ✅ Ready | CppDataGenerator |
| Graphics/Tiles | 3,000 | 🔄 Planned | (seph-tilesmith data) |
| Compression | 2,000 | 🔄 Planned | (koume-compress data) |

#### oracle-nayru Domain (10,000 samples) 🔄 PARTIAL

| Source | Samples | Status | Notes |
|--------|---------|--------|-------|
| Code Documentation | 3,000 | ✅ Ready | From asm_doc generator |
| Zelda Lore | 5,000 | ❌ Needs curation | Manual annotation required |
| Canon Verification | 2,000 | ❌ Needs curation | Expert validation |

#### oracle-farore Domain (10,000 samples) ❌ NEEDS WORK

| Source | Samples | Status | Notes |
|--------|---------|--------|-------|
| Oracle of Secrets Narrative | 5,000 | ❌ Needs creation | Story design data |
| Quest Templates | 3,000 | ❌ Needs LLM gen | Synthetic + validation |
| Dialogue Patterns | 2,000 | ❌ Needs extraction | Character voice data |

#### Cross-Domain Integration (10,000 samples) ❌ CRITICAL

| Source | Samples | Status | Notes |
|--------|---------|--------|-------|
| Quest → Implementation | 5,000 | ❌ HARD | Manual pairing required |
| ROM Hack Case Studies | 3,000 | ❌ Medium | Reverse engineering |
| Error Correction Chains | 2,000 | ❌ Hard | Multi-turn validation |

---

## Data Generation Strategy

### Phase 1: Leverage Existing Infrastructure

Use the specialized ASM generators we built:

```python
from hafs_scawful.generators.asm_synthesizer import AsmSynthesizer

# Generate all task variants
synth = AsmSynthesizer(generator_types=['base', 'debug', 'optimize', 'hook', 'doc'])
await synth.generate_unified_dataset(
    output_dir=Path("~/.context/training/datasets/triforce_din_samples"),
    limit_per_type=500,
)
```

This gives us ~2,500 diverse ASM samples covering:
- Code generation (base)
- Debugging (debug)
- Optimization (optimize)
- Patching (hook)
- Documentation (doc)

### Phase 2: Build Narrative Generators

Create equivalent generators for oracle-farore domain:
- `FaroreQuestGenerator` - Quest design samples
- `SariaDialogueGenerator` - Character dialogue samples
- `NayruLoreGenerator` - Lore/canon samples

### Phase 3: Cross-Domain Pairing

The **critical bottleneck**: Quest → Implementation pairs

**Strategy: Iterative Refinement**
1. Create 100 expert pairs manually
2. Train intermediate triforce-sage-pilot
3. Use pilot to generate 400 more pairs
4. Expert corrects (10 min/sample)
5. Bootstrap to 3,000 pairs over iterations

---

## Training Roadmap

### Wave 1: Specialists (Current - 2 weeks)
- [x] Build specialized ASM generators
- [x] Create AsmSynthesizer
- [ ] Train euclid-asm-1.5b
- [ ] Train seph-tilesmith-1.5b
- [ ] Validate on test sets

### Wave 2: Knowledge (4 weeks)
- [ ] Build narrative generators
- [ ] Curate lore dataset
- [ ] Train kaepora-teacher-4b
- [ ] Train nayru-lorekeeper-4b

### Wave 3: Creation (4 weeks)
- [ ] Build quest generators
- [ ] Oracle of Secrets story extraction
- [ ] Train farore-questweaver-4b
- [ ] Train saria-voice-4b

### Wave 4: Integration (8 weeks)
- [ ] Create 100 quest → implementation pairs
- [ ] Train triforce-sage-pilot
- [ ] Iterative refinement (5 iterations)
- [ ] Train triforce-sage-v1

### Wave 5: Polish (4 weeks)
- [ ] Error correction chains
- [ ] ROM hack case studies
- [ ] Final training: triforce-sage-v1.0
- [ ] A/B test vs oracle-council MoE

**Total Timeline**: ~22 weeks (5-6 months)

---

## Evaluation Plan

### Benchmark Categories

| Category | Baseline | Target | Metrics |
|----------|----------|--------|---------|
| Pure ASM | euclid-asm | ≥95% | Assembly correctness |
| Pure Graphics | seph-tilesmith | ≥95% | Tile/palette validity |
| Pure Lore | nayru-lorekeeper | ≥90% | Canon consistency |
| Pure Quest | farore-questweaver | ≥90% | Pacing quality |
| Cross-Domain | oracle-council MoE | ≥110% | Integration correctness |
| Latency | MoE (4s) | <2s | Response time |

### Cross-Domain Test Cases

```
Test 1: "Design a quest where Link must find a hidden fairy fountain,
        then implement the trigger and reward logic in ASM."

Test 2: "Create dialogue for a new NPC who gives hints about
        the Master Sword, including the text box constraints."

Test 3: "Design a new dungeon room with a puzzle, then write
        the tile layout and switch logic."
```

---

## Hybrid Deployment Strategy

```python
async def route_task(task: Task) -> Model:
    """Route to appropriate model based on task complexity."""

    if task.is_pure_domain():
        # Single domain → use specialist
        if task.domain == "asm":
            return euclid_asm
        elif task.domain == "graphics":
            return seph_tilesmith
        elif task.domain == "lore":
            return nayru_lorekeeper
        elif task.domain == "quest":
            return farore_questweaver

    elif task.requires_cross_domain():
        # Multi-domain → use triforce-sage
        return triforce_sage

    else:
        # Default → MoE with synthesis
        return oracle_council.route(task)
```

---

## Risk Mitigation

### Risk 1: Quest → Implementation Pairs Too Hard

**Mitigations**:
- Plan A: Iterative refinement with model assistance
- Plan B: Reduce target to 1,000 pairs
- Plan C: Focus on simpler patterns (fetch, talk, trigger)
- Plan D: Community sourcing

**Fallback**: Use oracle-council MoE for cross-domain tasks

### Risk 2: 32B Model Won't Fit

**Mitigations**:
- Plan A: DeepSpeed ZeRO-3 with CPU offloading
- Plan B: Use Magistral-24B instead
- Plan C: Rent cloud GPU (A100 80GB)
- Plan D: Train 14B unified model

**Fallback**: Rely on MoE architecture

### Risk 3: Cross-Domain Performance Degrades

**Mitigations**:
- Plan A: Curriculum learning (pure → mixed)
- Plan B: Adjust dataset ratios
- Plan C: Multi-task LoRA
- Plan D: Keep separate adapters

**Fallback**: triforce-sage for integration only

---

## Summary

**triforce-sage** is the north star - a unified 32B model combining:
- oracle-din (Power): ASM, ROM tooling
- oracle-nayru (Wisdom): Documentation, lore
- oracle-farore (Courage): Quest design, narrative

**Key Insights**:
- oracle-din data: ✅ 50% ready (generators built)
- oracle-nayru data: 🔄 25% ready (needs curation)
- oracle-farore data: ❌ Needs creation
- Cross-domain data: ❌ Critical bottleneck

**Hybrid Strategy**:
- Train small specialists first (euclid-asm, etc.)
- Use them while building toward triforce-sage
- oracle-council routes between specialists and unified model

**Next Steps**:
1. ✅ Run ASM synthesis to generate all task variants
2. Train euclid-asm-1.5b as proof of concept
3. Build narrative generators
4. Create 100 quest → implementation pairs
5. Train triforce-sage-pilot

---

**This is achievable with iterative refinement and the infrastructure we've built.**

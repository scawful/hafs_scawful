# Model Training Evaluation & Future Roadmap

## Council Review: Current Run
*   **Focus:** Tool-use (hafs/z3ed) and Semantic ASM (enriched symbols).
*   **Validation:** Syntactic only (via Asar).

## Phase 2 Roadmap (Active Improvement)

### A. Advanced Preprocessing
- [ ] **Stateful Width Tracking:** Detect `REP`/`SEP` and annotate instructions with `(A:8)` or `(A:16)`.
- [ ] **Context Overlap:** When chunking, include the last 10 instructions of the previous block as "system context".

### B. Behavioral Validation (The Sandbox)
- [ ] **Yaze-Core Integration:** Run generated code in a headless emulator.
- [ ] **Unit Tests for ASM:** Create a suite of "Zelda Benchmarks" (e.g., "Heal Link", "Spawn Sprite") that the model must solve.

### C. Knowledge Graph Fusion
- [ ] **Recursive Entity Expansion:** If a routine is extracted, automatically pull in all 1st-degree connected memory nodes into the training prompt.

## Evaluation Protocol (Post-Training)

### Metrics
1. **Asar Pass Rate:** % of model outputs that assemble without error.
2. **Symbol Adherence:** Ratio of known vs. hallucinated RAM addresses.
3. **Instruction Recall:** Ability to map natural language to the correct `z3ed` sub-command.

### Sandbox Setup
- **Binary:** `/Users/scawful/Code/asar/build/asar/bin/asar`
- **Emulator:** `yaze_emu` (for live state verification)
- **Base ROM:** `/Users/scawful/Code/Oracle-of-Secrets/Roms/vanilla.sfc`

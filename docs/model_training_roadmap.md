# HAFS Model Training Roadmap

This roadmap focuses on evolving our AI models from simple syntax generators to advanced ASM architects, specifically for 65816 (SNES) and emulator-related tasks.

## 1. Model Evolution Strategy
- **DPO for Tool-Use:** Train models to prefer optimized tool chains (e.g., DMA block moves vs. manual loops).
- **Agentic Self-Correction:** Integrate `AsarValidator` into the training loop for CoT (Chain of Thought) debugging.
- **Behavioral Validation:** Inject generated code into a running `yaze` instance and monitor RAM/CPU for correctness.

## 2. Training Pipelines
- **Project Farore:** Scale synthetic dataset generation using cloud H100 clusters (Target: 100k+ validated routines).
- **M/X Flag Awareness:** Upgrade `AsmPreprocessor` to track and annotate register widths (8-bit vs 16-bit) to eliminate the #1 source of SNES bugs.
- **Curriculum Learning:** Transition from simple utility routines to complex AI/physics state machines.
- **Evaluation:** Evaluate Qwen2.5-Coder-32B on RunPod if local 14B models are insufficient.

## 3. Distributed Orchestration (Project Exo-Node)
- **Hybrid Node roles:**
    - **Mac (M-Series):** Fast Orchestrator & Fast-Response dispatcher for 7B-8B models.
    - **Windows GPU (RTX 3090/4090):** Deep Training & Teacher duties (30B-70B models, long context).
- **Network Inference:** Mac hosts the MCP server and UI while offloading LLM requests to the Windows GPU via Project Exo-Node.

## 4. Validation & Quality
- **Cycle Counting:** Use `yaze` cycle counters to score routines for efficiency.
- **Visual Regression:** Use `CanvasAutomationService` to verify PPU/palette changes in the emulator.
- **Screenshot Verification:** Automated capture and review of visual results.

---

*Last Updated: 2025-12-22*

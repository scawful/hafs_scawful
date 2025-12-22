# Oracle Council: AI Strategy & Hardware Roadmap (2026)

## 1. Model Evolution: Beyond Syntax
To transition from an ASM "coder" to an ASM "architect," we are implementing the following training paradigms:

### A. DPO (Direct Preference Optimization) for Tool-Use
*   **Goal:** Train models to prefer idiomatic and efficient tool usage.
*   **Implementation:** Generate pairs of "Valid but Clunky" vs "Optimized" tool chains. Use DPO to bias the model toward the optimized path.

### B. Agentic Self-Correction (HIL Validation)
*   **Goal:** Enable models to debug their own assembly code.
*   **Implementation:** Integrate the `AsarValidator` and a future `BehavioralValidator` into the training loop. Failed generations are re-prompted for fixes, and the entire correction chain is used as a CoT (Chain of Thought) training sample.

### C. Behavioral Validation (Step-Loop Testing)
*   **Goal:** Verify code stability, not just syntax.
*   **Implementation:** Inject generated ASM into a running `yaze` instance, step for 60-120 frames, and monitor RAM for crashes or unintended side effects (e.g., stack corruption).

## 2. Hardware Strategy: Hybrid Scaling

### A. Local Node Breakdown
*   **Mac (M-Series/Darwin - 16GB RAM):**
    *   **Role:** Agent Orchestrator & "Fast Response" Node.
    *   **Advantage:** Low-latency inference for 7B-8B parameter models (e.g., Llama-3 8B, Mistral). Perfect for UI automation, documentation retrieval, and acting as the "Dispatcher" for complex queries.
    *   **Constraint:** Limited by RAM for large models (70B+); should avoid running high-parameter models locally to preserve memory for development tools.
*   **Windows GPU (NVIDIA RTX - Training Node):**
    *   **Role:** Heavy Compute & "Deep Thinker."
    *   **Advantage:** CUDA cores + 24GB VRAM (assumed 3090/4090 class). This is the primary node for:
        *   **Fine-Tuning:** specialized LoRAs for ASM synthesis.
        *   **Large Inference:** Running 30B-70B models via EXL2/GGUF for "Teacher" duties.
        *   **Long Context:** Handling large files like `MemoryMap.md` and full disassemblies.

### B. Cloud Bursting & Handoff
*   **Role:** High-Throughput Synthetic Data Generation.
*   **Strategy:** Rent H100 clusters to generate massive, validated ASM datasets (100k+ routines).
*   **Quantization Pipeline:** Cloud (FP16) -> Quantize -> Windows PC (EXL2 for speed) or Mac (GGUF for efficiency).

### C. Distributed Orchestration (Project "Exo-Node")
*   **Project:** Use the PC as the primary engine and the Mac as the "Headless" client.
*   **Workflow:** The Mac hosts the MCP server and `yaze`, while sending LLM requests over the local network to the Windows PC (serving via `Ollama` or `vLLM`).

## 3. Tooling Refinements: The "Mastery" Layer

### A. Instruction-Aware Width Tracking (M/X Flags)
*   **Context:** The #1 source of 65816 bugs is 8-bit/16-bit register ambiguity.
*   **Upgrade:** Enhance `AsmPreprocessor` to track not just `REP/SEP`, but also subroutine entry/exit.
*   **Output:** Explicitly annotate every line of training data with register status (e.g., `LDA $10 ; A=16-bit`).
*   **Validation:** Use `yaze` to dump the processor status (P register) during `behavioral_test_run` and verify it matches the preprocessor's prediction.

### B. DPO for ASM Efficiency
*   **Goal:** Train models to write *clean* code, not just *working* code.
*   **Implementation:**
    *   **Chosen (Correct):** Routine using `DMA` for block moves or `TDC/ADC` for efficient direct page math.
    *   **Rejected (Valid but Bad):** Routine using literal loops of `LDA/STA` for 512 bytes (inefficient cycle count).
*   **Metrics:** Use the `yaze` cycle counter to score routines. Faster = Better.

### C. Behavioral Step-Loop Testing (WRAM Sandbox)
*   **Mechanism:**
    1.  Take a WRAM snapshot of a running game state (e.g., Link in House).
    2.  Inject the agent's code into a free RAM area (e.g., `$7F:0000`).
    3.  Set PC to injected code and `JSR` to it.
    4.  Step for 60 frames (1 second).
    5.  Check for **Illegal Instruction** traps or **Infinite Loops** (cycle timeout).
    6.  **Heuristic Validation:** If the agent says "I fixed the health," check if `$7E:F36D` actually changed. If it didn't, the test failed even if it compiled.

### D. Visual Regression Testing
*   **Plan:** Link `CanvasAutomationService` to the validation loop.
*   **Goal:** For code that affects graphics (palettes, tile DMA), use the emulator's PPU state to verify that the target color/tile actually appeared on screen.

## 4. The Human-AI Collaboration Loop

### A. Confidence-Based Clarification
*   **Threshold:** If the model's behavioral test succeeds but results in a "High Cycle Count" (>10,000 cycles for a simple routine), it must ask the user: *"This code works but is inefficient. Should I try to optimize it using DMA?"*

### B. Screenshot Verification
*   **Workflow:** The agent performs a `behavioral_test_run`, captures a screenshot of the result, and presents it to the user with the message: *"I've injected the custom palette code. Does this look like the intended 'Frozen Hyrule' aesthetic to you?"*

### C. Joint Debugging Sessions
*   **Capability:** Use the `yaze-mcp` to set a breakpoint at the user's request. The agent and user then "Step Together" through the code, with the agent explaining the register changes at each instruction.

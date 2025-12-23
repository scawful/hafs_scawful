# Plan: Project "Farore" & The Local SME Swarm

**Status:** Implementation Starting (Model: Farore)
**Objective:** Deploy a swarm of specialized, small local models (SSEs) to maximize Mac (16GB) and Windows (16GB VRAM) efficiency.

## 1. The Swarm Architecture (SSEs)

| Code Name | Focus | Base Model | Deployment |
| :--- | :--- | :--- | :--- |
| **FARORE** | Tool Orchestration | Phi-3.5 (3.8B) | Mac (Local) |
| **DIN** | ASM Synthesis | Llama-3 (8B) | Windows (GPU) |
| **NAYRU** | Logic & Width Analysis | Qwen-2.5-Coder (7B) | Windows (GPU) |
| **IMPA** | Knowledge & Metadata | TinyLlama (1.1B) | Mac (Local) |

---

## 2. Model "Farore" (The Tool Specialist)
Farore's sole purpose is converting natural language into precise `yaze-mcp` or `z3ed` tool calls.

### A. Capabilities:
*   Translates "Show me Link's position" -> `get_game_state()`.
*   Translates "Step through the code at $00:8000" -> `get_disassembly(address="$008000")`.
*   Handles parameter extraction (Hex addresses, label resolution).

### B. Training Data Strategy (Synthetic Tool-Use):
We will generate 5,000+ training samples using the following template:
*   **User Intent:** "Wait until I hit the health routine."
*   **Tool Call:** `add_breakpoint(address="Link_Health_Routine", type="EXECUTE")`
*   **Chain of Thought:** "The user wants to pause execution when a specific routine is reached. I should use `add_breakpoint` with the label provided."

### C. Orchestration Pattern:
Farore will run on the Mac as a "Sidecar" to your active session. It will act as the "Semantic Bridge" between your words and the raw gRPC services.

---

## 3. Data Generation Pipeline (Phase 1)

1.  **Tool Schema Extraction:** [TODO] Export all MCP tools and `z3ed` commands into a structured JSON definition.
2.  **Scenario Generation:** [TODO] Use a "Teacher" LLM to dream up 100 debug/editing scenarios.
3.  **Command Mapping:** [TODO] Pair scenarios with the correct sequence of Yaze tools.
4.  **Fine-Tuning:** [TODO] Use Unsloth on the Windows PC to tune Phi-3.5 on this specific schema.

---

## 4. Hardware Allocation Logic (The 16/16 Split)

*   **Mac 16GB:**
    *   Hosts the **Supervisor** (Farore 3B + Impa 1B).
    *   Zero-latency UI response.
    *   Handles gRPC/MCP server hosting.
*   **Windows 16GB VRAM:**
    *   Hosts the **Engine** (Din 8B or Nayru 7B).
    *   Runs the `AsarValidator` and `BehavioralValidator`.
    *   Handles all LoRA training tasks.

---

## 5. Immediate Action Items
1.  **[ ] Tool Schema Export:** Run a script to gather every `mcp.tool()` definition from `server.py`.
2.  **[ ] Training File Creation:** Initialize `hafs_scawful/generators/farore_generator.py`.
3.  **[ ] Dataset Boilerplate:** Create the first 10 "Golden" tool samples manually to set the standard.

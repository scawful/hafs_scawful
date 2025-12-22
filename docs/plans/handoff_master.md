# Handoff: Unified Yaze-MCP & ASM Mastery Pipeline

**Session Date:** Monday, December 22, 2025
**Overview:** This document tracks the unification of gRPC debugging services, semantic ASM preprocessing, and the status of the current training run.

## 🔗 Repository Quick Links
*   **[Core HAFS] (../../hafs)**: Orchestration engine and generic generators.
*   **[Yaze Emulator] (../../yaze)**: SNES emulator and unified gRPC backend.
*   **[HAFS Scawful Plugin] (..)**: Zelda-domain knowledge, specific training data, and local validators.
*   **[Usdasm Reference] (../../usdasm)**: Vanilla ALTTP disassembly.

## 🛠 Active Tools & Status
| Tool | Location | Status | Description |
| :--- | :--- | :--- | :--- |
| **Yaze gRPC** | `yaze/bin/yaze` | Unified (50052) | Hosts ROM, Canvas, and Emulator services on one port. |
| **MCP Server** | `yaze-mcp/server.py` | Semantic | Supports labels like `Link_X_Pos` via Knowledge Graph. |
| **AsmDataGen** | `hafs_scawful/generators/asm_generator.py` | Enriched | Injects symbols into code before LLM generation. |
| **Asar Validator** | `hafs_scawful/validators/asar_validator.py` | Integrated | Real-time syntax check using `asar` binary. |
| **Behavioral Validator** | `yaze-mcp/server.py` | Functional | Test-runs ASM in the emulator via `behavioral_test_run`. |
| **Width Tracker** | `hafs/.../asm_preprocessor.py` | State-Aware | Tracks M/X flags to resolve 8-bit/16-bit register ambiguity. |

## 📜 Relevant Plan Documents
*   **[AI Strategy 2026](AI_STRATEGY_2026.md)**: Master roadmap for DPO, behavioral testing, and hardware scaling.
*   **[MCP Unification Blueprint](../../yaze/docs/plans/MCP_UNIFICATION.md)**: Details on the backend consolidation and gRPC bridge.
*   **[ASM Embedding Upgrade](ASM_EMBEDDING_UPGRADE.md)**: Technical spec for semantic enrichment and preprocessor logic.
*   **[Future Model Roadmap](model_roadmap_council.md)**: Oracle Council recommendations for Phase 2/3 (Stateful tracking).
*   **[Tool Training Plan](tool_training_plan.md)**: List of stable z3ed/hafs commands for instruction tuning.

## 🧪 Verification Logs
*   **Builds:** Yaze GUI successfully built with unified gRPC services.
*   **Tests:** `hafs_scawful/tests/test_asar_validator.py` passed (Real-world assembly validation).
*   **Datasets:** Updated `hafs_tooling_dataset.jsonl` and `z3ed_tooling_dataset.jsonl` are ready in `~/.context/training/datasets/`.

## ⏭ Next Steps
1.  **Run Training:** Deploy updated datasets to the `medical-mechanica` node.
2.  **Verify Result:** Check the first model outputs for "Hardware Register Mastery" (correct use of $21xx/$42xx).
3.  **Stateful Tracking:** Expand the `AsmPreprocessor` to track CPU flags (M/X) for width-aware assembly generation.

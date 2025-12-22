# Plan: "Golden Zelda" Cloud Data Preparation

**Objective:** Generate a high-density, validated training dataset of 50,000+ samples covering the Zelda 3 (ALTTP) engine and the Oracle of Secrets (OOS) additions.

## 1. Source Prioritization (The Extraction List)
To maximize the "intelligence" of the model, we will process the following sources in order of importance:

| Priority | Source | Description | Benefit |
| :--- | :--- | :--- | :--- |
| **Tier 1** | `usdasm/bank_00.asm` | Core Engine & Math | Teaches the model the "operating system" of the game. |
| **Tier 1** | `Core/ram.asm` | RAM Definitions | Crucial for the `AsmPreprocessor` to map labels to logic. |
| **Tier 2** | `usdasm/bank_05.asm` | Sprite Logic | Teaches how NPCs and enemies behave. |
| **Tier 2** | `Items/*.asm` | OOS Item Code | Provides "Modern" ASM patterns created by the user. |
| **Tier 3** | `Music/*.asm` | Audio Engine | Specialized SPC700 and engine interaction data. |

## 2. The "Golden" Generation Pipeline
We will use a four-stage loop to ensure every line of data is worth the cloud training cost:

1.  **Semantic Enrichment:** Run `AsmPreprocessor` to inject Knowledge Graph symbols and track register widths (M/X).
2.  **Teacher Synthesis:** Use a high-parameter model (Gemini 1.5 Pro or Llama-3 70B) to generate an `Instruction` and `Input` context for each routine.
3.  **Syntactic Validation:** Every sample is passed through `AsarValidator`. If it doesn't compile, it's sent back to the Teacher for one "Self-Correction" attempt.
4.  **Behavioral Verification:** High-priority routines (math, item logic) are passed through the `behavioral_test_run` in Yaze to verify they don't crash the stack.

## 3. Dataset Structure (JSONL)
The final output will be formatted for Unsloth/Axolotl training:
```json
{
  "instruction": "Write a routine to check if Link is currently in the 'Swimming' state.",
  "input": "Link State is stored at $7E:005D. Bit 0x02 indicates swimming.",
  "output": "CheckSwimming:\n    LDA $005D ; M=8, X=8 [LinkState]\n    AND #$02  ; Check swimming bit\n    RTS",
  "validation": {"asar": true, "behavioral": true, "cycles": 12}
}
```

## 4. Scaling Plan (The Holiday Run)
Since hardware acquisition is paused for the holidays, we will use your **4060 Ti 16GB** and **Mac** to generate the data:
*   **Day 1-3:** Batch process the 20+ banks of `usdasm`.
*   **Day 4-5:** Run the "Self-Correction" loop on failed samples.
*   **Day 6:** Final Deduplication and "DPO" pairing (generating optimized vs. slow versions).

## 5. Success Metrics
*   **Volume:** 50,000+ unique routine/instruction pairs.
*   **Accuracy:** 100% Asar-compliant code.
*   **Diversity:** Coverage of PPU registers, DMA, and standard game-loop hooks.


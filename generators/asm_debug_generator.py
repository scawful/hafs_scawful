"""ASM Debug Generator - Training data for crash analysis and debugging.

Generates samples that teach the model to:
- Analyze crash symptoms and identify root causes
- Trace execution flow to find bugs
- Diagnose memory corruption and stack issues
- Identify timing bugs and race conditions

Target model: euclid-asm (debugging specialist)
"""

from __future__ import annotations

import logging
import random
from typing import Optional

from hafs_scawful.generators.asm_base import AsmBaseGenerator, AsmSourceItem

logger = logging.getLogger(__name__)


# Simulated crash scenarios to inject variety
CRASH_SCENARIOS = [
    {
        "symptom": "Game freezes after executing this routine",
        "hint": "Check for infinite loops or missing RTS/RTL",
        "focus": "control_flow",
    },
    {
        "symptom": "Stack overflow crash when this routine is called repeatedly",
        "hint": "Check for unbalanced PHA/PLA or missing stack cleanup",
        "focus": "stack",
    },
    {
        "symptom": "Graphics corruption appears after this routine runs",
        "hint": "Check VRAM writes, DMA timing, or register clobbering",
        "focus": "graphics",
    },
    {
        "symptom": "Link's position becomes corrupted after this code",
        "hint": "Check RAM address calculations and indirect addressing",
        "focus": "memory",
    },
    {
        "symptom": "Music stops or glitches after executing this routine",
        "hint": "Check APU communication timing ($2140-$2143)",
        "focus": "audio",
    },
    {
        "symptom": "Save data becomes corrupted when this routine runs",
        "hint": "Check SRAM writes at $70:0000 and bank switching",
        "focus": "sram",
    },
    {
        "symptom": "Intermittent crash that only happens sometimes",
        "hint": "Check for race conditions, NMI timing, or uninitialized memory",
        "focus": "timing",
    },
    {
        "symptom": "Wrong value loaded from RAM causing incorrect behavior",
        "hint": "Check direct page setup, bank register, and addressing modes",
        "focus": "addressing",
    },
]


class AsmDebugGenerator(AsmBaseGenerator):
    """Generate debugging/crash analysis training samples.

    Creates instruction-tuning data that teaches models to:
    1. Analyze crash symptoms in 65816 assembly
    2. Identify common bug patterns (stack, memory, timing)
    3. Suggest fixes with explanations
    """

    TASK_TYPE = "debug"

    def __init__(self):
        super().__init__(
            name="AsmDebugGenerator",
            domain="asm_debug",
        )

    def get_teacher_prompt(self, item: AsmSourceItem) -> str:
        """Generate debugging-focused teacher prompt."""
        scenario = random.choice(CRASH_SCENARIOS)
        enriched_code = self.enrich_code(item.code)
        memory_context = ", ".join(item.memory_access) if item.memory_access else "Unknown"

        return f"""You are an expert SNES 65816 debugger specializing in Zelda: A Link to the Past crash analysis.

CRASH REPORT:
Symptom: {scenario['symptom']}
Suspected routine: {item.name}
Bank: {item.bank}
Address: {item.address}
Memory regions accessed: {memory_context}
Debug hint: {scenario['hint']}

CODE UNDER ANALYSIS:
```asm
{enriched_code}
```

Generate a JSON object with debugging analysis:

1. "instruction": A user's crash report/question about this code. Examples:
   - "My ROM hack crashes when [specific action]. Here's the routine..."
   - "I'm seeing [symptom] after calling {item.name}. Can you help debug?"
   - "This routine causes [issue] intermittently. What's wrong?"

2. "input": The crash context including:
   - The symptom described
   - The routine code (formatted)
   - Any relevant memory addresses or register states
   - What the user has already tried

3. "output": A detailed debugging analysis including:
   - Root cause identification with specific line references
   - Explanation of WHY the bug occurs (65816 behavior)
   - Step-by-step fix with corrected code
   - Prevention tips for similar bugs

DEBUGGING GUIDELINES:
- Reference specific addresses ($XX:XXXX format)
- Explain 65816-specific gotchas (8/16-bit mode, direct page, bank register)
- Consider timing issues (NMI, DMA, hardware registers)
- Check stack balance (PHA/PLA, PHX/PLX, PHP/PLP pairs)
- Verify addressing modes (.b vs .w, # for immediate)

EXAMPLE OUTPUT FORMAT:
{{
  "instruction": "My hack crashes when Link picks up a heart piece. The routine at $02:8000 seems involved...",
  "input": "Crash symptom: Game freezes after heart piece collection\\n\\nSuspected code:\\n```asm\\nHeartPickup:\\n    LDA.w $0F00\\n    ...\\n```\\n\\nI've verified the routine is being called correctly.",
  "output": "**Root Cause Analysis**\\n\\nThe crash occurs because [explanation]...\\n\\n**The Bug**\\n```asm\\n; Line 5: Missing stack cleanup\\nPHA\\n; ... no matching PLA before RTS\\n```\\n\\n**The Fix**\\n```asm\\nHeartPickup:\\n    PHA            ; Save A\\n    ...\\n    PLA            ; Restore A (ADDED)\\n    RTS\\n```\\n\\n**Prevention**\\nAlways verify stack balance..."
}}

JSON FORMAT:
{{
  "instruction": "...",
  "input": "...",
  "output": "..."
}}
"""

    def filter_items_for_task(self, items: list[AsmSourceItem]) -> list[AsmSourceItem]:
        """Filter to routines most suitable for debug scenarios.

        Prioritizes routines that:
        - Have complex control flow (branches, loops)
        - Access hardware registers
        - Use stack operations
        - Have memory indirection
        """
        scored_items = []
        for item in items:
            score = 0
            code_lower = item.code.lower()

            # Complex control flow
            if any(x in code_lower for x in ['beq', 'bne', 'bcc', 'bcs', 'bpl', 'bmi']):
                score += 2
            if 'jsr' in code_lower or 'jsl' in code_lower:
                score += 1

            # Stack operations (good for stack bugs)
            if any(x in code_lower for x in ['pha', 'pla', 'phx', 'plx', 'php', 'plp']):
                score += 3

            # Hardware register access (good for timing bugs)
            if '$21' in code_lower or '$42' in code_lower or '$43' in code_lower:
                score += 2

            # Memory indirection (good for addressing bugs)
            if '(' in item.code and ')' in item.code:
                score += 2

            # Loop constructs
            if 'loop' in item.name.lower() or 'wait' in item.name.lower():
                score += 2

            scored_items.append((score, item))

        # Sort by score, take top 70%
        scored_items.sort(key=lambda x: x[0], reverse=True)
        cutoff = int(len(scored_items) * 0.7)
        return [item for _, item in scored_items[:max(cutoff, 100)]]


if __name__ == "__main__":
    import asyncio
    from pathlib import Path

    async def main():
        gen = AsmDebugGenerator()
        await gen.setup()

        items = await gen.extract_source_items()
        filtered = gen.filter_items_for_task(items)
        print(f"Filtered to {len(filtered)} debug-suitable routines")

        # Test one sample
        if filtered:
            sample = await gen.generate_sample(filtered[0])
            if sample:
                print(f"\nSample instruction: {sample.instruction[:100]}...")

    asyncio.run(main())

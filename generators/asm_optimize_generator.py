"""ASM Optimize Generator - Training data for cycle optimization.

Generates samples that teach the model to:
- Count CPU cycles accurately
- Identify optimization opportunities
- Apply 65816-specific tricks (16-bit ops, direct page, etc.)
- Balance code size vs speed tradeoffs

Target model: euclid-asm (optimization specialist)
"""

from __future__ import annotations

import logging
import random
from typing import Optional

from hafs_scawful.generators.asm_base import AsmBaseGenerator, AsmSourceItem

logger = logging.getLogger(__name__)


# Optimization focus areas
OPTIMIZATION_FOCUSES = [
    {
        "goal": "Minimize CPU cycles for this hot path routine",
        "constraints": "Must maintain exact same behavior",
        "technique": "cycle_count",
    },
    {
        "goal": "Reduce code size while maintaining performance",
        "constraints": "Cannot exceed original cycle count",
        "technique": "size_optimize",
    },
    {
        "goal": "Optimize this routine for the NMI time budget",
        "constraints": "Must complete within ~2200 cycles (NTSC V-Blank)",
        "technique": "vblank_budget",
    },
    {
        "goal": "Convert this to use 16-bit operations where beneficial",
        "constraints": "Preserve register states on exit",
        "technique": "16bit_upgrade",
    },
    {
        "goal": "Optimize memory access patterns for this routine",
        "constraints": "Cannot change memory layout",
        "technique": "memory_access",
    },
    {
        "goal": "Unroll this loop for better performance",
        "constraints": "Code size increase must be justified by cycle savings",
        "technique": "loop_unroll",
    },
    {
        "goal": "Replace this with DMA where possible",
        "constraints": "Must not conflict with existing DMA usage",
        "technique": "dma_convert",
    },
    {
        "goal": "Optimize this for direct page addressing",
        "constraints": "Direct page must be set correctly before calling",
        "technique": "direct_page",
    },
]


class AsmOptimizeGenerator(AsmBaseGenerator):
    """Generate optimization-focused training samples.

    Creates instruction-tuning data that teaches models to:
    1. Analyze cycle counts in 65816 assembly
    2. Apply architecture-specific optimizations
    3. Balance tradeoffs (size vs speed, clarity vs performance)
    """

    TASK_TYPE = "optimize"

    def __init__(self):
        super().__init__(
            name="AsmOptimizeGenerator",
            domain="asm_optimize",
        )

    def get_teacher_prompt(self, item: AsmSourceItem) -> str:
        """Generate optimization-focused teacher prompt."""
        focus = random.choice(OPTIMIZATION_FOCUSES)
        enriched_code = self.enrich_code(item.code)
        memory_context = ", ".join(item.memory_access) if item.memory_access else "General RAM"

        return f"""You are an expert SNES 65816 assembly optimizer specializing in Zelda: A Link to the Past performance tuning.

OPTIMIZATION REQUEST:
Routine: {item.name}
Bank: {item.bank}
Address: {item.address}
Memory regions: {memory_context}
Description: {item.description or "Game routine"}

OPTIMIZATION GOAL: {focus['goal']}
CONSTRAINTS: {focus['constraints']}
TECHNIQUE FOCUS: {focus['technique']}

ORIGINAL CODE:
```asm
{enriched_code}
```

Generate a JSON object with optimization analysis:

1. "instruction": A user request for optimization. Examples:
   - "This routine runs every frame but it's slow. Can you optimize it?"
   - "I need to fit more logic in V-Blank. How can I speed up {item.name}?"
   - "What 65816 tricks can reduce cycles in this hot path?"

2. "input": The optimization context including:
   - The original code
   - Performance requirements or constraints
   - Current estimated cycle count
   - What optimizations have been considered

3. "output": Detailed optimization analysis including:
   - Original cycle count (with breakdown per instruction)
   - Optimization opportunities identified
   - Optimized code with cycle count comments
   - Total savings and tradeoffs explained

65816 CYCLE REFERENCE:
- LDA #imm: 2 cycles (8-bit), 3 cycles (16-bit)
- LDA dp: 3 cycles (8-bit), 4 cycles (16-bit)
- LDA abs: 4 cycles (8-bit), 5 cycles (16-bit)
- STA dp: 3 cycles (8-bit), 4 cycles (16-bit)
- BRA: 3 cycles (taken), 2 cycles (not taken)
- JSR: 6 cycles, RTS: 6 cycles
- JSL: 8 cycles, RTL: 6 cycles
- REP/SEP: 3 cycles
- PHx/PLx: 3-4 cycles

OPTIMIZATION TECHNIQUES:
- Use direct page ($00-$FF) instead of absolute addressing (saves 1 cycle)
- Use 16-bit mode for paired byte operations
- Unroll small loops (trade size for speed)
- Use DMA for large memory copies (CPU can do other work)
- Avoid mode switches (REP/SEP) in tight loops
- Use BRA instead of JMP for short jumps
- Inline small subroutines to avoid JSR/RTS overhead

EXAMPLE OUTPUT FORMAT:
{{
  "instruction": "This sprite update routine runs 12 times per frame and it's too slow...",
  "input": "Original routine (estimated ~45 cycles):\\n```asm\\nUpdateSprite:\\n    LDA.w $0E00,X  ; 5 cyc\\n    ...\\n```\\nNeed to reduce by at least 10 cycles.",
  "output": "**Cycle Analysis**\\n\\nOriginal: 45 cycles\\n- Line 1: LDA.w $0E00,X = 5 cycles\\n...\\n\\n**Optimizations Applied**\\n\\n1. Convert to direct page addressing (saves 1 cycle per access)\\n2. Use 16-bit load for paired bytes (saves 3 cycles)\\n\\n**Optimized Code**\\n```asm\\nUpdateSprite:\\n    ; Set direct page to sprite table\\n    PHD                 ; 4 cyc - save DP\\n    LDA.w #$0E00        ; 3 cyc\\n    TCD                 ; 2 cyc\\n    ; Now use DP addressing\\n    LDA.b $00,X         ; 4 cyc (was 5)\\n    ...\\n```\\n\\n**Results**: 45 → 32 cycles (29% reduction)"
}}

JSON FORMAT:
{{
  "instruction": "...",
  "input": "...",
  "output": "..."
}}
"""

    def filter_items_for_task(self, items: list[AsmSourceItem]) -> list[AsmSourceItem]:
        """Filter to routines suitable for optimization.

        Prioritizes routines that:
        - Are called frequently (update, draw, tick functions)
        - Have optimization potential (loops, repeated operations)
        - Use suboptimal patterns (absolute addressing in loops)
        """
        scored_items = []
        for item in items:
            score = 0
            code_lower = item.code.lower()
            name_lower = item.name.lower()

            # Frequently called routines
            if any(x in name_lower for x in ['update', 'draw', 'tick', 'main', 'loop', 'frame']):
                score += 3

            # Has loops (optimization opportunity)
            if any(x in code_lower for x in ['dex', 'dey', 'inx', 'iny', 'dec', 'inc']):
                if any(x in code_lower for x in ['bne', 'beq', 'bpl', 'bmi']):
                    score += 3

            # Uses absolute addressing (could use DP)
            if '.w $' in code_lower and '.b $' not in code_lower:
                score += 2

            # Multiple memory accesses (DMA candidate)
            mem_ops = code_lower.count('lda') + code_lower.count('sta')
            if mem_ops > 5:
                score += 2

            # Mode switches in routine (potential optimization)
            if 'rep #' in code_lower or 'sep #' in code_lower:
                score += 1

            # Non-trivial size (worth optimizing)
            if len(item.code.split('\n')) > 10:
                score += 1

            scored_items.append((score, item))

        scored_items.sort(key=lambda x: x[0], reverse=True)
        cutoff = int(len(scored_items) * 0.7)
        return [item for _, item in scored_items[:max(cutoff, 100)]]


if __name__ == "__main__":
    import asyncio
    from pathlib import Path

    async def main():
        gen = AsmOptimizeGenerator()
        await gen.setup()

        items = await gen.extract_source_items()
        filtered = gen.filter_items_for_task(items)
        print(f"Filtered to {len(filtered)} optimization-suitable routines")

        if filtered:
            sample = await gen.generate_sample(filtered[0])
            if sample:
                print(f"\nSample instruction: {sample.instruction[:100]}...")

    asyncio.run(main())

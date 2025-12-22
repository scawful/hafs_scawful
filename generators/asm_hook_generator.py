"""ASM Hook Generator - Training data for hook/patch creation.

Generates samples that teach the model to:
- Identify hookable locations in game code
- Write jump hooks (JSL to freespace, RTL back)
- Create patches that extend functionality
- Handle bank switching and freespace allocation

Target model: euclid-asm (hook/patch specialist)
"""

from __future__ import annotations

import logging
import random
from typing import Optional

from hafs_scawful.generators.asm_base import AsmBaseGenerator, AsmSourceItem

logger = logging.getLogger(__name__)


# Hook/patch scenarios
HOOK_SCENARIOS = [
    {
        "request": "Add a custom check before this game action",
        "hook_type": "pre_hook",
        "example": "Check if player has specific item before allowing action",
    },
    {
        "request": "Extend this routine with additional functionality",
        "hook_type": "extension",
        "example": "Add particle effects when this event triggers",
    },
    {
        "request": "Replace this behavior with custom logic",
        "hook_type": "replacement",
        "example": "Change how damage is calculated",
    },
    {
        "request": "Add a conditional branch to this routine",
        "hook_type": "conditional",
        "example": "Only execute original code if certain flag is set",
    },
    {
        "request": "Create a hook to track when this routine is called",
        "hook_type": "logging",
        "example": "Write to debug RAM when routine executes",
    },
    {
        "request": "Patch this routine to call a custom handler",
        "hook_type": "callback",
        "example": "Call custom event handler for mod compatibility",
    },
    {
        "request": "Add post-processing after this routine completes",
        "hook_type": "post_hook",
        "example": "Update custom UI after inventory changes",
    },
    {
        "request": "Create a table-driven replacement for this logic",
        "hook_type": "table_driven",
        "example": "Replace hardcoded values with data table lookup",
    },
]


class AsmHookGenerator(AsmBaseGenerator):
    """Generate hook/patch creation training samples.

    Creates instruction-tuning data that teaches models to:
    1. Identify safe hook points in existing code
    2. Write JSL hooks with proper setup/teardown
    3. Handle freespace allocation and bank switching
    4. Preserve game state across hooks
    """

    TASK_TYPE = "hook"

    def __init__(self):
        super().__init__(
            name="AsmHookGenerator",
            domain="asm_hook",
        )

    def get_teacher_prompt(self, item: AsmSourceItem) -> str:
        """Generate hook/patch-focused teacher prompt."""
        scenario = random.choice(HOOK_SCENARIOS)
        enriched_code = self.enrich_code(item.code)
        memory_context = ", ".join(item.memory_access) if item.memory_access else "Unknown"

        return f"""You are an expert SNES ROM hacker specializing in Zelda: A Link to the Past hook and patch creation.

HOOK REQUEST:
Target routine: {item.name}
Bank: {item.bank}
Address: {item.address}
Memory regions: {memory_context}
Description: {item.description or "Game routine"}

REQUEST TYPE: {scenario['request']}
HOOK TYPE: {scenario['hook_type']}
EXAMPLE USE CASE: {scenario['example']}

ORIGINAL CODE TO HOOK:
```asm
{enriched_code}
```

Generate a JSON object with hook implementation:

1. "instruction": A ROM hacker's request for a hook/patch. Examples:
   - "I want to add custom logic when Link picks up an item. How do I hook {item.name}?"
   - "I need to extend this routine to trigger a custom event. What's the safest hook point?"
   - "How can I patch this routine to use my custom handler instead?"

2. "input": The hooking context including:
   - The target routine code
   - What the hacker wants to achieve
   - Any constraints (freespace location, compatibility needs)
   - Current understanding of the routine

3. "output": Complete hook implementation including:
   - Analysis of safe hook points
   - The JSL hook patch (original ROM changes)
   - The freespace routine (custom code)
   - Register preservation requirements
   - Any caveats or compatibility notes

HOOK WRITING GUIDELINES:

**Standard JSL Hook Pattern:**
```asm
; === PATCH (in original ROM) ===
org $XX:XXXX          ; Original routine location
    JSL CustomHook    ; 4 bytes - replaces original instructions
    NOP               ; Pad if needed to match original size

; === FREESPACE (in expanded ROM) ===
org $XX:8000          ; Freespace in expanded bank
CustomHook:
    ; Preserve registers if needed
    PHP : PHA

    ; === YOUR CUSTOM CODE HERE ===

    ; Execute replaced original instructions
    [original code that was overwritten]

    ; Restore and return
    PLA : PLP
    RTL               ; Return to after the hook
```

**Key Considerations:**
- JSL is 4 bytes - must overwrite exactly 4 bytes or NOP pad
- Preserve registers (A, X, Y, P) that original code expects
- Handle both 8-bit and 16-bit accumulator states
- Consider bank register (DBR) for data access
- Test with both NTSC and PAL timing

EXAMPLE OUTPUT FORMAT:
{{
  "instruction": "I want to trigger a custom event when Link collects a heart piece. How do I hook the heart collection routine?",
  "input": "Target: HeartPieceCollect at $02:C4A0\\n```asm\\nHeartPieceCollect:\\n    LDA.w $7EF36B\\n    INC A\\n    STA.w $7EF36B\\n    ...\\n```\\nI have freespace at $3F:8000.",
  "output": "**Hook Analysis**\\n\\nThe safest hook point is at $02:C4A0, the routine entry. This lets us:\\n1. Check conditions before incrementing hearts\\n2. Trigger custom events after the increment\\n\\n**Patch (ROM changes)**\\n```asm\\norg $02C4A0\\n    JSL HeartHook   ; Hook entry point\\n    NOP             ; Pad (was LDA.w $7EF36B = 4 bytes)\\n```\\n\\n**Freespace ($3F:8000)**\\n```asm\\norg $3F8000\\nHeartHook:\\n    PHP             ; Save processor flags\\n    PHA             ; Save A\\n    \\n    ; --- Custom event trigger ---\\n    LDA.b #$01      ; Custom event ID\\n    STA.w $7FFF00   ; Write to mod event register\\n    \\n    ; --- Execute original code ---\\n    LDA.w $7EF36B   ; Original: Load heart pieces\\n    INC A           ; Original: Increment\\n    STA.w $7EF36B   ; Original: Store back\\n    \\n    PLA             ; Restore A\\n    PLP             ; Restore flags\\n    RTL             ; Return to $02:C4A5\\n```\\n\\n**Notes:**\\n- Hook replaces 5 bytes, padded with NOP\\n- $7FFF00 is unused WRAM for mod communication\\n- Safe for randomizer compatibility"
}}

JSON FORMAT:
{{
  "instruction": "...",
  "input": "...",
  "output": "..."
}}
"""

    def filter_items_for_task(self, items: list[AsmSourceItem]) -> list[AsmSourceItem]:
        """Filter to routines suitable for hooking.

        Prioritizes routines that:
        - Are game events (collect, trigger, enter, exit)
        - Have clear entry/exit points
        - Are commonly modified by ROM hacks
        """
        scored_items = []
        for item in items:
            score = 0
            name_lower = item.name.lower()
            code_lower = item.code.lower()

            # Event-like routines (good hook targets)
            event_keywords = ['collect', 'pickup', 'trigger', 'event', 'enter', 'exit',
                             'damage', 'heal', 'spawn', 'death', 'transition', 'load',
                             'init', 'setup', 'handle', 'process', 'check']
            if any(kw in name_lower for kw in event_keywords):
                score += 4

            # Has clear entry point (starts with meaningful code)
            first_lines = '\n'.join(item.code.split('\n')[:3]).lower()
            if any(x in first_lines for x in ['lda', 'ldx', 'ldy', 'php', 'pha']):
                score += 2

            # Modifies game state (worth hooking)
            if 'sta' in code_lower and ('$7e' in code_lower or '$7f' in code_lower):
                score += 2

            # Has subroutine calls (extensible)
            if 'jsr' in code_lower or 'jsl' in code_lower:
                score += 1

            # Not too short (meaningful to hook)
            if len(item.code.split('\n')) > 5:
                score += 1

            # Not too long (easier to understand)
            if len(item.code.split('\n')) < 50:
                score += 1

            scored_items.append((score, item))

        scored_items.sort(key=lambda x: x[0], reverse=True)
        cutoff = int(len(scored_items) * 0.6)
        return [item for _, item in scored_items[:max(cutoff, 100)]]


if __name__ == "__main__":
    import asyncio
    from pathlib import Path

    async def main():
        gen = AsmHookGenerator()
        await gen.setup()

        items = await gen.extract_source_items()
        filtered = gen.filter_items_for_task(items)
        print(f"Filtered to {len(filtered)} hookable routines")

        if filtered:
            sample = await gen.generate_sample(filtered[0])
            if sample:
                print(f"\nSample instruction: {sample.instruction[:100]}...")

    asyncio.run(main())

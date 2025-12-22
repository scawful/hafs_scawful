"""ASM Doc Generator - Training data for code explanation/documentation.

Generates samples that teach the model to:
- Explain what assembly code does in plain English
- Document routines with proper formatting
- Identify game mechanics from code patterns
- Create reference documentation

Target model: euclid-asm (documentation specialist)
"""

from __future__ import annotations

import logging
import random
from typing import Optional

from hafs_scawful.generators.asm_base import AsmBaseGenerator, AsmSourceItem

logger = logging.getLogger(__name__)


# Documentation request styles
DOC_STYLES = [
    {
        "style": "explain_beginner",
        "audience": "Someone new to 65816 assembly",
        "format": "Step-by-step explanation with basics covered",
    },
    {
        "style": "explain_expert",
        "audience": "Experienced ROM hacker",
        "format": "Concise technical explanation focusing on non-obvious details",
    },
    {
        "style": "document_reference",
        "audience": "Documentation reader",
        "format": "Formal reference documentation with parameters, returns, side effects",
    },
    {
        "style": "reverse_engineer",
        "audience": "ROM hacker trying to understand game mechanics",
        "format": "High-level game mechanic explanation derived from code",
    },
    {
        "style": "annotate_inline",
        "audience": "Code reader",
        "format": "Line-by-line inline comments explaining each instruction",
    },
    {
        "style": "summarize",
        "audience": "Quick reference user",
        "format": "One-paragraph summary of what the routine does",
    },
    {
        "style": "diagram",
        "audience": "Visual learner",
        "format": "ASCII diagram showing data flow or control flow",
    },
    {
        "style": "compare",
        "audience": "Researcher comparing game versions",
        "format": "Analysis suitable for comparing with other implementations",
    },
]


class AsmDocGenerator(AsmBaseGenerator):
    """Generate documentation/explanation training samples.

    Creates instruction-tuning data that teaches models to:
    1. Explain assembly code at various skill levels
    2. Create formal documentation
    3. Reverse-engineer game mechanics from code
    4. Annotate code with meaningful comments
    """

    TASK_TYPE = "doc"

    def __init__(self):
        super().__init__(
            name="AsmDocGenerator",
            domain="asm_doc",
        )

    def get_teacher_prompt(self, item: AsmSourceItem) -> str:
        """Generate documentation-focused teacher prompt."""
        style = random.choice(DOC_STYLES)
        enriched_code = self.enrich_code(item.code)
        memory_context = ", ".join(item.memory_access) if item.memory_access else "Various"

        return f"""You are an expert SNES 65816 assembly educator specializing in Zelda: A Link to the Past documentation and explanation.

DOCUMENTATION REQUEST:
Routine: {item.name}
Bank: {item.bank}
Address: {item.address}
Memory regions: {memory_context}
Known description: {item.description or "Undocumented routine"}

DOCUMENTATION STYLE: {style['style']}
TARGET AUDIENCE: {style['audience']}
OUTPUT FORMAT: {style['format']}

CODE TO DOCUMENT:
```asm
{enriched_code}
```

Generate a JSON object with documentation:

1. "instruction": A user asking for code explanation. Examples:
   - "Can you explain what this routine does? I'm new to 65816."
   - "I need reference documentation for {item.name}."
   - "What game mechanic does this code implement?"
   - "Add inline comments to this routine explaining each line."

2. "input": The documentation context including:
   - The code to be documented
   - Any known context about the routine
   - The user's skill level or needs

3. "output": The requested documentation including:
   - Appropriate level of detail for the audience
   - Accurate technical explanations
   - Clear formatting matching the requested style
   - Game-specific context where relevant

DOCUMENTATION GUIDELINES:

**For Beginners:**
- Explain what registers (A, X, Y) are
- Define addressing modes (immediate #, direct page .b, absolute .w)
- Describe what each instruction type does (LDA=load, STA=store, etc.)
- Connect code to game behavior

**For Experts:**
- Focus on non-obvious behavior
- Note timing-sensitive sections
- Highlight clever tricks or optimizations
- Mention edge cases and gotchas

**For Reference Docs:**
```
## RoutineName

**Address:** $XX:XXXX
**Bank:** $XX

### Description
[What it does]

### Parameters
- A: [expected value]
- X: [expected value]

### Returns
- A: [modified to...]

### Side Effects
- Modifies $7E:XXXX
- Clobbers X register

### Notes
[Important details]
```

**For Inline Annotation:**
```asm
RoutineName:
    ; [Overall purpose of this routine]
    LDA.w $0E00     ; Load player state from WRAM
    AND.b #$0F      ; Mask lower nibble (action state 0-15)
    CMP.b #$05      ; Compare to "sword swing" state
    BEQ .swinging   ; Branch if player is mid-swing
    ...
```

EXAMPLE OUTPUT FORMAT:
{{
  "instruction": "I found this routine while disassembling ALTTP. Can you explain what it does?",
  "input": "```asm\\nCheckSword:\\n    LDA.w $0301\\n    BEQ .no_sword\\n    ...\\n```\\nI think it's related to sword checks but I'm not sure how it works.",
  "output": "## CheckSword - Sword Equipment Verification\\n\\n**Purpose:** This routine checks whether Link currently has a sword equipped and sets flags accordingly.\\n\\n**How it works:**\\n\\n1. **Load sword status** (`LDA.w $0301`)\\n   - $7E:0301 holds Link's current sword level (0=none, 1=fighter, 2=master, 3=tempered, 4=gold)\\n   \\n2. **Check for no sword** (`BEQ .no_sword`)\\n   - If A=0 (no sword), branch to handle that case\\n   - Otherwise, fall through to sword-equipped logic\\n\\n**Used by:** Combat routines, menu display, item checks\\n\\n**RAM Reference:**\\n- $7E:0301 - Sword level (0-4)"
}}

JSON FORMAT:
{{
  "instruction": "...",
  "input": "...",
  "output": "..."
}}
"""

    def filter_items_for_task(self, items: list[AsmSourceItem]) -> list[AsmSourceItem]:
        """Filter to routines worth documenting.

        Prioritizes routines that:
        - Have meaningful names
        - Implement recognizable game features
        - Have moderate complexity (interesting but explainable)
        """
        scored_items = []
        for item in items:
            score = 0
            name_lower = item.name.lower()
            code_lower = item.code.lower()

            # Meaningful name (not just address-based)
            if not name_lower.startswith('sub_') and not name_lower.startswith('loc_'):
                score += 2
            if '_' in item.name or any(c.isupper() for c in item.name[1:]):
                score += 1  # CamelCase or snake_case suggests named function

            # Game feature keywords
            feature_keywords = ['player', 'link', 'enemy', 'sprite', 'item', 'menu',
                               'dialog', 'chest', 'door', 'switch', 'dungeon', 'overworld',
                               'music', 'sound', 'graphics', 'palette', 'animation',
                               'collision', 'physics', 'movement', 'inventory', 'save']
            if any(kw in name_lower for kw in feature_keywords):
                score += 3

            # Moderate complexity (not trivial, not overwhelming)
            line_count = len(item.code.split('\n'))
            if 5 <= line_count <= 40:
                score += 2
            elif 40 < line_count <= 80:
                score += 1

            # Has comments already (indicates importance)
            if ';' in item.code:
                score += 1

            # Accesses game-relevant RAM
            if '$7e' in code_lower or '$7f' in code_lower:
                score += 1

            scored_items.append((score, item))

        scored_items.sort(key=lambda x: x[0], reverse=True)
        cutoff = int(len(scored_items) * 0.75)
        return [item for _, item in scored_items[:max(cutoff, 100)]]


if __name__ == "__main__":
    import asyncio
    from pathlib import Path

    async def main():
        gen = AsmDocGenerator()
        await gen.setup()

        items = await gen.extract_source_items()
        filtered = gen.filter_items_for_task(items)
        print(f"Filtered to {len(filtered)} documentable routines")

        if filtered:
            sample = await gen.generate_sample(filtered[0])
            if sample:
                print(f"\nSample instruction: {sample.instruction[:100]}...")

    asyncio.run(main())

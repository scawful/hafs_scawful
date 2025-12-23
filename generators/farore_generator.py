"""
Farore Data Generator for Tool Orchestration training data.

Generates instruction-tuning data for the Farore SME model, focusing on 
converting natural language into precise MCP tool calls for Yaze.
"""

from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

from agents.training.base import DataGenerator, SourceItem, TrainingSample
from agents.training.json_utils import extract_json_from_response

logger = logging.getLogger(__name__)

@dataclass
class ToolSourceItem(SourceItem):
    """Source item for MCP tools."""
    name: str = ""
    content: str = ""
    source: str = ""
    arguments: str = ""
    description: str = ""

class FaroreDataGenerator(DataGenerator):
    """Generate instruction-tuning data for tool orchestration."""

    def __init__(self):
        super().__init__(
            name="FaroreDataGenerator",
            domain="tools",
            teacher_tier="coding",
        )
        self._schema = []
        self._orchestrator = None

    async def setup(self):
        await super().setup()
        schema_path = Path("/Users/scawful/Code/yaze_mcp_schema.json")
        if schema_path.exists():
            with open(schema_path, 'r') as f:
                self._schema = json.load(f)
        
        from core.orchestrator_v2 import UnifiedOrchestrator
        self._orchestrator = UnifiedOrchestrator()
        await self._orchestrator.initialize()

    async def extract_source_items(self) -> list[ToolSourceItem]:
        if not self._schema:
            await self.setup()
        
        return [
            ToolSourceItem(
                name=t['name'],
                content=t['description'],
                source="mcp_schema",
                arguments=t['arguments'],
                description=t['description']
            ) for t in self._schema
        ]

    def get_teacher_prompt(self, item: SourceItem) -> str:
        if not isinstance(item, ToolSourceItem):
            raise TypeError(f"Expected ToolSourceItem, got {type(item)}")

        schema_context = json.dumps(self._schema, indent=2)

        return f"""
You are an expert AI orchestrator for the Yaze SNES development environment. 
Your task is to generate high-quality training data for a tool-use model called 'Farore'.

TARGET TOOL: {item.name}
ARGUMENTS: {item.arguments}
DESCRIPTION: {item.description}

FULL TOOL SCHEMA:
```json
{schema_context}
```

Generate 3 diverse training samples for this specific tool. 
Each sample should show a different way a user might request this action.

Generate a JSON list of objects with:
1. "instruction": What the user says (Natural Language).
2. "thought": A brief chain-of-thought explaining why this tool is selected.
3. "output": The exact python function call (e.g., `read_memory(address="$7E0010", size=1)`).

VARIETY REQUIREMENTS:
- Sample 1: Direct request (e.g., 'Read the game mode').
- Sample 2: Conversational context (e.g., 'Hey, can you check how much health I have left?').
- Sample 3: Complex or technical request (e.g., 'Monitor the WRAM at $7E2000 for any writes').

JSON FORMAT:
[
  {{
    "instruction": "...",
    "thought": "...",
    "output": "..."
  }}, ...
]"""

    async def generate_sample(self, item: SourceItem) -> Optional[list[TrainingSample]]:
        if not isinstance(item, ToolSourceItem):
            return None

        prompt = self.get_teacher_prompt(item)

        try:
            from core.orchestrator_v2 import Provider, TaskTier

            response_obj = await self._orchestrator.generate(
                prompt=prompt,
                tier=TaskTier.CODING,
                provider=Provider.GEMINI,
            )

            response = response_obj.content
            data_list = extract_json_from_response(response)
            if not data_list or not isinstance(data_list, list):
                return None

            samples = []
            for data in data_list:
                samples.append(TrainingSample(
                    instruction=str(data.get("instruction", "")),
                    input=str(data.get("thought", "")),
                    output=str(data.get("output", "")),
                    domain="tools",
                    source="farore_gen",
                    teacher_model="gemini-3-flash-preview"
                ))
            return samples

        except Exception as e:
            logger.error(f"Failed to generate for {item.name}: {e}")
            return None

if __name__ == "__main__":
    async def main():
        gen = FaroreDataGenerator()
        await gen.setup()
        items = await gen.extract_source_items()
        
        all_samples = []
        for item in items[:5]: # Pilot run
            samples = await gen.generate_sample(item)
            if samples:
                all_samples.extend(samples)
                print(f"Generated {len(samples)} samples for {item.name}")
        
        output_path = Path("farore_train_pilot.jsonl")
        with open(output_path, "w") as f:
            for s in all_samples:
                f.write(s.to_jsonl_entry() + "\n")
        print(f"Pilot complete: {len(all_samples)} samples saved to {output_path}")

    import asyncio
    asyncio.run(main())

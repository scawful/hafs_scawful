"""Z3ed Tool Data Generator.

Generates instruction-tuning data for the stable subset of z3ed CLI commands.
"""

from __future__ import annotations

import asyncio
import json
import logging
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from agents.training.base import DataGenerator, SourceItem, TrainingSample
from agents.training.json_utils import extract_json_from_response
from config.prompts import get_prompt

logger = logging.getLogger(__name__)


@dataclass
class Z3edSourceItem(SourceItem):
    """Source item for z3ed CLI commands."""
    
    command: str = ""
    description: str = ""
    category: str = ""
    usage: str = ""
    is_stable: bool = True

    @property
    def item_id(self) -> str:
        return f"z3ed:{self.category}:{self.command}"


class Z3edToolGenerator(DataGenerator):
    """Generate instruction-tuning data for stable z3ed commands.
    
    Filters based on the 2025-12-22 codebase audit.
    """

    # Validated stable categories/commands from codebase audit
    STABLE_ALLOWLIST = {
        "resource": ["list", "search"],
        "dungeon": ["list-sprites", "describe-room", "export-room", "list-objects", "get-room-tiles"],
        "overworld": ["find-tile", "describe-map", "list-warps", "list-sprites", "get-entrance", "tile-stats"],
        "hex": ["read", "write"],  # Basic hex ops are stable
        "palette": ["export", "list"],
        "sprite": ["list", "export"],
        "music": ["list", "play"],
        "dialogue": ["list", "search"],
        "emulator": ["run", "pause", "step", "reset"], # gRPC based
    }

    def __init__(self):
        super().__init__(
            name="Z3edToolGenerator",
            domain="tool-use",
            teacher_tier="coding",
        )
        self._orchestrator = None
        self._doc_path = Path.home() / "Code/yaze/docs/public/reference/z3ed-command-reference.md"

    async def setup(self):
        await super().setup()
        from core.orchestrator_v2 import UnifiedOrchestrator
        self._orchestrator = UnifiedOrchestrator()

    def _is_stable(self, command_str: str) -> bool:
        """Check if command is in the stable allowlist."""
        parts = command_str.split()
        if len(parts) < 3: # z3ed <category> <action>
            return False
        
        # parts[0] is z3ed
        category = parts[1]
        action = parts[2]

        if category in self.STABLE_ALLOWLIST:
            allowed_actions = self.STABLE_ALLOWLIST[category]
            # Check for direct match or wildcard
            if "*" in allowed_actions:
                return True
            if action in allowed_actions:
                return True
        
        return False

    async def extract_source_items(self) -> list[Z3edSourceItem]:
        if not self._doc_path.exists():
            logger.warning(f"Z3ed docs not found at {self._doc_path}")
            return []

        items: list[Z3edSourceItem] = []
        
        # 1. Parse Markdown Documentation
        # We look for headers like `### `z3ed <command>`
        content = self._doc_path.read_text()
        
        # Regex to find command headers and their descriptions
        # Matches: ### `z3ed category action` \n Description...
        pattern = re.compile(r"### `(z3ed [a-z0-9-]+ [a-z0-9-]+)`\n(.*?)(?=\n###|\n##|$)", re.DOTALL)
        
        matches = pattern.findall(content)
        
        for cmd_str, desc_block in matches:
            cmd_str = cmd_str.strip()
            desc = desc_block.strip().split('\n')[0] # First line is usually the summary
            
            # Categorize
            parts = cmd_str.split()
            category = parts[1] if len(parts) > 1 else "misc"
            
            # Filter for stability
            if self._is_stable(cmd_str):
                items.append(Z3edSourceItem(
                    name=cmd_str,
                    content=f"Command: {cmd_str}\nDescription: {desc}",
                    source="z3ed-doc",
                    command=cmd_str,
                    description=desc,
                    category=category,
                    usage=cmd_str,
                    is_stable=True
                ))
            else:
                logger.debug(f"Skipping unstable/unknown command: {cmd_str}")

        # 2. Add manual entries for known stable workflows not explicitly in command ref headers
        # (e.g. from usage guide or verified workflows)
        manual_items = [
            ("z3ed asar patch.asm --rom zelda3.sfc", "Apply an assembly patch using the integrated Asar tool.", "asar"),
            ("python3 scripts/analyze_room.py --room 50", "Deep inspect a dungeon room using the analysis script (Alternative to dungeon-doctor).", "script"),
        ]

        for cmd, desc, cat in manual_items:
            items.append(Z3edSourceItem(
                name=cmd.split()[0] + " " + cat, # rudimentary name
                content=f"Command: {cmd}\nDescription: {desc}",
                source="z3ed-manual",
                command=cmd,
                description=desc,
                category=cat,
                usage=cmd,
                is_stable=True
            ))

        logger.info(f"Extracted {len(items)} stable z3ed commands")
        return items

    def get_teacher_prompt(self, item: SourceItem) -> str:
        if not isinstance(item, Z3edSourceItem):
            raise TypeError(f"Expected Z3edSourceItem, got {type(item)}")

        template = (
            "You are an expert ROM hacker teaching a user how to use the 'z3ed' CLI tool for Zelda: A Link to the Past.\n"
            "1. 'instruction': A natural language request a user might make.\n"
            "2. 'input': The context (e.g., 'User has a ROM file named zelda3.sfc').\n"
            "3. 'output': The specific z3ed command to fulfill the request.\n\n"
            "COMMAND DETAILS:\n"
            "Command: {command}\n"
            "Description: {description}\n"
            "Category: {category}\n\n"
            "RULES:\n"
            "- The output must be a valid CLI command string.\n"
            "- Include necessary flags like --rom if context implies it.\n"
            "- If the command is 'asar', explain that it applies a patch.\n"
            "- Make the instruction specific (e.g., 'List all sprites in the dungeon' instead of 'List sprites').\n\n"
            "JSON FORMAT:\n"
            "{{\n"
            "  \"instruction\": \"...\",\n"
            "  \"input\": \"...\",\n"
            "  \"output\": \"...\"\n"
            "}}"
        )

        return template.format(
            command=item.command,
            description=item.description,
            category=item.category
        )

    async def generate_sample(self, item: SourceItem) -> Optional[TrainingSample]:
        if not isinstance(item, Z3edSourceItem):
            return None

        if not self._orchestrator:
            await self.setup()

        prompt = self.get_teacher_prompt(item)

        try:
            from core.orchestrator_v2 import Provider, TaskTier

            response_obj = await asyncio.wait_for(
                self._orchestrator.generate(
                    prompt=prompt,
                    tier=TaskTier.CODING,
                    provider=Provider.GEMINI,
                ),
                timeout=60.0,
            )

            data = extract_json_from_response(response_obj.content)
            if not data:
                return None

            return TrainingSample(
                instruction=str(data.get("instruction", "")),
                input=str(data.get("input", "")),
                output=str(data.get("output", "")),
                domain="tool-use",
                source=item.source,
                teacher_model="gemini-2.0-flash",
                teacher_prompt=prompt,
                kg_entities=["z3ed", item.category, item.command.split()[1] if len(item.command.split()) > 1 else ""]
            )

        except Exception as e:
            logger.error(f"Failed to generate for {item.name}: {e}")
            return None


if __name__ == "__main__":
    async def main():
        logging.basicConfig(level=logging.INFO)
        gen = Z3edToolGenerator()
        await gen.setup()
        
        items = await gen.extract_source_items()
        print(f"Found {len(items)} stable items")
        
        if items:
            result = await gen.run_generation(
                limit=len(items),
                output_path=Path("z3ed_tooling_dataset.jsonl"),
            )
            print(f"Generated {result.processed} samples")

    import asyncio
    asyncio.run(main())
            
"""Z3ed Tool Data Generator.

Generates instruction-tuning data for the stable subset of z3ed CLI commands.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
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

    # Validated stable categories/commands from codebase audit & docs
    STABLE_ALLOWLIST = {
        "rom": ["read", "write", "validate", "snapshot", "restore", "info", "load"],
        "editor": {
            "dungeon": ["place-object", "set-property", "list-objects", "validate-room"],
            "overworld": ["set-tile", "place-entrance", "modify-sprite"],
            "batch": ["*"] # All batch ops
        },
        "query": ["rom-info", "available-commands", "find-tiles", "find-unused-space", "find-duplicates"],
        "test": ["run", "generate", "record", "baseline", "report"],
        "build": ["*"],
        "ci": ["*"],
        "ai": ["chat", "suggest", "analyze", "review", "apply"],
    }

    def __init__(self):
        super().__init__(
            name="Z3edToolGenerator",
            domain="tool-use",
            teacher_tier="coding",
        )
        self._orchestrator = None
        doc_override = os.environ.get("HAFS_Z3ED_DOC_PATH")
        yaze_root = os.environ.get("HAFS_YAZE_ROOT")
        if doc_override:
            self._doc_path = Path(doc_override).expanduser()
        elif yaze_root:
            self._doc_path = Path(yaze_root).expanduser() / "docs/public/reference/z3ed-command-reference.md"
        else:
            self._doc_path = Path.home() / "Code/yaze/docs/public/reference/z3ed-command-reference.md"

    async def setup(self):
        await super().setup()
        from core.orchestrator_v2 import UnifiedOrchestrator
        self._orchestrator = UnifiedOrchestrator()

    def _is_stable(self, command_parts: list[str]) -> bool:
        """Check if command is in the stable allowlist.
        Args:
            command_parts: ['z3ed', 'rom', 'read'] or ['z3ed', 'editor', 'dungeon', 'place-object']
        """
        if len(command_parts) < 2: 
            return False
        
        # parts[0] is z3ed
        category = command_parts[1]
        
        if category not in self.STABLE_ALLOWLIST:
            return False
            
        allowed = self.STABLE_ALLOWLIST[category]
        
        # Simple list (e.g. "rom": ["read"])
        if isinstance(allowed, list):
            action = command_parts[2] if len(command_parts) > 2 else ""
            if "*" in allowed: return True
            return action in allowed
            
        # Nested dict (e.g. "editor": {"dungeon": [...]})
        if isinstance(allowed, dict):
            if len(command_parts) < 3: return False
            subcat = command_parts[2]
            if subcat not in allowed: return False
            
            sub_allowed = allowed[subcat]
            if "*" in sub_allowed: return True
            
            action = command_parts[3] if len(command_parts) > 3 else ""
            return action in sub_allowed
            
        return False

    async def extract_source_items(self) -> list[Z3edSourceItem]:
        if not self._doc_path.exists():
            logger.warning(f"Z3ed docs not found at {self._doc_path}")
            return []

        items: list[Z3edSourceItem] = []
        content = self._doc_path.read_text()
        
        # Strategy: Split by "### `z3ed" to find main blocks
        sections = re.split(r"(?=### `z3ed)", content)
        
        for section in sections:
            if not section.strip().startswith("### `z3ed"):
                continue
                
            # Extract the command from the header
            # Header: ### `z3ed rom read`
            header_match = re.match(r"### `(.*?)`", section)
            if not header_match:
                continue
                
            full_cmd_str = header_match.group(1).strip()
            parts = full_cmd_str.split()
            
            # Extract description (text after header until next header or code block)
            desc_match = re.search(r"`\n(.*?)(?=\n\*\*|\n`|\n#)", section, re.DOTALL)
            desc = desc_match.group(1).strip() if desc_match else "No description"
            desc = desc.replace("\n", " ").strip()
            
            # Check stability
            if self._is_stable(parts):
                items.append(Z3edSourceItem(
                    name=full_cmd_str,
                    content=f"Command: {full_cmd_str}\nDescription: {desc}",
                    source="z3ed-doc",
                    command=full_cmd_str,
                    description=desc,
                    category=parts[1],
                    usage=full_cmd_str
                ))
            
            # Look for subcommands (#### `action`) within this section
            # This handles 'z3ed editor dungeon' -> 'place-object'
            sub_matches = re.findall(r"#### `(.*?)`\n(.*?)(?=\n####|\n\*\*|\n`|$)", section, re.DOTALL)
            logger.info(f"Checking subsection: {full_cmd_str}. Found {len(sub_matches)} subcommands.")
            
            for sub_action, sub_desc in sub_matches:
                # Construct full command: parent command + sub action
                # But parent command might already have args?
                # Usually parent is "z3ed editor dungeon" and sub is "place-object"
                # So we join them.
                sub_full_cmd = f"{full_cmd_str} {sub_action}"
                sub_parts = sub_full_cmd.split()
                
                if self._is_stable(sub_parts):
                    clean_desc = sub_desc.strip().split('\n')[0]
                    items.append(Z3edSourceItem(
                        name=sub_full_cmd,
                        content=f"Command: {sub_full_cmd}\nDescription: {clean_desc}",
                        source="z3ed-doc-sub",
                        command=sub_full_cmd,
                        description=clean_desc,
                        category=parts[1], # Keep top level category
                        usage=sub_full_cmd
                    ))

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
            

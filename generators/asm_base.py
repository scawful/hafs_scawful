"""Base class for specialized ASM generators.

Provides shared setup, source extraction, and sample generation logic.
Specialized generators override get_teacher_prompt() for task-specific prompts.
"""

from __future__ import annotations

import asyncio
import json
import logging
from abc import abstractmethod
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

from agents.training.base import DataGenerator, SourceItem, TrainingSample
from agents.training.json_utils import extract_json_from_response
from agents.knowledge.asm_preprocessor import AsmPreprocessor

logger = logging.getLogger(__name__)


@dataclass
class AsmSourceItem(SourceItem):
    """Source item for 65816 assembly routines."""

    code: str = ""
    bank: str = ""
    memory_access: list[str] = field(default_factory=list)
    description: str = ""
    address: str = ""

    @property
    def item_id(self) -> str:
        return f"{self.source}:{self.name}:{self.address}"


class AsmBaseGenerator(DataGenerator):
    """Base class for ASM sample generators.

    Subclasses must implement:
    - get_teacher_prompt(item) - returns task-specific prompt
    - TASK_TYPE class attribute - identifies the task type (e.g., "debug", "optimize")
    """

    TASK_TYPE: str = "base"  # Override in subclasses

    def __init__(self, name: str = "AsmBaseGenerator", domain: str = "asm"):
        super().__init__(
            name=name,
            domain=domain,
            teacher_tier="coding",
        )
        self._unified_kb = None
        self._orchestrator = None
        self._preprocessor = None

    async def setup(self):
        """Initialize resources and knowledge bases."""
        await super().setup()

        from agents.knowledge.alttp_unified import UnifiedALTTPKnowledge

        self._unified_kb = UnifiedALTTPKnowledge()
        await self._unified_kb.setup()

        # Build combined symbol map for preprocessor
        symbol_map = {}
        if self._unified_kb._vanilla_kb:
            for sym in self._unified_kb._vanilla_kb._symbols.values():
                addr = getattr(sym, "address", None) or sym.get("address")
                name = getattr(sym, "name", None) or sym.get("name")
                if addr:
                    symbol_map[addr] = name
        if self._unified_kb._hack_kb:
            for sym in self._unified_kb._hack_kb._symbols.values():
                addr = getattr(sym, "address", None) or sym.get("address")
                name = getattr(sym, "name", None) or sym.get("name")
                if addr:
                    symbol_map[addr] = name

        self._preprocessor = AsmPreprocessor(symbol_map)
        self._orchestrator = self._unified_kb._orchestrator

    async def extract_source_items(self) -> list[AsmSourceItem]:
        """Extract routines from vanilla and hack KBs."""
        if not self._unified_kb:
            await self.setup()

        items: list[AsmSourceItem] = []

        def extract_routine(name, routine, source: str) -> AsmSourceItem:
            routine_data = (
                routine.to_dict() if hasattr(routine, "to_dict") else dict(routine)
            )
            code = routine_data.get("code", "")
            if isinstance(code, (bytes, bytearray, memoryview)):
                code = code.decode("utf-8", errors="replace")
            elif not isinstance(code, str):
                code = str(code)

            return AsmSourceItem(
                name=str(name),
                content=code,
                source=source,
                code=code,
                bank=str(routine_data.get("bank", "")),
                memory_access=[str(m) for m in routine_data.get("memory_access", [])],
                description=str(routine_data.get("description", "")),
                address=str(routine_data.get("address", "")),
            )

        if self._unified_kb._vanilla_kb:
            for name, routine in self._unified_kb._vanilla_kb._routines.items():
                items.append(extract_routine(name, routine, "vanilla"))

        if self._unified_kb._hack_kb:
            for name, routine in self._unified_kb._hack_kb._routines.items():
                items.append(extract_routine(name, routine, "hack"))

        logger.info(f"[{self.TASK_TYPE}] Extracted {len(items)} ASM routines")
        return items

    def enrich_code(self, code: str) -> str:
        """Enrich code with semantic symbol names."""
        if self._preprocessor:
            return self._preprocessor.enrich(code)
        return code

    @abstractmethod
    def get_teacher_prompt(self, item: AsmSourceItem) -> str:
        """Generate task-specific teacher prompt. Must be implemented by subclasses."""
        raise NotImplementedError

    async def generate_sample(self, item: SourceItem) -> Optional[TrainingSample]:
        """Use teacher model to generate instruction from ASM routine."""
        if not isinstance(item, AsmSourceItem):
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
                timeout=120.0,
            )

            response = response_obj.content
            data = extract_json_from_response(response)
            if not data:
                logger.warning(f"[{self.TASK_TYPE}] Failed to extract JSON for {item.name}")
                return None

            instruction = str(data.get("instruction", "")).strip()
            input_text = str(data.get("input", "")).strip()
            output_data = data.get("output", item.code)

            if isinstance(output_data, (bytes, bytearray, memoryview)):
                output = output_data.decode("utf-8", errors="replace")
            elif isinstance(output_data, str):
                output = output_data
            else:
                output = str(output_data)

            kg_entities = [str(item.name)]
            for m in item.memory_access:
                kg_entities.append(str(m) if not isinstance(m, str) else m)

            return TrainingSample(
                instruction=instruction,
                input=input_text,
                output=output,
                domain=f"asm_{self.TASK_TYPE}",  # Task type encoded in domain
                source=str(item.source),
                teacher_model="gemini-3-flash-preview",
                teacher_prompt=str(prompt),
                kg_entities=kg_entities,
            )

        except asyncio.TimeoutError:
            logger.warning(f"[{self.TASK_TYPE}] Timeout for {item.name}")
            return None
        except json.JSONDecodeError as e:
            logger.warning(f"[{self.TASK_TYPE}] JSON parse failed for {item.name}: {e}")
            return None
        except Exception as e:
            import traceback
            logger.error(f"[{self.TASK_TYPE}] Failed for {item.name}: {e}")
            logger.error(f"Traceback:\n{traceback.format_exc()}")
            return None

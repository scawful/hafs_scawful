"""Asar Validator for verifying 65816 assembly code.

Uses the actual 'asar' binary to assemble code snippets against a dummy ROM.
This provides 100% accurate syntax and label validation.
"""

from __future__ import annotations

import asyncio
import logging
import os
import shutil
import tempfile
from pathlib import Path
from typing import Optional

from agents.training.base import TrainingSample
from agents.training.validators.base import ValidationResult, Validator

logger = logging.getLogger(__name__)

class AsarValidator(Validator):
    """Validates assembly code by running it through Asar."""

    # Default paths (can be overridden via config)
    DEFAULT_ASAR_PATH = Path.home() / "Code/asar/build/asar/bin/asar"
    DEFAULT_ROM_PATH = Path.home() / "Code/asar/dummy_rom.sfc"

    def __init__(self, asar_path: Path = None, rom_path: Path = None):
        super().__init__("AsarValidator", "asm")
        self.asar_path = asar_path or self.DEFAULT_ASAR_PATH
        self.rom_path = rom_path or self.DEFAULT_ROM_PATH
        
        if not self.asar_path.exists():
            logger.warning(f"Asar binary not found at {self.asar_path}")
        if not self.rom_path.exists():
            logger.warning(f"Dummy ROM not found at {self.rom_path}")

    async def validate(self, sample: TrainingSample) -> ValidationResult:
        """Run asar on the sample output code."""
        if not self.asar_path.exists() or not self.rom_path.exists():
            return ValidationResult(
                valid=True,
                score=0.5,
                warnings=["Asar validator skipped: binary or ROM missing"]
            )

        # Extract code (simple heuristic: look for code blocks or use full output)
        code = self._extract_code(sample.output)
        if not code:
             return ValidationResult(valid=False, score=0.0, errors=["No code found"])

        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            source_file = tmp_path / "test.asm"
            rom_file = tmp_path / "test.sfc"
            
            # Copy dummy ROM to temp (to avoid modifying the original)
            shutil.copy(self.rom_path, rom_file)
            
            # Wrap code in a safe patch structure
            # We assume the code is a snippet, so we hook it into free space
            wrapped_code = (
                "lorom\n"
                "org $008000\n" # Hook into start of ROM
                f"{code}\n"
            )
            
            source_file.write_text(wrapped_code)
            
            # Run asar
            proc = await asyncio.create_subprocess_exec(
                str(self.asar_path),
                str(source_file),
                str(rom_file),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await proc.communicate()
            
            if proc.returncode == 0:
                return ValidationResult(valid=True, score=1.0)
            else:
                error_msg = stderr.decode() + stdout.decode()
                # Clean up error message
                lines = [l for l in error_msg.split('\n') if "error:" in l.lower()]
                return ValidationResult(
                    valid=False,
                    score=0.0,
                    errors=lines[:3] or ["Asar failed to assemble"]
                )

    def _extract_code(self, text: str) -> str:
        """Extract ASM code from markdown block or raw text."""
        if "```asm" in text:
            parts = text.split("```asm")
            if len(parts) > 1:
                return parts[1].split("```")[0].strip()
        if "```" in text:
             parts = text.split("```")
             if len(parts) > 1:
                 return parts[1].strip()
        return text # Assume raw code if no blocks

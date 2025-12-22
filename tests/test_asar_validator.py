"""Tests for AsarValidator using real binaries."""

import pytest
import asyncio
from pathlib import Path
from agents.training.base import TrainingSample
from hafs_scawful.validators.asar_validator import AsarValidator

@pytest.mark.asyncio
async def test_asar_validator_success():
    """Verify that valid ASM assembles successfully."""
    validator = AsarValidator()
    
    sample = TrainingSample(
        instruction="Generate a simple NOP loop.",
        input="asm",
        output="""
        ```asm
        LDA #$01
        STA $00
        RTS
        ```
        """,
        domain="asm",
        source="test"
    )
    
    result = await validator.validate(sample)
    assert result.valid is True
    assert result.score == 1.0
    assert not result.errors

@pytest.mark.asyncio
async def test_asar_validator_failure():
    """Verify that invalid ASM returns errors."""
    validator = AsarValidator()
    
    sample = TrainingSample(
        instruction="Generate broken code.",
        input="asm",
        output="""
        ```asm
        INVALID_OPCODE #$1234
        ```
        """,
        domain="asm",
        source="test"
    )
    
    result = await validator.validate(sample)
    assert result.valid is False
    assert result.score == 0.0
    assert any("error" in e.lower() for e in result.errors)

@pytest.mark.asyncio
async def test_asar_validator_missing_binary():
    """Verify behavior when asar is missing (should skip with warning)."""
    validator = AsarValidator(asar_path=Path("/non/existent/asar"))
    
    sample = TrainingSample(
        instruction="...",
        input="asm",
        output="LDA #$00",
        domain="asm",
        source="test"
    )
    
    result = await validator.validate(sample)
    assert result.valid is True # Defaults to valid to not block generation
    assert result.score == 0.5
    assert any("skipped" in w.lower() for w in result.warnings)
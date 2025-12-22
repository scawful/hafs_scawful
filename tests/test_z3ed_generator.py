"""Tests for Z3edToolGenerator."""

import pytest

from unittest.mock import MagicMock, patch, AsyncMock

from pathlib import Path

import textwrap



from hafs_scawful.generators.z3ed_generator import Z3edToolGenerator



@pytest.mark.asyncio

async def test_z3ed_generator_parsing():

    """Verify generator parses documentation and filters stable commands."""

    

    # Mock documentation content

    mock_docs = textwrap.dedent("""

    # Z3ED Command Reference

    

    ### `z3ed rom read`

    Read rom data.

    

    ### `z3ed rom unstable_command`

    Do something unstable.

    

    ### `z3ed editor dungeon`

    Dungeon editing.

    

    #### `place-object`

    Place an object.

    

    #### `unstable-action`

    Do something risky.

    """)



    with patch("pathlib.Path.read_text", return_value=mock_docs):


        with patch("pathlib.Path.exists", return_value=True):
            generator = Z3edToolGenerator()
            generator.setup = AsyncMock()
            
            # Override doc path to something dummy (mocked anyway)
            generator._doc_path = Path("/dummy/z3ed-docs.md")
            
            items = await generator.extract_source_items()
            
            # Should find:
            # 1. z3ed rom read (Stable)
            # 2. z3ed editor dungeon place-object (Stable subcommand)
            # 3. Manual manual items (asar, analyze_room) - 2 items
            
            # Should NOT find:
            # - z3ed rom unstable_command
            # - z3ed editor dungeon unstable-action
            # - z3ed editor dungeon (top level container, usually skipped if no direct action in allowlist)
            
            cmd_names = [i.command for i in items]
            
            assert "z3ed rom read" in cmd_names
            assert "z3ed editor dungeon place-object" in cmd_names
            assert "z3ed rom unstable_command" not in cmd_names
            assert "z3ed editor dungeon unstable-action" not in cmd_names
            
            # Verify categories
            read_item = next(i for i in items if i.command == "z3ed rom read")
            assert read_item.category == "rom"
            
            place_item = next(i for i in items if i.command == "z3ed editor dungeon place-object")
            assert place_item.category == "editor"

@pytest.mark.asyncio
async def test_is_stable_logic():
    """Directly test the _is_stable filter logic."""
    gen = Z3edToolGenerator()
    
    # Stable
    assert gen._is_stable(["z3ed", "rom", "read"])
    assert gen._is_stable(["z3ed", "editor", "dungeon", "place-object"])
    assert gen._is_stable(["z3ed", "build", "anything"]) # Wildcard
    
    # Unstable / Unknown
    assert not gen._is_stable(["z3ed", "rom", "destroy"])
    assert not gen._is_stable(["z3ed", "magic", "wand"])
    assert not gen._is_stable(["z3ed", "editor", "dungeon", "explode"])

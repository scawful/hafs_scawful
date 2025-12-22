"""Zelda-specific training data generators for hafs_scawful plugin.

These generators are domain-specific to Zelda ROM hacking and should NOT
be in the main hafs repository. The main repo provides the base classes
and infrastructure; this plugin provides the actual domain knowledge.

Generators:
- AsmDataGenerator: SNES 65816 ASM from ALTTP knowledge base
- Zelda3DisasmGenerator: Vanilla ALTTP disassembly
- OracleDataGenerator: Oracle-of-Secrets ROM hack
- GigaleakDataGenerator: Nintendo gigaleak source code
- CuratedHackGenerator: Allowlisted ROM hacks
- CppDataGenerator: YAZE C++ editor code
"""

from pathlib import Path

# Plugin paths - these are machine-specific and belong here, not in main repo
PLUGIN_ROOT = Path(__file__).parent.parent
CONFIG_DIR = PLUGIN_ROOT / "config"

# Training resource paths (loaded from config)
def get_training_paths() -> dict:
    """Load training paths from plugin config."""
    import tomllib

    config_file = CONFIG_DIR / "training_paths.toml"
    if not config_file.exists():
        return {}

    with open(config_file, "rb") as f:
        return tomllib.load(f)

# Lazy imports to avoid circular dependencies
def get_asm_generator():
    from hafs_scawful.generators.asm_generator import AsmDataGenerator
    return AsmDataGenerator

def get_zelda3_generator():
    from hafs_scawful.generators.zelda3_generator import Zelda3DisasmGenerator
    return Zelda3DisasmGenerator

def get_oracle_generator():
    from hafs_scawful.generators.oracle_generator import OracleDataGenerator
    return OracleDataGenerator

def get_gigaleak_generator():
    from hafs_scawful.generators.gigaleak_generator import GigaleakDataGenerator
    return GigaleakDataGenerator

def get_curated_hack_generator():
    from hafs_scawful.generators.curated_hack_generator import CuratedHackGenerator
    return CuratedHackGenerator

def get_cpp_generator():
    from hafs_scawful.generators.cpp_generator import CppDataGenerator
    return CppDataGenerator

def get_hafs_generator():
    from hafs_scawful.generators.hafs_generator import HafsSystemGenerator
    return HafsSystemGenerator

def get_z3ed_tool_generator():
    from hafs_scawful.generators.z3ed_generator import Z3edToolGenerator
    return Z3edToolGenerator


# Registration function for plugin discovery
def register_generators(curator):
    """Register all zelda-specific generators with a DataCurator instance.

    This is called by the main hafs training system when it discovers
    this plugin.
    """
    import asyncio
    import logging

    logger = logging.getLogger(__name__)
    paths = get_training_paths()

    async def _register():
        # ASM generator
        try:
            AsmGen = get_asm_generator()
            asm_gen = AsmGen()
            await asm_gen.setup()
            curator.register_generator("asm", asm_gen)
            logger.info("Registered: asm (ALTTP knowledge base)")
        except Exception as e:
            logger.warning(f"Failed to register asm generator: {e}")

        # Oracle generator
        try:
            OracleGen = get_oracle_generator()
            oracle_gen = OracleGen()
            await oracle_gen.setup()
            curator.register_generator("oracle", oracle_gen)
            logger.info("Registered: oracle (Oracle-of-Secrets)")
        except Exception as e:
            logger.warning(f"Failed to register oracle generator: {e}")

        # Zelda3 disasm generator
        zelda3_path = paths.get("zelda3_disasm")
        if zelda3_path and Path(zelda3_path).exists():
            try:
                Zelda3Gen = get_zelda3_generator()
                zelda3_gen = Zelda3Gen()
                zelda3_gen.ZELDA3_PATH = Path(zelda3_path)  # Override path
                await zelda3_gen.setup()
                curator.register_generator("zelda3", zelda3_gen)
                logger.info(f"Registered: zelda3 ({zelda3_path})")
            except Exception as e:
                logger.warning(f"Failed to register zelda3 generator: {e}")

        # Gigaleak generator
        gigaleak_path = paths.get("gigaleak")
        if gigaleak_path and Path(gigaleak_path).exists():
            try:
                GigaleakGen = get_gigaleak_generator()
                gigaleak_gen = GigaleakGen()
                await gigaleak_gen.setup()
                curator.register_generator("gigaleak", gigaleak_gen)
                logger.info(f"Registered: gigaleak ({gigaleak_path})")
            except Exception as e:
                logger.warning(f"Failed to register gigaleak generator: {e}")

        # Curated hack generator
        try:
            CuratedGen = get_curated_hack_generator()
            curated_gen = CuratedGen()
            await curated_gen.setup()
            if curated_gen.has_hacks:
                curator.register_generator("hack_curated", curated_gen)
                logger.info("Registered: hack_curated (allowlisted hacks)")
        except Exception as e:
            logger.warning(f"Failed to register curated hack generator: {e}")

        # YAZE/C++ generator
        yaze_path = paths.get("yaze")
        if yaze_path and Path(yaze_path).exists():
            try:
                CppGen = get_cpp_generator()
                cpp_gen = CppGen()
                cpp_gen.yaze_path = Path(yaze_path)  # Override path
                await cpp_gen.setup()
                curator.register_generator("yaze", cpp_gen)
                logger.info(f"Registered: yaze ({yaze_path})")
            except Exception as e:
                logger.warning(f"Failed to register yaze generator: {e}")

        # HAFS System generator (Tool Use)
        try:
            HafsGen = get_hafs_generator()
            hafs_gen = HafsGen()
            await hafs_gen.setup()
            curator.register_generator("hafs_tooling", hafs_gen)
            logger.info("Registered: hafs_tooling (CLI, Scripts, Aliases)")
        except Exception as e:
            logger.warning(f"Failed to register hafs generator: {e}")

        # Z3ed Tooling generator (Stable CLI)
        try:
            Z3edToolGen = get_z3ed_tool_generator()
            z3ed_tool_gen = Z3edToolGen()
            await z3ed_tool_gen.setup()
            curator.register_generator("z3ed_tooling", z3ed_tool_gen)
            logger.info("Registered: z3ed_tooling (Stable CLI commands)")
        except Exception as e:
            logger.warning(f"Failed to register z3ed_tooling generator: {e}")

    asyncio.run(_register())


__all__ = [
    "get_training_paths",
    "register_generators",
    "get_asm_generator",
    "get_zelda3_generator",
    "get_oracle_generator",
    "get_gigaleak_generator",
    "get_curated_hack_generator",
    "get_cpp_generator",
    "get_hafs_generator",
    "get_z3ed_tool_generator",
]

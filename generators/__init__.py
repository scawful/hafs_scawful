"""Zelda-specific training data generators for hafs_scawful plugin.

These generators are domain-specific to Zelda ROM hacking and should NOT
be in the main hafs repository. The main repo provides the base classes
and infrastructure; this plugin provides the actual domain knowledge.

Generators:
- AsmDataGenerator: SNES 65816 ASM from ALTTP knowledge base (general)
- AsmDebugGenerator: Crash analysis and debugging samples
- AsmOptimizeGenerator: Cycle optimization samples
- AsmHookGenerator: Hook/patch creation samples
- AsmDocGenerator: Documentation/explanation samples
- AsmSynthesizer: Compare and merge all ASM generators
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

def get_z3ed_tool_generator():
    from hafs_scawful.generators.z3ed_generator import Z3edToolGenerator
    return Z3edToolGenerator

def get_asar_validator():
    from hafs_scawful.validators.asar_validator import AsarValidator
    return AsarValidator

# Specialized ASM generators (euclid-asm task types)
def get_asm_debug_generator():
    from hafs_scawful.generators.asm_debug_generator import AsmDebugGenerator
    return AsmDebugGenerator

def get_asm_optimize_generator():
    from hafs_scawful.generators.asm_optimize_generator import AsmOptimizeGenerator
    return AsmOptimizeGenerator

def get_asm_hook_generator():
    from hafs_scawful.generators.asm_hook_generator import AsmHookGenerator
    return AsmHookGenerator

def get_asm_doc_generator():
    from hafs_scawful.generators.asm_doc_generator import AsmDocGenerator
    return AsmDocGenerator

def get_asm_synthesizer():
    from hafs_scawful.generators.asm_synthesizer import AsmSynthesizer
    return AsmSynthesizer


# Registration function for plugin discovery
def register_generators(curator):
    """Register all zelda-specific generators with a DataCurator instance.

    This is called by the main hafs training system when it discovers
    this plugin. Handles both sync and async contexts.
    """
    import asyncio
    import logging

    logger = logging.getLogger(__name__)
    # Safe config loading
    config_data = get_training_paths()
    # Handle flat or nested [paths] structure
    paths = config_data.get("paths", config_data)

    async def _register():
        # Inject AsarValidator if pipeline exists
        if hasattr(curator, "_quality_pipeline") and curator._quality_pipeline:
            try:
                AsarVal = get_asar_validator()
                # Use paths from config if available
                asar_path = Path(paths.get("asar", "")).expanduser() if paths.get("asar") else None
                rom_path = Path(paths.get("dummy_rom", "")).expanduser() if paths.get("dummy_rom") else None
                
                validator = AsarVal(asar_path=asar_path, rom_path=rom_path)
                
                # Register/Override asm validator
                if hasattr(curator._quality_pipeline, "_validators"):
                    curator._quality_pipeline._validators["asm"] = validator
                    logger.info("Registered: AsarValidator (replacing default ASM validator)")
            except Exception as e:
                logger.warning(f"Failed to register AsarValidator: {e}")

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
        if zelda3_path:
            zelda3_path = Path(zelda3_path).expanduser()
        if zelda3_path and zelda3_path.exists():
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
        if gigaleak_path:
            gigaleak_path = Path(gigaleak_path).expanduser()
        if gigaleak_path and gigaleak_path.exists():
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
        if yaze_path:
            yaze_path = Path(yaze_path).expanduser()
        if yaze_path and yaze_path.exists():
            try:
                CppGen = get_cpp_generator()
                cpp_gen = CppGen()
                cpp_gen.yaze_path = Path(yaze_path)  # Override path
                await cpp_gen.setup()
                curator.register_generator("yaze", cpp_gen)
                logger.info(f"Registered: yaze ({yaze_path})")
            except Exception as e:
                logger.warning(f"Failed to register yaze generator: {e}")

        # Z3ed Tooling generator (Stable CLI)
        try:
            Z3edToolGen = get_z3ed_tool_generator()
            z3ed_tool_gen = Z3edToolGen()
            await z3ed_tool_gen.setup()
            curator.register_generator("z3ed_tooling", z3ed_tool_gen)
            logger.info("Registered: z3ed_tooling (Stable CLI commands)")
        except Exception as e:
            logger.warning(f"Failed to register z3ed_tooling generator: {e}")

        # Specialized ASM generators (euclid-asm task types)
        # These use the same source items but generate different sample types
        try:
            AsmDebugGen = get_asm_debug_generator()
            debug_gen = AsmDebugGen()
            await debug_gen.setup()
            curator.register_generator("asm_debug", debug_gen)
            logger.info("Registered: asm_debug (crash analysis samples)")
        except Exception as e:
            logger.warning(f"Failed to register asm_debug generator: {e}")

        try:
            AsmOptGen = get_asm_optimize_generator()
            opt_gen = AsmOptGen()
            await opt_gen.setup()
            curator.register_generator("asm_optimize", opt_gen)
            logger.info("Registered: asm_optimize (cycle optimization samples)")
        except Exception as e:
            logger.warning(f"Failed to register asm_optimize generator: {e}")

        try:
            AsmHookGen = get_asm_hook_generator()
            hook_gen = AsmHookGen()
            await hook_gen.setup()
            curator.register_generator("asm_hook", hook_gen)
            logger.info("Registered: asm_hook (hook/patch samples)")
        except Exception as e:
            logger.warning(f"Failed to register asm_hook generator: {e}")

        try:
            AsmDocGen = get_asm_doc_generator()
            doc_gen = AsmDocGen()
            await doc_gen.setup()
            curator.register_generator("asm_doc", doc_gen)
            logger.info("Registered: asm_doc (documentation samples)")
        except Exception as e:
            logger.warning(f"Failed to register asm_doc generator: {e}")

    # Handle both sync and async contexts
    try:
        loop = asyncio.get_running_loop()
        # We're in an async context - schedule the coroutine
        import nest_asyncio
        nest_asyncio.apply()
        loop.run_until_complete(_register())
    except RuntimeError:
        # No running event loop - we're in sync context
        asyncio.run(_register())


__all__ = [
    "get_training_paths",
    "register_generators",
    # Core generators
    "get_asm_generator",
    "get_zelda3_generator",
    "get_oracle_generator",
    "get_gigaleak_generator",
    "get_curated_hack_generator",
    "get_cpp_generator",
    "get_z3ed_tool_generator",
    # Specialized ASM generators (euclid-asm tasks)
    "get_asm_debug_generator",
    "get_asm_optimize_generator",
    "get_asm_hook_generator",
    "get_asm_doc_generator",
    "get_asm_synthesizer",
    # Validators
    "get_asar_validator",
]

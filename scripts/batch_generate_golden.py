import asyncio
import logging
from pathlib import Path
from hafs_scawful.generators.asm_generator import AsmDataGenerator

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

async def main():
    print("🚀 Starting Golden Zelda Batch Generation...")
    
    # Initialize Generator
    generator = AsmDataGenerator(use_enhanced_prompts=True)
    await generator.setup()
    
    # Define output path
    output_path = Path("/Users/scawful/Code/hafs_tooling_dataset.jsonl")
    
    # Run Generation
    # We'll do 50 samples for this run
    result = await generator.run_generation(
        limit=50,
        resume=False, # Fresh start to ensure we use the new library
        output_path=output_path
    )
    
    print("-" * 40)
    print(f"✅ Batch Complete!")
    print(f"Total Processed: {result.processed}")
    print(f"Errors: {result.errors}")
    print(f"Duration: {result.duration_seconds:.1f}s")
    print(f"Dataset: {output_path}")

if __name__ == "__main__":
    asyncio.run(main())

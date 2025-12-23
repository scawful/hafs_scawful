import asyncio
import logging
import json
from pathlib import Path
from hafs_scawful.generators.farore_generator import FaroreDataGenerator

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

async def main():
    print("🚀 Starting Farore Tool-Use Dataset Generation...")
    
    # Initialize Generator
    generator = FaroreDataGenerator()
    await generator.setup()
    
    # Extract all tools from schema
    items = await generator.extract_source_items()
    print(f"Extracted {len(items)} tools from schema.")
    
    # Define output path
    output_path = Path("/Users/scawful/Code/farore_tooling_dataset.jsonl")
    
    all_samples = []
    for item in items:
        print(f"Generating samples for: {item.name}...")
        samples = await generator.generate_sample(item)
        if samples:
            all_samples.extend(samples)
            print(f"  + {len(samples)} samples added.")
    
    # Save output
    with open(output_path, "w") as f:
        for s in all_samples:
            f.write(s.to_jsonl_entry() + "\n")
    
    print("-" * 40)
    print(f"✅ Batch Complete!")
    print(f"Total Samples: {len(all_samples)}")
    print(f"Dataset: {output_path}")

if __name__ == "__main__":
    asyncio.run(main())


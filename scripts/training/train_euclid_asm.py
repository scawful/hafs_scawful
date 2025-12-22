#!/usr/bin/env python3
"""Train euclid-asm model using Unsloth for efficient LoRA fine-tuning.

This script trains a 65816 assembly specialist model on ALTTP/Zelda ROM hacking data.

Requirements (install on medical-mechanica):
    pip install unsloth
    pip install transformers datasets accelerate peft trl

Usage:
    python train_euclid_asm.py --dataset ./euclid_asm_dataset --output ./euclid-asm-v1

Hardware requirements:
    - RTX 5060 Ti 16GB or better
    - ~6GB VRAM for 1.5B model with LoRA
"""

import argparse
import json
import os
from datetime import datetime
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Train euclid-asm model")
    parser.add_argument("--dataset", type=str, required=True, help="Path to dataset directory")
    parser.add_argument("--output", type=str, default="./euclid-asm-v1", help="Output directory")
    parser.add_argument("--base-model", type=str, default="Qwen/Qwen2.5-Coder-1.5B-Instruct",
                       help="Base model to fine-tune")
    parser.add_argument("--epochs", type=int, default=3, help="Number of training epochs")
    parser.add_argument("--batch-size", type=int, default=4, help="Per-device batch size")
    parser.add_argument("--grad-accum", type=int, default=4, help="Gradient accumulation steps")
    parser.add_argument("--lora-rank", type=int, default=16, help="LoRA rank")
    parser.add_argument("--lora-alpha", type=int, default=32, help="LoRA alpha")
    parser.add_argument("--lr", type=float, default=2e-4, help="Learning rate")
    parser.add_argument("--max-seq-length", type=int, default=2048, help="Maximum sequence length")
    parser.add_argument("--use-4bit", action="store_true", help="Use 4-bit quantization")
    parser.add_argument("--resume", type=str, default=None, help="Resume from checkpoint")
    args = parser.parse_args()

    print("=" * 60)
    print("EUCLID-ASM TRAINING")
    print("=" * 60)
    print(f"Base model: {args.base_model}")
    print(f"Dataset: {args.dataset}")
    print(f"Output: {args.output}")
    print(f"Epochs: {args.epochs}")
    print(f"Batch size: {args.batch_size} (effective: {args.batch_size * args.grad_accum})")
    print(f"LoRA rank: {args.lora_rank}, alpha: {args.lora_alpha}")
    print(f"Learning rate: {args.lr}")
    print(f"4-bit quantization: {args.use_4bit}")
    print()

    # Import dependencies
    try:
        from unsloth import FastLanguageModel
        from unsloth import is_bfloat16_supported
        print("✓ Unsloth loaded")
    except ImportError:
        print("ERROR: Unsloth not installed. Run: pip install unsloth")
        print("See: https://github.com/unslothai/unsloth")
        return 1

    from datasets import load_dataset, Dataset
    from trl import SFTTrainer
    from transformers import TrainingArguments
    import torch

    # Check GPU
    if torch.cuda.is_available():
        gpu_name = torch.cuda.get_device_name(0)
        gpu_mem = torch.cuda.get_device_properties(0).total_memory / 1e9
        print(f"✓ GPU: {gpu_name} ({gpu_mem:.1f} GB)")
    else:
        print("WARNING: No GPU detected, training will be slow")

    # Load base model with LoRA
    print("\nLoading base model with LoRA adapters...")
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=args.base_model,
        max_seq_length=args.max_seq_length,
        dtype=None,  # Auto-detect
        load_in_4bit=args.use_4bit,
    )

    # Add LoRA adapters
    model = FastLanguageModel.get_peft_model(
        model,
        r=args.lora_rank,
        lora_alpha=args.lora_alpha,
        lora_dropout=0.05,
        target_modules=[
            "q_proj", "k_proj", "v_proj", "o_proj",
            "gate_proj", "up_proj", "down_proj",
        ],
        bias="none",
        use_gradient_checkpointing="unsloth",
        random_state=42,
    )

    print(f"✓ Model loaded with LoRA (rank={args.lora_rank})")

    # Load dataset
    print(f"\nLoading dataset from {args.dataset}...")
    dataset_path = Path(args.dataset)

    train_file = dataset_path / "train.jsonl"
    val_file = dataset_path / "val.jsonl"

    if not train_file.exists():
        print(f"ERROR: {train_file} not found")
        return 1

    train_data = load_dataset("json", data_files=str(train_file), split="train")
    print(f"✓ Training samples: {len(train_data)}")

    val_data = None
    if val_file.exists():
        val_data = load_dataset("json", data_files=str(val_file), split="train")
        print(f"✓ Validation samples: {len(val_data)}")

    # Format prompt template (Alpaca style)
    alpaca_template = """Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

### Instruction:
{instruction}

### Input:
{input}

### Response:
{output}"""

    alpaca_template_no_input = """Below is an instruction that describes a task. Write a response that appropriately completes the request.

### Instruction:
{instruction}

### Response:
{output}"""

    def format_prompts(examples):
        """Format examples using Alpaca template."""
        texts = []
        for instruction, input_text, output in zip(
            examples["instruction"],
            examples["input"],
            examples["output"]
        ):
            if input_text and input_text.strip():
                text = alpaca_template.format(
                    instruction=instruction,
                    input=input_text,
                    output=output,
                )
            else:
                text = alpaca_template_no_input.format(
                    instruction=instruction,
                    output=output,
                )
            texts.append(text + tokenizer.eos_token)
        return {"text": texts}

    # Apply formatting
    train_data = train_data.map(format_prompts, batched=True)
    if val_data:
        val_data = val_data.map(format_prompts, batched=True)

    # Training arguments
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    training_args = TrainingArguments(
        output_dir=str(output_dir),
        per_device_train_batch_size=args.batch_size,
        gradient_accumulation_steps=args.grad_accum,
        warmup_steps=50,
        num_train_epochs=args.epochs,
        learning_rate=args.lr,
        fp16=not is_bfloat16_supported(),
        bf16=is_bfloat16_supported(),
        logging_steps=10,
        save_steps=100,
        save_total_limit=3,
        optim="adamw_8bit",
        weight_decay=0.01,
        lr_scheduler_type="cosine",
        seed=42,
        report_to="none",  # Disable wandb
        evaluation_strategy="steps" if val_data else "no",
        eval_steps=100 if val_data else None,
    )

    # Initialize trainer
    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=train_data,
        eval_dataset=val_data,
        dataset_text_field="text",
        max_seq_length=args.max_seq_length,
        args=training_args,
    )

    # Train
    print("\n" + "=" * 60)
    print("STARTING TRAINING")
    print("=" * 60)

    start_time = datetime.now()

    if args.resume:
        print(f"Resuming from checkpoint: {args.resume}")
        trainer.train(resume_from_checkpoint=args.resume)
    else:
        trainer.train()

    duration = datetime.now() - start_time
    print(f"\nTraining completed in {duration}")

    # Save final model
    print(f"\nSaving model to {output_dir}...")

    # Save LoRA adapters
    model.save_pretrained(output_dir / "lora_adapters")
    tokenizer.save_pretrained(output_dir / "lora_adapters")
    print(f"✓ LoRA adapters saved to {output_dir / 'lora_adapters'}")

    # Save merged model (optional, larger but easier to use)
    print("Merging LoRA adapters into base model...")
    model.save_pretrained_merged(
        output_dir / "merged_model",
        tokenizer,
        save_method="merged_16bit",
    )
    print(f"✓ Merged model saved to {output_dir / 'merged_model'}")

    # Save training metadata
    metadata = {
        "model_name": "euclid-asm",
        "version": "v1",
        "base_model": args.base_model,
        "trained_on": datetime.now().isoformat(),
        "training_duration": str(duration),
        "hyperparameters": {
            "epochs": args.epochs,
            "batch_size": args.batch_size,
            "gradient_accumulation": args.grad_accum,
            "learning_rate": args.lr,
            "lora_rank": args.lora_rank,
            "lora_alpha": args.lora_alpha,
            "max_seq_length": args.max_seq_length,
            "use_4bit": args.use_4bit,
        },
        "dataset": {
            "path": str(args.dataset),
            "train_samples": len(train_data),
            "val_samples": len(val_data) if val_data else 0,
        },
    }

    with open(output_dir / "training_metadata.json", 'w') as f:
        json.dump(metadata, f, indent=2)
    print(f"✓ Metadata saved to {output_dir / 'training_metadata.json'}")

    print("\n" + "=" * 60)
    print("TRAINING COMPLETE")
    print("=" * 60)
    print(f"Model saved to: {output_dir}")
    print()
    print("To use the model:")
    print(f"  from unsloth import FastLanguageModel")
    print(f"  model, tokenizer = FastLanguageModel.from_pretrained('{output_dir / 'merged_model'}')")
    print()
    print("Or with Ollama (create Modelfile):")
    print(f"  ollama create euclid-asm -f {output_dir / 'Modelfile'}")

    # Create Ollama Modelfile template
    modelfile = f"""# Modelfile for euclid-asm
# Run: ollama create euclid-asm -f Modelfile

FROM {output_dir / 'merged_model'}

TEMPLATE \"\"\"Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

### Instruction:
{{{{ .Prompt }}}}

### Response:
\"\"\"

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER stop "### Instruction:"
PARAMETER stop "### Input:"

SYSTEM \"\"\"You are euclid-asm, an expert in SNES 65816 assembly programming specializing in Zelda: A Link to the Past ROM hacking. You provide accurate, well-commented assembly code and debugging assistance.\"\"\"
"""

    with open(output_dir / "Modelfile", 'w') as f:
        f.write(modelfile)
    print(f"✓ Ollama Modelfile saved")

    return 0


if __name__ == "__main__":
    exit(main())

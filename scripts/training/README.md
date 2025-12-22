# euclid-asm Training Scripts

Scripts for training the euclid-asm model - a 65816 assembly specialist for ALTTP ROM hacking.

## Overview

```
euclid-asm
├── Base model: Qwen2.5-Coder-1.5B-Instruct
├── Training: LoRA fine-tuning with Unsloth
├── Dataset: ~5,000 ASM samples (base + debug + optimize + hook + doc)
└── Hardware: RTX 5060 Ti 16GB (~2 hours training)
```

## Quick Start

### 1. Generate Training Data (on Mac)

First, ensure the ASM synthesis has completed:

```bash
# Check synthesis progress
tail -f /tmp/asm_synthesis.log

# When done, prepare dataset
cd ~/Code/hafs_scawful
python scripts/training/prepare_euclid_dataset.py \
    --output ~/training_data/euclid_asm_v1
```

### 2. Transfer to Windows (medical-mechanica)

```bash
# Copy dataset
scp -r ~/training_data/euclid_asm_v1 scawful@100.104.53.21:D:/training/

# Copy training scripts
scp scripts/training/*.py scawful@100.104.53.21:D:/training/
```

### 3. Install Dependencies (on Windows)

```powershell
# SSH into medical-mechanica
ssh scawful@100.104.53.21

# Install Unsloth (CUDA required)
pip install unsloth
pip install transformers datasets accelerate peft trl
```

### 4. Train Model

```powershell
cd D:\training

python train_euclid_asm.py \
    --dataset ./euclid_asm_v1 \
    --output ./euclid-asm-v1 \
    --epochs 3 \
    --batch-size 4 \
    --lora-rank 16
```

### 5. Test Model

```powershell
python test_euclid_asm.py --model ./euclid-asm-v1/merged_model
```

### 6. Deploy to Ollama

```powershell
# Create Ollama model
ollama create euclid-asm -f ./euclid-asm-v1/Modelfile

# Test
ollama run euclid-asm "Write a routine to check if Link has the hookshot"
```

## Training Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--base-model` | Qwen2.5-Coder-1.5B-Instruct | Base model |
| `--epochs` | 3 | Training epochs |
| `--batch-size` | 4 | Per-device batch size |
| `--grad-accum` | 4 | Gradient accumulation (effective batch = 16) |
| `--lora-rank` | 16 | LoRA adapter rank |
| `--lora-alpha` | 32 | LoRA alpha |
| `--lr` | 2e-4 | Learning rate |
| `--max-seq-length` | 2048 | Max sequence length |
| `--use-4bit` | False | Enable 4-bit quantization |

## Dataset Structure

```
euclid_asm_v1/
├── train.jsonl     # 80% of samples
├── val.jsonl       # 10% of samples
├── test.jsonl      # 10% of samples
└── metadata.json   # Dataset info
```

Each sample is in Alpaca format:
```json
{
    "instruction": "Write a routine to...",
    "input": "Context about RAM addresses...",
    "output": "```asm\nRoutineName:\n    LDA.w $0E00\n    ...\n```"
}
```

## Sample Types

The dataset includes 5 task types:

| Type | Domain | Purpose |
|------|--------|---------|
| base | asm_base | General code generation |
| debug | asm_debug | Crash analysis, debugging |
| optimize | asm_optimize | Cycle counting, optimization |
| hook | asm_hook | JSL hooks, freespace patches |
| doc | asm_doc | Code explanation, documentation |

## VRAM Requirements

| Model Size | VRAM (Training) | VRAM (Inference) |
|------------|-----------------|------------------|
| 1.5B | ~6GB | ~3GB |
| 1.5B + 4-bit | ~4GB | ~2GB |
| 7B | ~14GB | ~7GB |

## Output Files

After training:

```
euclid-asm-v1/
├── lora_adapters/          # LoRA weights only (~100MB)
├── merged_model/           # Full merged model (~3GB)
├── Modelfile               # Ollama model definition
├── training_metadata.json  # Training config
└── checkpoint-*/           # Training checkpoints
```

## Troubleshooting

### CUDA out of memory
- Reduce `--batch-size` to 2
- Enable `--use-4bit`
- Reduce `--max-seq-length` to 1024

### Slow training
- Ensure CUDA is being used: `nvidia-smi`
- Check Unsloth is using Flash Attention

### Poor quality outputs
- Increase `--epochs` to 5
- Increase `--lora-rank` to 32
- Check dataset quality with `test_euclid_asm.py`

## Next Steps

After euclid-asm is trained:

1. **seph-tilesmith**: Graphics/tile specialist
2. **kaepora-teacher**: Documentation specialist
3. **triforce-sage**: Unified 32B model (future)

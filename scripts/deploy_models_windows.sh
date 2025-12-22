#!/bin/bash
# Deploy and setup models on medical-mechanica (Windows GPU server)

set -e

WINDOWS_HOST="medical-mechanica"
SCRIPTS_DIR="D:/hafs_training/scripts"
MODELS_DIR="D:/hafs_training/models"

echo "=========================================="
echo "Model Setup Deployment to medical-mechanica"
echo "=========================================="
echo ""

# Step 1: Copy setup scripts to Windows
echo "[1/5] Copying setup scripts to Windows..."
scp scripts/setup_windows_models.ps1 ${WINDOWS_HOST}:${SCRIPTS_DIR}/
scp scripts/setup_finetuning_models.py ${WINDOWS_HOST}:${SCRIPTS_DIR}/
scp config/models.toml ${WINDOWS_HOST}:D:/hafs_training/config/
echo "✓ Scripts copied"
echo ""

# Step 2: Install Ollama models (for data generation)
echo "[2/5] Installing Ollama models..."
echo "This will install:"
echo "  - qwen2.5-coder:14b (9GB) - Best for code"
echo "  - qwen2.5-coder:7b (5GB) - Fast alternative"
echo "  - deepseek-coder:6.7b (4GB) - ASM specialist"
echo "  - phi3.5 (2GB) - Efficient model"
echo ""
read -p "Install Ollama models? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ssh ${WINDOWS_HOST} << 'EOF'
        # Install essential models (lower VRAM usage)
        ollama pull qwen2.5-coder:14b
        ollama pull qwen2.5-coder:7b
        ollama pull deepseek-coder:6.7b
        ollama pull phi3.5:latest

        # List all models
        ollama list
EOF
    echo "✓ Ollama models installed"
else
    echo "⊘ Skipped Ollama installation"
fi
echo ""

# Step 3: Setup Python environment for fine-tuning
echo "[3/5] Setting up Python environment..."
read -p "Setup Unsloth for fine-tuning? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ssh ${WINDOWS_HOST} << 'EOF'
        cd D:/hafs_training

        # Verify CUDA
        python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}, GPU: {torch.cuda.get_device_name(0)}')"

        # Install Unsloth
        pip install "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
        pip install --no-deps "trl<0.9.0" peft accelerate bitsandbytes
        pip install datasets transformers wandb

        # Install huggingface-cli for model downloads
        pip install -U "huggingface_hub[cli,hf_transfer]"

        echo "✓ Fine-tuning environment ready"
EOF
    echo "✓ Python environment configured"
else
    echo "⊘ Skipped Python setup"
fi
echo ""

# Step 4: Download fine-tuning base models
echo "[4/5] Downloading fine-tuning base models..."
echo "Recommended models:"
echo "  - Qwen2.5-Coder-14B (28GB) - BEST for your use case"
echo "  - Qwen2.5-Coder-7B (14GB) - Faster alternative"
echo ""
read -p "Download fine-tuning models? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Run the Python setup script on Windows
    ssh ${WINDOWS_HOST} "python ${SCRIPTS_DIR}/setup_finetuning_models.py --models recommended --setup-unsloth"
    echo "✓ Fine-tuning models downloaded"
else
    echo "⊘ Skipped model downloads"
fi
echo ""

# Step 5: Verify setup
echo "[5/5] Verifying setup..."
ssh ${WINDOWS_HOST} << 'EOF'
    echo "=== Ollama Models ==="
    ollama list

    echo ""
    echo "=== Disk Usage (D:) ==="
    Get-PSDrive D | Select-Object Used,Free | Format-Table -AutoSize

    echo ""
    echo "=== Fine-tuning Models ==="
    ls D:/hafs_training/models/ -ErrorAction SilentlyContinue

    echo ""
    echo "=== CUDA Status ==="
    python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}, Device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"
EOF
echo ""

echo "=========================================="
echo "✓ Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Test Ollama: curl http://100.104.53.21:11435/api/tags"
echo "  2. Run hybrid campaign: ./scripts/launch_hybrid_training.sh 100"
echo "  3. Start fine-tuning: hafs training fine-tune --model qwen2.5-coder-14b"
echo ""

#!/bin/bash
# Deploy and run training campaign on medical-mechanica (GPU server)
#
# This script:
# 1. Syncs code to medical-mechanica
# 2. Sets up D drive directories
# 3. Launches training campaign using D drive for storage
# 4. Monitors progress remotely
#
# Usage:
#   ./scripts/deploy_training_medical_mechanica.sh generate  # Generate datasets
#   ./scripts/deploy_training_medical_mechanica.sh train     # Train models
#   ./scripts/deploy_training_medical_mechanica.sh status    # Check status

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_plugin_env.sh"

HAFS_ROOT="${HAFS_ROOT:-$HOME/Code/hafs}"
LOCAL_CONTEXT="${HAFS_CONTEXT:-$HOME/.context}"

REMOTE_HOST="${HAFS_WINDOWS_HOST:-medical-mechanica}"
REMOTE_USER="${HAFS_WINDOWS_USER:-Administrator}"
REMOTE_DIR="${HAFS_WINDOWS_CODE_DIR:-C:/hafs}"
D_DRIVE_DIR="${HAFS_WINDOWS_TRAINING:-D:/hafs_training}"
WINDOWS_CONTEXT="${HAFS_WINDOWS_CONTEXT:-D:/.context}"
WINDOWS_PLUGIN_DIR="${HAFS_WINDOWS_PLUGIN_DIR:-C:/hafs_scawful}"
TRAINING_CONFIG_PATH="${WINDOWS_PLUGIN_DIR}/config/training.toml"
SYNC_METHOD="${HAFS_CODE_SYNC_METHOD:-git}"
REPO_URL="${HAFS_REPO_URL:-$(git -C "$HAFS_ROOT" config --get remote.origin.url 2>/dev/null)}"

echo "========================================================================"
echo "GPU TRAINING DEPLOYMENT"
echo "========================================================================"
echo "Remote: $REMOTE_USER@$REMOTE_HOST"
echo "Code: $REMOTE_DIR"
echo "Data: $D_DRIVE_DIR"
echo ""

# Parse command
COMMAND=${1:-status}

case "$COMMAND" in
  setup)
    echo "[1/3] Setting up directories on D drive..."
    ssh "$REMOTE_USER@$REMOTE_HOST" << 'EOF'
      # Create D drive directories
      mkdir -p "D:/hafs_training/datasets"
      mkdir -p "D:/hafs_training/checkpoints"
      mkdir -p "D:/hafs_training/logs"
      mkdir -p "D:/hafs_training/models"
      mkdir -p "D:/hafs_training/temp"

      echo "✓ D drive directories created"

      # Check disk space
      wmic logicaldisk get name,freespace,size | findstr "D:"
EOF

    echo ""
    echo "[2/3] Syncing code to ${REMOTE_HOST}..."
    if [ "$SYNC_METHOD" = "git" ]; then
      if ssh "$REMOTE_USER@$REMOTE_HOST" "test -d \"$REMOTE_DIR/.git\""; then
        ssh "$REMOTE_USER@$REMOTE_HOST" "cd \"$REMOTE_DIR\" && git pull --ff-only"
      else
        if [ -z "$REPO_URL" ]; then
          echo "✗ Missing repo URL. Set HAFS_REPO_URL in config.toml or export it."
          exit 1
        fi
        ssh "$REMOTE_USER@$REMOTE_HOST" "git clone \"$REPO_URL\" \"$REMOTE_DIR\""
      fi
    else
      rsync -avz --exclude='.venv' --exclude='__pycache__' --exclude='.git' \
        "$HAFS_ROOT/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
    fi

    echo ""
    echo "[3/3] Installing dependencies..."
    ssh "$REMOTE_USER@$REMOTE_HOST" << 'EOF'
      cd C:/hafs

      # Check if Python is available
      if ! command -v python &> /dev/null; then
        echo "⚠️  Python not found. Please install Python 3.11+"
        exit 1
      fi

      # Create/activate venv
      if [ ! -d ".venv" ]; then
        python -m venv .venv
      fi

      # Install dependencies (Windows)
      .venv/Scripts/python.exe -m pip install --upgrade pip

      if [ -f "requirements.txt" ]; then
        .venv/Scripts/pip.exe install -r requirements.txt
      elif [ -f "pyproject.toml" ]; then
        .venv/Scripts/pip.exe install -e .
      else
        echo "⚠️  No requirements.txt or pyproject.toml found"
        exit 1
      fi

      echo "✓ Dependencies installed"
EOF

    echo ""
    echo "✅ Setup complete!"
    ;;

  generate)
    TARGET=${2:-34500}

    echo "Launching dataset generation campaign..."
    echo "Target: $TARGET samples"
    echo "Output: $D_DRIVE_DIR/datasets"
    echo ""

    # Launch campaign on GPU host
    ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
      cd C:/hafs

      # Set environment variables
      set PYTHONPATH=src
      set TRAINING_OUTPUT_DIR=${D_DRIVE_DIR}/datasets
      set TRAINING_CHECKPOINT_DIR=${D_DRIVE_DIR}/checkpoints
      set TRAINING_LOG_DIR=${D_DRIVE_DIR}/logs

      # Launch campaign in background (Windows)
      start /B .venv/Scripts/python.exe -m agents.training.scripts.generate_campaign \
        --target $TARGET \
        --export \
        --resume \
        > ${D_DRIVE_DIR}/logs/campaign_${TARGET}_\$(date +%Y%m%d_%H%M%S).log 2>&1

      echo "✓ Campaign launched on ${REMOTE_HOST}"
      echo "Monitor with: ssh $REMOTE_USER@$REMOTE_HOST 'tail -f ${D_DRIVE_DIR}/logs/campaign_*.log'"
EOF
    ;;

  train)
    DATASET=${2:-"D:/hafs_training/datasets/alttp_yaze_full_*_asm"}
    MODEL_NAME=${3:-"oracle-rauru-assembler"}

    echo "Launching model training..."
    echo "Dataset: $DATASET"
    echo "Model: $MODEL_NAME"
    echo "Output: $D_DRIVE_DIR/models/$MODEL_NAME"
    echo ""

    ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
      cd C:/hafs

      # Set environment variables
      set PYTHONPATH=src
      set CUDA_VISIBLE_DEVICES=0

      # Launch training
      .venv/Scripts/python.exe -m agents.training.scripts.train_model \
        --dataset "$DATASET" \
        --model-name "$MODEL_NAME" \
        --output-dir "${D_DRIVE_DIR}/models/$MODEL_NAME" \
        --config "${TRAINING_CONFIG_PATH}" \
        > ${D_DRIVE_DIR}/logs/training_${MODEL_NAME}_\$(date +%Y%m%d_%H%M%S).log 2>&1 &

      echo "✓ Training launched on ${REMOTE_HOST}"
EOF
    ;;

  status)
    echo "Checking ${REMOTE_HOST} status..."
    echo ""

    ssh "$REMOTE_USER@$REMOTE_HOST" << 'EOF'
      echo "=== D Drive Space ==="
      wmic logicaldisk where "DeviceID='D:'" get FreeSpace,Size

      echo ""
      echo "=== Datasets ==="
      ls -lh D:/hafs_training/datasets/ 2>/dev/null || echo "No datasets yet"

      echo ""
      echo "=== Models ==="
      ls -lh D:/hafs_training/models/ 2>/dev/null || echo "No models yet"

      echo ""
      echo "=== Running Processes ==="
      tasklist | findstr python || echo "No Python processes running"

      echo ""
      echo "=== Latest Log ==="
      if [ -f D:/hafs_training/logs/campaign_*.log ]; then
        tail -20 D:/hafs_training/logs/campaign_*.log | head -1
      fi
EOF
    ;;

  monitor)
    echo "Monitoring campaign on ${REMOTE_HOST}..."
    echo "Press Ctrl+C to stop monitoring"
    echo ""

    # Find latest log and tail it
    ssh "$REMOTE_USER@$REMOTE_HOST" << 'EOF'
      LATEST_LOG=$(ls -t D:/hafs_training/logs/campaign_*.log 2>/dev/null | head -1)

      if [ -z "$LATEST_LOG" ]; then
        echo "No campaign logs found"
        exit 1
      fi

      echo "Following: $LATEST_LOG"
      tail -f "$LATEST_LOG"
EOF
    ;;

  stop)
    echo "Stopping training processes on ${REMOTE_HOST}..."

    ssh "$REMOTE_USER@$REMOTE_HOST" << 'EOF'
      # Kill Python training processes
      taskkill /IM python.exe /F

      echo "✓ Training processes stopped"
EOF
    ;;

  sync-datasets)
    echo "Syncing datasets FROM ${REMOTE_HOST} to local..."
    echo ""

    # Create local directory
    mkdir -p "$LOCAL_CONTEXT/training/datasets_from_mechanica"

    # Rsync datasets
    rsync -avzP --progress \
      "$REMOTE_USER@$REMOTE_HOST:${D_DRIVE_DIR}/datasets/" \
      "$LOCAL_CONTEXT/training/datasets_from_mechanica/"

    echo ""
    echo "✓ Datasets synced to: $LOCAL_CONTEXT/training/datasets_from_mechanica/"
    ;;

  sync-models)
    echo "Syncing models FROM ${REMOTE_HOST} to local..."
    echo ""

    # Create local directory
    mkdir -p "$LOCAL_CONTEXT/training/models_from_mechanica"

    # Rsync models
    rsync -avzP --progress \
      "$REMOTE_USER@$REMOTE_HOST:${D_DRIVE_DIR}/models/" \
      "$LOCAL_CONTEXT/training/models_from_mechanica/"

    echo ""
    echo "✓ Models synced to: $LOCAL_CONTEXT/training/models_from_mechanica/"
    ;;

  *)
    echo "Usage: $0 {setup|generate|train|status|monitor|stop|sync-datasets|sync-models}"
    echo ""
    echo "Commands:"
    echo "  setup            - Initial setup of D drive directories and dependencies"
    echo "  generate [N]     - Generate N samples (default: 34500)"
    echo "  train [dataset]  - Train model on dataset"
    echo "  status           - Check current status"
    echo "  monitor          - Monitor campaign logs (live)"
    echo "  stop             - Stop all training processes"
    echo "  sync-datasets    - Download datasets to local machine"
    echo "  sync-models      - Download trained models to local machine"
    echo ""
    echo "Examples:"
    echo "  $0 setup                    # First time setup"
    echo "  $0 generate 100000          # Generate 100K samples"
    echo "  $0 train                    # Train on default dataset"
    echo "  $0 monitor                  # Watch campaign progress"
    exit 1
    ;;
esac

echo ""
echo "========================================================================"

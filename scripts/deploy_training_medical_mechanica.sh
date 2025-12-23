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
REMOTE_USER="${HAFS_WINDOWS_USER:-starw}"
REMOTE_DIR="${HAFS_WINDOWS_CODE_DIR:-C:/hafs}"
D_DRIVE_DIR="${HAFS_WINDOWS_TRAINING:-D:/hafs_training}"
WINDOWS_CONTEXT="${HAFS_WINDOWS_CONTEXT:-D:/.context}"
WINDOWS_PLUGIN_DIR="${HAFS_WINDOWS_PLUGIN_DIR:-C:/hafs_scawful}"
WINDOWS_PYTHON="${HAFS_WINDOWS_PYTHON:-${REMOTE_DIR}/.venv/Scripts/python.exe}"
TRAINING_CONFIG_PATH="${WINDOWS_PLUGIN_DIR}/config/training_medical_mechanica.toml"
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
    ssh "$REMOTE_USER@$REMOTE_HOST" "powershell -NoProfile -Command \"New-Item -ItemType Directory -Force -Path 'D:/hafs_training/datasets' | Out-Null; New-Item -ItemType Directory -Force -Path 'D:/hafs_training/checkpoints' | Out-Null; New-Item -ItemType Directory -Force -Path 'D:/hafs_training/logs' | Out-Null; New-Item -ItemType Directory -Force -Path 'D:/hafs_training/models' | Out-Null; New-Item -ItemType Directory -Force -Path 'D:/hafs_training/temp' | Out-Null; Write-Output '✓ D drive directories created'; Get-PSDrive -Name D | Select-Object Name,Free,Used\""

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

    PS_SCRIPT="& '${WINDOWS_PLUGIN_DIR}/scripts/windows/start_campaign.ps1' -Target '${TARGET}' -Resume:\$true -Export:\$true -Pilot:\$false -TrainingRoot '${D_DRIVE_DIR}' -CodeRoot '${REMOTE_DIR}' -PluginRoot '${WINDOWS_PLUGIN_DIR}' -PythonExe '${WINDOWS_PYTHON}'"
    PS_B64=$(printf "%s" "$PS_SCRIPT" | iconv -t UTF-16LE | base64 | tr -d '\n')
    ssh "$REMOTE_USER@$REMOTE_HOST" "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${PS_B64}"
    ;;

  train)
    DATASET=${2:-"${D_DRIVE_DIR}/datasets/latest"}
    MODEL_NAME=${3:-"oracle-rauru-assembler"}

    echo "Launching model training..."
    echo "Dataset: $DATASET"
    echo "Model: $MODEL_NAME"
    echo "Output: $D_DRIVE_DIR/models/$MODEL_NAME"
    echo ""

    PS_SCRIPT="& '${WINDOWS_PLUGIN_DIR}/scripts/windows/start_training.ps1' -DatasetPath '${DATASET}' -ModelName '${MODEL_NAME}' -TrainingRoot '${D_DRIVE_DIR}' -CodeRoot '${REMOTE_DIR}' -PluginRoot '${WINDOWS_PLUGIN_DIR}' -PythonExe '${WINDOWS_PYTHON}'"
    PS_B64=$(printf "%s" "$PS_SCRIPT" | iconv -t UTF-16LE | base64 | tr -d '\n')
    ssh "$REMOTE_USER@$REMOTE_HOST" "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${PS_B64}"
    ;;

  status)
    echo "Checking ${REMOTE_HOST} status..."
    echo ""

    ssh "$REMOTE_USER@$REMOTE_HOST" "powershell -NoProfile -Command \"Write-Output '=== D Drive Space ==='; Get-PSDrive -Name D | Select-Object Name,Free,Used; Write-Output ''; Write-Output '=== Datasets ==='; Get-ChildItem -Path 'D:/hafs_training/datasets' -ErrorAction SilentlyContinue | Select-Object Name,Length,LastWriteTime; Write-Output ''; Write-Output '=== Models ==='; Get-ChildItem -Path 'D:/hafs_training/models' -ErrorAction SilentlyContinue | Select-Object Name,LastWriteTime; Write-Output ''; Write-Output '=== Running Processes ==='; Get-Process python -ErrorAction SilentlyContinue | Select-Object Id,ProcessName,CPU -First 10; Write-Output ''; Write-Output '=== Latest Log ==='; \$log=Get-ChildItem -Path 'D:/hafs_training/logs' -Filter 'campaign_*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if (\$log) { Get-Content -Path \$log.FullName -Tail 1 }\""
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

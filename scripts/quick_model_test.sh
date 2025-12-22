#!/bin/bash
# Quick test of new models via Ollama

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_plugin_env.sh"

OLLAMA_HOST="${HAFS_WINDOWS_IP:-${HAFS_WINDOWS_HOST:-localhost}}"
OLLAMA_URL="http://${OLLAMA_HOST}:11434"

echo "Testing DeepSeek-R1 8B (reasoning model)..."
echo ""

curl -s "${OLLAMA_URL}/api/generate" -d '{
  "model": "deepseek-r1:8b",
  "prompt": "Explain this 65816 assembly in one sentence: LDA #$80 STA $2100 (hide screen during setup)",
  "stream": false,
  "options": {
    "temperature": 0.7,
    "num_predict": 200
  }
}' | python3 -c "import sys, json; print(json.load(sys.stdin)['response'])"

echo ""
echo "Testing Qwen3 14B (latest version)..."
echo ""

curl -s "${OLLAMA_URL}/api/generate" -d '{
  "model": "qwen3:14b",
  "prompt": "Explain this 65816 assembly in one sentence: LDA #$80 STA $2100 (hide screen during setup)",
  "stream": false,
  "options": {
    "temperature": 0.7,
    "num_predict": 200
  }
}' | python3 -c "import sys, json; print(json.load(sys.stdin)['response'])"

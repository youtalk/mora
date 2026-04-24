#!/usr/bin/env bash
# tools/yokai-forge/scripts/train_style_lora.sh
set -euo pipefail

# Requires Ostris AI Toolkit cloned under tools/ai-toolkit.
# Usage: ./train_style_lora.sh /path/to/dataset

DATASET="${1:-}"
if [[ -z "$DATASET" ]]; then
  echo "usage: $0 <dataset_dir>" >&2; exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
FORGE_ROOT="$(cd "$HERE/.." && pwd)"
DATASET_ABS="$(cd "$DATASET" && pwd)"
mkdir -p "$FORGE_ROOT/outputs"
ln -sfn "$DATASET_ABS" "$FORGE_ROOT/outputs/lora_dataset"

# Ostris invocation using a pinned config file. The config
# is checked in as config/style_lora.yaml next to this script.
python "${AI_TOOLKIT_ROOT:-$HOME/ai-toolkit}/run.py" \
  "$FORGE_ROOT/config/style_lora.yaml"

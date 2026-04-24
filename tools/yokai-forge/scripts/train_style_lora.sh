#!/usr/bin/env bash
# tools/yokai-forge/scripts/train_style_lora.sh
set -euo pipefail

# Requires Ostris AI Toolkit cloned at $AI_TOOLKIT_ROOT (defaults to
# $HOME/ai-toolkit — see Appendix A.5 of the RPG Shell Yokai plan).
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

# Ostris's config/style_lora.yaml uses relative paths (outputs/lora,
# outputs/lora_dataset), so invoke from FORGE_ROOT so those resolve
# into tools/yokai-forge/outputs/ regardless of the caller's CWD.
cd "$FORGE_ROOT"
python "${AI_TOOLKIT_ROOT:-$HOME/ai-toolkit}/run.py" \
  "$FORGE_ROOT/config/style_lora.yaml"

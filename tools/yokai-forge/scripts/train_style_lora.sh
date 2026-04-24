# tools/yokai-forge/scripts/train_style_lora.sh
#!/usr/bin/env bash
set -euo pipefail

# Requires Ostris AI Toolkit cloned under tools/ai-toolkit.
# Usage: ./train_style_lora.sh /path/to/dataset

DATASET="${1:-}"
if [[ -z "$DATASET" ]]; then
  echo "usage: $0 <dataset_dir>" >&2; exit 1
fi

# Ostris invocation using a pinned config file. The config
# is checked in as config/style_lora.yaml next to this script.
python "${AI_TOOLKIT_ROOT:-$HOME/ai-toolkit}/run.py" \
  "$(dirname "$0")/../config/style_lora.yaml"

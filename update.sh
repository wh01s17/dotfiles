#!/usr/bin/env bash
# Update this checkout and apply its user configuration.
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -B "$repo_dir/installer/tools/update-dotfiles.py" "$@"

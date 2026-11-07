#!/bin/bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -eq 0 ]]; then
    echo 'Usage: release.sh "/path/to/NoLogo.app" [--first-release] [--notes FILE]'
    echo 'Packages, signs, and publishes NoLogo using the release script.'
    exit 1
fi

exec python3 "$script_dir/release.py" "$@" --publish

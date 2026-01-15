#!/usr/bin/env bash
# Run noir-build-tools tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check for bats
if ! command -v bats &>/dev/null; then
  echo "bats not found. Install with:"
  echo "  brew install bats-core     # macOS"
  echo "  apt install bats           # Debian/Ubuntu"
  echo "  npm install -g bats        # npm"
  exit 1
fi

echo "Running noir-build-tools tests..."
echo ""

# Run all .bats files in tests/
bats "$ROOT_DIR/tests/"*.bats "$@"

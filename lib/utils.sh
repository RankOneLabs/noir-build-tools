#!/usr/bin/env bash
# Common utilities

set -euo pipefail

# Colors (disabled if not tty)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi

log_info()    { echo -e "${CYAN}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warn()    { echo -e "${YELLOW}⚠${NC} $*" >&2; }
log_error()   { echo -e "${RED}✗${NC} $*" >&2; }

die() { log_error "$@"; exit 1; }

# Check command exists
require_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1"
}

# Get script directory (for finding lib/)
get_script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

#!/usr/bin/env bash
# Output formatting utilities

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Print table separator
print_separator() {
  echo "+----------------------+--------------+--------------+--------------+------------+"
}

# Print profile table header
print_profile_header() {
  print_separator
  printf "| %-20s | %12s | %12s | %12s | %10s |\n" "Circuit" "ACIR" "Brillig" "Total" "Status"
  print_separator
}

# Format number with commas
format_number() {
  printf "%'d" "$1"
}

# Print status (OK or OVER)
format_status() {
  local within_budget="$1"
  if [[ "$within_budget" == "true" ]]; then
    echo -e "${GREEN}✓ OK${NC}"
  else
    echo -e "${RED}✗ OVER${NC}"
  fi
}

#!/usr/bin/env bash
# Config loading and validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

CONFIG_FILE=""
CONFIG_SEARCH_NAMES=("nbt.config.json" "nbt.json" "noir-build.config.json" "noir-build.json")

# Find config file, searching up directory tree
find_config() {
  local dir="${1:-$PWD}"
  while [[ "$dir" != "/" ]]; do
    for name in "${CONFIG_SEARCH_NAMES[@]}"; do
      if [[ -f "$dir/$name" ]]; then
        echo "$dir/$name"
        return 0
      fi
    done
    dir="$(dirname "$dir")"
  done
  return 1
}

# Load and validate config
load_config() {
  CONFIG_FILE="${1:-$(find_config)}" || die "No noir-build.config.json found. Run 'noir-init' to create one."

  [[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"

  # Validate JSON
  jq empty "$CONFIG_FILE" 2>/dev/null || die "Invalid JSON in $CONFIG_FILE"

  # Validate required fields
  local circuit_count
  circuit_count=$(jq '.circuits | length' "$CONFIG_FILE")
  [[ "$circuit_count" -gt 0 ]] || die "No circuits defined in config"

  # Validate each circuit has name and path
  local invalid
  invalid=$(jq -r '.circuits[] | select(.name == null or .path == null) | .name // "unnamed"' "$CONFIG_FILE")
  [[ -z "$invalid" ]] || die "Circuit missing name or path: $invalid"
}

# Get circuit config by name
get_circuit() {
  local name="$1"
  jq -e --arg n "$name" '.circuits[] | select(.name == $n)' "$CONFIG_FILE" || \
    die "Circuit not found: $name"
}

# Get all circuit names
get_circuit_names() {
  jq -r '.circuits[].name' "$CONFIG_FILE"
}

# Get circuit field with default
get_circuit_field() {
  local name="$1" field="$2" default="${3:-}"
  local value
  value=$(jq -r --arg n "$name" --arg f "$field" \
    '.circuits[] | select(.name == $n) | .[$f] // empty' "$CONFIG_FILE")
  echo "${value:-$default}"
}

# Get config path with default
get_config_path() {
  local field="$1" default="$2"
  local value
  value=$(jq -r --arg f "$field" '.paths[$f] // empty' "$CONFIG_FILE")
  echo "${value:-$default}"
}

# Get backend path
get_backend_path() {
  jq -r '.backend.path // "bb"' "$CONFIG_FILE"
}

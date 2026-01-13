#!/usr/bin/env bash
# Nargo wrapper functions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Run nargo command in circuit directory
run_nargo() {
  local circuit_path="$1"
  shift
  (cd "$circuit_path" && nargo "$@")
}

# Compile circuit
nargo_compile() {
  local circuit_path="$1"
  run_nargo "$circuit_path" compile
}

# Execute circuit (generate witness)
nargo_execute() {
  local circuit_path="$1"
  local witness_name="${2:-}"
  if [[ -n "$witness_name" ]]; then
    run_nargo "$circuit_path" execute "$witness_name"
  else
    run_nargo "$circuit_path" execute
  fi
}

# Run tests
nargo_test() {
  local circuit_path="$1"
  run_nargo "$circuit_path" test
}

# Get circuit info (parses nargo info table into JSON)
nargo_info() {
  local circuit_path="$1"
  if ! output=$(run_nargo "$circuit_path" info 2>/dev/null); then
    # Fallback/Error state
    echo '{"package":"","function":"","acir":0,"brillig":0}'
    return 0
  fi

  # Parse table output:
  # | Package | Function | Expression Width     | ACIR Opcodes | Brillig Opcodes |
  echo "$output" | awk -F'|' '
    NR > 3 && NF > 4 {
      gsub(/^[ \t]+|[ \t]+$/, "", $2)  # package
      gsub(/^[ \t]+|[ \t]+$/, "", $3)  # function
      gsub(/^[ \t]+|[ \t]+$/, "", $5)  # acir
      gsub(/^[ \t]+|[ \t]+$/, "", $6)  # brillig
      if ($2 != "" && $2 !~ /^-+$/) {
        printf "{\"package\":\"%s\",\"function\":\"%s\",\"acir\":%d,\"brillig\":%d}\n", 
          $2, $3, $5, $6
      }
    }
  ' | head -1
}

# Get ACIR opcode count
get_acir_opcodes() {
  local circuit_path="$1"
  nargo_info "$circuit_path" | jq -r '.acir'
}

# Get Brillig opcode count  
get_brillig_opcodes() {
  local circuit_path="$1"
  nargo_info "$circuit_path" | jq -r '.brillig'
}

# Get total constraints (ACIR + Brillig)
get_total_constraints() {
  local circuit_path="$1"
  local info
  info=$(nargo_info "$circuit_path")
  local acir brillig
  acir=$(echo "$info" | jq -r '.acir')
  brillig=$(echo "$info" | jq -r '.brillig')
  echo $((acir + brillig))
}

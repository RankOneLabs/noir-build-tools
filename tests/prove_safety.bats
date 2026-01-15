#!/usr/bin/env bats
# Tests for noir-build-tools prove command safety

setup() {
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  export NOIR_BUILD_TOOLS_LIB="$BATS_TEST_DIRNAME/../lib"
  
  if ! command -v nargo &>/dev/null; then
    skip "nargo not installed"
  fi
  
  TEST_DIR="$(mktemp -d)"
  export MOCK_BIN="$TEST_DIR/bin"
  mkdir -p "$MOCK_BIN"
  export PATH="$MOCK_BIN:$PATH"

  # Mock bb
  cat > "$MOCK_BIN/bb" << 'EOF'
#!/bin/bash
# Mock bb
# Usage: bb [write_vk|prove] ... -o OUTPUT_DIR

command="$1"
shift

# Simple arg parsing to find -o
output_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output_dir="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$output_dir" ]]; then
  # Default to current dir or error?
  # write_vk: -o "target"
  # prove: -o "$output_dir_abs"
  echo "Mock bb: No output dir found"
  exit 1
fi

mkdir -p "$output_dir"

if [[ "$command" == "write_vk" ]]; then
  touch "$output_dir/vk"
elif [[ "$command" == "prove" ]]; then
  touch "$output_dir/proof"
fi

exit 0
EOF
  chmod +x "$MOCK_BIN/bb"

  cd "$TEST_DIR"

  mkdir -p test_circuit/src
  cat > test_circuit/Nargo.toml << 'EOF'
[package]
name = "test_circuit"
type = "bin"
authors = ["test"]
[dependencies]
EOF

  cat > test_circuit/src/main.nr << 'EOF'
fn main(x: pub Field, y: Field) {
    assert(x == y);
}
EOF

  # ORIGINAL Prover.toml
  cat > test_circuit/Prover.toml << 'EOF'
x = "100"
y = "100"
EOF

  # CUSTOM inputs
  cat > custom_inputs.toml << 'EOF'
x = "5"
y = "5"
EOF

  cat > nbt.config.json << 'EOF'
{
  "circuits": [
    {
      "name": "test_circuit",
      "path": "./test_circuit"
    }
  ]
}
EOF
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "nbt prove -i respects custom inputs but restores original Prover.toml" {
  # Mocking bb is enough, we don't need real installation check
  # if ! command -v bb &>/dev/null; then skip "bb not installed"; fi

  # 1. Run prove with custom inputs
  run nbt prove test_circuit -i custom_inputs.toml
  prove_output="$output"
  
  # Debug output if failed
  if [ "$status" -ne 0 ]; then
     echo "Output: $prove_output"
  fi
  [ "$status" -eq 0 ]
  
  # 2. Verify original Prover.toml is restored and has original content ("100")
  [ -f "test_circuit/Prover.toml" ]
  run cat test_circuit/Prover.toml
  if [[ "$output" != *"100"* ]]; then
     echo "Expected 100, got: $output"
     echo "Prove command output logic:"
     echo "$prove_output"
     echo "Directory state:"
     ls -la test_circuit/
  fi
  [[ "$output" == *"100"* ]]
  [[ "$output" != *"5"* ]]
}

#!/usr/bin/env bats
# Tests for noir-build-tools benchmark command

setup() {
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  export NOIR_BUILD_TOOLS_LIB="$BATS_TEST_DIRNAME/../lib"
  
  # Skip if nargo not available
  if ! command -v nargo &>/dev/null; then
    skip "nargo not installed"
  fi
  
  # Create temp directory for test fixtures
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"

  # Create a minimal Noir circuit
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

  # Needs Prover.toml for execution
  cat > test_circuit/Prover.toml << 'EOF'
x = "5"
y = "5"
EOF

  # Create nbt config
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

@test "nbt benchmark outputs ascii table by default" {
  run nbt benchmark test_circuit -n 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Benchmark Results"* ]]
  [[ "$output" == *"| test_circuit"* ]]
}

@test "nbt benchmark --json outputs valid JSON" {
  run nbt benchmark test_circuit -n 1 --json
  [ "$status" -eq 0 ]
  
  # Parse output with jq
  echo "$output" | jq . > /dev/null
  
  # Note: benchmark output might also be single object/array dependent?
  # Let's check logic:
  # if [[ "$OUTPUT_JSON" == "true" ]]; then
  #   echo "["; for i in "${!results[@]}"; do [[ $i -gt 0 ]] && echo ","; echo "  ${results[$i]}"; done; echo "]"
  # fi
  # Benchmark ALWAYS outputs an array `[...]` in JSON mode, unlike report.
  
  [ "$(echo "$output" | jq '.[0].name')" == "\"test_circuit\"" ]
  [ "$(echo "$output" | jq '.[0] | has("compileAvg")')" == "true" ]
  [ "$(echo "$output" | jq '.[0] | has("proveAvg")')" == "true" ]
  [ "$(echo "$output" | jq '.[0].runs')" == "1" ]
}

@test "nbt benchmark --csv outputs CSV format" {
  run nbt benchmark test_circuit -n 1 --csv
  [ "$status" -eq 0 ]
  
  # Check header
  [[ "${lines[0]}" == "circuit,acir,brillig,compile_ms,prove_ms,runs" ]]
  # Check data row
  [[ "${lines[1]}" == *"test_circuit"* ]]
}

@test "nbt benchmark honors --runs flag" {
  # We can't easily count the actual runs inside the robust script without instrumenting it,
  # but we can check the reported runs count in JSON output
  run nbt benchmark test_circuit --runs 2 --json
  [ "$status" -eq 0 ]
  
  [ "$(echo "$output" | jq '.[0].runs')" == "2" ]
}

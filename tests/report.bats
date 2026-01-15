#!/usr/bin/env bats
# Tests for noir-build-tools report command

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

  # Use enough constraints to definitely exceed 1
  cat > test_circuit/src/main.nr << 'EOF'
fn main(x: pub Field, y: Field) {
    assert(x != y);
    assert(x == y);
}
EOF

  # Create nbt config
  cat > nbt.config.json << 'EOF'
{
  "circuits": [
    {
      "name": "test_circuit",
      "path": "./test_circuit",
      "constraintBudget": 10000
    }
  ]
}
EOF
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "nbt report generates valid JSON with expected fields" {
  run nbt report
  if [ "$status" -ne 0 ]; then
    echo "Command failed with status $status"
    echo "Output: $output"
  fi
  [ "$status" -eq 0 ]
  
  # Parse output with jq
  echo "$output" | jq . > /dev/null
  
  # Check for fields - logic returns single object for single circuit
  [ "$(echo "$output" | jq '.name')" == "\"test_circuit\"" ]
  [ "$(echo "$output" | jq '. | has("acir")')" == "true" ]
  [ "$(echo "$output" | jq '. | has("brillig")')" == "true" ]
  [ "$(echo "$output" | jq '. | has("total")')" == "true" ]
  [ "$(echo "$output" | jq '.budget')" == "10000" ]
  [ "$(echo "$output" | jq '.withinBudget')" == "true" ]
}

@test "nbt report detects budget violation" {
  # Update config with low budget (1 constraint)
  cat > nbt.config.json << 'EOF'
{
  "circuits": [
    {
      "name": "test_circuit",
      "path": "./test_circuit",
      "constraintBudget": 1
    }
  ]
}
EOF

  run nbt report
  [ "$status" -eq 0 ]
  
  # If this fails, we want to know why
  if [ "$(echo "$output" | jq '.withinBudget')" != "false" ]; then
    echo "Expected withinBudget: false, but got:"
    echo "$output" | jq .
    return 1
  fi
}

@test "nbt report supports single circuit argument" {
  run nbt report test_circuit
  [ "$status" -eq 0 ]
  
  # Single result is an object, not an array
  echo "$output" | jq . > /dev/null
  [ "$(echo "$output" | jq '.name')" == "\"test_circuit\"" ]
}

#!/usr/bin/env bats
# Integration tests with a real circuit (requires nargo + bb)

setup() {
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  export NOIR_BUILD_TOOLS_LIB="$BATS_TEST_DIRNAME/../lib"
  
  # Skip if nargo not available
  if ! command -v nargo &>/dev/null; then
    skip "nargo not installed"
  fi
  
  # Create temp directory with a minimal circuit
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

@test "nbt compile works with real circuit" {
  run nbt compile test_circuit
  [ "$status" -eq 0 ]
  [ -f "test_circuit/target/test_circuit.json" ]
}

@test "nbt test works with real circuit" {
  run nbt test test_circuit
  # May pass or fail based on test presence, but should run
  [ "$status" -eq 0 ] || [[ "$output" == *"no tests"* ]] || [[ "$output" == *"0 passed"* ]]
}

@test "nbt profile works with real circuit" {
  nbt compile test_circuit
  run nbt profile test_circuit
  [ "$status" -eq 0 ]
  [[ "$output" == *"constraint"* ]] || [[ "$output" == *"ACIR"* ]]
}

@test "nbt verifier generates VK" {
  if ! command -v bb &>/dev/null; then
    skip "bb not installed"
  fi
  
  run nbt verifier test_circuit
  [ "$status" -eq 0 ]
  [ -f "test_circuit/target/vk" ]
}

@test "nbt prove generates proof" {
  if ! command -v bb &>/dev/null; then
    skip "bb not installed"
  fi
  
  run nbt prove test_circuit
  [ "$status" -eq 0 ]
  [ -f "test_circuit/target/proof" ]
}

@test "nbt verify validates proof" {
  if ! command -v bb &>/dev/null; then
    skip "bb not installed"
  fi
  
  # Generate VK and proof first
  nbt verifier test_circuit
  nbt prove test_circuit
  
  run nbt verify test_circuit
  [ "$status" -eq 0 ]
  [[ "$output" == *"verified"* ]] || [[ "$output" == *"success"* ]]
}

@test "nbt sol-verifier generates Solidity contract" {
  if ! command -v bb &>/dev/null; then
    skip "bb not installed"
  fi
  
  run nbt sol-verifier test_circuit
  [ "$status" -eq 0 ]
  [ -f "contracts/verifiers/test_circuit/Verifier.sol" ]
}

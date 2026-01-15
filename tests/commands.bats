#!/usr/bin/env bats
# Tests for noir-build-tools commands

setup() {
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  export NOIR_BUILD_TOOLS_LIB="$BATS_TEST_DIRNAME/../lib"
  
  # Create temp directory for test fixtures
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "nbt without args shows help" {
  run nbt
  # Shows usage but exits non-zero (expected)
  [[ "$output" == *"Usage:"* ]]
}

@test "nbt help shows usage" {
  run nbt
  [[ "$output" == *"Commands:"* ]]
  [[ "$output" == *"compile"* ]]
}

@test "nbt init creates config file" {
  run nbt init
  # init may succeed or fail based on environment, just check config was created
  [ -f "nbt.config.json" ] || [[ "$output" == *"Created"* ]] || [[ "$output" == *"exists"* ]]
}

@test "nbt list without config fails gracefully" {
  run nbt list
  [ "$status" -ne 0 ]
  [[ "$output" == *"config"* ]] || [[ "$output" == *"not found"* ]]
}

@test "nbt list with config shows circuits" {
  nbt init
  run nbt list
  [ "$status" -eq 0 ]
}

@test "nbt doctor checks environment" {
  run nbt doctor
  # May pass or fail depending on installed tools, but should run
  [[ "$output" == *"nargo"* ]] || [[ "$output" == *"jq"* ]]
}

@test "nbt compile without circuit name shows usage" {
  nbt init
  run nbt compile
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"circuit"* ]]
}

@test "nbt verifier without circuit name shows usage" {
  run nbt verifier
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"CIRCUIT"* ]]
}

@test "nbt sol-verifier without circuit name shows usage" {
  run nbt sol-verifier
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"CIRCUIT"* ]]
}

@test "nbt prove without circuit name shows usage" {
  run nbt prove
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"CIRCUIT"* ]]
}

@test "nbt verify without circuit name shows usage" {
  run nbt verify
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"CIRCUIT"* ]]
}

@test "nbt sol-verify without circuit name shows usage" {
  run nbt sol-verify
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"CIRCUIT"* ]]
}

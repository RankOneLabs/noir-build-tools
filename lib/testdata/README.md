# Test Data Generation Engine

This directory contains the core logic for `nbt testdata`, a declarative engine for generating cryptographic test vectors.

## Architecture

The system is designed to separate **execution logic** (this engine) from **circuit specification** (user YAML files).

### 1. Engine (`engine.mjs`)
The heart of the system. It:
1.  **Parses** a YAML configuration file.
2.  **Resolves** variables (e.g., `$inputs.birth_year`) and dependencies.
3.  **Executes** a linear pipeline of operations.
4.  **Formats** the results into a valid `Prover.toml` string.

### 2. Primitives (`primitives.mjs`)
A collection of specific cryptographic implementations required by Noir.
*   `pedersenHash`: Wrapper around `@aztec/bb.js` to ensure compatibility with Noir's Grumpkin curve hashing.
*   `signSecp256k1`: Wrapper around `@noble/secp256k1` to produce compatible signatures.

### 3. CLI (`cli.mjs`)
The entry point invoked by the `nbt` bash wrapper. It handles argument parsing and file I/O.

## YAML Specification

Users provide a YAML file to define their generation logic.

```yaml
inputs:
  # Static values
  my_field: 123

pipeline:
  # Sequence of operations
  - id: my_hash
    op: pedersenHash
    args: [$my_field]

outputs:
  # Final TOML mapping
  circuit_input_name: $my_hash
```

## Adding New Primitives
To support new crypto schemes (e.g., Poseidon, Schnorr):
1.  Add the implementation to `primitives.mjs`.
2.  It is immediately available to use in YAML via `op: newPrimitiveName`.

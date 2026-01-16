# Test Data Generation (`nbt testdata`)

The `nbt testdata` command generates cryptographically valid test inputs for Noir circuits using a declarative YAML configuration.

## Usage

```bash
# Generate inputs using a specific config file
nbt testdata <config_file> [options]

# Example
nbt testdata age_gate_inputs.yaml -o Prover.toml
```

### Options

| Flag | Description |
|------|-------------|
| `-o, --output <FILE>` | Write output to a file instead of stdout |

## Configuration (`.yaml`)

Create a YAML file in your project directory (e.g., `age_gate_inputs.yaml`) to define how inputs are generated.

### Structure

1.  **inputs**: Define static values or defaults.
2.  **pipeline**: A list of operations to perform (e.g., hashing, signing).
3.  **outputs**: Map the results to your `Prover.toml` fields.

### Example Configuration

```yaml
inputs:
  birth_year: 1990
  birth_month: 6
  birth_day: 15
  salt: 123456789

pipeline:
  # Compute Pedersen Hash
  - id: msg_hash
    op: pedersenHash
    args: 
      - $birth_year
      - $birth_month
      - $birth_day
      - $salt

  # Sign the hash
  - id: signer
    op: signSecp256k1
    message: $msg_hash

outputs:
  # Map results to TOML keys
  birth_year: $birth_year
  salt: $salt
  signature: $signer.signature
  issuer_pub_key_x: $signer.publicKeyX
```

## Available Operations

*   `pedersenHash(inputs...)`: Computes a Pedersen hash (Grumpkin curve) of the inputs.
*   `signSecp256k1(message, [privateKey])`: Signs a message using ECDSA (secp256k1). Returns `{ signature, publicKeyX, publicKeyY, privateKey }`.

## Architecture or "How it works"

The system uses a generic engine in `noir-build-tools` that reads your local YAML file.
This strictly separates the **Tooling** (which knows how to compute hashes/signatures) from the **Project Config** (which knows what your circuit needs).

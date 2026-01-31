# Test Data Generation for Noir Circuits

## Problem

Noir circuits often require cryptographic inputs (signatures, hashes, commitments) that must be valid for the circuit to execute. Generating dummy data fails because:

1. **Pedersen hash** is computed on the Grumpkin curve inside Noir - can't compute off-chain without matching implementation
2. **ECDSA signatures** must be valid over the exact message the circuit expects
3. **Public keys** must be valid curve points

Example error with invalid data:
```
Failed to solve blackbox function: ecdsa_secp256k1, reason: Invalid public key provided for ECDSA verification
```

## Solution

Add `nbt testdata` command that uses `@aztec/bb.js` to compute the same cryptographic primitives Noir uses, generating valid Prover.toml inputs.

## Command

```bash
nbt testdata <circuit> [options]
```

### Options

| Flag | Description |
|------|-------------|
| `-o, --output FILE` | Write to file (default: stdout) |
| `-t, --template NAME` | Use specific template |
| `--list` | List available templates |
| `--dry-run` | Show what would be generated |
| `--json` | JSON output for scripting |
| `-- [args]` | Pass arguments to template |

### Examples

```bash
# Generate test data for age_gate
nbt testdata age_gate > age_gate/Prover.toml

# With custom birthdate
nbt testdata age_gate -- --birth-year 2000 --birth-month 3 --birth-day 15

# List available templates  
nbt testdata --list

# Explicit template
nbt testdata my_circuit --template ecdsa-signed-message
```

## Architecture

```
noir-build-tools/
├── lib/
│   ├── commands/
│   │   └── testdata                  # Bash entry point
│   └── testdata/                     # Node.js implementation
│       ├── package.json              # Dependencies
│       ├── cli.mjs                   # CLI parser, template loader
│       ├── primitives.mjs            # Crypto primitives (bb.js wrappers)
│       ├── toml.mjs                  # TOML output formatter
│       └── templates/                # Circuit-specific templates
│           ├── index.mjs             # Template registry
│           ├── age_gate.mjs          # age_gate circuit
│           ├── ecdsa_signed.mjs      # Generic ECDSA pattern
│           └── generic.mjs           # Fallback (random valid values)
```

## Implementation Phases

### Phase 1: Core Infrastructure

**Files:**
- `lib/testdata/package.json`
- `lib/testdata/primitives.mjs`
- `lib/commands/testdata`

**package.json:**
```json
{
  "name": "nbt-testdata",
  "type": "module",
  "dependencies": {
    "@aztec/bb.js": "^0.87.0",
    "@noble/secp256k1": "^2.0.0",
    "@noble/hashes": "^1.3.0"
  }
}
```

**primitives.mjs:**
```javascript
import { Barretenberg, Fr } from '@aztec/bb.js';
import * as secp from '@noble/secp256k1';

let api = null;

export async function init() {
  if (!api) {
    api = await Barretenberg.new({ threads: 1 });
  }
  return api;
}

export async function destroy() {
  if (api) {
    await api.destroy();
    api = null;
  }
}

// Compute Pedersen hash matching Noir's std::hash::pedersen_hash
export async function pedersenHash(inputs) {
  const bb = await init();
  const frInputs = inputs.map(x => new Fr(BigInt(x)));
  const hash = await bb.pedersenHash(frInputs, 0);
  return hash.toBuffer();
}

// Generate secp256k1 keypair and sign message
export function signSecp256k1(message, privateKey = null) {
  const privKey = privateKey || secp.utils.randomPrivateKey();
  const pubKey = secp.getPublicKey(privKey, false); // uncompressed
  const signature = secp.sign(message, privKey);
  
  return {
    privateKey: privKey,
    publicKeyX: pubKey.slice(1, 33),
    publicKeyY: pubKey.slice(33, 65),
    signature: signature.toCompactRawBytes(),
  };
}

// Format bytes as TOML array
export function toTomlArray(bytes) {
  return '[' + Array.from(bytes).join(', ') + ']';
}
```

**lib/commands/testdata:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# ... standard lib resolution ...

source "$LIB_DIR/utils.sh"
source "$LIB_DIR/config.sh"

TESTDATA_DIR="$LIB_DIR/testdata"

# Check Node.js
require_cmd node

# Install deps if needed
if [[ ! -d "$TESTDATA_DIR/node_modules" ]]; then
  log_info "Installing testdata dependencies..."
  (cd "$TESTDATA_DIR" && npm install --silent)
fi

# Run the generator
exec node "$TESTDATA_DIR/cli.mjs" "$@"
```

### Phase 2: Template System

**Template Interface:**
```javascript
// templates/age_gate.mjs
export default {
  name: 'age_gate',
  description: 'Age verification with ECDSA-signed birthdate',
  
  // Auto-detect from circuit ABI
  detect(abi) {
    const params = abi.parameters.map(p => p.name);
    return params.includes('birth_year') && 
           params.includes('signature') &&
           params.includes('issuer_pub_key_x');
  },
  
  // CLI options for this template
  options: [
    { name: 'birth-year', type: 'number', default: 1990 },
    { name: 'birth-month', type: 'number', default: 6 },
    { name: 'birth-day', type: 'number', default: 15 },
    { name: 'min-age', type: 'number', default: 18 },
  ],
  
  // Generate Prover.toml content
  async generate(opts, primitives) {
    const { pedersenHash, signSecp256k1, toTomlArray } = primitives;
    
    const messageHash = await pedersenHash([
      opts.birthYear,
      opts.birthMonth, 
      opts.birthDay
    ]);
    
    const { signature, publicKeyX, publicKeyY } = signSecp256k1(messageHash);
    
    const now = new Date();
    
    return `# Auto-generated test data for age_gate
# Generated: ${new Date().toISOString()}

# Private inputs
birth_year = ${opts.birthYear}
birth_month = ${opts.birthMonth}
birth_day = ${opts.birthDay}
signature = ${toTomlArray(signature)}

# Public inputs
current_year = ${now.getFullYear()}
current_month = ${now.getMonth() + 1}
current_day = ${now.getDate()}
min_age = ${opts.minAge}
issuer_pub_key_x = ${toTomlArray(publicKeyX)}
issuer_pub_key_y = ${toTomlArray(publicKeyY)}
`;
  }
};
```

### Phase 3: CLI Implementation

**cli.mjs:**
```javascript
import { parseArgs } from 'node:util';
import * as primitives from './primitives.mjs';
import templates from './templates/index.mjs';

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    output: { type: 'string', short: 'o' },
    template: { type: 'string', short: 't' },
    list: { type: 'boolean' },
    'dry-run': { type: 'boolean' },
    json: { type: 'boolean' },
    help: { type: 'boolean', short: 'h' },
  },
});

if (values.list) {
  console.log('Available templates:');
  for (const t of templates) {
    console.log(`  ${t.name.padEnd(20)} ${t.description}`);
  }
  process.exit(0);
}

const circuitName = positionals[0];
if (!circuitName) {
  console.error('Usage: nbt testdata <circuit> [options]');
  process.exit(1);
}

// Find template
const template = values.template 
  ? templates.find(t => t.name === values.template)
  : templates.find(t => t.name === circuitName) || templates.find(t => t.name === 'generic');

if (!template) {
  console.error(`Template not found: ${values.template}`);
  process.exit(1);
}

try {
  const output = await template.generate({/* parsed options */}, primitives);
  
  if (values.output) {
    fs.writeFileSync(values.output, output);
    console.error(`Wrote: ${values.output}`);
  } else {
    console.log(output);
  }
} finally {
  await primitives.destroy();
}
```

### Phase 4: Circuit Auto-Detection (Future)

Parse `target/<circuit>.json` ABI to auto-detect patterns:

| Pattern | Template |
|---------|----------|
| `signature: [u8; 64]` + `pub_key_*` | ecdsa_signed |
| `merkle_proof: [Field; N]` | merkle_proof |
| `nullifier: Field` | nullifier |
| (fallback) | generic |

## Dependencies

| Package | Purpose | Size |
|---------|---------|------|
| `@aztec/bb.js` | Pedersen hash, other ZK primitives | ~50MB |
| `@noble/secp256k1` | ECDSA signing | ~50KB |
| `@noble/hashes` | Utilities | ~100KB |

Note: `@aztec/bb.js` is large due to WASM. Consider lazy-loading or optional install.

## Testing

Add to `tests/integration.bats`:

```bash
@test "nbt testdata generates valid Prover.toml" {
  run nbt testdata age_gate
  [ "$status" -eq 0 ]
  [[ "$output" =~ "birth_year" ]]
  [[ "$output" =~ "signature" ]]
}

@test "nbt testdata with output file" {
  run nbt testdata age_gate -o "$BATS_TMPDIR/Prover.toml"
  [ "$status" -eq 0 ]
  [ -f "$BATS_TMPDIR/Prover.toml" ]
}

@test "nbt testdata --list shows templates" {
  run nbt testdata --list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "age_gate" ]]
}
```

## Open Questions

1. **Lazy install?** `@aztec/bb.js` is 50MB+. Install on first use or require explicit setup?

2. **User templates?** Support `<project>/.nbt/templates/` for custom templates?

3. **Deterministic mode?** Flag to use fixed seed for reproducible outputs?

4. **ABI parsing?** Worth implementing auto-detection from compiled circuit JSON?

## Timeline

| Phase | Effort | Description |
|-------|--------|-------------|
| 1 | 2 hours | Core infrastructure, primitives |
| 2 | 2 hours | Template system, age_gate template |
| 3 | 1 hour | CLI, integration |
| 4 | 2 hours | Auto-detection (optional) |

## Related

- [bb.js documentation](https://barretenberg.aztec.network/docs/how_to_guides/on-the-browser/)
- [Noir stdlib hash functions](https://noir-lang.org/docs/noir/standard_library/cryptographic_primitives/hashes)
- [noble-secp256k1](https://github.com/paulmillr/noble-secp256k1)

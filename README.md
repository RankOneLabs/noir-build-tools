# noir-build-tools

Config-driven build, test, profile, and verifier tooling for Noir circuits. Minimal dependencies: `nargo` and `jq` (plus optional `bb` for verifier generation).

## Features
- JSON config, no hardcoded paths
- Compile, test, profile (with budgets), benchmark, verifier generation
- Machine-readable output (`--json`, `--csv`), CI-friendly exit codes
- No trusted setup required (UltraPlonk)

## Requirements
- `nargo` (includes `noir-profiler`)
- `jq`
- Optional: `bb` for Solidity verifier generation

## Install
```bash
./install.sh
export PATH="$HOME/.local/bin:$PATH"
```

## Quickstart
```bash
nbt init                       # create nbt.config.json
nbt list                       # list circuits
nbt compile my_circuit         # compile one circuit
nbt test --all                 # run tests for all circuits
nbt profile --all              # profile constraints, exits 1 if over budget
nbt benchmark my_circuit --csv # timing benchmarks
nbt verifier my_circuit        # generate Solidity verifier
nbt deploy my_circuit          # deploy Solidity verifier (forge)
nbt report --all               # JSON report of constraints/budgets
nbt doctor                     # check environment health
```

## Commands
- `nbt init`: Creates `nbt.config.json` in the current directory.
- `nbt list`: Prints circuits from the config with their paths and budgets.
- `nbt compile [name|--all]`: Runs `nargo compile` in each circuit directory.
- `nbt test [name|--all]`: Runs `nargo test` in each circuit directory.
- `nbt profile [name|--all]`: Runs `nargo info`, sums constraints, and exits 1 if over `constraintBudget`.
- `nbt benchmark [name|--all] [--csv]`: Runs `nargo execute` multiple times and reports timing.
- `nbt verifier [name]`: Uses `bb` to emit Solidity verifier + vk artifacts into `paths.verifiers/<circuit>/`.
- `nbt deploy [name]`: Deploys `paths.verifiers/<circuit>/Verifier.sol` via `forge create` (configurable rpc/private key). Falls back to env: `NBT_CIRCUIT`/`CIRCUIT`, `RPC_URL`, `PRIVATE_KEY`, `CONTRACT_NAME`, `CHAIN_ID`/`CHAINID`, `DRY_RUN`. Auto-deploys/link required libraries, broadcasts by default (add `--dry-run` to skip), and saves per-chain metadata (address, tx, chainId, libraries) to `paths.verifiers/<circuit>/deployment-<chainId>.json` (or `deployment.json` if unknown).
- `nbt report [name|--all]`: Emits JSON summarizing constraints/budgets.
- `nbt doctor`: Checks environment for required tools (jq, nargo).

## End-to-end local workflow (example)
1) **Install tools**
```bash
cd ~/codes/rol/noir-build-tools
./install.sh
export PATH="$HOME/.local/bin:$PATH"
# Optional: export NOIR_BUILD_TOOLS_LIB="/absolute/path/to/lib" if the libs are elsewhere
```

2) **Create config** where you want to work (no circuit required yet)
```bash
cd /path/to/your/noir/project
nbt init
```

3) **Point circuits to their folders** (edit `nbt.config.json`)
- For each circuit, set `circuits[].path` to the directory containing its `Nargo.toml` (often `./` or `circuits/<name>`).
- Optional fields: `constraintBudget`, `benchmarkRuns`, `paths.reports`, `paths.verifiers`, `backend.path` (default `bb`).

4) **Inspect config**
```bash
nbt list
```

5) **Compile**
```bash
nbt compile --all     # or nbt compile my_circuit
```

6) **Test**
```bash
nbt test --all        # or nbt test my_circuit
```

7) **Profile constraints (budget check)**
```bash
nbt profile --all     # exits 1 if any circuit exceeds its constraintBudget
```

8) **Benchmark execution time**
```bash
nbt benchmark my_circuit --csv  # averages over benchmarkRuns
```

9) **Generate Solidity verifier** (requires `bb`)
```bash
nbt verifier my_circuit
# Outputs Verifier.sol to paths.verifiers/<circuit>/ (default ./contracts/verifiers/<circuit>/)
```

9b) **Deploy the verifier** (requires Foundry)
```bash
nbt deploy my_circuit --rpc-url http://127.0.0.1:8545 --private-key 0x...
# Defaults: rpc=http://127.0.0.1:8545, key=anvil default, contract name=HonkVerifier
# Auto-deploys/link any libraries, broadcasts by default, and writes deployment-<chainId>.json under paths.verifiers/<circuit>/ with address, tx hash, chainId, libraries
# Add --dry-run (or DRY_RUN=true) to skip broadcasting
```

10) **Produce a machine-readable report**
```bash
nbt report --all > reports/summary.json
```

11) **Test verifier on a local chain** (example flow)
- Start a local EVM (e.g., `anvil` or `hardhat node`).
- Compile and deploy the generated Solidity verifier with your preferred tool (Foundry/Hardhat/Remix) using the vk and verifier artifacts from `paths.verifiers/<circuit>/` (file name is always Verifier.sol).
- Generate a proof with `bb` or your proving pipeline, then call the verifier contract’s verify function on the local chain to confirm it accepts a valid proof and rejects an invalid one.

### Foundry deploy/test (minimal example)
Assumes `nbt verifier my_circuit` produced `contracts/verifiers/my_circuit/Verifier.sol` plus `proof` and `public_inputs` (newline-separated hex field elements) in your circuit’s `target/`.

1) Start a local chain in one terminal:
```bash
anvil --block-time 2 --chain-id 31337
```

2) Deploy the verifier (contract name is typically `HonkVerifier` in the generated Solidity):
```bash
cd /path/to/your/noir/project
forge create \
	--rpc-url http://127.0.0.1:8545 \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \ # anvil default key[0]
	./contracts/verifiers/<circuit>/Verifier.sol:HonkVerifier
# capture the deployed address from the output
```

3) Call `verify` with your proof and public inputs:
```bash
VERIFIER=<deployed_address>
PROOF=$(cat target/proof)  # expects 0x-prefixed hex
PUBS=$(tr '\n' ',' < target/public_inputs | sed 's/,$//')
cast call $VERIFIER "verify(bytes,bytes32[])" $PROOF "[$PUBS]" --rpc-url http://127.0.0.1:8545
```

Notes:
- If your generated verifier contract has a different name, adjust the `forge create` target accordingly.
- If `public_inputs` is emitted in another format (JSON, abi-encoded), convert it to a comma-separated list of 0x-prefixed 32-byte values for the `bytes32[]` argument.
- You can also wrap steps 2–3 in a Foundry script that reads `target/proof` and `target/public_inputs` from disk and asserts `verify(...) == true`.

#### Foundry script (ready to run)
Example script at `examples/foundry/VerifyLocal.s.sol`. Copy it into your project’s `script/` folder and update the import path to your generated verifier (default `contracts/verifiers/<circuit>/<circuit>Verifier.sol`). It expects:
- `target/proof` containing the proof bytes (0x-prefixed hex).
- `target/public_inputs.json` containing `{ "public_inputs": ["0x...", "0x..."] }`.

Convert `public_inputs` (newline-separated hex) to JSON:
```bash
jq -R -s 'split("\n")[:-1] | {public_inputs: map(select(length>0))}' target/public_inputs > target/public_inputs.json
```

Run the script (after deploying the verifier and exporting `VERIFIER_ADDRESS`):
```bash
forge script script/VerifyLocal.s.sol \
	--rpc-url http://127.0.0.1:8545 \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	--broadcast
```
The script reads the proof/public inputs from disk and calls `verify(...)`; it reverts if verification fails.

Tips:
- Commands auto-discover `nbt.config.json` by walking up directories; run them anywhere under your project tree.
- Make sure each `circuits[].path` actually contains `Nargo.toml`; `nargo` resolves `src/main.nr` from there.
- If you see `lib/utils.sh not found`, reinstall or set `NOIR_BUILD_TOOLS_LIB` to the repo’s `lib` directory.

## Config
See `templates/nbt.config.json` for schema. Key fields: `circuits[].name`, `circuits[].path`, optional `constraintBudget`, `benchmarkRuns`, `paths.reports`, `paths.verifiers`, `backend.path`.

## CI Example
See `examples/github-workflow.yml` for GitHub Actions usage.

## License
MIT

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
// Update this import to your generated verifier path (default: contracts/verifiers/<circuit>/<circuit>Verifier.sol)
import {IVerifier} from "../contracts/verifiers/Verifier.sol";

/// @notice Forge script to call the generated Noir verifier contract with the proof/public inputs on a local chain.
/// - Expects `target/proof` (0x-prefixed hex) and `target/public_inputs.json` with {"public_inputs":["0x..",...]}
/// - Set VERIFIER_ADDRESS in the environment.
contract VerifyLocal is Script {
    string constant PROOF_PATH = "target/proof";
    string constant PUBLIC_INPUTS_JSON = "target/public_inputs.json";

    function run() external {
        address verifier = vm.envAddress("VERIFIER_ADDRESS");

        bytes memory proof = vm.readFileBinary(PROOF_PATH);
        string memory raw = vm.readFile(PUBLIC_INPUTS_JSON);
        bytes32[] memory publicInputs = abi.decode(vm.parseJson(raw, ".public_inputs"), (bytes32[]));

        vm.startBroadcast();
        bool ok = IVerifier(verifier).verify(proof, publicInputs);
        vm.stopBroadcast();

        console2.log("verify() result", ok);
        if (!ok) revert("verification failed");
    }
}

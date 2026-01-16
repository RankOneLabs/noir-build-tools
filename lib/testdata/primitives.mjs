import { Barretenberg, Fr } from '@aztec/bb.js';
import { etc, getPublicKey, sign, utils } from '@noble/secp256k1';
import { hmac } from '@noble/hashes/hmac';
import { sha256 } from '@noble/hashes/sha256';

// noble-secp256k1 v2+ requires HMAC-SHA256 configuration on 'etc'
etc.hmacSha256Sync = (k, ...m) => hmac(sha256, k, etc.concatBytes(...m));

let api = null;

export async function init() {
    if (!api) {
        // bb.js requires specific thread configuration in Node
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
export async function pedersenHash(...inputs) {
    const bb = await init();
    // Flatten if inputs[0] is an array (handle both styles)
    const flatInputs = Array.isArray(inputs[0]) ? inputs[0] : inputs;
    const frInputs = flatInputs.map(x => new Fr(BigInt(x)));
    const hash = await bb.pedersenHash(frInputs, 0);
    return hash.toBuffer();
}

// Generate secp256k1 keypair and sign message
export function signSecp256k1(message, privateKey = null) {
    const privKey = privateKey || utils.randomPrivateKey();
    const pubKey = getPublicKey(privKey, false); // uncompressed = 65 bytes (04 + X + Y)

    // Hash message if passing bytes? 
    // verify_signature in Noir usually expects the 32-byte message hash
    // sign expects 32-byte hash
    const signature = sign(message, privKey);

    // Uncompressed public key format: [0x04, x_32, y_32]
    // We generally need x and y separately for Noir
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

import { Barretenberg, Fr } from '@aztec/bb.js';
import { etc, getPublicKey, sign, utils } from '@noble/secp256k1';
import { hmac } from '@noble/hashes/hmac';
import { sha256 } from '@noble/hashes/sha256';
import { blake2s } from '@noble/hashes/blake2s';
import { poseidon1, poseidon2, poseidon3, poseidon4, poseidon5, poseidon6, poseidon7 } from 'poseidon-lite';

// noble-secp256k1 v2+ requires HMAC-SHA256 configuration on 'etc'
etc.hmacSha256Sync = (k, ...m) => hmac(sha256, k, etc.concatBytes(...m));

// BN254 field modulus
const FIELD_MODULUS = 21888242871839275222246405745257275088548364400416034343698204186575808495617n;

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

// Compute Blake2s hash (32 bytes)
export function blake2sHash(data) {
    if (Array.isArray(data)) {
        // If data is an array of numbers, convert to Uint8Array
        return blake2s(new Uint8Array(data));
    }
    return blake2s(data);
}

// Format bytes as TOML array
export function toTomlArray(bytes) {
    return '[' + Array.from(bytes).join(', ') + ']';
}

// ============================================================================
// Poseidon Hash (BN254 field)
// ============================================================================

/**
 * Poseidon hash of field elements (matches Noir's poseidon::bn254::hash_*)
 * @param {...bigint|number} inputs - Field elements to hash
 * @returns {bigint} Hash result as bigint
 */
export function poseidonHash(...inputs) {
    const flatInputs = Array.isArray(inputs[0]) ? inputs[0] : inputs;
    const bigInputs = flatInputs.map(x => BigInt(x));

    switch (bigInputs.length) {
        case 1: return poseidon1(bigInputs);
        case 2: return poseidon2(bigInputs);
        case 3: return poseidon3(bigInputs);
        case 4: return poseidon4(bigInputs);
        case 5: return poseidon5(bigInputs);
        case 6: return poseidon6(bigInputs);
        case 7: return poseidon7(bigInputs);
        default:
            throw new Error(`Poseidon: unsupported input count ${bigInputs.length} (max 7)`);
    }
}

// ============================================================================
// Pedersen Commitment (Grumpkin curve, matches Noir's std::hash::pedersen_commitment)
// ============================================================================

/**
 * Compute Pedersen commitment: C = secret * G0 + blinding * G1
 * @param {bigint|number} secret - Value to commit to
 * @param {bigint|number} blinding - Blinding factor
 * @returns {Promise<{x: bigint, y: bigint}>} Commitment point
 */
export async function pedersenCommit(secret, blinding) {
    const bb = await init();
    const inputs = [new Fr(BigInt(secret)), new Fr(BigInt(blinding))];
    const result = await bb.pedersenCommit(inputs, 0);
    return {
        x: frToBigInt(result.x),
        y: frToBigInt(result.y),
    };
}

// Helper to convert Fr to bigint
function frToBigInt(fr) {
    let result = 0n;
    for (const byte of fr.value) {
        result = (result << 8n) | BigInt(byte);
    }
    return result;
}

// ============================================================================
// Helper functions
// ============================================================================

/**
 * Generate random field element
 */
function randomField() {
    const bytes = new Uint8Array(32);
    crypto.getRandomValues(bytes);
    let value = 0n;
    for (const b of bytes) {
        value = (value << 8n) | BigInt(b);
    }
    return value % FIELD_MODULUS;
}

const LIMB_MASK = (1n << 128n) - 1n;  // 2^128 - 1

/**
 * Split a field element into lo/hi 128-bit limbs for EmbeddedCurveScalar
 */
function splitScalar(s) {
    const lo = s & LIMB_MASK;
    const hi = s >> 128n;
    return { lo, hi };
}

// ============================================================================
// Schnorr Signature (Grumpkin curve, matches Noir's embedded_curve_ops)
// ============================================================================

// Grumpkin Scalar Modulus (BN254 Base Field) - required for valid Schnorr signatures
const GRUMPKIN_SCALAR_MODULUS = 21888242871839275222246405745257275088696311157297823662689037894645226208583n;


// Grumpkin uses Barretenberg's embedded curve (cycle with BN254)
// We use pedersenCommit([s, 0], 0) = s * G0 for scalar multiplication

/**
 * Grumpkin scalar multiplication: s * G0
 * Uses bb.js pedersenCommit([s, 0], 0) which equals s * G0 + 0 * G1 = s * G0
 */
async function grumpkinScalarMulG(s) {
    const bb = await init();
    const result = await bb.pedersenCommit([new Fr(BigInt(s)), new Fr(0n)], 0);
    return {
        x: frToBigInt(result.x),
        y: frToBigInt(result.y),
    };
}

/**
 * Sign a message using Schnorr signature on Grumpkin (matches Noir's embedded_curve_ops)
 * s*G == R + H(R || pk || m) * pk
 * 
 * Returns signature with s split into lo/hi limbs for Noir's EmbeddedCurveScalar
 * 
 * @param {bigint} message - Message hash (field element)
 * @param {bigint|null} secretKey - Secret key (null = generate random)
 * @returns {Promise<{signature: {r: {x: bigint, y: bigint}, s: bigint, s_lo: bigint, s_hi: bigint}, publicKey: {x: bigint, y: bigint}, secretKey: bigint}>}
 */
export async function signSchnorrBn254(message, secretKey = null) {
    // WORKAROUND: bb.js pedersenCommit wraps inputs in Fr, effectively reducing mod Fr.
    // To ensure consistency, we rely on sk and k being < Fr.

    // 1. Generate sk < Fr (safe for bb.js)
    const sk = secretKey !== null ? BigInt(secretKey) : randomField();
    const msg = BigInt(message);

    // 2. Derive pk = sk * G
    // Since sk < Fr, bb.js computes this correctly
    const pk = await grumpkinScalarMulG(sk);

    // 3. Generate nonce k < Fr (safe for bb.js)
    const k = randomField();

    // 4. Compute R = k * G
    // Since k < Fr, bb.js computes this correctly
    const R = await grumpkinScalarMulG(k);

    // 5. Compute Challenge e
    const e = poseidon5([R.x, R.y, pk.x, pk.y, msg]);

    // 6. Compute s = k + e * sk (mod Fq)
    // s can be > Fr, which is fine because the circuit handles 256-bit s
    const s = (k + e * sk) % GRUMPKIN_SCALAR_MODULUS;

    // Check math locally
    // We can't check s*G vs R+e*pk without point mul.

    if (process.env.DEBUG_SCHNORR_BN254 === '1') {
        console.log('--- DEBUG Schnorr JS ---');
        console.log(`sk: 0x${sk.toString(16)}`);
        console.log(`k: 0x${k.toString(16)}`);
        console.log(`pk.x: 0x${pk.x.toString(16)}`);
        console.log(`R.x: 0x${R.x.toString(16)}`);
        console.log(`msg: 0x${msg.toString(16)}`);
        console.log(`e: 0x${e.toString(16)}`);
        console.log(`s: 0x${s.toString(16)}`);
        console.log('------------------------');
    }

    // Split s into 128-bit limbs for Noir
    const { lo: s_lo, hi: s_hi } = splitScalar(s);

    return {
        signature: {
            r: { x: R.x, y: R.y },
            s: s,
            s_lo: s_lo,
            s_hi: s_hi,
        },
        publicKey: { x: pk.x, y: pk.y },
        secretKey: sk,
    };
}

/**
 * Generate a Grumpkin keypair
 */
export async function generateBn254Keypair() {
    const sk = randomField();
    const pk = await grumpkinScalarMulG(sk);
    return {
        secretKey: sk,
        publicKey: { x: pk.x, y: pk.y },
    };
}

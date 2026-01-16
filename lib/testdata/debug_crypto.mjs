import { etc, sign, utils } from '@noble/secp256k1';
import { hmac } from '@noble/hashes/hmac';
import { sha256 } from '@noble/hashes/sha256';

console.log('Setting up HMAC-SHA256 sync on etc...');

try {
    // Correct v2 API: etc.hmacSha256Sync
    etc.hmacSha256Sync = (key, ...msgs) => {
        return hmac(sha256, key, etc.concatBytes(...msgs));
    };
    console.log('Success: Set etc.hmacSha256Sync');
} catch (e) {
    console.error('Failed to set hmacSha256Sync:', e);
}

console.log('Sign test...');
// Correct v2 API: utils.randomPrivateKey
const priv = utils.randomPrivateKey();
const msg = new Uint8Array(32).fill(1);
const sig = sign(msg, priv);
console.log('Sign success:', sig.toCompactRawBytes());

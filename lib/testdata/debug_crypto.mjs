import * as secp from '@noble/secp256k1';
import { hmac } from '@noble/hashes/hmac';
import { sha256 } from '@noble/hashes/sha256';

console.log('secp keys:', Object.keys(secp));
console.log('secp.utils keys:', Object.keys(secp.utils));
console.log('Initial hmacSha256Sync:', secp.utils.hmacSha256Sync);

try {
    secp.utils.hmacSha256Sync = (key, ...msgs) => {
        console.log('HMAC called');
        return hmac(sha256, key, secp.utils.concatBytes(...msgs));
    };
    console.log('Set hmacSha256Sync');
} catch (e) {
    console.error('Failed to set hmacSha256Sync:', e);
}

console.log('Sign test...');
const priv = secp.utils.randomPrivateKey();
const msg = new Uint8Array(32).fill(1);
const sig = secp.sign(msg, priv);
console.log('Sign success:', sig);

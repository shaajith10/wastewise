const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');

const JWT_SECRET = process.env.JWT_SECRET || 'dev_secret_replace_in_production';
const EXPIRY = parseInt(process.env.QR_TOKEN_EXPIRY_SECONDS || '86400', 10);

/**
 * Generate a signed QR token for a pickup request.
 * @param {string} requestId  - The pickup request document ID
 * @param {string} citizenUid - Owner citizen's UID
 * @returns {string} JWT string to be encoded in the QR image
 */
function generateQrToken(requestId, citizenUid) {
  const payload = {
    requestId,
    citizenUid,
    nonce: uuidv4(), // ensure uniqueness per generation
  };
  return jwt.sign(payload, JWT_SECRET, { expiresIn: EXPIRY });
}

/**
 * Verify and decode a QR token.
 * @param {string} token
 * @returns {{ requestId: string, citizenUid: string, nonce: string }}
 */
function verifyQrToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (err) {
    throw new Error(`Invalid or expired QR token: ${err.message}`);
  }
}

module.exports = { generateQrToken, verifyQrToken };

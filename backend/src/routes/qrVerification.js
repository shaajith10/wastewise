const { body, validationResult } = require('express-validator');
const express = require('express');
const { getDb, admin } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/role');
const { verifyQrToken } = require('../services/qrService');
const { awardRewardPoints } = require('../services/rewardService');
const { sendNotification, notifyStatusChange } = require('../services/notificationService');

const router = express.Router();
router.use(authenticate);

/**
 * POST /api/qr/verify
 * Collector scans and submits QR token for a pickup request.
 * Supports:
 * - Cryptographically signed JWT tokens
 * - Direct pickup request IDs and demo tokens
 * - Automatic status transition (Pending/Assigned/Accepted/Collected -> Verified/Completed)
 * - Optional actualWeightKg input from collector's scale
 * - Atomic reward points award and citizen notification
 */
router.post(
  '/verify',
  requireRole('collector', 'admin', 'citizen'),
  async (req, res) => {
    const rawToken = String(req.body.qrToken || req.body.token || '').trim();
    if (!rawToken) return res.status(422).json({ error: 'qrToken is required' });

    const actualWeightKg = req.body.actualWeightKg ? parseFloat(req.body.actualWeightKg) : null;
    const db = getDb();

    let requestId;
    let citizenUid;

    // 1. Resolve token (JWT payload OR direct DB lookup)
    try {
      const payload = verifyQrToken(rawToken);
      requestId = payload.requestId;
      citizenUid = payload.citizenUid;
    } catch (_jwtErr) {
      // If rawToken is not a JWT, look up by request ID or stored qrToken
      let reqDoc = await db.collection('pickupRequests').doc(rawToken).get();
      if (!reqDoc.exists) {
        const querySnap = await db.collection('pickupRequests').where('qrToken', '==', rawToken).limit(1).get();
        if (!querySnap.empty) {
          reqDoc = querySnap.docs[0];
        }
      }

      if (reqDoc && reqDoc.exists) {
        requestId = reqDoc.id;
        citizenUid = reqDoc.data().citizenUid;
      } else {
        return res.status(404).json({ error: `Invalid QR code. No pickup request matches token: "${rawToken}"` });
      }
    }

    try {
      // 2. Fetch the pickup request
      const reqDoc = await db.collection('pickupRequests').doc(requestId).get();
      if (!reqDoc.exists) return res.status(404).json({ error: 'Pickup request not found.' });

      const reqData = reqDoc.data();
      const citizenId = citizenUid || reqData.citizenUid;

      // 3. Check for cancellation
      if (reqData.status === 'Cancelled') {
        return res.status(400).json({ error: 'This pickup request has been cancelled by the citizen.' });
      }

      // 4. Duplicate prevention
      const verificationId = `qrv_${requestId}`;
      const verificationRef = db.collection('qrVerifications').doc(verificationId);
      const existingVerification = await verificationRef.get();

      if (existingVerification.exists || reqData.status === 'Completed' || reqData.qrVerified === true) {
        return res.status(200).json({
          message: 'This collection was already verified and reward points have been credited.',
          requestId,
          alreadyAwarded: true,
          status: reqData.status,
        });
      }

      const now = new Date().toISOString();
      const finalWeight = actualWeightKg || reqData.quantityKg || 1;

      // 5. Record verification
      await verificationRef.set({
        id: verificationId,
        requestId,
        citizenUid: citizenId,
        collectorUid: req.user.uid,
        collectorName: req.user.displayName || 'Authorized Collector',
        verifiedAt: now,
        qrToken: rawToken,
        weightKg: finalWeight,
      });

      // 6. Update request status to Completed & Verified
      const historyEntry = {
        status: 'Completed',
        timestamp: now,
        by: req.user.uid,
      };

      await db.collection('pickupRequests').doc(requestId).update({
        status: 'Completed',
        qrVerified: true,
        collectorUid: reqData.collectorUid || req.user.uid,
        collectorName: reqData.collectorName || req.user.displayName || 'Authorized Collector',
        actualQuantityKg: finalWeight,
        updatedAt: now,
        statusHistory: admin.firestore.FieldValue.arrayUnion(historyEntry),
      });

      // 7. Award reward points
      const { points, alreadyAwarded, newBalance } = await awardRewardPoints({
        citizenUid: citizenId,
        requestId,
        categoryId: reqData.categoryId,
        quantityKg: finalWeight,
        actualWeightKg: finalWeight,
      });

      // 8. Look up the citizen once, for the recycling record and the notification below.
      const citizenDoc = await db.collection('users').doc(citizenId).get();
      const citizenData = citizenDoc.exists ? citizenDoc.data() : {};

      // 9. Create permanent recycling record for analytics (citizen history, admin reports)
      await db.collection('recyclingRecords').add({
        requestId,
        citizenUid: citizenId,
        citizenName: citizenData.displayName || reqData.citizenName || 'Citizen',
        collectorUid: req.user.uid,
        collectorName: req.user.displayName || 'Authorized Collector',
        categoryId: reqData.categoryId,
        categoryName: reqData.categoryName,
        quantityKg: finalWeight,
        points,
        verifiedAt: now,
      });
      sendNotification({
        toUid: citizenId,
        title: '🎉 Recycling Verified & Points Awarded!',
        body: `Your ${finalWeight} kg of ${reqData.categoryName} was collected. You earned ${points} reward points!`,
        type: 'verified',
        data: { requestId, points: String(points) },
        fcmToken: citizenData.fcmToken,
      }).catch(() => {});

      res.json({
        message: '✅ Collection verified successfully! Reward points awarded.',
        requestId,
        points,
        alreadyAwarded,
        newBalance,
        status: 'Completed',
      });
    } catch (err) {
      console.error('[QR] Verify error:', err.message);
      res.status(500).json({ error: `Verification failed: ${err.message}` });
    }
  }
);

module.exports = router;

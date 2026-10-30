const { getDb, admin } = require('../config/firebase');

/**
 * Write an in-app notification and optionally send FCM push.
 * @param {object} opts
 * @param {string} opts.toUid        - Recipient user UID
 * @param {string} opts.title        - Notification title
 * @param {string} opts.body         - Notification body
 * @param {string} [opts.type]       - e.g. 'request_submitted', 'status_updated', 'verified'
 * @param {object} [opts.data]       - Extra metadata (requestId, etc.)
 * @param {string} [opts.fcmToken]   - FCM device token for push
 */
async function sendNotification({ toUid, title, body, type = 'general', data = {}, fcmToken }) {
  let db;
  try { db = getDb(); } catch (_) { return; }

  // 1. Write in-app notification to Firestore
  try {
    await db.collection('notifications').add({
      toUid,
      title,
      body,
      type,
      data,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.error('[Notification] Failed to write in-app notification:', err.message);
  }

  // 2. Send FCM push if token is available
  if (fcmToken) {
    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
        data: Object.fromEntries(
          Object.entries({ type, ...data }).map(([k, v]) => [k, String(v)])
        ),
      });
    } catch (err) {
      // FCM failure is non-fatal — in-app notification already written
      console.warn('[Notification] FCM push failed (non-fatal):', err.message);
    }
  }
}

/**
 * Helper: notify citizen + admin in one call.
 */
async function notifyStatusChange({ requestId, citizenUid, citizenFcmToken, newStatus }) {
  const messages = {
    Assigned: 'Your pickup request has been assigned to a collector.',
    Accepted: 'Your collector has accepted your pickup request.',
    Collected: 'Your waste has been collected! Awaiting verification.',
    Verified: 'Collection verified! Reward points have been credited.',
    Completed: 'Your pickup request has been completed.',
    Cancelled: 'Your pickup request has been cancelled.',
  };

  const body = messages[newStatus] || `Request status updated to: ${newStatus}`;

  await sendNotification({
    toUid: citizenUid,
    title: 'Pickup Request Update',
    body,
    type: 'status_updated',
    data: { requestId, newStatus },
    fcmToken: citizenFcmToken,
  });
}

module.exports = { sendNotification, notifyStatusChange };

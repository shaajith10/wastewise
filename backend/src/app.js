require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');
const fs = require('fs');
const { initFirebase } = require('./config/firebase');

// Initialize Firebase Admin SDK
initFirebase();

const app = express();

// Disable ETags completely to prevent 304 Not Modified empty body responses on API calls
app.set('etag', false);

// Behind the HTTPS tunnel every request arrives from the proxy; trust its
// X-Forwarded-For so rate limiting is per real client, not shared by everyone.
app.set('trust proxy', 1);

// ─── Security & Middleware ────────────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Cache-Control', 'Pragma', 'If-None-Match'],
}));

// Anti-cache headers for all /api endpoints
app.use('/api', (req, res, next) => {
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.setHeader('Surrogate-Control', 'no-store');
  next();
});

app.use(express.json({ limit: '2mb' }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// ─── Rate Limiting ────────────────────────────────────────────────────────────
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 300,
  message: { error: 'Too many requests, please try again later.' },
});
const strictLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  message: { error: 'Too many requests for this endpoint.' },
});
app.use('/api/', apiLimiter);
app.use('/api/qr/verify', strictLimiter);

// ─── API Routes ───────────────────────────────────────────────────────────────
app.use('/api/auth', require('./routes/auth'));
app.use('/api/users', require('./routes/users'));
app.use('/api/pickup-requests', require('./routes/pickupRequests'));
app.use('/api/categories', require('./routes/categories'));
app.use('/api/collectors', require('./routes/collectors'));
app.use('/api/qr', require('./routes/qrVerification'));
app.use('/api/recycling-records', require('./routes/recyclingRecords'));
app.use('/api/rewards', require('./routes/rewards'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/admin', require('./routes/admin'));

// ─── Health Check ─────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok', env: process.env.NODE_ENV }));

// ─── Serve Flutter Web Frontend ───────────────────────────────────────────────
const webBuildPath = path.join(__dirname, '../../waste_mgmt_app/build/web');
if (fs.existsSync(webBuildPath)) {
  app.use(express.static(webBuildPath, {
    etag: true,
    lastModified: true,
    setHeaders: (res, filePath) => {
      if (filePath.endsWith('index.html')) {
        // The shell page must never be cached, so a rebuild is always picked up.
        res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');
      } else {
        // Build assets (main.dart.js is ~3MB) can be cached by the browser, but must
        // be revalidated with the server on each load (a cheap 304 if unchanged).
        // Without this, every load re-downloads the whole bundle, which times out
        // over slow connections (e.g. the HTTPS tunnel on a mobile hotspot).
        res.setHeader('Cache-Control', 'no-cache');
      }
    }
  }));
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api') || req.path === '/health') return next();
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.sendFile(path.join(webBuildPath, 'index.html'));
  });
}

// ─── 404 ──────────────────────────────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ error: 'Endpoint not found' }));

// ─── Global Error Handler ─────────────────────────────────────────────────────
// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error('[Unhandled Error]', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

module.exports = app;

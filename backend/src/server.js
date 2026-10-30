const { exec } = require('child_process');
const app = require('./app');
const { ensureDefaultAccounts, DEFAULT_ACCOUNTS } = require('./services/authService');

const PORT = parseInt(process.env.PORT || '3000', 10);

ensureDefaultAccounts()
  .then(() => {
    console.log('[Auth] Default logins:');
    for (const a of DEFAULT_ACCOUNTS) console.log(`        ${a.role.padEnd(9)} ${a.email} / ${a.password}`);
  })
  .catch((err) => console.error('[Auth] Could not create default accounts:', err.message));

const server = app.listen(PORT, () => {
  console.log(`[Server] Waste Management API running on port ${PORT} (${process.env.NODE_ENV || 'development'})`);
  console.log(`[Server] Health check: http://localhost:${PORT}/health`);
  console.log(`[Server] Web App: http://localhost:${PORT}`);

  // Only auto-open a browser for local development runs (run_app.bat). On a
  // hosted server (NODE_ENV=production, e.g. Render) there's no desktop to open.
  if (process.env.NODE_ENV === 'development' && process.env.NO_AUTO_OPEN !== 'true') {
    const cmd = process.platform === 'win32' ? `start http://localhost:${PORT}` : `open http://localhost:${PORT}`;
    exec(cmd, () => {});
  }
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\n[ERROR] Port ${PORT} is already in use by another process.`);
    console.error(`Please run run_app.bat again (it will auto-clear port ${PORT}) or close existing terminal windows.\n`);
  } else {
    console.error('[Server Error]', err);
  }
  process.exit(1);
});

process.on('SIGTERM', () => {
  console.log('[Server] SIGTERM received — shutting down gracefully');
  server.close(() => process.exit(0));
});

process.on('unhandledRejection', (reason) => {
  console.error('[Server] Unhandled rejection:', reason);
});

module.exports = server;

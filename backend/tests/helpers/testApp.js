const express = require('express');
const { errorHandler } = require('../../src/middleware/errorHandler');

/**
 * Build a minimal Express app that mounts a single router with the real
 * JSON body parser and the real central error handler — but WITHOUT the
 * socket server, cron jobs, rate limiters, or a live TCP listener that
 * server.js would otherwise start on import.
 *
 * Auth is expected to be mocked at the module level in the test file so
 * `req.user` is injected without a real JWT/DB round-trip.
 */
function buildApp(mountPath, router) {
  const app = express();
  app.use(express.json());
  app.use(mountPath, router);
  app.use(errorHandler);
  return app;
}

module.exports = { buildApp };

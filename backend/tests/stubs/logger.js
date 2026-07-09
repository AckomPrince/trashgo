// Silent logger stub — mapped in place of src/config/logger.js during tests
// so Winston never writes to the console and never touches transports.
module.exports = {
  info: () => {},
  warn: () => {},
  error: () => {},
  debug: () => {},
};

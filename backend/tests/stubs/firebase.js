// Firebase Admin stub — mapped in place of src/config/firebase.js during tests
// so the real firebase-admin SDK is never initialised (no credentials needed).
module.exports = {
  messaging: () => ({
    send: async () => 'stub-message-id',
  }),
  apps: [],
};

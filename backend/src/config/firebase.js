const admin = require('firebase-admin');
const logger = require('./logger');

let firebaseApp;

if (!admin.apps.length) {
  try {
    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert({
        projectId:    process.env.FIREBASE_PROJECT_ID,
        privateKey:   process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        clientEmail:  process.env.FIREBASE_CLIENT_EMAIL,
      }),
    });
    logger.info('Firebase Admin SDK initialised');
  } catch (err) {
    logger.error('Firebase init error:', err.message);
  }
} else {
  firebaseApp = admin.apps[0];
}

module.exports = admin;

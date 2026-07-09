// Global test environment setup — runs before each test file.
// Provides deterministic env vars so signing/verification logic is testable
// without a real .env or external services.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-access-secret';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';
process.env.JWT_EXPIRES_IN = '7d';
process.env.JWT_REFRESH_EXPIRES_IN = '30d';
process.env.JWT_REFRESH_EXPIRES_DAYS = '30';
process.env.PAYSTACK_SECRET_KEY = 'sk_test_dummy_paystack_key';
process.env.PLATFORM_COMMISSION = '0.20';
process.env.POINTS_PER_PICKUP = '50';
process.env.RECYCLABLE_MULTIPLIER = '1.5';
process.env.MIN_REDEMPTION_POINTS = '500';
process.env.REDEMPTION_RATE = '100';

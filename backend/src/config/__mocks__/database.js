// Manual Jest mock for src/config/database.js.
// Used automatically whenever a test calls jest.mock('../../src/config/database').
// Keeps the real `pg` Pool from ever being constructed or connecting.

const mockClient = {
  query: jest.fn(),
  release: jest.fn(),
};

module.exports = {
  query: jest.fn(),
  getClient: jest.fn(() => Promise.resolve(mockClient)),
  pool: { query: jest.fn(), connect: jest.fn() },
  // exposed so tests can assert on / configure the transaction client
  __mockClient: mockClient,
};

#!/usr/bin/env node
/**
 * Ordered, tracked SQL migration runner.
 *
 *   node scripts/migrate.js            # apply all pending migrations
 *   node scripts/migrate.js --status   # show applied / pending, apply nothing
 *   node scripts/migrate.js --baseline # mark all existing files as applied (no SQL run)
 *
 * Applies every *.sql in src/migrations/ in filename order, once each, inside
 * a transaction, recording success in the schema_migrations table. Safe to
 * re-run: already-applied files are skipped. Designed so any agent can add a
 * new NNN_name.sql file and just run `npm run migrate`.
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const MIGRATIONS_DIR = path.join(__dirname, '..', 'src', 'migrations');
const mode = process.argv[2];

async function main() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        filename    TEXT PRIMARY KEY,
        applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )`);

    const files = fs.readdirSync(MIGRATIONS_DIR)
      .filter((f) => f.endsWith('.sql'))
      .sort();

    const { rows } = await pool.query('SELECT filename FROM schema_migrations');
    const applied = new Set(rows.map((r) => r.filename));
    const pending = files.filter((f) => !applied.has(f));

    if (mode === '--status') {
      console.log('Applied:'); files.filter((f) => applied.has(f)).forEach((f) => console.log('  ✓', f));
      console.log('Pending:'); pending.forEach((f) => console.log('  •', f));
      if (!pending.length) console.log('  (none)');
      return;
    }

    if (mode === '--baseline') {
      for (const f of pending) {
        await pool.query('INSERT INTO schema_migrations (filename) VALUES ($1) ON CONFLICT DO NOTHING', [f]);
        console.log('baselined (not run):', f);
      }
      return;
    }

    if (!pending.length) { console.log('✅ No pending migrations.'); return; }

    for (const f of pending) {
      const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, f), 'utf8');
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [f]);
        await client.query('COMMIT');
        console.log('✅ applied:', f);
      } catch (err) {
        await client.query('ROLLBACK');
        console.error(`❌ failed on ${f}: ${err.message}`);
        process.exitCode = 1;
        return;
      } finally {
        client.release();
      }
    }
    console.log('✅ All migrations applied.');
  } finally {
    await pool.end();
  }
}

main().catch((e) => { console.error(e); process.exit(1); });

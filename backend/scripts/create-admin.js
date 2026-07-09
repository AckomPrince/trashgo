#!/usr/bin/env node
/**
 * Create (or reset) a TrashGo admin user.
 *
 * Usage:
 *   node scripts/create-admin.js                         # uses defaults below
 *   node scripts/create-admin.js admin@trashgo.app Secret123! "Admin Name" +233200000000
 *
 * Reads DATABASE_URL from .env. Safe to re-run: if the admin already exists
 * (same email+role) its password is reset instead of erroring.
 */
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

const [, , emailArg, passArg, nameArg, phoneArg] = process.argv;

const email = (emailArg || 'admin@trashgo.app').toLowerCase().trim();
const password = passArg || 'Admin123!';
const fullName = nameArg || 'TrashGo Admin';
const phone = phoneArg || '+233200000000';

(async () => {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  try {
    const hash = await bcrypt.hash(password, 12);
    const { rows } = await pool.query(
      `INSERT INTO users (full_name, email, phone, password_hash, role, is_active)
       VALUES ($1,$2,$3,$4,'admin',TRUE)
       ON CONFLICT (LOWER(email), role)
       DO UPDATE SET password_hash = EXCLUDED.password_hash,
                     full_name     = EXCLUDED.full_name,
                     is_active     = TRUE
       RETURNING id, email, role`,
      [fullName, email, phone, hash]
    );
    console.log('✅ Admin ready:');
    console.log('   id:', rows[0].id);
    console.log('   email:', rows[0].email);
    console.log('   password:', password);
  } catch (err) {
    console.error('❌ Failed to create admin:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
})();

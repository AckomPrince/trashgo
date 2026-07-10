#!/usr/bin/env node
/**
 * End-to-end smoke test against a RUNNING TrashGo backend.
 * Exercises real HTTP + real Postgres (no mocks). Assumes the server is up
 * on $BASE (default http://localhost:8080) and the DB migration has run.
 *
 *   node scripts/smoke-test.js
 *
 * A couple of steps that normally require Paystack are simulated with a
 * direct DB write (marking an order payment_authorized) so the completion /
 * points / earnings path can be verified without hitting Paystack.
 */
require('dotenv').config();
const crypto = require('crypto');
const { Pool } = require('pg');

const BASE = process.env.SMOKE_BASE || 'http://localhost:8080';
const API = `${BASE}/api/v1`;
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

let pass = 0, fail = 0;
const ok = (name, cond, extra = '') => {
  if (cond) { pass++; console.log(`  ✅ ${name}`); }
  else { fail++; console.log(`  ❌ ${name} ${extra}`); }
};

async function req(method, path, { token, body, headers } = {}) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(headers || {}),
    },
    body: body ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined,
  });
  let json = null;
  try { json = await res.json(); } catch { /* no body */ }
  return { status: res.status, body: json };
}

(async () => {
  const ts = Date.now();
  const cust = { full_name: 'Test Customer', email: `cust${ts}@test.io`, phone: `+2335${String(ts).slice(-8)}`, password: 'Passw0rd!' };
  const rider = { full_name: 'Test Rider', email: `rider${ts}@test.io`, phone: `+2336${String(ts).slice(-8)}`, password: 'Passw0rd!', vehicle_type: 'tricycle', vehicle_plate: `GT-${ts % 10000}` };
  const admin = { email: 'admin@trashgo.app', password: 'Admin123!' };

  try {
    console.log('\n── Health ──');
    const h = await fetch(`${BASE}/health`).then(r => r.json());
    ok('GET /health db connected', h.status === 'ok' && h.db === 'connected', JSON.stringify(h));

    console.log('\n── Auth: customer ──');
    let r = await req('POST', '/auth/register/customer', { body: cust });
    ok('register customer 201', r.status === 201, `-> ${r.status} ${JSON.stringify(r.body)}`);
    const custToken = r.body?.token;
    const custRefresh = r.body?.refresh_token;
    ok('customer got token + refresh', !!custToken && !!custRefresh);

    r = await req('POST', '/auth/register/customer', { body: cust });
    ok('duplicate customer -> 409', r.status === 409, `-> ${r.status}`);

    r = await req('GET', '/auth/me', { token: custToken });
    ok('GET /auth/me returns customer', r.status === 200 && r.body?.user?.role === 'customer', `-> ${r.status}`);
    ok('customer wallet present', !!r.body?.user?.wallet, JSON.stringify(r.body?.user?.wallet));

    r = await req('GET', '/auth/me');
    ok('no-token /auth/me -> 401', r.status === 401, `-> ${r.status}`);

    r = await req('POST', '/auth/login', { body: { email: cust.email, password: 'wrong', role: 'customer' } });
    ok('bad password -> 401', r.status === 401, `-> ${r.status}`);

    console.log('\n── Auth: rider (pending) ──');
    r = await req('POST', '/auth/register/rider', { body: rider });
    ok('register rider 201', r.status === 201, `-> ${r.status} ${JSON.stringify(r.body)}`);
    const riderId = r.body?.user?.id;

    r = await req('POST', '/auth/login', { body: { email: rider.email, password: rider.password, role: 'rider' } });
    ok('pending rider login blocked -> 403', r.status === 403, `-> ${r.status} ${JSON.stringify(r.body)}`);

    console.log('\n── Auth: admin + approve rider ──');
    r = await req('POST', '/auth/login', { body: admin });
    ok('admin login 200', r.status === 200 && r.body?.user?.role === 'admin', `-> ${r.status} ${JSON.stringify(r.body)}`);
    const adminToken = r.body?.token;

    r = await req('GET', '/admin/dashboard', { token: adminToken });
    ok('admin dashboard 200', r.status === 200 && r.body?.success, `-> ${r.status}`);

    r = await req('GET', '/admin/riders?status=pending', { token: adminToken });
    ok('admin list pending riders', r.status === 200 && Array.isArray(r.body?.riders), `-> ${r.status}`);

    r = await req('PATCH', `/admin/riders/${riderId}/review`, { token: adminToken, body: { action: 'approved', note: 'looks good' } });
    ok('approve rider 200', r.status === 200 && r.body?.success, `-> ${r.status} ${JSON.stringify(r.body)}`);

    // role guard: customer hitting admin route
    r = await req('GET', '/admin/dashboard', { token: custToken });
    ok('customer -> admin route 403', r.status === 403, `-> ${r.status}`);

    console.log('\n── Auth: rider login after approval ──');
    r = await req('POST', '/auth/login', { body: { email: rider.email, password: rider.password, role: 'rider' } });
    ok('approved rider login 200', r.status === 200, `-> ${r.status} ${JSON.stringify(r.body)}`);
    const riderToken = r.body?.token;

    console.log('\n── Order lifecycle ──');
    r = await req('POST', '/orders', { token: custToken, body: {
      pickup_address: '12 Ring Road, Accra', pickup_lat: 5.6037, pickup_lng: -0.1870,
      waste_type: 'general', waste_description: 'two bags',
    }});
    ok('create order 201', r.status === 201 && r.body?.order?.id, `-> ${r.status} ${JSON.stringify(r.body)}`);
    const orderId = r.body?.order?.id;

    r = await req('POST', '/orders', { token: custToken, body: { pickup_address: 'x', pickup_lat: 5.6, pickup_lng: -0.1 }});
    ok('second active order -> 409', r.status === 409, `-> ${r.status}`);

    r = await req('POST', `/orders/${orderId}/accept`, { token: riderToken });
    ok('rider accept 200', r.status === 200, `-> ${r.status} ${JSON.stringify(r.body)}`);

    // state machine: cannot skip to size_confirmed
    r = await req('PATCH', `/orders/${orderId}/status`, { token: riderToken, body: { status: 'size_confirmed', waste_size: 'medium' } });
    ok('skip transition blocked -> 400', r.status === 400, `-> ${r.status} ${JSON.stringify(r.body)}`);

    r = await req('PATCH', `/orders/${orderId}/status`, { token: riderToken, body: { status: 'rider_en_route' } });
    ok('-> rider_en_route 200', r.status === 200, `-> ${r.status}`);
    r = await req('PATCH', `/orders/${orderId}/status`, { token: riderToken, body: { status: 'rider_arrived' } });
    ok('-> rider_arrived 200', r.status === 200, `-> ${r.status}`);
    r = await req('PATCH', `/orders/${orderId}/status`, { token: riderToken, body: { status: 'size_confirmed', waste_size: 'medium' } });
    ok('-> size_confirmed 200 (price set)', r.status === 200, `-> ${r.status} ${JSON.stringify(r.body)}`);

    r = await req('PATCH', `/orders/${orderId}/approve-price`, { token: custToken });
    ok('customer approve price 200', r.status === 200, `-> ${r.status} ${JSON.stringify(r.body)}`);

    console.log('\n── Payment (simulate authorized) + webhook ──');
    const reference = `TG-SMOKE-${ts}`;
    await pool.query(
      `UPDATE orders SET status='payment_authorized', payment_reference=$1, payment_status='authorized' WHERE id=$2`,
      [reference, orderId]
    );
    ok('order marked payment_authorized (db)', true);

    const secret = process.env.PAYSTACK_SECRET_KEY;
    const payload = { event: 'charge.success', data: { reference } };
    const raw = JSON.stringify(payload);
    const sig = crypto.createHmac('sha512', secret).update(raw).digest('hex');

    r = await req('POST', '/payments/webhook', { body: raw, headers: { 'x-paystack-signature': 'deadbeef' } });
    ok('webhook bad signature -> 400', r.status === 400, `-> ${r.status}`);

    r = await req('POST', '/payments/webhook', { body: raw, headers: { 'x-paystack-signature': sig } });
    ok('webhook valid signature -> 200', r.status === 200, `-> ${r.status} ${JSON.stringify(r.body)}`);

    let dbrow = (await pool.query('SELECT payment_status FROM orders WHERE id=$1', [orderId])).rows[0];
    ok('order payment_status = paid', dbrow.payment_status === 'paid', `-> ${dbrow.payment_status}`);

    // idempotency: resend
    r = await req('POST', '/payments/webhook', { body: raw, headers: { 'x-paystack-signature': sig } });
    ok('webhook idempotent resend -> 200', r.status === 200, `-> ${r.status}`);
    const paidTxns = (await pool.query(`SELECT count(*)::int c FROM points_transactions WHERE order_id=$1`, [orderId])).rows[0].c;
    ok('no double points from resend (<=1 earned txn later)', paidTxns <= 1, `-> ${paidTxns}`);

    console.log('\n── Complete + points/earnings ──');
    r = await req('PATCH', `/orders/${orderId}/start`, { token: riderToken });
    ok('rider start -> in_progress 200', r.status === 200, `-> ${r.status} ${JSON.stringify(r.body)}`);

    r = await req('PATCH', `/orders/${orderId}/complete`, { token: riderToken, body: { completion_photo_url: 'https://cdn/proof.jpg' } });
    ok('rider complete 200', r.status === 200 && r.body?.points_awarded === 70, `-> ${r.status} ${JSON.stringify(r.body)}`);
    ok('rider net earning = 8 (10 - 20%)', r.body?.rider_net_earning === 8, `-> ${r.body?.rider_net_earning}`);

    r = await req('GET', '/rewards/wallet', { token: custToken });
    ok('customer wallet balance = 70', r.status === 200 && Number(r.body?.wallet?.balance) === 70, `-> ${r.status} ${JSON.stringify(r.body)}`);

    r = await req('POST', `/orders/${orderId}/rate`, { token: custToken, body: { rating: 5, review: 'great' } });
    ok('rate completed order 200', r.status === 200, `-> ${r.status} ${JSON.stringify(r.body)}`);

    console.log('\n── S2: Rider ratings & reliability ──');
    r = await req('POST', `/orders/${orderId}/rate-rider`, { token: custToken, body: { rating: 4, review: 'polite and quick' } });
    ok('customer rates rider 200', r.status === 200, `-> ${r.status} ${JSON.stringify(r.body)}`);
    r = await req('POST', `/orders/${orderId}/rate-rider`, { token: custToken, body: { rating: 5 } });
    ok('re-rate rider blocked -> 404', r.status === 404, `-> ${r.status}`);
    r = await req('GET', '/riders/profile', { token: riderToken });
    ok('rider rating_avg = 4', r.status === 200 && Number(r.body?.profile?.rating_avg) === 4, `-> ${r.status} ${JSON.stringify(r.body?.profile?.rating_avg)}`);
    ok('rider rating_count = 1', Number(r.body?.profile?.rating_count) === 1, `-> ${r.body?.profile?.rating_count}`);
    ok('rider accepted_count >= 1', Number(r.body?.profile?.accepted_count) >= 1, `-> ${r.body?.profile?.accepted_count}`);
    ok('rider completed_count >= 1', Number(r.body?.profile?.completed_count) >= 1, `-> ${r.body?.profile?.completed_count}`);
    ok('rider reliability = 1', Number(r.body?.profile?.reliability) === 1, `-> ${r.body?.profile?.reliability}`);

    r = await req('GET', '/riders/earnings', { token: riderToken });
    ok('rider earnings summary', r.status === 200 && Number(r.body?.summary?.total_net) === 8, `-> ${r.status} ${JSON.stringify(r.body?.summary)}`);

    console.log('\n── S1: Rider wallet accrual ──');
    r = await req('GET', '/riders/wallet', { token: riderToken });
    ok('rider wallet balance = 8 (net accrued)', r.status === 200 && Number(r.body?.wallet?.balance) === 8, `-> ${r.status} ${JSON.stringify(r.body?.wallet)}`);
    ok('rider wallet total_earned = 8', Number(r.body?.wallet?.total_earned) === 8, `-> ${r.body?.wallet?.total_earned}`);

    r = await req('PATCH', `/orders/${orderId}/complete`, { token: riderToken });
    ok('second complete -> 404 (already completed)', r.status === 404, `-> ${r.status}`);
    r = await req('GET', '/riders/wallet', { token: riderToken });
    ok('wallet unchanged after double-complete = 8', Number(r.body?.wallet?.balance) === 8, `-> ${r.body?.wallet?.balance}`);

    console.log('\n── S3: Smart dispatch & job feed ──');
    await req('PATCH', '/riders/availability', { token: riderToken, body: { online: true } });
    await req('PATCH', '/riders/location', { token: riderToken, body: { lat: 5.6037, lng: -0.1870 } });

    const cust2 = { full_name: 'Cust Two', email: `cust2${ts}@test.io`, phone: `+2337${String(ts).slice(-8)}`, password: 'Passw0rd!' };
    r = await req('POST', '/auth/register/customer', { body: cust2 });
    const cust2Token = r.body?.token;
    r = await req('POST', '/orders', { token: cust2Token, body: { pickup_address: 'KNUST, Kumasi', pickup_lat: 5.6037, pickup_lng: -0.1870, waste_type: 'general' } });
    const order2 = r.body?.order?.id;
    ok('order2 created + riders notified >= 1', r.status === 201 && r.body?.riders_notified >= 1, `-> ${r.status} notified=${r.body?.riders_notified}`);

    r = await req('GET', '/riders/nearby-orders', { token: riderToken });
    const feedOrder = (r.body?.orders || []).find((o) => o.id === order2);
    ok('nearby feed includes order2 w/ estimated_earning=8', !!feedOrder && Number(feedOrder.estimated_earning) === 8, `-> ${JSON.stringify(feedOrder)}`);

    r = await req('POST', `/orders/${order2}/decline`, { token: riderToken });
    ok('decline offer 200', r.status === 200, `-> ${r.status}`);
    r = await req('GET', '/riders/nearby-orders', { token: riderToken });
    ok('declined order2 excluded from feed', !(r.body?.orders || []).find((o) => o.id === order2), `-> still present?`);
    r = await req('GET', '/riders/profile', { token: riderToken });
    ok('rider declined_count >= 1', Number(r.body?.profile?.declined_count) >= 1, `-> ${r.body?.profile?.declined_count}`);

    console.log('\n── S4: Onboarding & verification ──');
    r = await req('PATCH', '/riders/documents', { token: riderToken, body: { doc_type: 'ghana_card_url', url: 'https://cdn/ghana-card.jpg', ghana_card_number: 'GHA-000111222-3' } });
    ok('upload ghana card 200', r.status === 200, `-> ${r.status}`);
    r = await req('PATCH', '/riders/documents', { token: riderToken, body: { doc_type: 'vehicle_photo_url', url: 'https://cdn/tricycle.jpg' } });
    ok('upload vehicle photo 200', r.status === 200, `-> ${r.status}`);
    r = await req('PATCH', '/riders/documents', { token: riderToken, body: { doc_type: 'license_url', url: 'https://cdn/license.jpg' } });
    ok('upload license 200', r.status === 200, `-> ${r.status}`);
    r = await req('PATCH', '/riders/documents', { token: riderToken, body: { doc_type: 'passport_url', url: 'x' } });
    ok('invalid doc_type -> 400', r.status === 400, `-> ${r.status}`);
    r = await req('GET', '/riders/onboarding', { token: riderToken });
    ok('onboarding complete = true', r.status === 200 && r.body?.onboarding?.complete === true, `-> ${r.status} ${JSON.stringify(r.body?.onboarding?.next_step)}`);
    r = await req('GET', '/admin/riders?status=approved', { token: adminToken });
    const rprof = (r.body?.riders || []).find((x) => x.id === riderId);
    ok('admin riders list exposes ghana_card_url', !!rprof && !!rprof.ghana_card_url, `-> ${JSON.stringify(rprof?.ghana_card_url)}`);

    console.log('\n── S5: Job execution polish ──');
    r = await req('GET', `/orders/${orderId}`, { token: custToken });
    ok('completed order returns completion_photo_url', r.status === 200 && r.body?.order?.completion_photo_url === 'https://cdn/proof.jpg', `-> ${r.status} ${JSON.stringify(r.body?.order?.completion_photo_url)}`);
    ok('completed order has maps_link', !!r.body?.order?.maps_link, `-> ${r.body?.order?.maps_link}`);
    ok('completed order masks rider phone', typeof r.body?.order?.rider_phone === 'string' && r.body.order.rider_phone.includes('*'), `-> ${r.body?.order?.rider_phone}`);

    r = await req('GET', `/orders/${order2}`, { token: cust2Token });
    ok('active order exposes unmasked customer phone', r.status === 200 && typeof r.body?.order?.customer_phone === 'string' && !r.body.order.customer_phone.includes('*'), `-> ${r.body?.order?.customer_phone}`);
    ok('active order has maps_link', !!r.body?.order?.maps_link, `-> ${r.body?.order?.maps_link}`);

    console.log('\n── S6: Engagement & safety ──');
    r = await req('GET', '/riders/incentives', { token: riderToken });
    ok('incentives list returned (>=2 seeded)', r.status === 200 && Array.isArray(r.body?.incentives) && r.body.incentives.length >= 2, `-> ${r.status} n=${r.body?.incentives?.length}`);
    ok('every incentive has numeric progress', (r.body?.incentives || []).every((i) => typeof i.progress === 'number'), `-> ${JSON.stringify((r.body?.incentives || []).map((i) => i.progress))}`);
    r = await req('POST', '/riders/sos', { token: riderToken, body: { lat: 5.6037, lng: -0.1870, note: 'flat tyre' } });
    ok('sos logged 201', r.status === 201 && !!r.body?.sos_id, `-> ${r.status} ${JSON.stringify(r.body)}`);

    console.log('\n── P: Payments — rider payouts ──');
    r = await req('POST', '/riders/payout-recipients', { token: riderToken, body: { type: 'mobile_money', provider: 'MTN', account_number: '0241234602', account_name: 'Test Rider', is_default: true } });
    ok('save payout recipient 201', r.status === 201 && !!r.body?.recipient?.id, `-> ${r.status} ${JSON.stringify(r.body)}`);
    r = await req('GET', '/riders/payout-recipients', { token: riderToken });
    ok('list recipients >= 1', r.status === 200 && (r.body?.recipients || []).length >= 1, `-> ${r.status}`);

    r = await req('POST', '/riders/payout', { token: riderToken, body: { amount: 5 } });
    ok('withdraw 5 -> processing 201', r.status === 201 && r.body?.payout?.status === 'processing', `-> ${r.status} ${JSON.stringify(r.body)}`);
    const transferCode = r.body?.payout?.paystack_transfer_code;

    r = await req('GET', '/riders/wallet', { token: riderToken });
    ok('wallet debited to 3 after payout', Number(r.body?.wallet?.balance) === 3, `-> ${r.body?.wallet?.balance}`);
    ok('wallet total_withdrawn = 5', Number(r.body?.wallet?.total_withdrawn) === 5, `-> ${r.body?.wallet?.total_withdrawn}`);

    r = await req('POST', '/riders/payout', { token: riderToken, body: { amount: 1 } });
    ok('withdraw below min -> 400', r.status === 400, `-> ${r.status}`);

    const twBody = JSON.stringify({ event: 'transfer.success', data: { transfer_code: transferCode } });
    const twSig = crypto.createHmac('sha512', secret).update(twBody).digest('hex');
    r = await req('POST', '/payments/transfer-webhook', { body: twBody, headers: { 'x-paystack-signature': 'bad' } });
    ok('transfer webhook bad sig -> 400', r.status === 400, `-> ${r.status}`);
    r = await req('POST', '/payments/transfer-webhook', { body: twBody, headers: { 'x-paystack-signature': twSig } });
    ok('transfer webhook success -> 200', r.status === 200, `-> ${r.status}`);
    r = await req('GET', '/riders/payouts', { token: riderToken });
    const po = (r.body?.payouts || []).find((p) => p.paystack_transfer_code === transferCode);
    ok('payout settled to paid', !!po && po.status === 'paid', `-> ${JSON.stringify(po?.status)}`);
    r = await req('POST', '/payments/transfer-webhook', { body: twBody, headers: { 'x-paystack-signature': twSig } });
    ok('transfer webhook idempotent resend -> 200', r.status === 200, `-> ${r.status}`);
    r = await req('GET', '/riders/wallet', { token: riderToken });
    ok('wallet unchanged after idempotent resend = 3', Number(r.body?.wallet?.balance) === 3, `-> ${r.body?.wallet?.balance}`);

    console.log('\n── Refresh token rotation + logout ──');
    r = await req('POST', '/auth/refresh', { body: { refresh_token: custRefresh } });
    ok('refresh rotates token 200', r.status === 200 && r.body?.token && r.body?.refresh_token !== custRefresh, `-> ${r.status}`);
    const newRefresh = r.body?.refresh_token;

    r = await req('POST', '/auth/refresh', { body: { refresh_token: custRefresh } });
    ok('old refresh reuse rejected -> 401', r.status === 401, `-> ${r.status}`);

    r = await req('POST', '/auth/logout', { body: { refresh_token: newRefresh } });
    ok('logout 200', r.status === 200, `-> ${r.status}`);
    r = await req('POST', '/auth/refresh', { body: { refresh_token: newRefresh } });
    ok('refresh after logout -> 401', r.status === 401, `-> ${r.status}`);

    console.log('\n── Admin analytics/pricing ──');
    r = await req('GET', '/admin/analytics?period=30', { token: adminToken });
    ok('analytics 200', r.status === 200 && Array.isArray(r.body?.daily_trend), `-> ${r.status}`);
    r = await req('GET', '/admin/pricing', { token: adminToken });
    ok('pricing 200 (15 rows)', r.status === 200 && r.body?.pricing?.length === 15, `-> ${r.status} len=${r.body?.pricing?.length}`);
    r = await req('PATCH', '/admin/pricing', { token: adminToken, body: { waste_size: 'large', waste_type: 'bulky', price: 40 } });
    ok('update pricing 200', r.status === 200, `-> ${r.status}`);

  } catch (e) {
    console.error('\n💥 Smoke test crashed:', e);
    fail++;
  } finally {
    await pool.end();
  }

  console.log(`\n══════════ RESULT: ${pass} passed, ${fail} failed ══════════`);
  process.exit(fail ? 1 : 0);
})();

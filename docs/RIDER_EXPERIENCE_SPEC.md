# TrashGo — Rider Experience & Payments Spec

Status: ACTIVE · Owner: engineering · Last updated: 2026-07-09

This is a **living spec**. It is the single source of truth for the Rider
Experience initiative and the Payments phase that follows it. Every agent or
contributor working on this initiative MUST keep the Progress Tracker below in
sync with reality (see "Working conventions").

---

## 1. Why this exists (the goal)

TrashGo is an on-demand waste-pickup marketplace for Ghana — "Uber for waste".
Households/businesses request pickups; nearby riders accept, collect, and get
paid cashless (Paystack + MTN MoMo); customers earn recycling reward points.

A marketplace dies from **supply starvation**, not demand. The rider is the
supply side and the keystone of the business: if riders can't get jobs, build
reputation, see their money, and (eventually) withdraw it instantly to MoMo,
they leave — and the app is empty when a customer requests. So we build the
**entire rider experience first**, then wire payments last.

## 2. Sequencing decision (do not reorder without sign-off)

1. Build the full rider experience (Epics S1–S6).
2. Wire payouts **last** (Epic P). Payments must be **flexible, quick, and
   seamless** (MoMo + bank, instant transfer, saved recipient, one tap).

### Architectural guardrail (the one rule)
Even though payouts ship last, the **rider wallet / earnings ledger is built in
S1** and every completed job accrues a running balance from day one. Payments
then become a thin **payout adapter over an existing balance**, never a
refactor. Riders SEE their money grow the whole time (half the retention value
before withdrawal even exists).

## 3. Working conventions (for humans and agents)

- **State lives here.** Update the Progress Tracker (§4) whenever a story
  changes state. Allowed states: `TODO`, `IN PROGRESS`, `IN REVIEW`, `DONE`,
  `BLOCKED`.
- **One issue per epic** (see §4 for links). Sub-tasks are the checklists inside
  each epic in §5. Check them off as you land them.
- **Branch/commit:** work on `feat/rider-experience` (or a child branch per
  epic). Conventional commits: `feat(rider): ...`, `feat(payments): ...`,
  `test(rider): ...`. Reference the issue: `Refs #N` (or `Closes #N` when an
  epic is fully done).
- **Migrations:** add a new `src/migrations/NNN_name.sql` file (never edit an
  applied one). Apply with `npm run migrate`; inspect with `npm run
  migrate:status`. The runner tracks applied files in `schema_migrations`.
- **Definition of done for every story:** code + a new migration (if schema
  changes) + Jest unit tests (DB mocked) + the story's checks added to
  `scripts/smoke-test.js` (live end-to-end) + this spec updated + issue box
  checked. `npm test` and `node scripts/smoke-test.js` must be green.
- **Response shape:** all endpoints return `{ success: boolean, ...data }`.
- **Money:** GHS. Commission via `PLATFORM_COMMISSION` (default 0.20). Store
  monetary values as DECIMAL(10,2); points as INTEGER.

## 4. Progress Tracker (KEEP CURRENT)

| Epic | Title | Issue | State | Notes |
|------|-------|-------|-------|-------|
| — | Rider Experience → Payments (tracking) | #9 | IN PROGRESS | Epic |
| S1 | Rider Wallet & Earnings Ledger | #2 | DONE | Ledger + accrual + GET /riders/wallet. 47/47 smoke |
| S2 | Rider Ratings & Reliability | #3 | DONE | rate-rider + avg + counters + reliability. 54/54 smoke |
| S3 | Smart Dispatch & Job Feed | #4 | IN PROGRESS | Depends on S1, S2 |
| S4 | Rider Onboarding & Verification | #5 | TODO | Ghana Card + vehicle photos |
| S5 | Job Execution Polish | #6 | TODO | Proof photo, contact, nav |
| S6 | Engagement & Safety | #7 | TODO | Streaks/incentives, SOS |
| P  | Payments — Payouts to MoMo/Bank | #8 | TODO | LAST. Depends on S1. Flexible/quick/seamless |

Legend: TODO · IN PROGRESS · IN REVIEW · DONE · BLOCKED

## 5. Epics & user stories

Each epic lists user stories (As a … I want … so that …), acceptance criteria
(AC), technical notes, and dependencies. Personas: **Rider** (supply),
**Customer** (demand), **Admin** (ops), **System**.

---

### S1 — Rider Wallet & Earnings Ledger  `[anchor]`

**Goal:** every completed job credits a rider's running balance; the rider sees
per-job, daily, and lifetime earnings. No withdrawals yet.

Stories
- As a **Rider**, I want each completed pickup to add my net earning to my
  wallet balance, so that I always know what I've made.
- As a **Rider**, I want an earnings dashboard (today / this week / all-time +
  recent jobs), so that I can track my income.
- As a **System**, I want wallet credit to be atomic with order completion, so
  that a crash never loses or double-counts earnings.

Acceptance criteria
- [x] New table `rider_wallets(user_id PK, balance, total_earned, total_withdrawn, currency, updated_at)`.
- [x] `orderController.completeOrder` credits the rider wallet **inside the same
      transaction** as the `rider_earnings` insert (idempotent on `order_id`).
- [x] `GET /api/v1/riders/wallet` → `{ success, wallet }`.
- [x] `GET /api/v1/riders/earnings?period=today|week|month|all` returns summary
      (jobs, gross, net, commission) + recent earnings (existing, verified).
- [x] Unit tests: accrual math, idempotency, transaction rollback.
- [x] Smoke checks: complete an order → wallet balance == net; second complete
      is a no-op.

Technical notes
- Reuse the `db.getClient()` BEGIN/COMMIT/ROLLBACK pattern already in
  `completeOrder`. Upsert wallet like `points_wallets`.
- Ledger truth = `rider_earnings` rows; `rider_wallets.balance` is the fast
  aggregate. Payout (Epic P) will debit `balance` + `total_withdrawn`.

Depends on: none. **Blocks: P (payments).**

---

### S2 — Rider Ratings & Reliability

**Goal:** customers rate riders; riders accrue a rating and a reliability score
used later by dispatch (S3).

Stories
- As a **Customer**, I want to rate the rider after a completed pickup, so that
  good riders are recognized.
- As a **Rider**, I want to see my average rating and completed-job count, so I
  know my standing.
- As **System/Admin**, I want acceptance and cancellation counts per rider, so
  reliability can be measured.

Acceptance criteria
- [x] Migration: `orders.rider_rating SMALLINT CHECK (1..5)`, `orders.rider_review TEXT`;
      `rider_profiles.rating_avg`, `rating_count`, `accepted_count`,
      `cancelled_count`, `completed_count`.
- [x] `POST /api/v1/orders/:id/rate-rider` (customer, completed order) updates
      the order and recomputes the rider aggregate atomically.
- [x] Rider profile / `GET /riders/profile` returns rating + reliability fields.
- [x] Counters updated: `accepted_count` on accept, `completed_count` on
      complete. (`cancelled_count` column reserved — wired when a rider-cancel
      endpoint lands.)
- [x] Unit + smoke tests (rate rider → avg reflects it; bad rating rejected).

Technical notes
- Recompute `rating_avg = ((rating_avg*rating_count)+new)/(rating_count+1)`.
- `reliability = completed / max(accepted,1)` computed on read (not stored).

Depends on: none. Feeds S3.

---

### S3 — Smart Dispatch & Job Feed

**Goal:** riders get a richer, fairer job feed; offers can be declined/expire;
dispatch considers proximity + rating, not just who taps first.

Stories
- As a **Rider**, I want each job offer to show distance and estimated earning,
  so I can decide quickly.
- As a **Rider**, I want to decline an offer without penalty and have it expire
  if I don't respond, so I'm not locked to jobs I can't take.
- As the **System**, I want to prioritize nearby, higher-rated, reliable riders
  when broadcasting, so pickups are fulfilled faster.

Acceptance criteria
- [ ] `GET /riders/nearby-orders` includes `estimated_earning` (price − commission)
      and `distance_km` per order.
- [ ] `matchingService` ordering: distance first, tie-broken by rider rating /
      reliability (rider-side ranking retained; order broadcast prioritizes
      better riders).
- [ ] Migration: `order_offers(id, order_id, rider_id, status[offered|accepted|declined|expired], expires_at, created_at)`.
- [ ] `POST /orders/:id/decline` (rider) marks the offer declined + bumps a
      decline counter; offers expire after `OFFER_TTL_SECONDS` (default 60).
- [ ] `acceptOrder` respects an existing offer and closes sibling offers.
- [ ] Unit + smoke tests (feed shows earnings; decline works; expiry logic).

Technical notes
- Keep the bounding-box + Haversine matching. Add ranking after distance.
- Expiry can be lazy (checked on read / accept) to avoid a scheduler for MVP;
  note a future cron to sweep expired offers.

Depends on: S1 (estimated earning uses commission), S2 (rating for ranking).

---

### S4 — Rider Onboarding & Verification

**Goal:** trusted riders. Ghana Card + vehicle photos, verification workflow,
richer admin review.

Stories
- As a **Rider**, I want to submit my Ghana Card and vehicle photos during
  onboarding, so I can be verified and start earning.
- As a **Rider**, I want to see my onboarding progress and what's missing, so I
  know how to get approved.
- As an **Admin**, I want to view submitted documents and approve/reject with a
  reason, so only legitimate riders operate.

Acceptance criteria
- [ ] Migration: `rider_profiles.ghana_card_number`, `ghana_card_url`,
      `vehicle_photo_url`, `onboarding_step`, and reuse `status` enum.
- [ ] `POST /riders/documents` accepts `doc_type` in
      {id_document_url, license_url, ghana_card_url, vehicle_photo_url} + url
      (Cloudinary URL). Validates doc_type.
- [ ] `GET /riders/onboarding` returns completed steps + next required step.
- [ ] Admin `GET /admin/riders` already returns doc URLs; add ghana_card +
      vehicle photo. `reviewRider` unchanged (approve/reject/suspend).
- [ ] Unit + smoke tests.

Technical notes
- Cloudinary upload is client-side (mobile) → server stores the returned URL.
  `multer-storage-cloudinary` is available if we later add direct upload.

Depends on: none.

---

### S5 — Job Execution Polish

**Goal:** smoother, more trustworthy on-the-ground pickups.

Stories
- As a **Customer**, I want proof my waste was collected (a photo), so I trust
  the completion.
- As a **Rider/Customer**, I want each other's masked contact during an active
  job, so we can coordinate arrival.
- As a **Rider**, I want the pickup coordinates handed to my maps app, so I can
  navigate.

Acceptance criteria
- [ ] Migration: `orders.completion_photo_url`.
- [ ] `completeOrder` accepts optional `completion_photo_url` and stores it.
- [ ] `GET /orders/:id` returns a maps deep-link payload (lat/lng already
      present) and masked counterpart phone during active states.
- [ ] Unit + smoke tests.

Technical notes
- Masking: expose phone only while order is active (not completed/cancelled).
- In-app chat is out of scope for MVP; contact = masked phone/call intent.

Depends on: none.

---

### S6 — Engagement & Safety

**Goal:** keep good riders active and safe.

Stories
- As a **Rider**, I want streak/volume incentives, so consistent work pays off.
- As a **Rider**, I want an SOS action during a job, so I can get help fast.
- As the **System**, I want per-zone demand signals, so incentives can target
  under-served areas (foundation only for MVP).

Acceptance criteria
- [ ] Migration: `rider_incentives(id, rider_id, type, criteria, reward_points_or_cash, period, status)`;
      `rider_sos_events(id, rider_id, order_id, lat, lng, created_at)`.
- [ ] `GET /riders/incentives` lists active incentives + progress.
- [ ] `POST /riders/sos` logs an SOS event + notifies admin (notification row).
- [ ] Unit + smoke tests.

Technical notes
- Incentive evaluation can be a daily job later; MVP stores definitions +
  computes progress on read.

Depends on: S1 (earnings/volume), S2 (reliability).

---

### P — Payments: Payouts to MoMo / Bank  `[LAST]`

**Goal:** riders withdraw their wallet balance to MTN MoMo or bank — flexible,
quick, seamless. This is a thin adapter over the S1 wallet.

Stories
- As a **Rider**, I want to withdraw my balance to my MoMo number in a couple
  taps, so I get paid fast.
- As a **Rider**, I want to save my payout method once and reuse it, so payouts
  are one tap next time.
- As a **Rider**, I want to see payout history and status, so I trust the money
  movement.
- As the **System**, I want payouts to reconcile via Paystack transfer webhooks
  and be idempotent, so money is never double-sent.

Acceptance criteria
- [ ] Migration: `payout_recipients(id, rider_id, type[mobile_money|bank], provider, account_number, account_name, paystack_recipient_code, is_default, created_at)`;
      `payouts(id, rider_id, amount, currency, status[pending|processing|paid|failed|reversed], paystack_transfer_code, reference, recipient_id, failure_reason, created_at, settled_at)`.
- [ ] `POST /riders/payout-recipients` → create Paystack transfer recipient
      (MoMo or bank), store code, optionally set default.
- [ ] `POST /riders/payout` → validate balance ≥ amount ≥ MIN_PAYOUT, debit
      wallet + create `payouts(pending)` **atomically**, then initiate Paystack
      transfer; on API failure, roll back the debit.
- [ ] `GET /riders/payouts` + `GET /riders/payout-recipients`.
- [ ] `POST /payments/transfer-webhook` (raw body + HMAC verify, idempotent):
      `transfer.success` → payout `paid`, `transfer.failed|reversed` → refund
      wallet + mark failed.
- [ ] Config: `MIN_PAYOUT` (default 10 GHS), optional daily cap.
- [ ] Unit + smoke tests (recipient create mocked; payout debit/rollback;
      webhook success refund/settle; idempotent resend).

Technical notes — flexible / quick / seamless
- **Flexible:** support `mobile_money` (MTN/Vodafone/AirtelTigo) and `bank`
  recipients; default method for one-tap reuse.
- **Quick:** use Paystack Transfers (instant to MoMo in GH). Wallet balance is
  already maintained (S1) so no batch computation at payout time.
- **Seamless:** saved `payout_recipients` → withdraw needs only an amount;
  reuse the raw-body + HMAC webhook pattern already fixed for charges.
- Reuse `paystackRequest()` in `paymentController`; add transfer endpoints.

Depends on: **S1 (wallet balance is the source of funds).** Should not start
until S1 is DONE.

## 6. Out of scope (for now)
- In-app chat (use masked phone/call intent).
- Automated incentive disbursement engine (definitions + read-time progress
  only).
- KYC provider integration for Ghana Card (store + manual admin verify for MVP).
- `backend/.env` is committed to the repo (secrets in history) — track + rotate
  in a separate security task.

# TrashGo — Agent Guide

> On-Demand Waste Pickup Platform. Full-stack monorepo: Node.js backend · Flutter mobile app · React admin dashboard.
> Target market: Ghana (currency GHS, Paystack payments including MTN MoMo).

---

## 1. Project Structure

```
trashgo/
├── backend/          Node.js + Express API (port 5000)
├── mobile/           Flutter app (iOS + Android)
└── admin/            React admin dashboard (port 3000)
```

---

## 2. Technology Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter 3.x + Dart |
| Mobile State | Riverpod (`flutter_riverpod`) |
| Mobile Navigation | Go Router (`go_router`) |
| Mobile Networking | Dio + Retrofit |
| Backend | Node.js 18 + Express 4 |
| Database | PostgreSQL 14 |
| Real-time | Socket.IO (server + client) |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Payments | Paystack (mobile_money + card) |
| Maps | Google Maps Flutter SDK |
| Location | Geolocator + Geocoding |
| Admin UI | React 18 (Create React App) + Recharts |
| File Storage | Cloudinary |
| Logging | Winston (backend) |

---

## 3. Backend (`backend/`)

### 3.1 Setup

```bash
cd backend
npm install
cp .env.example .env        # fill in credentials
psql $DATABASE_URL -f src/migrations/001_schema.sql
npm run dev                 # nodemon on port 5000
```

### 3.2 Key Scripts

| Script | Command |
|---|---|
| Start | `npm start` |
| Dev | `npm run dev` |
| Migrate | `npm run migrate` |

### 3.3 Environment Variables

Critical vars in `.env`:
- `DATABASE_URL` — PostgreSQL connection string
- `JWT_SECRET`, `JWT_REFRESH_SECRET` — token signing
- `PAYSTACK_SECRET_KEY` — payment processing
- `FIREBASE_PROJECT_ID`, `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL` — FCM
- `CLOUDINARY_*` — photo uploads
- `PLATFORM_COMMISSION=0.20` — 20% rider commission
- `ALLOWED_ORIGINS` — CORS whitelist

### 3.4 Code Organization

```
backend/src/
├── config/           database.js, firebase.js, logger.js
├── controllers/      authController.js, orderController.js, paymentController.js,
│                    riderController.js, adminController.js
├── middleware/       auth.js (JWT + 60s user cache), errorHandler.js
├── routes/           Express routers per domain
├── services/         socketService.js, notificationService.js, matchingService.js,
│                    pricingService.js, rewardsService.js
└── migrations/       001_schema.sql (single migration file)
```

### 3.5 Architecture Patterns

- **Controllers** use `asyncHandler` to catch async errors and forward them to the central `errorHandler`.
- **Auth middleware** verifies JWT, then checks a 60-second in-process LRU cache before hitting the DB. Call `invalidateUserCache(userId)` when suspending or changing roles.
- **Database** uses `pg` Pool. Always use parameterized queries. Transactions use `db.getClient()` with explicit `BEGIN`/`COMMIT`/`ROLLBACK`.
- **Socket.IO** initializes on the same HTTP server. JWT auth happens in `io.use()`. Riders join `rider:{id}`; customers join `user:{id}`. Location tracking uses `tracking_rider:{rider_id}` rooms.
- **Order state machine** enforces valid transitions in `orderController.js` (e.g., `accepted` → `rider_en_route` only).
- **Matching** uses a SQL bounding-box filter first, then exact Haversine on the small candidate set — avoids OOM with thousands of riders.
- **Payments** are processed via Paystack. Webhook handler verifies HMAC-SHA512, is idempotent, and does all DB writes before returning 200.
- **Refresh tokens** are stored as SHA-256 hashes and rotated on every use. Deleting them from `refresh_tokens` revokes the session.
- **Cron job** (`scheduleRewardExpiry()`) runs daily at 02:00 to expire points for inactive accounts (>12 months).

### 3.6 API Routes

```
POST   /api/v1/auth/register/customer
POST   /api/v1/auth/register/rider
POST   /api/v1/auth/login
POST   /api/v1/auth/refresh
POST   /api/v1/auth/logout
GET    /api/v1/auth/me
PATCH  /api/v1/auth/fcm-token

POST   /api/v1/orders
GET    /api/v1/orders
GET    /api/v1/orders/:id
POST   /api/v1/orders/:id/accept
PATCH  /api/v1/orders/:id/status
PATCH  /api/v1/orders/:id/approve-price
PATCH  /api/v1/orders/:id/start
PATCH  /api/v1/orders/:id/complete
PATCH  /api/v1/orders/:id/cancel
POST   /api/v1/orders/:id/rate

PATCH  /api/v1/riders/availability
PATCH  /api/v1/riders/location
GET    /api/v1/riders/earnings
GET    /api/v1/riders/nearby-orders

POST   /api/v1/payments/initialize
POST   /api/v1/payments/webhook
GET    /api/v1/payments/verify/:reference

GET    /api/v1/rewards/wallet
GET    /api/v1/rewards/transactions
POST   /api/v1/rewards/redeem
GET    /api/v1/rewards/redemptions

GET    /api/v1/admin/health
GET    /api/v1/admin/dashboard
GET    /api/v1/admin/riders
POST   /api/v1/admin/riders/:rider_id/review
GET    /api/v1/admin/orders
GET    /api/v1/admin/disputes
POST   /api/v1/admin/disputes/:dispute_id/resolve
GET    /api/v1/admin/analytics
GET    /api/v1/admin/pricing
POST   /api/v1/admin/pricing
```

---

## 4. Mobile (`mobile/`)

### 4.1 Setup

```bash
cd mobile
flutter pub get

# Configure Firebase:
# Android → android/app/google-services.json
# iOS     → ios/Runner/GoogleService-Info.plist

# Run with API URL and Maps key:
flutter run \
  --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:5000/api/v1 \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

### 4.2 Build Commands

```bash
flutter build apk --release      # Android
flutter build ipa --release      # iOS
flutter analyze                  # Static analysis
flutter test                     # Tests (currently minimal)
```

### 4.3 Code Organization

```
mobile/lib/
├── core/
│   ├── config/app_config.dart      # API base URL, keys, constants
│   └── theme/app_theme.dart        # AppColors, AppTheme (Material 3, Poppins font)
├── data/
│   ├── models/                     # UserModel, OrderModel, RiderProfile, PointsWallet
│   └── services/
│       ├── api_service.dart        # Dio singleton with auth interceptor + token refresh
│       └── socket_service.dart     # Socket.IO client wrapper
├── presentation/
│   ├── screens/
│   │   ├── auth/                   # Login, register (customer + rider), role select
│   │   ├── user/                   # Home, request pickup, tracking, price approval,
│   │   │                          # order history, rewards wallet
│   │   ├── rider/                  # Home, active pickup, earnings
│   │   ├── shared/                 # Notifications, profile
│   │   └── splash/                 # SplashScreen
│   └── widgets/                    # CustomButton, OrderStatusChip, etc.
└── providers/
    ├── auth_provider.dart          # AuthNotifier + authProvider (StateNotifierProvider)
    └── order_provider.dart         # ActiveOrderNotifier + order history
```

### 4.4 Architecture Patterns

- **State management**: Riverpod `StateNotifier` classes. `AuthNotifier` caches user in `FlutterSecureStorage`. `ActiveOrderNotifier` listens to Socket.IO `order:update` events and refreshes from server.
- **Navigation**: Go Router with redirect logic in `app.dart`. Unauthenticated users are redirected to `/auth/role-select`; authenticated users away from auth routes go to `/home` or `/rider/home` based on role.
- **API**: Singleton `ApiService` using Dio. Auto-attaches Bearer token. On 401, attempts refresh via `/auth/refresh`; if that fails, clears storage.
- **Sockets**: `SocketService` singleton connects on login, disconnects on logout. Re-binds cached listeners on reconnect.
- **Config**: `AppConfig` reads from `--dart-define`. Defaults to `http://10.0.2.2:5000/api/v1` for Android emulator.
- **Theme**: Custom `AppTheme.light` using Material 3, primary color deep green (`#2E7D32`), font family Poppins.

### 4.5 App Roles & Flows

**Customer:**
1. Register / Login → Home → Request Pickup (address + waste type)
2. Backend broadcasts to nearby riders
3. Rider accepts → customer sees live tracking
4. Rider arrives → confirms waste size → price calculated
5. Customer approves price → pays via Paystack
6. Rider completes → customer earns points

**Rider:**
1. Register → pending admin approval
2. Go Online → receive job notifications (Socket.IO + FCM)
3. Accept → navigate to pickup
4. Arrive → confirm size → wait for payment
5. Start pickup → complete → earnings logged

---

## 5. Admin Dashboard (`admin/`)

### 5.1 Setup

```bash
cd admin
npm install
cp .env.example .env        # set REACT_APP_API_URL
npm start                   # http://localhost:3000
npm run build               # outputs build/ for static hosting
```

### 5.2 Code Organization

```
admin/src/
├── api/axios.js            # Axios instance with Bearer token interceptor
├── context/AuthContext.jsx # Admin-only auth context (localStorage token)
├── components/Layout.jsx   # Sidebar + header layout
├── pages/
│   ├── Login.jsx
│   ├── Dashboard.jsx       # Live stats cards
│   ├── Riders.jsx          # Approve / reject / suspend with doc preview
│   ├── Orders.jsx          # List with status filter and pagination
│   ├── Analytics.jsx       # Charts (Recharts)
│   ├── Disputes.jsx        # View and resolve disputes
│   └── Pricing.jsx         # Edit pricing grid
└── App.jsx                 # Router with PrivateRoute guard
```

### 5.3 Patterns

- **Auth**: Token stored in `localStorage` as `admin_token`. 401 responses clear it and redirect to `/login`.
- **Role enforcement**: Login rejects non-admin accounts. `AuthContext` fetches `/auth/me` on mount.
- **Routing**: `BrowserRouter` with a `PrivateRoute` wrapper that shows a loading spinner while auth state initializes.

---

## 6. Database Schema

Single migration file: `backend/src/migrations/001_schema.sql`

**Tables:**
- `users` — customers, riders, admins (ENUM `user_role`)
- `rider_profiles` — vehicle info, documents, online status, GPS, approval status
- `orders` — full pickup lifecycle with status ENUM (`requested` → `completed`)
- `pricing_config` — admin-managed per-size/per-type pricing (seeded with defaults)
- `points_transactions` + `points_wallets` — rewards ledger
- `redemptions` — cash-out requests (pending → paid)
- `rider_earnings` — gross, commission (20%), net per order
- `notifications` — in-app notification log
- `disputes` — customer/rider dispute tracking
- `refresh_tokens` — revocable refresh token hashes

**Key indexes:** `orders(customer_id, rider_id, status, created_at)`, `rider_profiles(is_online)`, `notifications(user_id, is_read)`.

**Triggers:** `update_updated_at()` on `users`, `rider_profiles`, `orders`, `disputes`.

---

## 7. Security Considerations

- **Helmet** sets secure HTTP headers.
- **CORS** is origin-restricted via `ALLOWED_ORIGINS`.
- **Rate limiting**: 30 requests per 15 min on `/api/v1/auth`; 200 per minute on general API.
- **Passwords**: bcrypt with 12 rounds.
- **SQL**: strictly parameterized queries. No string interpolation in SQL.
- **JWT**: short-lived access tokens (default 7d), refresh tokens hashed and rotated.
- **User cache**: 60-second TTL. Must call `invalidateUserCache()` on role/status changes.
- **Paystack webhook**: HMAC-SHA512 signature verification + idempotency check.
- **Socket.IO**: JWT validation on connection. Customers can only track riders they have an active order with.
- **Cloudinary**: used via `multer-storage-cloudinary` for document/photo uploads.

---

## 8. Testing Strategy

**Current state:**
- Backend: no automated tests are present.
- Mobile: only the default Flutter `widget_test.dart` exists, and it is broken (references `MyApp` instead of `TrashGoApp`).
- Admin: no tests are present.

**Recommended approach:**
- Backend: add Jest + Supertest for API endpoint tests. Test state-machine transitions and idempotency paths.
- Mobile: add widget tests for key screens and unit tests for providers. Use `ProviderScope(overrides: ...)` to mock `ApiService`.
- Admin: add React Testing Library tests for page components and auth flows.

---

## 9. Deployment

### Backend (Railway / Render / Heroku)
```bash
# Set all .env variables in platform dashboard
# Run migration once:
psql $DATABASE_URL -f src/migrations/001_schema.sql
npm start
```

### Admin (Vercel / Netlify)
```bash
cd admin && npm run build
# Deploy the build/ folder
```

### Mobile
```bash
flutter build apk --release    # Android APK
flutter build ipa --release    # iOS archive
```

---

## 10. Points & Rewards Rules

| Component | Value |
|---|---|
| Base per pickup | 50 pts |
| Size bonus (medium) | +20 pts |
| Size bonus (large) | +40 pts |
| Recyclable multiplier | ×1.5 |
| Minimum to redeem | 500 pts |
| Conversion rate | 100 pts = GHS 1.00 |
| Payout cycle | Quarterly (Jan / Apr / Jul / Oct) |
| Methods | MTN MoMo · Airtel · Bank Transfer |

---

## 11. Code Style & Conventions

- **Comments**: Many backend files contain `FIX:` comments documenting specific bug fixes or architectural decisions. Preserve this convention when adding fixes.
- **Backend**: Use `asyncHandler` for all async controller functions. Return JSON shape `{ success: boolean, ...data }`.
- **Mobile**: Use `const` constructors where possible. Follow `flutter_lints` rules (`analysis_options.yaml`).
- **Naming**: snake_case for DB columns and backend files; camelCase for Dart; PascalCase for React components.
- **Currency**: Always GHS unless explicitly configured otherwise.

---

## 12. Creating the First Admin User

Run directly on the database:
```sql
INSERT INTO users (full_name, email, phone, password_hash, role)
VALUES ('Admin', 'admin@trashgo.app', '+1234567890',
        '$2a$12$...bcrypt_hash...', 'admin');
```
Or hash a password with `bcryptjs` and insert.

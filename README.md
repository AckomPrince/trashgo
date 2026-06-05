# TrashGo — On-Demand Waste Pickup Platform

Full-stack monorepo: Node.js backend · Flutter mobile app · React admin dashboard

## Project Structure

```
trashgo/
├── backend/          Node.js + Express API
├── mobile/           Flutter app (iOS + Android)
└── admin/            React admin dashboard
```

---

## 1. Backend Setup

### Prerequisites
- Node.js 18+
- PostgreSQL 14+
- Firebase project (for push notifications)
- Paystack account (for payments)
- Cloudinary account (optional, for photo uploads)

### Quick Start

```bash
cd backend
npm install
cp .env.example .env        # fill in your credentials
psql $DATABASE_URL -f src/migrations/001_schema.sql
npm run dev                 # starts on port 5000
```

### Environment Variables (`.env`)
| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET` | Random secret for JWT signing |
| `PAYSTACK_SECRET_KEY` | From paystack.com dashboard |
| `FIREBASE_PROJECT_ID` | From Firebase console |
| `FIREBASE_PRIVATE_KEY` | Service account private key |
| `FIREBASE_CLIENT_EMAIL` | Service account email |

### Key API Endpoints
```
POST   /api/v1/auth/register/customer   Register customer
POST   /api/v1/auth/register/rider      Register rider
POST   /api/v1/auth/login               Login (all roles)
POST   /api/v1/orders                   Create pickup request
POST   /api/v1/orders/:id/accept        Rider accepts order
PATCH  /api/v1/orders/:id/status        Update order status
PATCH  /api/v1/orders/:id/approve-price Customer approves price
PATCH  /api/v1/orders/:id/complete      Rider completes order
POST   /api/v1/payments/initialize      Initialize Paystack payment
POST   /api/v1/payments/webhook         Paystack webhook
GET    /api/v1/rewards/wallet           Customer points balance
POST   /api/v1/rewards/redeem           Redeem points for cash
GET    /api/v1/admin/dashboard          Admin stats
```

---

## 2. Mobile App Setup (Flutter)

### Prerequisites
- Flutter 3.x SDK
- Android Studio / Xcode
- Firebase project with `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
- Google Maps API key

### Quick Start

```bash
cd mobile
flutter pub get

# Add your Firebase config files:
# Android: android/app/google-services.json
# iOS:     ios/Runner/GoogleService-Info.plist

# Run on device/emulator:
flutter run --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:5000/api/v1 \
            --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

### Android: add Maps API key to `android/app/src/main/AndroidManifest.xml`
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

### iOS: add Maps API key to `ios/Runner/AppDelegate.swift`
```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

### App Roles & Flows
**Customer flow:**
1. Register → Home → Request Pickup (address + waste type)
2. Wait for rider assignment → Track live on map
3. Rider arrives → confirms waste size
4. Customer approves price → pays via Paystack (MTN MoMo / card)
5. Rider completes → customer earns points
6. Redeem points every quarter as cash

**Rider flow:**
1. Register → Admin approval required
2. Go Online → receive job notifications
3. Accept → navigate → arrive → confirm size
4. Wait for payment → start pickup → complete
5. View earnings dashboard

---

## 3. Admin Dashboard Setup (React)

### Quick Start

```bash
cd admin
npm install
cp .env.example .env        # set REACT_APP_API_URL
npm start                   # opens http://localhost:3000
```

### Features
- **Dashboard** — live stats: customers, riders, orders, revenue
- **Riders** — approve / reject / suspend riders with document preview
- **Orders** — full order list with status filter and pagination
- **Analytics** — charts: daily trend, waste type breakdown, top riders
- **Disputes** — view and resolve customer/rider disputes
- **Pricing** — edit per-size, per-type pricing in a grid table

### Creating the first Admin user
Run this SQL directly on your database:
```sql
INSERT INTO users (full_name, email, phone, password_hash, role)
VALUES ('Admin', 'admin@trashgo.app', '+1234567890',
        '$2a$12$...bcrypt_hash_of_your_password...', 'admin');
```
Or use `bcryptjs` to hash a password then insert.

---

## 4. Job Flow (Exact Sequence)

```
Customer creates request
       ↓
Backend broadcasts to nearby riders (Socket.IO + FCM)
       ↓
Rider accepts (locked — first come first served)
       ↓
Rider navigates → Rider en route → Rider arrived
       ↓
Rider confirms waste SIZE (small / medium / large)
       ↓
System calculates price from pricing_config table
       ↓
Customer receives price notification
       ↓
Customer APPROVES price  ← CRITICAL STEP
       ↓
Customer pays via Paystack (MTN MoMo / card)
       ↓
Paystack webhook confirms payment → order = in_progress
       ↓
Rider completes pickup
       ↓
System awards points to customer
       ↓
Rider earnings logged (gross - 20% commission)
```

---

## 5. Points & Rewards

| Component | Value |
|---|---|
| Base per pickup | 50 pts |
| Size bonus (medium) | +20 pts |
| Size bonus (large) | +40 pts |
| Recyclable multiplier | ×1.5 |
| Minimum to redeem | 500 pts |
| Conversion rate | 100 pts = GHS 1.00 |
| Payout cycle | Every quarter (Jan / Apr / Jul / Oct) |
| Methods | MTN MoMo · Airtel · Bank Transfer |

---

## 6. Tech Stack Summary

| Layer | Technology |
|---|---|
| Mobile | Flutter 3.x + Dart + Riverpod |
| Backend | Node.js 18 + Express 4 |
| Database | PostgreSQL 14 |
| Real-time | Socket.IO |
| Push Notifications | Firebase Cloud Messaging |
| Payments | Paystack (MTN MoMo + card) |
| Maps | Google Maps Flutter SDK |
| Location | Geolocator + Geocoding |
| Admin UI | React 18 + Recharts |
| File Storage | Cloudinary |

---

## 7. Deployment

### Backend (Railway / Render / Heroku)
```bash
# Set all .env variables in the platform dashboard
# The DATABASE_URL is auto-injected by most platforms
# Run migrations manually once:
psql $DATABASE_URL -f src/migrations/001_schema.sql
```

### Admin Dashboard (Vercel / Netlify)
```bash
cd admin && npm run build
# Deploy the `build/` folder
```

### Mobile App
- **Android**: `flutter build apk --release`
- **iOS**: `flutter build ipa --release`

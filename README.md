# TrashGo

**On-demand waste pickup platform for Ghana — connecting households and businesses with nearby riders for cashless, trackable waste disposal.**

TrashGo is a full-stack monorepo solving the urban waste management gap in Accra and beyond. Customers request pickups through a Flutter mobile app, riders receive real-time job notifications via Socket.IO and FCM, and an admin dashboard provides oversight with live analytics, rider management, dispute resolution, and dynamic pricing. Payments flow through Paystack (including MTN MoMo), and a points-based rewards system incentivizes consistent recycling.

Built for the Ghanaian market — designed for GHS currency, local mobile money payments, and reliable operation on modest infrastructure.

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter 3.x + Dart, Riverpod, Go Router, Dio |
| Backend | Node.js 18 + Express 4, PostgreSQL 14, Socket.IO |
| Admin UI | React 18 (Create React App) + Recharts |
| Payments | Paystack (mobile_money + card) |
| Maps | Google Maps Flutter SDK |
| Push | Firebase Cloud Messaging |
| Storage | Cloudinary |
| Auth | JWT (short-lived access + rotated refresh tokens) |

## Quick Start

### Backend

```bash
cd backend
npm install
cp .env.example .env
# Fill in credentials (DATABASE_URL, JWT_SECRET, PAYSTACK_SECRET_KEY, etc.)
psql $DATABASE_URL -f src/migrations/001_schema.sql
npm run dev
```

### Mobile

```bash
cd mobile
flutter pub get
# Configure Firebase (google-services.json / GoogleService-Info.plist)
flutter run --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:5000/api/v1 \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

### Admin Dashboard

```bash
cd admin
npm install
cp .env.example .env
npm start
```

## Architecture

- **Mobile** — Flutter app with Riverpod state management, Go Router navigation, Socket.IO for real-time tracking, and Google Maps for pickup/delivery visualization.
- **Backend** — Express REST API with JWT auth, Socket.IO for rider-customer matching and location streaming, Paystack webhook integration with HMAC-SHA512 verification, and PostgreSQL with parameterized queries.
- **Admin** — React dashboard with Recharts analytics, rider approval workflow, order management with status filters, dispute resolution, and dynamic pricing grid.

## Roles & Flows

- **Customer** — Register, request pickup, track rider in real-time, approve pricing, pay via Paystack/MoMo, earn rewards points.
- **Rider** — Go online, receive job notifications, accept pickups, navigate to locations, complete jobs, track earnings.
- **Admin** — Approve/reject riders, monitor live stats, manage orders and disputes, configure pricing.

## License

MIT

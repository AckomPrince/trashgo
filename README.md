# TrashGo

**On-demand waste pickup platform for Ghana.** A full-stack monorepo connecting customers, riders, and administrators through a real-time logistics marketplace.

TrashGo solves the urban waste collection problem by matching households and businesses with nearby independent riders. Customers request pickups through a Flutter mobile app, riders receive real-time job notifications via Socket.IO and Firebase Cloud Messaging, and an admin dashboard provides operational oversight — rider approvals, pricing grids, dispute resolution, and analytics.

Built for the Ghanaian market with Paystack payments (including MTN MoMo), GHS pricing, deep-green Material 3 design, and a PostgreSQL-backed Node.js API with integrated rewards and loyalty system.

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter 3.x + Dart (Riverpod, Go Router) |
| Backend | Node.js 18 + Express 4 |
| Database | PostgreSQL 14 |
| Real-time | Socket.IO |
| Payments | Paystack (mobile_money + card) |
| Maps | Google Maps Flutter SDK |
| Push | Firebase Cloud Messaging |
| Admin UI | React 18 + Recharts |
| File Storage | Cloudinary |

## Quick Start

### Backend

```bash
cd backend
npm install
cp .env.example .env        # fill in credentials
psql $DATABASE_URL -f src/migrations/001_schema.sql
npm run dev                 # nodemon on port 5000
```

### Mobile

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:5000/api/v1 \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

### Admin Dashboard

```bash
cd admin
npm install
npm start                   # http://localhost:3000
npm run build               # static build output
```

## Project Structure

```
trashgo/
├── backend/          Node.js + Express REST API
├── mobile/           Flutter cross-platform mobile app
└── admin/            React admin dashboard
```

## Architecture Highlights

- **Order state machine** enforces valid status transitions from `requested` through to `completed` or `canceled`
- **Rider matching** uses SQL bounding-box filtering then Haversine distance on the reduced set
- **Paystack webhooks** verify HMAC-SHA512 signatures and are fully idempotent
- **Refresh tokens** stored as SHA-256 hashes, rotated on each use
- **Rewards system** — customers earn points per pickup, redeemable quarterly via MTN MoMo or bank transfer

## License

MIT

# TrashGo

**On-demand waste pickup platform for Ghana. Full-stack monorepo: Node.js backend, Flutter mobile app, React admin dashboard.**

TrashGo connects households and businesses with nearby waste collectors (riders) in real time. Customers request pickups, riders compete for jobs, payments happen via Paystack (card + MTN Mobile Money), and an admin dashboard provides full operational visibility.

The platform handles the entire lifecycle: customer registration, rider onboarding, real-time order matching via Socket.IO, live GPS tracking from pickup to disposal, dynamic pricing based on waste volume, in-app payments, and a loyalty rewards system. Built for the Ghanaian market with GHS currency, MTN MoMo support, and offline-capable mobile architecture.

## Tech Stack

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

## Project Structure

```
trashgo/
├── backend/          Node.js + Express API (port 5000)
├── mobile/           Flutter app (iOS + Android)
└── admin/            React admin dashboard (port 3000)
```

## Quick Start

### Backend

```bash
cd backend
cp .env.example .env        # fill in credentials
npm install
psql $DATABASE_URL -f src/migrations/001_schema.sql
npm run dev                 # starts on port 5000
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
npm start                   # starts on port 3000
```

## Key Features

- **Real-time order matching** — broadcasts pickup requests to nearby riders via Socket.IO with Haversine distance filtering
- **Live GPS tracking** — customers see their rider's location from acceptance to disposal
- **In-app payments** — Paystack integration with card and MTN Mobile Money support
- **Dynamic pricing** — waste volume estimation at pickup, customer approval before payment
- **Rewards system** — loyalty points for frequent customers with expiry-based retention
- **Admin analytics** — revenue dashboard, rider performance, dispute resolution, pricing management
- **JWT auth with token rotation** — 60-second user cache, SHA-256 hashed refresh tokens

## Architecture Highlights

- **Order state machine**: enforces valid transitions (`pending → accepted → rider_en_route → arrived → priced → paid → disposed → completed`)
- **Rider matching**: SQL bounding-box pre-filter + exact Haversine on candidate set (avoids OOM with thousands of riders)
- **Idempotent payments**: Paystack webhooks verified via HMAC-SHA512, all DB writes before returning 200
- **Secure sessions**: refresh tokens stored as SHA-256 hashes, rotated on every use, revocable by deletion

## License

MIT

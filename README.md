# TrashGo

**On-demand waste pickup platform for Ghana.** Customers request waste collection, nearby riders get matched in real time, and payments process through Paystack — including MTN Mobile Money.

TrashGo is a full-stack monorepo: a Flutter mobile app for customers and riders, a Node.js + Express API backend, and a React admin dashboard for operators. It targets the Ghanaian market with GHS currency, Paystack payments, and local mobile money integration.

The platform handles the complete pickup lifecycle: a customer requests pickup with their address and waste type, the backend broadcasts to nearby riders via a bounding-box + Haversine matching algorithm, the first rider to accept gets the order, live GPS tracking follows via Socket.IO, the rider confirms waste size on arrival, the backend calculates pricing, the customer approves and pays, and the rider earns with a 20% platform commission. A rewards wallet keeps customers coming back with points that expire after 12 months of inactivity.

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
npm install
cp .env.example .env        # fill in credentials
psql $DATABASE_URL -f src/migrations/001_schema.sql
npm run dev                 # nodemon on port 5000
```

Key environment variables: `DATABASE_URL`, `JWT_SECRET`, `JWT_REFRESH_SECRET`, `PAYSTACK_SECRET_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL`, `CLOUDINARY_*`, `PLATFORM_COMMISSION` (default: 0.20), `ALLOWED_ORIGINS`.

### Mobile

```bash
cd mobile
flutter pub get

# Configure Firebase:
#   Android → android/app/google-services.json
#   iOS     → ios/Runner/GoogleService-Info.plist

flutter run \
  --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:5000/api/v1 \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

### Admin

```bash
cd admin
npm install
npm start    # Create React App on port 3000
```

## App Roles

- **Customer** — registers, requests pickup, tracks rider live, approves price, pays via Paystack, rates rider, earns rewards points
- **Rider** — sets availability, receives nearby orders, accepts, navigates to pickup, confirms waste size, completes pickup, tracks earnings
- **Admin** — monitors platform health, reviews riders, resolves disputes, manages pricing, views analytics

## License

MIT

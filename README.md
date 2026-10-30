# WasteWise: Community-Based Waste Management & Recycling Incentive App

WasteWise is a full-stack college project mobile application designed to optimize community waste collection and encourage recycling through a reward points incentive system.

---

## 🏗 System Architecture

The application comprises a **Node.js/Express REST backend** integrated with **Firebase Admin SDK (Firestore & Auth)** and a cross-platform **Flutter mobile frontend** with role-based routing (Citizen, Collector, Administrator).

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Mobile Application               │
│  ├── AuthProvider (Firebase Auth + ID Token Sync)           │
│  ├── ApiClient (HTTP Interceptor with Bearer Token)          │
│  ├── GoRouter Navigation Guard (Role-based UI Shells)       │
│  └── Screens: Citizen | Collector | Administrator           │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTP REST API (JWT / Firebase Auth)
┌──────────────────────────────▼──────────────────────────────┐
│                    Node.js / Express Backend                │
│  ├── Auth Middleware (Firebase ID Token verification & RBAC) │
│  ├── Services: QR Service, Notification Service, Rewards     │
│  └── Routes: Auth, Requests, Collectors, QR, Admin, Rewards │
└──────────────────────────────┬──────────────────────────────┘
                               │ Firebase Admin SDK
┌──────────────────────────────▼──────────────────────────────┐
│                    Firebase Cloud Services                  │
│  ├── Firebase Authentication (User identity & security tokens)│
│  ├── Cloud Firestore (NoSQL database for requests, records) │
│  └── Firebase Cloud Messaging (FCM push notifications)      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🌟 Key Features

1. **Role-Based Access Control (RBAC)**
   - **Citizen**: Submit waste pickup requests with geolocation, view active request status timeline, present QR code to collector, view reward wallet balance and transaction logs.
   - **Collector**: View assigned collection tasks, update task status (Assigned → Accepted → Collected), scan citizen QR code via camera or manual token entry to complete verification.
   - **Administrator**: Comprehensive dashboard metrics (total citizens, collectors, requests, total recycled kg, rewards issued), request-to-collector assignment, collector registration, waste category management, reward rule configuration, system-wide analytics.

2. **Secure QR-Based Verification & Reward Engine**
   - Cryptographically signed JWT QR tokens per pickup request.
   - Atomic Firestore transactions prevent duplicate verification or double point awarding.
   - Dynamic point calculation based on configurable category rates per kilogram.

3. **In-App & Push Notifications**
   - Instant status updates when requests are assigned, collected, or verified.
   - Unread notification badge count in bottom navigation shell.

---

## 📁 Project Directory Structure

```
community based/
├── backend/
│   ├── src/
│   │   ├── config/          # Firebase Admin SDK initialization
│   │   ├── middleware/      # Firebase Auth verification & Role middleware
│   │   ├── routes/          # Express route handlers (8 modules)
│   │   ├── services/        # QR verification, Notifications, Reward calculation
│   │   └── app.js           # Express application setup & middleware stack
│   ├── tests/               # Jest integration test suite with Firebase mocks
│   ├── seed.js              # Mock data seeding script for development
│   ├── firestore.rules      # Firestore Security Rules
│   ├── package.json
│   └── .env.example
└── waste_mgmt_app/
    ├── lib/
    │   ├── core/            # Theme, ApiClient, Router setup
    │   ├── providers/       # AuthProvider, NotificationProvider
    │   ├── screens/         # Auth, Citizen, Collector, Admin screens
    │   ├── widgets/         # StatusBadge, Loading, Error, Empty state widgets
    │   ├── firebase_options.dart
    │   └── main.dart
    └── pubspec.yaml
```

---

## 🚀 Setup & Execution Instructions

### Prerequisites
- Node.js v16+
- Flutter SDK v3.0+
- Firebase Project with Firestore & Authentication enabled

### 1. Backend Setup
```bash
cd backend
npm install

# Copy environment template
cp .env.example .env
```
Edit `.env` with your Firebase Service Account JSON path, JWT secret, and project ID:
```env
PORT=5000
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_SERVICE_ACCOUNT_PATH=./config/firebase-service-account.json
JWT_SECRET=your-secure-jwt-secret
```

To run the backend server:
```bash
npm run dev
```

To run backend integration tests:
```bash
npm test
```

To seed initial categories, admin user, and sample requests:
```bash
npm run seed
```

### 2. Frontend (Flutter) Setup
```bash
cd waste_mgmt_app
flutter pub get
```

Place `google-services.json` inside `waste_mgmt_app/android/app/` (for Android) and `GoogleService-Info.plist` inside `waste_mgmt_app/ios/Runner/` (for iOS).

Run on an emulator or connected device:
```bash
flutter run
```

---

## 🧪 Testing Verification Flow

1. **Log in as Citizen** (`citizen@waste.dev` / `citizen123`):
   - Submit a pickup request with 3.5 kg of Plastic waste and GPS location.
   - Navigate to **Requests** → Click request → View **Show QR Code**.
2. **Log in as Admin** (`admin@waste.dev` / `admin123`):
   - Navigate to **Manage Requests** → Assign request to Collector (`collector@waste.dev`).
3. **Log in as Collector** (`collector@waste.dev` / `collector123`):
   - View assigned task on dashboard → Update status to **Accepted** → **Collected**.
   - Tap **Scan QR Code** → Use camera or tap **Manual Entry** and paste the request's QR token / Request ID.
   - Tap **Submit Verification**.
4. **Log in back as Citizen**:
   - Check **Rewards** wallet: Points credited automatically based on configured rate (e.g., 3.5 kg × 10 pts/kg = 35 pts).

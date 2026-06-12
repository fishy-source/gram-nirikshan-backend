# Gram Nirikshan App — Complete Project Documentation

> **Version:** 1.0.0 | **Stack:** Flutter + FastAPI + MySQL + Gemini AI

---

## 📁 Project Structure

```
gram_nirikshan/
├── backend/                          # FastAPI Python Backend
│   ├── app/
│   │   ├── main.py                   # App entry point, all routes registered
│   │   ├── api/routes/
│   │   │   ├── auth.py               # OTP login, JWT tokens
│   │   │   ├── inspections.py        # CRUD, GPS, approval workflow
│   │   │   ├── photos.py             # Upload with watermark overlay
│   │   │   ├── reports.py            # PDF generation (ReportLab)
│   │   │   ├── ai.py                 # Gemini AI chat & suggestions
│   │   │   └── dashboard.py          # Stats, users, panchayats
│   │   ├── core/
│   │   │   ├── config.py             # Pydantic Settings (env vars)
│   │   │   ├── security.py           # JWT, OTP, bcrypt
│   │   │   └── dependencies.py       # Auth injection, role checks
│   │   ├── db/database.py            # SQLAlchemy async MySQL
│   │   ├── models/models.py          # All 8 database table models
│   │   └── schemas/schemas.py        # Pydantic request/response DTOs
│   ├── schema.sql                    # MySQL DDL + seed data
│   ├── requirements.txt              # Python dependencies
│   ├── Dockerfile                    # Production Docker image
│   └── .env.example                  # Environment variable template
│
├── flutter_app/                      # Flutter Android App
│   ├── lib/
│   │   ├── main.dart                 # Entry point, providers, navigation
│   │   ├── core/
│   │   │   ├── constants/app_constants.dart
│   │   │   ├── theme/app_theme.dart  # Material 3 theme
│   │   │   └── services/api_service.dart  # Dio HTTP client
│   │   ├── data/
│   │   │   └── models/models.dart    # All data classes
│   │   └── presentation/
│   │       ├── providers/            # State management (Provider)
│   │       │   ├── auth_provider.dart
│   │       │   └── inspection_provider.dart
│   │       └── screens/
│   │           ├── auth/login_screen.dart
│   │           ├── dashboard/dashboard_screen.dart
│   │           ├── inspections/inspection_list_screen.dart
│   │           ├── inspections/inspection_detail_screen.dart
│   │           └── ai_assistant/ai_assistant_screen.dart
│   ├── android/app/src/main/AndroidManifest.xml
│   └── pubspec.yaml                  # All Flutter dependencies
│
└── deployment/
    ├── docker-compose.yml            # MySQL + API + Nginx
    └── nginx.conf                    # Reverse proxy, SSL, rate limit
```

---

## 🚀 Setup Instructions

### 1. Backend Setup

```bash
# Navigate to backend directory
cd gram_nirikshan/backend

# Create virtual environment
python -m venv venv
venv\Scripts\activate  # Windows
# source venv/bin/activate  # Linux/Mac

# Install dependencies
pip install -r requirements.txt

# Configure environment
copy .env.example .env
# Edit .env with your database credentials and API keys

# Initialize MySQL database
mysql -u root -p < schema.sql

# Start development server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

**Access API Docs:** http://localhost:8000/docs

---

### 2. Flutter App Setup

```bash
# Navigate to flutter app
cd gram_nirikshan/flutter_app

# Install Flutter dependencies
flutter pub get

# Update API base URL in lib/core/constants/app_constants.dart
# Change 'YOUR_SERVER_IP' to your actual server IP or localhost

# Add Google Maps API key in android/app/src/main/AndroidManifest.xml
# Replace 'YOUR_GOOGLE_MAPS_API_KEY'

# Run on connected device/emulator
flutter run

# Build APK (debug)
flutter build apk --debug

# Build APK (release - for production)
flutter build apk --release --split-per-abi
```

**APK Location:** `flutter_app/build/outputs/flutter-apk/`

---

### 3. Production Deployment (Hostinger VPS)

```bash
# 1. SSH into your Hostinger VPS
ssh user@your-server-ip

# 2. Install Docker & Docker Compose
curl -fsSL https://get.docker.com | sh
sudo apt install docker-compose-plugin

# 3. Clone/upload project to server
git clone your-repo-url /opt/gram_nirikshan
cd /opt/gram_nirikshan

# 4. Create production .env
cp backend/.env.example backend/.env
nano backend/.env  # Fill in production values

# 5. SSL Certificate (Let's Encrypt)
sudo apt install certbot
sudo certbot certonly --standalone -d gramnirikshan.in
# Copy certs to deployment/ssl/

# 6. Start all services
cd deployment
docker compose up -d

# 7. Check logs
docker compose logs -f api
docker compose logs -f db
```

---

## 🔑 Required API Keys

| Service | Where to Get | Setting |
|---------|-------------|---------|
| **Google Maps** | console.cloud.google.com | `GOOGLE_MAPS_API_KEY` |
| **Gemini AI** | aistudio.google.com | `GEMINI_API_KEY` |
| **MSG91 SMS** | msg91.com | `SMS_API_KEY` |
| **Firebase** | console.firebase.google.com | `google-services.json` |
| **Gmail App Password** | myaccount.google.com | `SMTP_PASSWORD` |

---

## 📱 APK Build Instructions (Step by Step)

### Prerequisites
1. Install [Flutter SDK](https://flutter.dev/docs/get-started/install/windows) (3.3+)
2. Install [Android Studio](https://developer.android.com/studio) with SDK
3. Install [JDK 17](https://adoptium.net/)

### Build Steps

```bash
# 1. Verify Flutter installation
flutter doctor -v

# 2. Install app dependencies
cd flutter_app
flutter pub get

# 3. Update configuration files:
#    - lib/core/constants/app_constants.dart → set baseUrl
#    - android/app/src/main/AndroidManifest.xml → set Maps API key
#    - Add google-services.json to android/app/ (from Firebase console)

# 4. Create keystore for signed APK (production)
keytool -genkey -v -keystore gram_nirikshan_key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias gram_nirikshan

# 5. Configure signing in android/app/build.gradle
# (Add signing config with your keystore details)

# 6. Build release APK
flutter build apk --release

# 7. Or build App Bundle (for Play Store)
flutter build appbundle --release
```

### Output Files
- Debug: `build/app/outputs/flutter-apk/app-debug.apk`
- Release: `build/app/outputs/flutter-apk/app-release.apk`
- Bundle: `build/app/outputs/bundle/release/app-release.aab`

---

## 📊 Database Tables Overview

| Table | Key Fields | Purpose |
|-------|-----------|---------|
| `users` | id, mobile, role, district | Login, roles |
| `otp_records` | mobile, otp, expires_at | OTP authentication |
| `panchayats` | name, district, block, lat/lng | GP locations |
| `inspections` | inspection_id, status, GPS data | Main inspection records |
| `photos` | watermark data, file_path, GPS | Photo storage |
| `documents` | type, file_path | PDF/Excel uploads |
| `reports` | generated PDF path | Report files |
| `approvals` | level (JE/AE/XEN), action | Approval trail |
| `notifications` | user_id, type, is_read | Push/in-app alerts |

---

## 🔄 Workflow

```
Engineer (JE)              AE / XEN              Admin
     │                        │                    │
     ├─ Create Draft           │                    │
     ├─ GPS Check-in           │                    │
     ├─ Add Photos             │                    │
     ├─ Fill Observations      │                    │
     ├─ Submit ──────────────► │                    │
     │                        ├─ Review             │
     │                        ├─ Approve ──────────►│
     │                        │  or Reject          ├─ Final Approve
     │◄── Notification ────── │                    │
     │                        │                    │
```

---

## 🤖 AI Features

### Gemini AI Assistant
- **Chat Mode**: Hindi/English Q&A about inspections
- **Report Draft**: Auto-generate professional report text
- **Inspection Guide**: Step-by-step checklist by type

### Hindi Voice Input
- Uses `speech_to_text` package
- Locale: `hi_IN`
- Auto-fills AI chat input field

---

## 📸 Watermark Details

Each uploaded photo gets a watermark band at the bottom containing:
1. **App Name + Panchayat Name** (large, bold)
2. **Engineer Name** (medium)
3. **GPS Coordinates** (latitude, longitude)
4. **Date & Time** (DD/MM/YYYY HH:MM IST)
5. **Caption** (if provided)

Implementation: Python **Pillow** library in `backend/app/api/routes/photos.py`

---

## 📄 PDF Report Contents

Generated using Python **ReportLab**:
1. Department header
2. Inspection info table
3. GPS check-in/out details
4. Observations, Recommendations, Action Taken
5. Photo grid (2 per row with captions)
6. Approval trail table
7. Signature section
8. Footer with report ID

---

## 🔧 Troubleshooting

### Common Issues

**Flutter build fails**
```bash
flutter clean
flutter pub cache repair
flutter pub get
flutter build apk
```

**Backend cannot connect to MySQL**
```bash
# Check if MySQL is running
docker compose ps
docker compose logs db
# Verify DB credentials in .env
```

**Photos not uploading**
- Check `UPLOAD_DIR` exists and is writable
- Verify `MAX_FILE_SIZE_MB` setting
- Check file type is JPEG/PNG/WEBP

**OTP not received**
- Verify `SMS_API_KEY` is set in .env
- In development mode, OTP is logged to console (no SMS)
- Check MSG91 balance and sender ID approval

---

## 📝 Notes

> [!IMPORTANT]  
> Replace all placeholder API keys before deploying to production.

> [!NOTE]  
> The app uses **24-hour JWT tokens** by default. Change `ACCESS_TOKEN_EXPIRE_MINUTES` for different behavior.

> [!TIP]  
> For development without SMS: OTP is printed to the backend console log when `SMS_API_KEY` is empty.

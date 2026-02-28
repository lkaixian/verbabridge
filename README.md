# VerbaBridge

A small Flutter app with a Python backend that provides AI/caching services and serves static UI for demos.

## Project structure

- `lib/` - Flutter app source (screens, tabs, services)
- `server/` - Python backend (main.py, core modules, static assets)
- `android/`, `ios/`, `windows/` - platform-specific build files

## Tech Stack

- Mobile: Flutter (Dart)
- Backend: Python (FastAPI + Uvicorn)
- Auth & DB: Firebase (Authentication, Firestore)
- Integrations: Google Sign-In, device camera plugins (e.g. mobile_scanner)
- Caching: local JSON cache (`server/cache_data/`)

## Mermaid: Tech Stack Diagram

```mermaid
graph LR
  subgraph Mobile_App[Mobile App]
    FlutterApp[Flutter App (Dart)]
    FlutterApp -->|Auth & DB| Firebase[Firebase (Auth, Firestore)]
    FlutterApp -->|Sign-in| GoogleSignIn[Google Sign-In]
    FlutterApp -->|Camera/Scanner| MobileScanner[mobile_scanner plugin]
  end

  subgraph Backend[Backend]
    FastAPI[FastAPI (Python)]
    FastAPI -->|Serves| Static[Static files (server/static/)]
    FastAPI -->|Uses| AI[AI Module (server/core/ai.py)]
    FastAPI -->|Caches| Cache[Cache Layer (server/cache.py)]
    FastAPI -->|Runs on| Uvicorn[Uvicorn]
  end

  Firebase -->|Service Account| Firestore[Firestore]
  FlutterApp -->|HTTP/API calls| FastAPI
  Cache -->|JSON files| CacheData[server/cache_data/*.json]
  AI -->|Loads| CacheData

  style Mobile_App fill:#f9f,stroke:#333,stroke-width:1px
  style Backend fill:#9ff,stroke:#333,stroke-width:1px
```

## Quick run (local)

- Run backend (from `server/`):

```powershell
cd server
uvicorn main:app --reload
```

- Run Flutter app (from project root):

```powershell
flutter run
```

## Notes

- Backend stores cached API responses in `server/cache_data/` as JSON.
- `server/serviceAccountKey.json` is used to authenticate with Firebase for server-side operations.
# 🌉 VerbaBridge (Backend)

**The Linguistic Bridge for Cultural Preservation & Digital Inclusion**

VerbaBridge is a powerful FastAPI backend designed to break down cultural and generational language barriers. Built as a Tech 4 Good initiative, it empowers traditional B40 food vendors—like aging Kopitiam owners in Penang—to instantly digitize their menus without technical skills, while allowing tourists to interact with local culture using AI-driven context translation.

## 🚀 Key Features

* **The "Rizzeta Stone" Protocol:** A novel linguistic framework powered by Gemini 3 Flash that bridges the generational gap, dynamically translating standard English into highly contextual **Gen Alpha Semantics** (Brainrot).
* **Cultural Context Engine:** Preserves local heritage by supporting hyper-local dialects, including **Ah Beng (Penang Hokkien)** and **Mak Cik Bawang (Dramatic Gossip)**.
* **Zero-Friction Merchant Portal:** A built-in web dashboard (`/admin`) that allows traditional vendors to auto-generate dynamic QR menus that sync directly to Firebase—no app installation required for the merchant.
* **Multimodal AI Menu Extraction:** Vendors simply upload a photo of a messy, handwritten menu. The system uses Gemini's spatial vision to extract the items and automatically rewrites them into "Michelin-star" dramatic food descriptions.
* **Smart Edge Caching:** Implements a JSON-based caching layer to drastically reduce API latency and optimize cloud quota usage.

## 🏗️ Tech Stack

* **Framework:** FastAPI (Python)
* **AI Engine:** Google Gemini (3.1 Pro / Flash Preview) via `google-genai`
* **Database:** Firebase Firestore (via `firebase-admin` SDK)
* **QR Generation:** Python `qrcode`

## 🛠️ Local Setup Instructions

Clone the repository

```bash
git clone https://github.com/lkaixian/verbabridge.git
cd verbabridge/server
```

**Server Side**

1. Install dependencies

```bash
pip install -r requirements.txt
```

2. Configure Environment Variables & Secrets

- Create a .env file in the ./server directory and add your Gemini API Key:

```bash
GEMINI_API_KEY=your_api_key_here
```

- Firebase Setup: Place your serviceAccountKey.json in the root directory.

(Note: For security reasons, this file is intentionally excluded via .gitignore and must be generated via the Firebase Console).

3. Setup cloudflared tunnel for external access.

Prerequisite: This step require a valid domain and a cloudflare account in order to work it out.

**Windows:**

```bash
# 1. Install cloudflared using Chocolatey (Requires Admin privileges)
choco install cloudflared -y

# 2. Authenticate your machine with Cloudflare 
# (This will pop open a browser window to select your domain)
cloudflared tunnel login

# 3. Create the named tunnel for your backend
# Copy that UUID, you will need it for the config file!
cloudflared tunnel create verbabridge

# 4. Route the DNS to your Cloudflare domain
# Replace 'api.yourdomain.com' with the actual domain you own on Cloudflare
cloudflared tunnel route dns verbabridge api.yourdomain.com

# 5. Create the routing configuration file (config.yml)
# Replace <YOUR_UUID>, <YOUR_WINDOWS_USERNAME>, and <api.yourdomain.com>
cat <<EOF > config.yml
tunnel: <YOUR_UUID>
credentials-file: C:\Users\<YOUR_WINDOWS_USERNAME>\.cloudflared\<YOUR_UUID>.json

ingress:
  - hostname: <api.yourdomain.com>
    service: http://localhost:8000
  - service: http_status:404
EOF

# 6. Spin up the tunnel!
# This reads your config.yml and wires your local FastAPI server to the internet
cloudflared tunnel run verbabridge
```

**Linux:**

```bash
# 1. Download and install cloudflared for Debian/Ubuntu
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb

# 2. Authenticate your machine (opens a browser link)
cloudflared tunnel login

# 3. Create the tunnel
# Copy the UUID it spits out!
cloudflared tunnel create verbabridge

# 4. Route DNS (Replace with your actual domain)
cloudflared tunnel route dns verbabridge api.yourdomain.com

# 5. Create the config file securely in your home directory
# Replace <YOUR_UUID> and api.yourdomain.com with your real values
mkdir -p ~/.cloudflared
cat <<EOF > ~/.cloudflared/config.yml
tunnel: <YOUR_UUID>
credentials-file: /home/$USER/.cloudflared/<YOUR_UUID>.json

ingress:
  - hostname: api.yourdomain.com
    service: http://localhost:8000
  - service: http_status:404
EOF

# 6. Spin up the tunnel!
cloudflared tunnel run verbabridge
```

4. Update API link in the flutter lib files.
Looking for link such as:

```bash
final String baseUrl = "...";
```

Change it to your own api.yourdomain.com:

```bash
final String baseUrl = "https://api.yourdomain.com";
```

5. Configure and spin up firebase

VerbaBridge relies on Firebase for seamless user authentication and real-time database syncing for the Kopitiam merchant menus. To run this project locally, you will need to connect it to your own Firebase instance.


**A. Create the Firebase Project**

1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project named `VerbaBridge`.
2. Navigate to **Authentication** > **Sign-in method** and enable **Google Sign-In**.
3. Navigate to **Firestore Database** and create a new database in your preferred region.

To ensure data privacy while allowing merchants and tourists to use the app, update your Firestore Security Rules to require authentication:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      // Only authenticated users can read or write data
      allow read, write: if request.auth != null; 
    }
  }
}
```

**B. Frontend Setup (Flutter)**
We use the FlutterFire CLI to automatically link the mobile app to Firebase.

Install the CLI: npm install -g firebase-tools

Log in: firebase login

In your app/ directory, run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This will generate a lib/firebase_options.dart file. (Note: The API keys in this file are public identifiers and are restricted via Google Cloud Console to only allow Firebase connections).

**C. Backend Setup (FastAPI)**
The FastAPI server needs admin access to sync the AI-extracted menus directly into Firestore.

In the Firebase Console, go to Project Settings > Service Accounts.

Click Generate new private key and download the JSON file.

Rename the file to serviceAccountKey.json and place it inside the server/ directory of this repository.

⚠️ CRITICAL: Never commit this file to GitHub! Ensure it is listed in your .gitignore before pushing any code.

6. Compile the flutter program to include new links with:

```bash
flutter build apk --release
```

7. The first terminal will be running cloudflared where:

```bash
cloudflared tunnel run
```

and the second terminal will be running the server:

```bash
uvicorn main:app --reload
```

**Client Side**:
Download the binary from the releases and sign in with your own google account.

## 📚 API Architecture

**Core Translation Endpoints:**

- POST /process_text - Deep Linguistic Analysis: Breaks down Kopitiam slang into literal, tonal, and phonetic mappings.

- POST /translate_style - Vibe Engine: Applies specific cultural personas (Gen Alpha, Mak Cik Bawang, Penang Hokkien) to input text.

- POST /process_image - AR Lens Mapping: Processes an image, runs OCR bounding boxes, and returns coordinate data for the Flutter frontend to overlay interactive AR translations.

**Merchant & Infrastructure Endpoints:**

- GET /admin - Serves the HTML Merchant Portal for vendor onboarding.

- POST /api/extract_menu - Accepts an image upload (UploadFile) and uses Gemini Multimodal to extract and embellish handwritten menus.

- POST /api/save_stall - Syncs vendor data securely to Firebase Firestore.

- GET /api/generate_qr/{stall_id} - Generates and returns a downloadable PNG dynamic QR code on the fly.
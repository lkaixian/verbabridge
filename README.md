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

🛠️ Local Setup Instructions
1. Clone the repository

```bash
git clone https://github.com/lkaixian/verbabridge.git
cd verbabridge/server
```

2. Install dependencies

```bash
pip install -r requirements.txt
```

3. Configure Environment Variables & Secrets

- Create a .env file in the root directory and add your Gemini API Key:

```bash
GEMINI_API_KEY=your_api_key_here
```

- Firebase Setup: Place your serviceAccountKey.json in the root directory. 
(Note: For security reasons, this file is intentionally excluded via .gitignore and must be generated via the Firebase Console).

4. Boot the Server

```bash
uvicorn main:app --reload
```

The server will start at http://127.0.0.1:8000. Access the Merchant Portal at http://127.0.0.1:8000/admin.

**📚 API Architecture**
**Core Translation Endpoints:**

- POST /process_text - Deep Linguistic Analysis: Breaks down Kopitiam slang into literal, tonal, and phonetic mappings.

- POST /translate_style - Vibe Engine: Applies specific cultural personas (Gen Alpha, Mak Cik Bawang, Penang Hokkien) to input text.

- POST /process_image - AR Lens Mapping: Processes an image, runs OCR bounding boxes, and returns coordinate data for the Flutter frontend to overlay interactive AR translations.

**Merchant & Infrastructure Endpoints:**

- GET /admin - Serves the HTML Merchant Portal for vendor onboarding.

- POST /api/extract_menu - Accepts an image upload (UploadFile) and uses Gemini Multimodal to extract and embellish handwritten menus.

- POST /api/save_stall - Syncs vendor data securely to Firebase Firestore.

- GET /api/generate_qr/{stall_id} - Generates and returns a downloadable PNG dynamic QR code on the fly.
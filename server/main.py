import os
import logging
import firebase_admin
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.concurrency import run_in_threadpool
from firebase_admin import credentials, firestore
from pydantic import BaseModel
from dotenv import load_dotenv

# --- MODULAR IMPORTS ---
from core.cache import FileSystemCache
from core.ai import generate_translations       # The Main Logic
from core.style import translate_style          # The Style Engine
from core.utils import get_hokkien_romanization # The Penang Patcher

# --- SETUP & LOGGING ---
load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(levelname)s:\t  %(message)s")
logger = logging.getLogger(__name__)

app = FastAPI(title="VerbaBridge Backend", version="3.0.0")

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Allow all origins for the hackathon
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    logger.info("🔥 Firebase Admin initialized successfully")
except Exception as e:
    logger.error(f"Firebase initialization failed: {e}")

cache = FileSystemCache()

# --- DATA MODELS (Input Validation) ---
class UserInput(BaseModel):
    text: str

class StyleInput(BaseModel):
    text: str
    style: str  # e.g., "Gen Alpha", "Penang Hokkien"

# --- ROUTES ---

@app.get("/", response_class=HTMLResponse)
async def home():
    """Serves the Frontend Dashboard safely"""
    file_path = "static/index.html"
    if os.path.exists(file_path):
        return FileResponse(file_path)
    return HTMLResponse(content="<h1 style='color:red; font-family:sans-serif'>Error: static/index.html not found!</h1>", status_code=404)

# 1. CORE TRANSLATION (Text -> Culture)
@app.post("/process_text")
async def process_text(data: UserInput):
    logger.info(f"📩 Processing Text: '{data.text}'")

    # A. Check Cache (Speed Layer)
    cached_data = cache.get(data.text)
    if cached_data:
        logger.info("⚡ CACHE HIT")
        return {
            "status": "success", 
            "source": "cache", 
            "is_ambiguous": cached_data.get("is_ambiguous", False),
            "results": cached_data.get("results", [])
        }

    # B. Ask AI (Intelligence Layer)
    try:
        ai_data = await run_in_threadpool(generate_translations, data.text)
    except Exception as e:
        logger.error(f"AI Generation Error: {e}")
        raise HTTPException(status_code=500, detail="AI generation failed")

    if not ai_data or not ai_data.get("results"):
        raise HTTPException(status_code=500, detail="Invalid AI response format")

    # C. Apply Penang Hokkien Patch (Logic Layer)
    for res in ai_data.get("results", []):
        try:
            translations = res.get("translations", {})
            hokkien_data = translations.get("hokkien", {})
            
            if "hanzi" in hokkien_data:
                raw_hanzi = hokkien_data["hanzi"]
                hokkien_data["romanization"] = get_hokkien_romanization(raw_hanzi)
        except Exception as e:
            logger.warning(f"Failed to apply Taibun patch: {e}")

    # D. Save to Cache (Persistence Layer)
    cache.set(data.text, ai_data) 

    return {
        "status": "success", 
        "source": "gemini", 
        "is_ambiguous": ai_data.get("is_ambiguous", False),
        "results": ai_data["results"]
    }

# 2. STYLE TRANSFER (Text -> Slang)
@app.post("/translate_style")
async def api_translate_style(data: StyleInput):
    """Converts standard text into a specific persona."""
    logger.info(f"🎭 Applying Style [{data.style}] to: '{data.text}'")
    
    try:
        result = await run_in_threadpool(translate_style, data.text, data.style)
        return result
    except Exception as e:
        logger.error(f"Style Translation Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
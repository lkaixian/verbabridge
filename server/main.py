import os
import logging
import firebase_admin
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import credentials, firestore
from pydantic import BaseModel
from dotenv import load_dotenv
from fastapi import UploadFile, File, Form, Response

# --- MODULAR IMPORTS ---
from core.cache import FileSystemCache
from core.style import live_translate, live_translate_audio
from core.ai import generate_analogy, generate_analogy_audio, generate_gemini_tts
from core.style import live_translate

# --- SETUP & LOGGING ---
load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(levelname)s:\t  %(message)s")
logger = logging.getLogger(__name__)

app = FastAPI(title="VerbaBridge Backend", version="3.0.0")

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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

# --- DATA MODELS ---
class AnalogyInput(BaseModel):
    slang_text: str
    user_generation: str
    user_vibe: str

class LiveTranslateInput(BaseModel):
    text: str
    user_vibe: str

class SaveWordInput(BaseModel):
    user_id: str
    slang_word: str
    literal_translation: str
    successful_analogy: str
class AnalogyInput(BaseModel):
    slang_text: str
    user_generation: str
    user_vibe: str
    preferred_language: str = "en"

class LiveTranslateInput(BaseModel):
    text: str
    user_vibe: str
    preferred_language: str = "en"

# --- ROUTES ---

@app.get("/", response_class=HTMLResponse)
async def home():
    """Serves the Frontend Dashboard safely"""
    file_path = "static/index.html"
    if os.path.exists(file_path):
        return FileResponse(file_path)
    return HTMLResponse(content="<h1 style='color:red; font-family:sans-serif'>Error: static/index.html not found!</h1>", status_code=404)

# 1. ANALOGY ENGINE (Slang -> Cultural Analogies)
@app.post("/generate_analogy")
async def api_generate_analogy(data: AnalogyInput):
    """Takes a slang word and generates personalized cultural analogies."""
    logger.info(f"🧠 Analogy Request: '{data.slang_text}' | Gen: {data.user_generation} | Vibe: {data.user_vibe} | Lang: {data.preferred_language}")

    # Check cache first
    cache_key = f"{data.slang_text}|{data.user_generation}|{data.user_vibe}|{data.preferred_language}"
    cached_data = cache.get(cache_key)
    if cached_data:
        logger.info("⚡ CACHE HIT")
        return {"status": "success", "source": "cache", **cached_data}

    try:
        result = await generate_analogy(data.slang_text, data.user_generation, data.user_vibe, data.preferred_language)
        # Cache the result
        cache.set(cache_key, result)
        return {"status": "success", "source": "gemini", **result}
    except Exception as e:
        logger.error(f"Analogy Generation Error: {e}")
        raise HTTPException(status_code=500, detail="Analogy generation failed")


# 2. LIVE TRANSLATE (Slang -> Polite Senior-Friendly Language)
@app.post("/live_translate")
async def api_live_translate(data: LiveTranslateInput):
    """Translates slang text into polite, senior-friendly language."""
    logger.info(f"🔴 Live Translate: '{data.text}' | Vibe: {data.user_vibe} | Lang: {data.preferred_language}")

    try:
        result = await live_translate(data.text, data.user_vibe, data.preferred_language)
        return {"status": "success", **result}
    except Exception as e:
        logger.error(f"Live Translation Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# 3. SAVE WORD (My Words → Firestore)
@app.post("/api/save_word")
async def api_save_word(data: SaveWordInput):
    """Saves a slang word and its analogy to the user's vocabulary book."""
    logger.info(f"💾 Saving word '{data.slang_word}' for user: {data.user_id}")
    try:
        doc_ref = db.collection("saved_words").document()
        doc_ref.set({
            "user_id": data.user_id,
            "slang_word": data.slang_word,
            "literal_translation": data.literal_translation,
            "successful_analogy": data.successful_analogy,
            "saved_at": firestore.SERVER_TIMESTAMP,
        })
        return {"status": "success", "message": f"'{data.slang_word}' saved to My Words!"}
    except Exception as e:
        logger.error(f"Firestore Save Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to save word")

# 4. GET WORDS (My Words ← Firestore)
@app.get("/api/get_words/{user_id}")
async def api_get_words(user_id: str):
    """Retrieves all saved words for a user, sorted by newest first."""
    logger.info(f"📖 Fetching saved words for user: {user_id}")
    try:
        docs = (
            db.collection("saved_words")
            .where("user_id", "==", user_id)
            .order_by("saved_at", direction=firestore.Query.DESCENDING)
            .stream()
        )
        words = []
        for doc in docs:
            entry = doc.to_dict()
            entry["id"] = doc.id
            # Convert Firestore timestamp to ISO string for JSON
            if entry.get("saved_at"):
                entry["saved_at"] = entry["saved_at"].isoformat()
            words.append(entry)

        return {"status": "success", "count": len(words), "words": words}
    except Exception as e:
        logger.error(f"Firestore Read Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch saved words")
    
# 5. LIVE AUDIO TRANSLATE (Audio -> Gemini -> JSON)
@app.post("/live_translate_audio")
async def api_live_translate_audio(
    file: UploadFile = File(...),
    user_vibe: str = Form(...),
    preferred_language: str = Form("en")
):
    """Receives an audio file, sends it to Gemini, and returns the transcription + translation."""
    logger.info(f"🎤 Receiving Audio: {file.filename} | Vibe: {user_vibe}")
    
    try:
        audio_bytes = await file.read()
        
        # --- THE FIX IS HERE ---
        mime_type = file.content_type
        # If Flutter sends a generic binary stream, force it to m4a
        if not mime_type or mime_type in ["application/octet-stream", ""]:
            mime_type = "audio/mp4" # Gemini accepts audio/mp4 or audio/m4a for .m4a files
            
        logger.info(f"Audio Size: {len(audio_bytes)} bytes | Forced MIME: {mime_type}")
        
        result = await live_translate_audio(audio_bytes, mime_type, user_vibe, preferred_language)
        return {"status": "success", **result}
        
    except Exception as e:
        logger.error(f"Audio Processing Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to process audio")
    
# 6. AUDIO TO ANALOGY (One-Shot Lookup)
@app.post("/generate_analogy_audio")
async def api_generate_analogy_audio(
    file: UploadFile = File(...),
    user_generation: str = Form(...),
    user_vibe: str = Form(...),
    preferred_language: str = Form("en")
):
    """Receives an audio file and directly returns the Analogy swipe card data."""
    logger.info(f"🎤 Receiving Analogy Audio: {file.filename}")
    
    try:
        audio_bytes = await file.read()
        mime_type = file.content_type
        if not mime_type or mime_type in ["application/octet-stream", ""]:
            mime_type = "audio/mp4" 
            
        result = await generate_analogy_audio(audio_bytes, mime_type, user_generation, user_vibe, preferred_language)
        return {"status": "success", **result}
        
    except Exception as e:
        logger.error(f"Audio Analogy Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate audio analogy")
    
@app.get("/api/tts")
async def api_generate_tts(text: str, language: str):
    """Generates Audio from text using Gemini and returns the raw bytes."""
    try:
        # Catch both variables returned from ai.py
        audio_bytes, actual_mime_type = await generate_gemini_tts(text, language)
        
        # Use the actual mime type (e.g., 'audio/wav') instead of hardcoding mp3!
        return Response(content=audio_bytes, media_type=actual_mime_type)
    except Exception as e:
        logger.error(f"TTS Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate audio")
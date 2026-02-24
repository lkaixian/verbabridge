import os
import logging
import qrcode
import firebase_admin
from google.genai import types
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.concurrency import run_in_threadpool
from firebase_admin import credentials, firestore
from pydantic import BaseModel
from dotenv import load_dotenv
from io import BytesIO
from fastapi.responses import Response
from fastapi.responses import HTMLResponse
from fastapi import UploadFile, File

# --- MODULAR IMPORTS ---
from core.cache import FileSystemCache
from core.ai import generate_translations       # The Main Logic
from core.style import translate_style          # The "Brainrot" Engine
from core.ocr import process_image_remix        # The "Visual Remix" Engine
from core.utils import get_hokkien_romanization # The Penang Patcher

# --- SETUP & LOGGING ---
load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(levelname)s:\t  %(message)s")
logger = logging.getLogger(__name__)

app = FastAPI(title="VerbaBridge Backend", version="2.0.0")

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

class StallData(BaseModel):
    stall_id: str
    name: str
    menu_items: str

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

    # B. Ask AI (Intelligence Layer - Wrapped in Threadpool to prevent blocking)
    # Assuming generate_translations is a synchronous function making API calls
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
            # Safer dictionary traversal
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
        # Wrap in threadpool so it doesn't freeze the server waiting for Gemini
        result = await run_in_threadpool(translate_style, data.text, data.style)
        return result
    except Exception as e:
        logger.error(f"Style Translation Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# 3. VISUAL REMIX (Image -> Translated Overlay) 
@app.post("/process_image")
async def api_process_image(
    file: UploadFile = File(...), 
    style: str = Form("Gen Alpha") 
):
    """Takes an image, translates the text inside it, and overlays the translation."""
    logger.info(f"📸 Processing Image for style: [{style}]")
    try:
        image_bytes = await file.read()
        
        # This is already awaited, assuming process_image_remix is defined as 'async def'
        result = await process_image_remix(image_bytes, target_style=style)
        
        if "error" in result:
             return JSONResponse(content=result, status_code=500)

        return result

    except Exception as e:
        logger.error(f"❌ Vision Server Error: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)
    
# --- QR CODE GENERATION ---
@app.get("/api/generate_qr/{stall_id}")
async def generate_qr_endpoint(stall_id: str):
    """Generates a QR code PNG for a specific stall ID on the fly."""
    logger.info(f"🖨️ Generating QR for Stall: {stall_id}")
    
    # Create the QR Code
    qr = qrcode.QRCode(version=1, box_size=10, border=4)
    qr.add_data(stall_id)
    qr.make(fit=True)
    
    # Render to an image
    img = qr.make_image(fill_color="black", back_color="white")
    
    # Save to a bytes buffer
    buf = BytesIO()
    img.save(buf, format='PNG')
    buf.seek(0)
    
    # Return directly as an image file
    return Response(content=buf.getvalue(), media_type="image/png")

@app.post("/api/save_stall")
async def save_stall(data: StallData):
    """Saves or updates a stall's menu in Firestore"""
    logger.info(f"💾 Saving data for Stall: {data.stall_id}")
    try:
        # Write to Firestore collection 'stalls'
        db.collection("stalls").document(data.stall_id).set({
            "name": data.name,
            "menu_items": data.menu_items
        }, merge=True) # merge=True allows updating existing stalls without deleting other fields
        
        return {"status": "success", "message": "Menu saved to database!"}
    except Exception as e:
        logger.error(f"Firestore Save Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to save to database")

@app.get("/admin", response_class=HTMLResponse)
async def admin_dashboard():
    html_content = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>VerbaBridge | Merchant Portal</title>
        <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-gray-50 flex flex-col items-center justify-center min-h-screen p-6">
        
        <div class="max-w-lg w-full bg-white rounded-2xl shadow-xl overflow-hidden">
            <div class="bg-orange-500 p-6 text-center">
                <h1 class="text-2xl font-bold text-white">Merchant Portal</h1>
                <p class="text-orange-100 mt-2">Set up your stall & get your QR code</p>
            </div>
            
            <div class="p-8 space-y-4">
                <div>
                    <label class="block text-gray-700 text-sm font-bold mb-2">Unique Stall ID</label>
                    <input id="stall_id" type="text" placeholder="e.g., uncle_muthu_01" 
                        class="shadow appearance-none border rounded w-full py-3 px-4 text-gray-700 focus:ring-2 focus:ring-orange-500 outline-none">
                </div>

                <div>
                    <label class="block text-gray-700 text-sm font-bold mb-2">Stall Name</label>
                    <input id="stall_name" type="text" placeholder="e.g., Uncle Muthu Nasi Lemak" 
                        class="shadow appearance-none border rounded w-full py-3 px-4 text-gray-700 focus:ring-2 focus:ring-orange-500 outline-none">
                </div>

                <div>
                    <label class="block text-gray-700 text-sm font-bold mb-2">Menu Items</label>
                    
                    <div class="mb-3 p-3 bg-orange-50 border border-orange-200 rounded-lg flex items-center justify-between">
                        <span class="text-sm text-orange-800 font-semibold">✨ Auto-Extract from Photo</span>
                        <input type="file" id="menu_image" accept="image/*" class="hidden" onchange="extractFromImage()">
                        <button onclick="document.getElementById('menu_image').click()" 
                            class="bg-orange-500 hover:bg-orange-600 text-white text-xs font-bold py-2 px-3 rounded shadow">
                            📷 Upload Menu
                        </button>
                    </div>

                    <textarea id="menu_items" rows="5" placeholder="1. Nasi Lemak Biasa RM5&#10;2. Kopi O Peng RM2.50" 
                        class="shadow appearance-none border rounded w-full py-3 px-4 text-gray-700 focus:ring-2 focus:ring-orange-500 outline-none"></textarea>
                    <p id="extract-status" class="text-xs text-blue-500 mt-1 hidden">🧠 AI is reading the menu...</p>
                </div>
                
                <button onclick="saveAndGenerate()" id="submitBtn"
                    class="mt-4 w-full bg-gray-800 hover:bg-gray-900 text-white font-bold py-3 px-4 rounded transition duration-200">
                    Save Menu & Generate QR
                </button>

                <p id="status-msg" class="text-center text-sm font-bold hidden"></p>

                <div id="qr-result" class="hidden mt-6 flex flex-col items-center border-t pt-6">
                    <h3 class="font-bold text-gray-700 mb-2">Your Table QR Code</h3>
                    <div class="p-4 border-2 border-dashed border-gray-300 rounded-xl mb-4">
                        <img id="qr-image" src="" alt="QR Code" class="w-48 h-48 object-contain">
                    </div>
                    <button onclick="window.print()"
                        class="text-orange-500 font-semibold hover:text-orange-700 flex items-center gap-2">
                        🖨️ Print for Table
                    </button>
                </div>
            </div>
        </div>

        <script>
        async function extractFromImage() {
                const fileInput = document.getElementById('menu_image');
                const textArea = document.getElementById('menu_items');
                const statusText = document.getElementById('extract-status');
                
                if (fileInput.files.length === 0) return;

                const formData = new FormData();
                formData.append("file", fileInput.files[0]);

                // Show loading UI
                statusText.classList.remove('hidden');
                statusText.innerText = "🧠 AI is reading your menu... please wait.";
                textArea.disabled = true;

                try {
                    const response = await fetch('/api/extract_menu', {
                        method: 'POST',
                        body: formData
                    });
                    
                    const data = await response.json();
                    
                    if (data.status === "success") {
                        // Magically fill the text box!
                        textArea.value = data.extracted_text;
                        statusText.innerText = "✅ Menu extracted successfully! You can edit it below.";
                        statusText.className = "text-xs text-green-600 mt-1 font-bold block";
                    } else {
                        throw new Error(data.message);
                    }
                } catch (error) {
                    statusText.innerText = "❌ Failed to read image. Please type manually.";
                    statusText.className = "text-xs text-red-500 mt-1 font-bold block";
                } finally {
                    textArea.disabled = false;
                    // Reset the file input so they can upload a different image if needed
                    fileInput.value = ""; 
                }
            }

            async function saveAndGenerate() {
                const stallId = document.getElementById('stall_id').value.trim();
                const stallName = document.getElementById('stall_name').value.trim();
                const menuItems = document.getElementById('menu_items').value.trim();
                const statusMsg = document.getElementById('status-msg');
                const btn = document.getElementById('submitBtn');

                if (!stallId || !stallName || !menuItems) {
                    alert('Please fill in all fields!');
                    return;
                }

                // Show loading state
                btn.innerText = "Saving to database...";
                btn.disabled = true;
                statusMsg.className = "text-center text-sm font-bold text-blue-500 block";
                statusMsg.innerText = "Syncing with cloud...";

                try {
                    // 1. Send data to FastAPI to save in Firestore
                    const response = await fetch('/api/save_stall', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            stall_id: stallId,
                            name: stallName,
                            menu_items: menuItems
                        })
                    });

                    if (response.ok) {
                        // 2. If save is successful, trigger the QR Code image
                        document.getElementById('qr-image').src = `/api/generate_qr/${stallId}`;
                        document.getElementById('qr-result').classList.remove('hidden');
                        
                        statusMsg.className = "text-center text-sm font-bold text-green-500 block mt-2";
                        statusMsg.innerText = "✅ Successfully saved! QR Code ready.";
                    } else {
                        throw new Error("Failed to save data");
                    }
                } catch (error) {
                    statusMsg.className = "text-center text-sm font-bold text-red-500 block mt-2";
                    statusMsg.innerText = "❌ Error saving menu. Try again.";
                } finally {
                    // Reset button
                    btn.innerText = "Save Menu & Generate QR";
                    btn.disabled = false;
                }
            }
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.post("/api/extract_menu")
async def extract_menu_from_image(file: UploadFile = File(...)):
    """Uses Gemini to read a menu photo and dramatically over-exaggerate the food."""
    logger.info(f"📸 Extracting and embellishing menu from: {file.filename}")
    
    try:
        image_bytes = await file.read()
        
        # Prepare the image
        image_part = types.Part.from_bytes(
            data=image_bytes,
            mime_type=file.content_type or "image/jpeg"
        )
        
        # 🎭 THE DRAMATIC VLOGGER PROMPT 🎭
        prompt = """
        You are a dramatic, Michelin-star food critic and a hyper-enthusiastic Malaysian food vlogger. 
        Look at the attached Kopitiam menu. Extract every food and drink item along with its price.

        Here is the twist: You MUST write an insanely over-exaggerated, mouth-watering, and dramatic description for EVERY single item. Make it sound like the greatest culinary masterpiece on earth. Mention things like 'artisanal', 'heritage', 'pristine shores of Penang', 'divine', or 'celestial'.

        Format strictly as a numbered list:
        1. [Item Name] - [Dramatic Description] - [Price]
        
        Examples:
        1. Nasi Lemak Biasa - A celestial mound of fragrant basmati rice, lovingly bathed in freshly squeezed artisanal coconut milk from the pristine shores of Penang, accompanied by a rich, fiery sambal that dances on the palate. - RM5.00
        2. Kopi O Peng - A midnight-dark elixir brewed from legendary robusta beans, chilled to absolute perfection with glacial ice, delivering a caffeinated awakening straight to your soul. - RM2.50
        3. Roti Bakar - Thick-cut artisanal toast, kissed by the searing flames of a charcoal grill, slathered generously with liquid gold butter and heritage coconut jam. - RM3.00
        
        Do not include any intro or outro text. Just the formatted list based on the items in the image.
        """
        
        # Call Gemini
        response = client.models.generate_content(
            model="gemini-3-flash-preview", 
            contents=[image_part, prompt]
        )
        
        extracted_text = response.text.strip()
        return {"status": "success", "extracted_text": extracted_text}
        
    except Exception as e:
        logger.error(f"❌ Menu Extraction Error: {e}")
        return {"status": "error", "message": str(e)}
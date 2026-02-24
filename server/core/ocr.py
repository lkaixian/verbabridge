import json
import io
import base64
import time
import textwrap
import numpy as np
import PIL.Image
import PIL.ImageDraw
import PIL.ImageFont
import PIL.ImageOps  # Crucial for phone photos
import easyocr
from google.genai import types
from core.client import client
from fastapi.concurrency import run_in_threadpool

# --- INITIALIZE LOCAL CPU OCR ---
# We load this globally so it only boots into RAM once when the server starts.
# gpu=False forces it to use your Ryzen 5 5600H threads.
print("Loading Local OCR Engine (English, Malay, Chinese)...")
reader = easyocr.Reader(['en', 'ch_sim'], gpu=True) # You can add 'ms' for Malay if needed, but it may slow down the model loading.

# --- TEXT-ONLY TRANSLATION PROMPT ---
def GET_TEXT_REMIX_PROMPT(target_style, raw_texts):
    return f"""
  You are the VerbaBridge **Linguist**.
  Your task is to **decode** the provided text using your extensive knowledge of Malaysian dialects, Internet Slang (Gen Z/Alpha), and Kopitiam culture.

  ### 🎯 TARGET STYLE: {target_style}

  ### 🕵️‍♂️ ANALYSIS STEPS:
  1.  **CLASSIFY CONTEXT:** Determine if these texts belong to a **Menu** (Kopitiam/Mamak), a **Meme** (Brainrot), a **Signboard**, or a **Historical Plaque**.
  2.  **DECODE MEANING (Apply All Linguistic Filters):**
      * **The "Kopitiam Algorithm" (Food & Drink):**
          * **"O"** = Black / No Milk (e.g., Kopi O).
          * **"C"** = Evaporated Milk (e.g., Kopi C).
          * **"Kosong"** = No Sugar / Empty.
          * **"Peng" / "Bing"** = Iced.
          * **"Cham" / "Yuan Yang"** = Coffee + Tea Mix.
          * **"Ikat"** = Takeaway (Tied in a bag).
      * **The "Zoomer/Alpha" Filter (Memes):**
          * **Gen Z:** Cap, Bet, Bussin (Delicious), Sheesh.
          * **Gen Alpha:** Skibidi, Rizz, Gyatt, Fanum Tax, Ohio, Sigma.
          * **Italian Brainrot (2025):** Tung Tung Tung, Ballerina Cappuccina.
      * **The "Dialect" Filter (Local Lingo):**
          * **Hokkien:** "Char Koay Teow", "Cia" (Eat), "Bo Jio" (Didn't invite).
          * **Cantonese:** "Leng Zai" (Handsome/Waiter), "Dap Pau" (Takeaway).
          * **Malay Slang:** "Mata" (Police), "Ayam" (Noob/Prostitute).
  3.  **TRANSLATE:** Rewrite EACH item in the provided list into the requested **{target_style}**.

  ### 📥 INPUT TEXTS:
  {json.dumps(raw_texts)}

  ### 📝 OUTPUT REQUIREMENTS:
  Return ONLY a strict JSON object with a single array called "translations".
  The output array MUST have the exact same number of items as the input array, maintaining the exact same order. Do NOT include bounding box coordinates in your response, just the translated strings.
  
  Example format:
  {{
    "translations": ["Sigma Rice", "10 Fanum Tax", "Bussin feels"]
  }}
    """

# --- VISUAL HELPER: SMART COLOR SAMPLING ---
def _get_smart_bg_color(img_pil, box_pixels):
    """Samples the PERIMETER of the box using exact pixel coordinates."""
    try:
        ymin, xmin, ymax, xmax = box_pixels
        
        # Safety check for bounds
        if xmin >= xmax or ymin >= ymax: return (0, 0, 0, 220)

        region = img_pil.crop((xmin, ymin, xmax, ymax))
        img_np = np.array(region)

        if img_np.ndim == 3 and img_np.shape[0] > 0 and img_np.shape[1] > 0:
            top_edge = img_np[0, :, :]
            bottom_edge = img_np[-1, :, :]
            left_edge = img_np[:, 0, :]
            right_edge = img_np[:, -1, :]

            edges = np.concatenate((top_edge, bottom_edge, left_edge, right_edge), axis=0)
            median_color = np.median(edges, axis=0).astype(int)
        else:
             median_color = np.median(img_np, axis=(0, 1)).astype(int)
        
        return tuple(median_color[:3]) + (255,)
    except:
        return (0, 0, 0, 200)

def _is_dark_color(color_tuple):
    """Returns True if the background is dark (use White text)"""
    r, g, b = color_tuple[:3]
    brightness = (r * 299 + g * 587 + b * 114) / 1000
    return brightness < 128

def _process_hybrid_ocr(image_bytes, target_style):
    print(f"🖥️ Step 1: Local Ryzen OCR Scanning...")
    
    # 1. LOAD & PREPARE IMAGE
    try:
        original = PIL.Image.open(io.BytesIO(image_bytes))
        try:
            img = PIL.ImageOps.exif_transpose(original).convert("RGBA")
        except:
            img = original.convert("RGBA")
            
        # Optional: Resize massive images for faster CPU processing
        if img.width > 1200 or img.height > 1200:
            img.thumbnail((1200, 1200))
            
        width, height = img.size
        # Convert to RGB numpy array specifically for EasyOCR
        img_np = np.array(img.convert("RGB")) 
    except Exception as e:
        return {"error": f"Invalid Image: {str(e)}"}

    # 2. RUN LOCAL EASYOCR
    try:
        # EasyOCR returns: [([[x1,y1], [x2,y1], [x2,y2], [x1,y2]], 'Text', confidence)]
        ocr_results = reader.readtext(img_np)
    except Exception as e:
        return {"error": f"Local OCR Failed: {str(e)}"}

    if not ocr_results:
        return {"error": "No text found in image."}

    extracted_boxes = []
    raw_texts = []
    
    for bbox, text, prob in ocr_results:
        if prob > 0.25: # Filter out low-confidence artifacts
            # Extract absolute min/max pixel coordinates
            xs = [int(point[0]) for point in bbox]
            ys = [int(point[1]) for point in bbox]
            ymin, xmin, ymax, xmax = min(ys), min(xs), max(ys), max(xs)
            
            extracted_boxes.append([ymin, xmin, ymax, xmax])
            raw_texts.append(text)

    if not raw_texts:
        return {"error": "Text found, but confidence was too low."}

    # 3. CALL GEMINI FOR VIBE TRANSLATION (Text Only)
    print(f"☁️ Step 2: Gemini Vibe Translation ({target_style})...")
    prompt = GET_TEXT_REMIX_PROMPT(target_style, raw_texts)
    translated_texts = []

    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview", 
            contents=[prompt],
            config=types.GenerateContentConfig(response_mime_type="application/json")
        )
        clean_json = response.text.replace("```json", "").replace("```", "").strip()
        data = json.loads(clean_json)
        translated_texts = data.get("translations", raw_texts) # Fallback to raw if key missing
    except Exception as e:
        print(f"⚠️ Gemini Translation Failed: {e}. Falling back to original text.")
        translated_texts = raw_texts # Fallback so the app doesn't crash

    # 4. VISUAL EDITING (Local Rendering)
    # 4. VISUAL EDITING (Local Rendering)
    print(f"🎨 Step 3: Local CPU Rendering...")
    try:
        overlay = PIL.Image.new("RGBA", img.size, (0, 0, 0, 0))
        draw = PIL.ImageDraw.Draw(overlay)
        
        loop_count = min(len(extracted_boxes), len(translated_texts))
        
        for i in range(loop_count):
            box = extracted_boxes[i]
            text = translated_texts[i]
            
            if not text:
                continue
                
            ymin, xmin, ymax, xmax = box
            left, top, right, bottom = xmin, ymin, xmax, ymax
            
            box_w = right - left
            box_h = bottom - top

            # 1. Dynamic Font Sizing (Tuned down slightly for dense text)
            font_size = int(max(10, min(box_h * 0.85, 28))) 
            try:
                font = PIL.ImageFont.truetype("arial.ttf", font_size)
            except:
                font = PIL.ImageFont.load_default()
                font_size = 12

            # 2. Wrap Text
            approx_char_width = font_size * 0.55
            chars_per_line = max(12, int((box_w * 1.5) / approx_char_width)) 
            wrapped_lines = textwrap.wrap(text, width=chars_per_line)
            multiline_string = "\n".join(wrapped_lines)

            # 3. The "Erase" Background Layer (STRICT Boundaries!)
            bg_color = _get_smart_bg_color(img, box)
            
            # We ONLY paint over the original text bounds to hide it. No expanding!
            pad = 2
            draw.rectangle(
                [left - pad, top - pad, right + pad, bottom + pad], 
                fill=bg_color
            )

            # 4. Draw the Native Multiline Text with an AR STROKE
            center_x = left + (box_w / 2)
            start_y = top 
            
            # By using stroke_width, the text becomes a "sticker". 
            # Even if it overlaps another line slightly, it won't be a giant beige square blocking everything.
            draw.multiline_text(
                (center_x, start_y), 
                multiline_string, 
                font=font, 
                fill=(255, 255, 255, 255), # Pure White Text
                anchor="ma", 
                align="center",
                spacing=2,
                stroke_width=2,            # Thick outline
                stroke_fill=(0, 0, 0, 255) # Pure Black outline
            )

        # ... (Keep all your drawing logic above this) ...
        
        # Merge the transparent overlay layer with the original image
        final_img = PIL.Image.alpha_composite(img, overlay)

        buffered = io.BytesIO()
        final_img.save(buffered, format="PNG")
        img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")

        # --- NEW: Build the exact coordinate map for Flutter ---
        interactive_items = []
        for i in range(loop_count):
            ymin, xmin, ymax, xmax = extracted_boxes[i]
            interactive_items.append({
                "original": raw_texts[i],
                "translated": translated_texts[i],
                "box": {"ymin": ymin, "xmin": xmin, "ymax": ymax, "xmax": xmax}
            })

        return {
            "item_count": loop_count,
            "width": width,   # Crucial for Flutter scaling
            "height": height, # Crucial for Flutter scaling
            "items": interactive_items, # The interactive hotspot map
            "remixed_image": f"data:image/png;base64,{img_str}"
        }

    except Exception as draw_err:
        return {"error": f"Drawing Error: {str(draw_err)}"}

async def process_image_remix(image_bytes, target_style="Gen Alpha"):
    return await run_in_threadpool(_process_hybrid_ocr, image_bytes, target_style)
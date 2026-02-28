import json
import os
from google import genai
from google.genai import types
from dotenv import load_dotenv
from core.client import client

# Load API Key
load_dotenv()
API_KEY = os.getenv("GEMINI_API_KEY")

if not API_KEY:
    raise ValueError("❌ API Key missing! Check .env file.")

client = genai.Client(api_key=API_KEY)

# --- GENBRIDGE ANALOGY ENGINE ---

ANALOGY_PROMPT = """
You are GenBridge, a master cultural translator. Your personality is a mix of an Oxford Dictionary (for literal meanings), Urban Dictionary (for slang), and a Meme Historian (for internet brainrot).

The user belongs to the {user_generation} generation and their cultural background / dialect vibe is {user_vibe}. 

Input: "{slang_text}"

### 🧠 ANALYSIS LOGIC:
1. CHECK FOR AMBIGUITY (Crucial): Does this word have a standard meaning AND a street/meme meaning? (e.g., "Mata" = Eye OR Police; "Payung" = Umbrella OR Treat; "Ayam" = Chicken OR Noob/Prostitute).
2. DECODE THE LORE: Identify if it is Gen Z (Cap, Bet, Drip, Sus, Mid), Gen Alpha Brainrot (Skibidi, Gyatt, Rizz, Fanum Tax, Mewing), or Numeric Slang (520, 6 7, 26889).
3. BE DIRECT: Be raw, accurate, and uncensored when explaining the true context of internet culture.

Return a strict JSON object with this exact schema:
{{
  "slang_detected": "The core slang word or phrase normalized",
  "literal_translation": "Direct, simple meaning (Urban Dictionary style definition)",
  "analogies": [
    "A highly relatable cultural analogy tailored specifically to the '{user_vibe}' vibe. (e.g., If Penang Hokkien, compare it to local food, Jelutong market, or Kopitiam dynamics. Use their cultural lens).",
    "A relatable pop-culture or historical analogy tailored specifically for a {user_generation}. (e.g., If Boomer, compare to P. Ramlee, old radio shows, or 70s daily life. If Gen X, use 90s pop culture/VHS tape analogies)."
  ],
  "ambiguity_warning": "If the word has conflicting cultural or literal meanings (like 'Payung' or '6 7'), explain the different contexts briefly. Otherwise, output null."
}}
"""

AUDIO_ANALOGY_PROMPT = """
You are GenBridge, a master cultural translator. 
The user belongs to the {user_generation} generation and their cultural background / dialect vibe is {user_vibe}. 

Listen to the attached audio containing slang (e.g., Gen Z/Alpha brainrot, Manglish, Hokkien).

**CRITICAL INSTRUCTIONS:**
1. **NATIVE SCRIPT:** When writing the detected slang, you MUST use the original native script of the spoken language (e.g., use 漢字/Hanzi for Chinese/Hokkien like "你好". Do NOT use Pinyin like "ni hao").
2. **PRESERVE TITLES:** Do not ignore words like "Uncle", "Auntie", or "Bro" if they are spoken.

Return a strict JSON object with this exact schema:
{{
  "slang_detected": "The core slang phrase spoken in its NATIVE script (e.g., '你好 Uncle').",
  "literal_translation": "Direct, simple meaning in English",
  "analogies": [
    "A highly relatable cultural analogy tailored specifically to the '{user_vibe}' vibe.",
    "A relatable pop-culture or historical analogy tailored specifically for a {user_generation}."
  ],
  "ambiguity_warning": "If the word has conflicting cultural or literal meanings, explain briefly. Otherwise, output null."
}}
"""

async def generate_analogy(slang_text: str, user_generation: str, user_vibe: str):
    """
    Takes a slang word/phrase and generates culturally tailored analogies
    based on the user's generation and dialect/vibe.
    """
    print(f"🧠 GenBridge Analogy: '{slang_text}' | Gen: {user_generation} | Vibe: {user_vibe}")
    try:
        prompt = ANALOGY_PROMPT.format(
            slang_text=slang_text,
            user_generation=user_generation,
            user_vibe=user_vibe,
        )

        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.7,
            ),
        )
        return json.loads(response.text)
    except Exception as e:
        print(f"❌ GenBridge Error: {e}")
        return {
            "slang_detected": slang_text,
            "literal_translation": "Error generating translation",
            "analogies": [],
            "ambiguity_warning": str(e),
        }

async def generate_analogy_audio(audio_bytes: bytes, mime_type: str, user_generation: str, user_vibe: str):
    """
    Takes raw audio of a slang word and directly generates culturally tailored analogies in one shot.
    """
    print(f"🎙️ Audio Analogy | Gen: {user_generation} | Vibe: {user_vibe} | Size: {len(audio_bytes)} bytes")
    try:
        prompt = AUDIO_ANALOGY_PROMPT.format(
            user_generation=user_generation,
            user_vibe=user_vibe,
        )

        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=[
                types.Part.from_bytes(data=audio_bytes, mime_type=mime_type),
                prompt
            ],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.6,
            ),
        )
        return json.loads(response.text)
    except Exception as e:
        print(f"❌ Audio Analogy Error: {e}")
        raise e
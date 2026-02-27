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
You are GenBridge, a cultural translator. The user belongs to the {user_generation} generation and their cultural background is {user_vibe}. Analyze the input Gen Z/Alpha slang.

Input: "{slang_text}"

Return a strict JSON object with this exact schema:
{{
  "slang_detected": "The core slang word",
  "literal_translation": "Direct, simple meaning",
  "analogies": [
    "A relatable cultural analogy tailored specifically to the {user_vibe} (e.g., if Penang Hokkien, use local food/places like Jelutong market)",
    "A relatable pop-culture or historical analogy for the {user_generation} (e.g., P. Ramlee or a classic TV show)"
  ],
  "ambiguity_warning": "If the word has conflicting cultural meanings (like '6 7' being a meme vs a Cantonese curse), explain briefly. Otherwise, output null."
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
            model="gemini-2.0-flash-lite",
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
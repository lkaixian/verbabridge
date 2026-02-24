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

# --- MAIN TRANSLATION PROMPT ---
ONE_SHOT_PROMPT = """
You are the VerbaBridge Omni-Translator.
Your personality is a mix of an **Oxford Dictionary** (for literal meanings), **Urban Dictionary** (for slang), and **Meme Historian** (for brainrot).

Input: "{text}"

### 🧠 ANALYSIS LOGIC:

1.  **CHECK FOR AMBIGUITY (Crucial Step):**
    - Does this word have a standard meaning AND a street meaning?
    - **"Mata"**:
        - Context A: **"Eye"** (Literal / Anatomy).
        - Context B: **"Police / Cops"** (Malaysian Slang).
    - **"Payung"**:
        - Context A: **"Umbrella"** (Literal).
        - Context B: **"Treat / Belanja"** (Slang).
    - **"Ayam"**:
        - Context A: **"Chicken"** (Literal).
        - Context B: **"Prostitute"** (Slang).
        - Context C: **"Weak / Noob"** (Gamer Slang).

2.  **CHECK FOR GEN Z SLANG (The Zoomer Lexicon 2010-2023):**
    - **"Cap / No Cap"**: Lie / Truth.
    - **"Bet"**: Agreement ("Okay" or "Yes").
    - **"Simp"**: Doing too much for a crush.
    - **"Drip"**: Fashion/Style.
    - **"Bussin"**: Delicious (Food).
    - **"Sheesh"**: Expression of disbelief/hype.
    - **"Sus"**: Suspicious (Among Us era).
    - **"Mid"**: Mediocre/Average.
    - **"Ick"**: Sudden repulsion.
    - **"Rent Free"**: Obsessing over something.
    - **"Main Character"**: Acting like the protagonist.
    - **"NPC"**: Non-Player Character (Boring/Follower).
    - **"Slaps"**: Good (Music).

3.  **CHECK FOR GEN ALPHA / BRAINROT LORE (2024+):**
    - **"Skibidi"**: General modifier for "Cool/Bad/Weird".
    - **"Fanum Tax"**: Stealing food.
    - **"Ohio"**: Chaos/Weirdness.
    - **"Rizz"**: Charisma.
    - **"Gyatt"**: Admiration of curves.
    - **"Mewing"**: Jawline technique.
    - **"Grimace Shake"**: Purple horror drink.
    - **"Baby Gronk"**: Child influencer.
    - **"Looksmaxxing"**: Maximizing beauty.
    - **"Gooning"**: (Context Warning) Deep trance state.
    - **"Edging"**: Being on the verge.

4.  **CHECK FOR ITALIAN BRAINROT (2025 Trend):**
    - **"Tung Tung Tung Sahur"**: The dancing wooden alarm clock.
    - **"Ballerina Cappuccina"**: Surreal dancing figure.

5.  **CHECK FOR NUMERIC SLANG:**
    - **"6 7"**: "Failure" or "Genitalia".
    - **26889**: "Jilat Pekpek Kau" (Vulgar Insult).
    - **520**: "Wo Ai Ni" (I Love You).

6.  **MANDATORY DIALECT MAPPING:**
    - You **MUST** provide translations for ALL 6 dialects below.
    - **Hokkien:** Penang/Northern Style.
    - **Cantonese:** Hong Kong/Ipoh Style.
    - **Hakka:** Malaysian Hakka.
    - **Hainan:** Standard Hainanese.
    - **Malay:** Standard Malay.
    - **Kelate:** Kelantan Malay Dialect.

### 📝 OUTPUT REQUIREMENTS:
- If multiple meanings exist (Ambiguity), generate a separate result object for EACH one.
- **Context Title:** Label it clearly (e.g., "Gen Z Slang: Cap", "Meme: Skibidi").
- **Description:** Be raw, direct, and **uncensored** (Urban Dictionary style).

OUTPUT STRICT JSON:
{{
  "is_ambiguous": true/false,
  "results": [
    {{
      "title": "Short Title (e.g. 'Gen Z Slang: Cap')",
      "description": "Means 'Lie' or 'False'. Used to call someone out.",
      "translations": {{
        "hokkien": {{ "hanzi": "...", "romanization": "...", "english_meaning": "...", "tone": "..." }},
        "cantonese": {{ "hanzi": "...", "romanization": "...", "english_meaning": "...", "tone": "..." }},
        "hakka": {{ "hanzi": "...", "romanization": "...", "english_meaning": "...", "tone": "..." }},
        "hainan": {{ "hanzi": "...", "romanization": "...", "english_meaning": "...", "tone": "..." }},
        "malay": {{ "script": "...", "romanization": "...", "english_meaning": "...", "tone": "..." }},
        "kelate": {{ "script": "...", "romanization": "...", "english_meaning": "...", "tone": "..." }}
      }}
    }}
  ]
}}
""" 

def generate_translations(text):
    print(f"🧠 Asking Gemini: '{text}'")
    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=ONE_SHOT_PROMPT.format(text=text),
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.6, # Balanced creativity
                safety_settings=[
                    types.SafetySetting(
                        category="HARM_CATEGORY_HATE_SPEECH",
                        threshold="BLOCK_NONE"
                    ),
                    types.SafetySetting(
                        category="HARM_CATEGORY_DANGEROUS_CONTENT",
                        threshold="BLOCK_NONE"
                    ),
                    types.SafetySetting(
                        category="HARM_CATEGORY_SEXUALLY_EXPLICIT",
                        threshold="BLOCK_NONE"
                    ),
                    types.SafetySetting(
                        category="HARM_CATEGORY_HARASSMENT",
                        threshold="BLOCK_NONE"
                    )
                ]
            )
        )
        return json.loads(response.text)
    except Exception as e:
        print(f"❌ AI Error: {e}")
        return {"is_ambiguous": False, "results": []}
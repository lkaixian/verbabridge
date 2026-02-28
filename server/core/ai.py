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

LANG_MAP = {
    "en": "English",
    "ch": "Chinese (Mandarin, output strictly in 漢字/Hanzi characters)",
    "ms": "Malay (Bahasa Melayu)"
}

# --- GENBRIDGE ANALOGY ENGINE ---

ANALOGY_PROMPT = """
You are GenBridge, a master cultural translator. Your personality is a mix of an Oxford Dictionary (for literal meanings), Urban Dictionary (for slang), and a Meme Historian (for internet brainrot).

The user belongs to the {user_generation} generation and their cultural background / dialect vibe is {user_vibe}. 
Preferred Output Language: "{preferred_language}"

Input: "{slang_text}"

### 🧠 ANALYSIS LOGIC:
1. CHECK FOR AMBIGUITY (Crucial): Does this word have a standard meaning AND a street/meme meaning? (e.g., "Mata" = Eye OR Police; "Payung" = Umbrella OR Treat; "Ayam" = Chicken OR Noob/Prostitute).
2. DECODE THE LORE: Identify if it is Gen Z (Cap, Bet, Drip, Sus, Mid), Gen Alpha Brainrot (Skibidi, Gyatt, Rizz, Fanum Tax, Mewing), or Numeric Slang (520, 6 7, 26889).
3. BE DIRECT: Be raw, accurate, and uncensored when explaining the true context of internet culture.
4. OUTPUT LANGUAGE (CRITICAL): The values for `literal_translation`, `analogies`, and `ambiguity_warning` MUST be translated and written fluently in {preferred_language}. Keep the `slang_detected` in its original slang form.

Return a strict JSON object with this exact schema:
{{
  "slang_detected": "The core slang word or phrase normalized",
  "literal_translation": "Direct, simple meaning written in {preferred_language}",
  "analogies": [
    "A highly relatable cultural analogy tailored specifically to the '{user_vibe}' vibe, written in {preferred_language}.",
    "A relatable pop-culture or historical analogy tailored specifically for a {user_generation}, written in {preferred_language}."
  ],
  "ambiguity_warning": "If the word has conflicting meanings, explain briefly in {preferred_language}. Otherwise, output null."
}}
"""

AUDIO_ANALOGY_PROMPT = """
You are GenBridge, a master cultural translator. 
The user belongs to the {user_generation} generation and their cultural background / dialect vibe is {user_vibe}. 
Preferred Output Language: "{preferred_language}"

Listen to the attached audio containing slang (e.g., Gen Z/Alpha brainrot, Manglish, Hokkien).

**CRITICAL INSTRUCTIONS:**
1. **NATIVE SCRIPT:** When writing the detected slang, you MUST use the original native script of the spoken language (e.g., use 漢字/Hanzi for Chinese/Hokkien like "你好". Do NOT use Pinyin like "ni hao").
2. **PRESERVE TITLES:** Do not ignore words like "Uncle", "Auntie", or "Bro" if they are spoken.
3. **OUTPUT LANGUAGE (CRITICAL):** Translate the meanings and analogies into {preferred_language}.

Return a strict JSON object with this exact schema:
{{
  "slang_detected": "The core slang phrase spoken in its NATIVE script.",
  "literal_translation": "Direct, simple meaning translated into {preferred_language}",
  "analogies": [
    "A highly relatable cultural analogy tailored specifically to the '{user_vibe}' vibe, written in {preferred_language}.",
    "A relatable pop-culture or historical analogy tailored specifically for a {user_generation}, written in {preferred_language}."
  ],
  "ambiguity_warning": "If ambiguous, explain briefly in {preferred_language}. Otherwise, output null."
}}
"""

async def generate_analogy(slang_text: str, user_generation: str, user_vibe: str, preferred_language: str):
    """
    Takes a slang word/phrase and generates culturally tailored analogies
    based on the user's generation and dialect/vibe.
    """
    actual_language = LANG_MAP.get(preferred_language, "English")
    print(f"🧠 GenBridge Analogy: '{slang_text}' | Gen: {user_generation} | Vibe: {user_vibe} | Lang: {actual_language}")
    try:
        prompt = ANALOGY_PROMPT.format(
            slang_text=slang_text,
            user_generation=user_generation,
            user_vibe=user_vibe,
            preferred_language=actual_language,
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

async def generate_analogy_audio(audio_bytes: bytes, mime_type: str, user_generation: str, user_vibe: str, preferred_language: str):
    """
    Takes raw audio of a slang word and directly generates culturally tailored analogies in one shot.
    """
    actual_language = LANG_MAP.get(preferred_language, "English")
    print(f"🎙️ Audio Analogy | Gen: {user_generation} | Vibe: {user_vibe} | Lang: {actual_language} | Size: {len(audio_bytes)} bytes")
    try:
        prompt = AUDIO_ANALOGY_PROMPT.format(
            user_generation=user_generation,
            user_vibe=user_vibe,
            preferred_language=actual_language,
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

async def generate_gemini_tts(text: str, language: str):
    """Uses Gemini's native audio modality to generate TTS."""
    
    print(f"🔊 Generating TTS | Auto-Detecting Lang | Text: {text[:30]}...")
    
    try:
        # THE POLYGLOT DICTATION PROMPT:
        # Let the AI auto-detect the language based on the characters.
        prompt = (
            f"You are an automated voice generator. "
            f"Read the following text aloud naturally exactly as written. "
            f"Auto-detect the language based on the text provided. "
            f"Do not translate it, do not explain it, and do not generate any extra text. "
            f"Text to dictate: {text}"
        )
        
        response = client.models.generate_content(
            model="gemini-2.5-flash-preview-tts",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=types.SpeechConfig(
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(
                            voice_name="Aoede" 
                        )
                    )
                ),
                safety_settings=[
                    types.SafetySetting(
                        category=types.HarmCategory.HARM_CATEGORY_HATE_SPEECH,
                        threshold=types.HarmBlockThreshold.BLOCK_NONE,
                    ),
                    types.SafetySetting(
                        category=types.HarmCategory.HARM_CATEGORY_HARASSMENT,
                        threshold=types.HarmBlockThreshold.BLOCK_NONE,
                    ),
                    types.SafetySetting(
                        category=types.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
                        threshold=types.HarmBlockThreshold.BLOCK_NONE,
                    ),
                    types.SafetySetting(
                        category=types.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
                        threshold=types.HarmBlockThreshold.BLOCK_NONE,
                    ),
                ]
            ),
        )
        
        if not response.candidates or not response.candidates[0].content:
            finish_reason = response.candidates[0].finish_reason if response.candidates else "UNKNOWN"
            print(f"⚠️ TTS Blocked! Finish Reason: {finish_reason}")
            raise ValueError(f"Audio blocked by safety filters (Reason: {finish_reason}).")
            
        for part in response.candidates[0].content.parts:
            if part.inline_data and part.inline_data.data:
                return part.inline_data.data, part.inline_data.mime_type
                
        fallback_text = response.text if response.text else "Unknown Output"
        print(f"⚠️ TTS failed. Model returned text instead: {fallback_text}")
        raise ValueError("Model failed to return audio bytes.")
        
    except Exception as e:
        print(f"❌ TTS Error: {e}")
        raise e
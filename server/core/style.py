import json
from google.genai import types
from core.client import client


LANG_MAP = {
    "en": "English",
    "ch": "Chinese (Mandarin, output strictly in 漢字/Hanzi characters)",
    "ms": "Malay (Bahasa Melayu)"
}

# --- LIVE TRANSLATION PROMPT (TEXT) ---
LIVE_TRANSLATE_PROMPT = """
You are the GenBridge Linguistic Anthropologist and Empathy Translator.
Your goal is to bridge the generational gap by translating modern internet slang into clear, respectful language suitable for a senior citizen.

Target Audience Vibe: "{user_vibe}"
Preferred Output Language: "{preferred_language}" (e.g., 'en' for English, 'ch' for Chinese, 'ms' for Malay)
Input text: "{live_text}"

### 🧠 TRANSLATION LOGIC:
1. Identify the modern lore/slang.
2. **ZERO DROP RULE (CRITICAL):** You MUST translate the ENTIRE sentence. Do NOT delete English words, names, or titles (Uncle, Auntie, Bro, Boss).
3. **IDENTITY RULE (CRITICAL):** If the input is ALREADY polite and naturally matches the {user_vibe} AND the {preferred_language}, do NOT truncate or delete anything. Output the full, exact sentence as-is.
4. Apply the linguistic rules of the {user_vibe}.
5. **OUTPUT LANGUAGE (CRITICAL):** The final `translated_text` MUST be written in the {preferred_language} language. For example, if {preferred_language} is 'ch', write the translated sentence in Chinese characters while maintaining the {user_vibe} cultural nuance. If 'ms', write it in Malay. If 'en', write it in English.

Return ONLY a strict JSON object with this exact schema:
{{
  "translated_text": "The fully translated, complete sentence written in {preferred_language}.",
  "highlight_words": ["slang_word_1", "slang_word_2"]
}}
"""

async def live_translate(live_text: str, user_vibe: str, preferred_language: str):
    """
    Translates modern slang text into polite, senior-friendly language
    tailored to the user's cultural background and preferred language.
    """
    actual_language = LANG_MAP.get(preferred_language, "English")

    print(f"🔴 Live Translate: '{live_text}' | Vibe: {user_vibe} | Lang: {actual_language}")
    try:
        prompt = LIVE_TRANSLATE_PROMPT.format(
            live_text=live_text,
            user_vibe=user_vibe,
            preferred_language=actual_language,
        )

        response = client.models.generate_content(
            model="gemini-3.0-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.5,
            ),
        )
        return json.loads(response.text)
    except Exception as e:
        print(f"❌ Live Translate Error: {e}")
        return {
            "translated_text": live_text,
            "highlight_words": [],
        }

# --- LIVE TRANSLATION PROMPT (AUDIO) ---
AUDIO_TRANSLATE_PROMPT = """
You are the GenBridge Linguistic Anthropologist. 
The user's cultural background target is: {user_vibe}
Preferred Output Language: "{preferred_language}" (e.g., 'en' for English, 'ch' for Chinese, 'ms' for Malay)

Listen to the attached audio.
1. TRANSCRIBE: Transcribe exactly what was said. Use the NATIVE SCRIPT for the language spoken (e.g., Hanzi for Chinese/Hokkien, proper spelling for Malay). Keep English titles like "Uncle" or "Bro" intact.
2. TRANSLATE: Translate the ENTIRE meaning of the sentence into natural, fluent language suitable for a senior citizen with a {user_vibe} background. 
3. SEMANTIC OVERRIDE (CRITICAL): Translate the MEANING fluently. Do not do a broken word-for-word translation. 
4. ZERO DROP RULE (CRITICAL): Always preserve the titles and names (Uncle, Auntie, Bro). Never delete them.
5. IDENTITY RULE (CRITICAL): If the spoken audio perfectly matches the {user_vibe} AND the {preferred_language} already, just output the full transcribed text as the translated text. DO NOT truncate.
6. OUTPUT LANGUAGE (CRITICAL): The final `translated_text` MUST be output in the {preferred_language} language. Make sure the translated meaning aligns with the {user_vibe} but uses the {preferred_language} vocabulary/script.

Return ONLY a strict JSON object with this exact schema:
{{
  "original_transcription": "The exact words spoken.",
  "translated_text": "The FULL, complete, fluent translated sentence written in {preferred_language}.",
  "highlight_words": ["slang_word_1"]
}}
"""

async def live_translate_audio(audio_bytes: bytes, mime_type: str, user_vibe: str, preferred_language: str):
    """
    Sends raw audio to Gemini to transcribe and translate in one shot, 
    outputting in the preferred language.
    """
    actual_language = LANG_MAP.get(preferred_language, "English")

    print(f"🎙️ Live Audio Translate | Vibe: {user_vibe} | Lang: {preferred_language} | Size: {len(audio_bytes)} bytes")
    try:
        prompt = AUDIO_TRANSLATE_PROMPT.format(
            user_vibe=user_vibe,
            preferred_language=actual_language
        )

        response = client.models.generate_content(
            model="gemini-3.0-flash-preview", # Flash models are incredibly fast at audio
            contents=[
                types.Part.from_bytes(data=audio_bytes, mime_type=mime_type),
                prompt
            ],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.4, # Lower temperature for better transcription accuracy
            ),
        )
        return json.loads(response.text)
    except Exception as e:
        print(f"❌ Audio Translate Error: {e}")
        raise e
import json
from google.genai import types
from core.client import client

# --- LIVE TRANSLATION PROMPT ---
LIVE_TRANSLATE_PROMPT = """
You are GenBridge Live Translator. Your job is to translate modern internet slang and Gen Z/Alpha language into natural, polite language that a senior citizen can easily understand.

The user's cultural background is: {user_vibe}

Input text (may contain slang): "{live_text}"

### INSTRUCTIONS:
1. Identify all slang, abbreviations, or Gen Z/Alpha terms in the input.
2. Rewrite the ENTIRE sentence into clear, respectful, natural language suitable for a senior citizen with a {user_vibe} background.
3. List the specific slang words you detected and translated.

Return ONLY a strict JSON object with this exact schema:
{{
  "translated_text": "The fully translated, polite sentence.",
  "highlight_words": ["slang_word_1", "slang_word_2"]
}}
"""


async def live_translate(live_text: str, user_vibe: str):
    """
    Translates modern slang text into polite, senior-friendly language
    tailored to the user's cultural background.
    """
    print(f"🔴 Live Translate: '{live_text}' | Vibe: {user_vibe}")
    try:
        prompt = LIVE_TRANSLATE_PROMPT.format(
            live_text=live_text,
            user_vibe=user_vibe,
        )

        response = client.models.generate_content(
            model="gemini-2.0-flash-lite",
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
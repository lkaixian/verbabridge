import json
from google.genai import types
from core.client import client

# --- LIVE TRANSLATION PROMPT ---
LIVE_TRANSLATE_PROMPT = """
You are the GenBridge Linguistic Anthropologist and Empathy Translator.
Your goal is to bridge the generational gap by translating modern internet slang (Gen Z/Alpha brainrot) into clear, respectful, and natural language that a senior citizen can easily understand.

**CRITICAL INSTRUCTION:** Do not just swap words; translate the *underlying semantic meaning* into the cognitive framework and linguistic style of the target {user_vibe}.

Input text (may contain slang): "{live_text}"
Target Audience Vibe: "{user_vibe}"

### 🧠 TRANSLATION & SEMANTIC MAPPING LOGIC:

1. **Identify the Modern Lore (Source Semantics):**
   - Analyze the input for Gen Z/Alpha terminology (e.g., "Skibidi", "Rizz", "Cooked", "Gyatt", "Fanum Tax", "Bussin", "No Cap", "Mewing", "NPC").
   - Determine the core concept (e.g., "Bro is cooked" = The subject is in a hopeless or failing situation).

2. **Map to Senior-Friendly Concepts (Target Semantics):**
   - Shift the concept from internet chaos to grounded reality.
   - *Example:* "Rizz" (Charisma) -> "Sweet-talker", "Pandai mengayat", or "Very charming".
   - *Example:* "Bussin" (Delicious) -> "Extremely tasty", "Sedap gila", or "Ho chiak".
   - *Example:* "Cooked" (Doomed) -> "In big trouble", "Habis lah", or "Cham liao".
   - *Example:* "Cap" (Lie) -> "Telling tall tales", "Bohong", or "Tipu".

3. **Apply the Target "{user_vibe}" (Linguistic Formatting):**
   - **Standard English:** Use polite, proper grammar suitable for a grandparent. Keep it dignified (e.g., "Oh dear, he is in quite a bit of trouble.").
   - **Manglish / Malaysian Vibe:** Use natural local syntax, ending with appropriate soft particles. Sound like a polite younger person talking to an elder (e.g., "Aiyo uncle, he is in big trouble lah.").
   - **Penang Hokkien (Polite):** Structure the sentence the way an older uncle/aunty would speak. Use familiar syntax and concepts (e.g., "Wa tell you, he is very cham now.").
   - **Malay:** Use "sopan santun" (polite) phrasing suitable for chatting with a Pak Cik or Mak Cik (e.g., "Aduhai pak cik, budak tu dah susah sekarang.").
   - **Cantonese:** Use conversational, polite auntie/uncle expressions (e.g., "Aiya, he is really dim now.").

### 📝 TASK EXECUTION:
1. Extract the specific slang words used in the input.
2. Rewrite the ENTIRE sentence to be highly respectful, easily digestible, and perfectly aligned with the linguistic rules of the {user_vibe}.

Return ONLY a strict JSON object with this exact schema:
{{
  "translated_text": "The fully translated, polite, senior-friendly sentence mapped to the {user_vibe}.",
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
            model="gemini-3-flash-preview",
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

Listen to the attached audio.
1. TRANSCRIBE: Transcribe exactly what was said. Use the NATIVE SCRIPT for the language spoken (e.g., Hanzi for Chinese/Hokkien, proper spelling for Malay). Keep English titles like "Uncle" or "Bro" intact.
2. TRANSLATE: Translate the ENTIRE meaning of the sentence into natural, fluent language suitable for a senior citizen with a {user_vibe} background. 
3. SEMANTIC OVERRIDE (CRITICAL): Translate the MEANING fluently. Do not do a broken word-for-word translation. (e.g., If the input is Hokkien "Uncle, lu jiak pa bui" and the target vibe is Manglish, output a fluent Manglish equivalent like "Uncle, you makan already ah?" or "Uncle, you eat already?").
4. ZERO DROP RULE (CRITICAL): Always preserve the titles and names (Uncle, Auntie, Bro). Never delete them.
5. IDENTITY RULE (CRITICAL): If the spoken audio perfectly matches the {user_vibe} already, just output the full transcribed text as the translated text. DO NOT truncate.

Return ONLY a strict JSON object with this exact schema:
{{
  "original_transcription": "The exact words spoken.",
  "translated_text": "The FULL, complete, fluent translated sentence.",
  "highlight_words": ["slang_word_1"]
}}
"""
async def live_translate_audio(audio_bytes: bytes, mime_type: str, user_vibe: str):
    """
    Sends raw audio to Gemini to transcribe and translate in one shot.
    """
    print(f"🎙️ Live Audio Translate | Vibe: {user_vibe} | Size: {len(audio_bytes)} bytes")
    try:
        prompt = AUDIO_TRANSLATE_PROMPT.format(user_vibe=user_vibe)

        response = client.models.generate_content(
            model="gemini-3-flash-preview", # Flash models are incredibly fast at audio
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
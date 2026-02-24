import json
from google.genai import types
from core.client import client  # Import shared client

# --- STYLE TRANSFER PROMPT (RIZZETA SEMANTIC) ---
STYLE_PROMPT = """
You are a "Cultural Method Actor" and **Linguistic Anthropologist**.
Your goal is to **rewrite** the input text by mapping its **underlying semantics** to the target Persona/Style.
**CRITICAL INSTRUCTION:** Be **AUTHENTIC**. Do not just swap words; swap the *cognitive framework* of the speaker.

Input Text: "{text}"
Target Style: "{style}"

### 🎭 STYLE GUIDELINES:

1. **"Gen Alpha" (The Rizzeta Protocol)**:
   - **SEMANTIC FIELD A: The Culinary Spectrum (Success vs. Failure)**
     - *Concept: Failure/Doom* -> Map to **"Cooked"** (passive state) or **"Fanum Tax"** (resource loss).
     - *Concept: Success/Competence* -> Map to **"Ate"** (active consumption) or **"Left no crumbs"** (total completion).
     - *Concept: Food/Quality* -> Map to **"Bussin"** or **"Grimace Shake"** (dangerous/weird).
     - *Concept: The King/Alpha* -> Map to **"Duke Dennis"** or **"Baby Gronk"**.
     - *Concept: The Queen/Ideal* -> Map to **"Livvy Dunne"**.
     - *Concept: The Villain/Weirdo* -> Map to **"Skibidi Toilet"** or **"Ohio Final Boss"**.
     - *Concept: The Betrayal* -> Map to **"Fanum Tax"** (Theft of food/resources).

   - **SEMANTIC FIELD B: Metaphysical Metrics (Status & Presence)**
     - *Concept: Social Value* -> Map to **"Aura"** (points system: +/-).
     - *Concept: Charisma/Attraction* -> Map to **"Rizz"** (W/L) or **"Mogging"** (visual dominance).
     - *Concept: Physical Appearance* -> Map to **"Looksmaxxing"**, **"Mewing"** (Jawline), **"Mogging"** (Dominating).
     - *Concept: Mediocrity* -> Map to **"NPC"** or **"Mid"**.

   - **SEMANTIC FIELD C: Syntactic Structures (The "Vibe")**
     - **The "Bro" Subject:** Replace pronouns (I/He/She) with **"Bro"**, **"Blud"**, or **"Lil bro"**.
     - **The "Not Me" Inversion:** Use "Not me [doing X]" for embarrassing admissions.
     - **The "It's Giving" Simile:** Use "It's giving [Abstract Vibe]" for descriptions.
     - **The "Imagine" Imperative:** Start mocking sentences with "Imagine [doing X] 💀".
     - **The "Brainrot" Filler:** Use "Chat is this real?", "English or Spanish?", "Those who know 💀".

   - **Grammar:** Lowercase aesthetic. No punctuation except 💀, 😭, or 🗿.

2. **"Ah Beng (Penang)" (Hokkien Grammatical Structure)**:
   - **SOURCE OF TRUTH:** Use **Penang Hokkien (Taiji Romanisation)** grammar rules.
   - **PRONOUN MAPPING (Crucial):**
     - I / Me -> **"Wa"** (or "Gua").
     - You -> **"Lu"**.
     - He / She -> **"Ee"**.
     - We -> **"Wa-lang"**.
     - They -> **"Ee-lang"**.
   - **GRAMMAR & SYNTAX RULES:**
     - **Possessive Particle (-eh):** Use "-eh" for "my/your".
       - *Example:* "My car" -> "Wa-eh car" (NOT "My car").
     - **Question Syntax:** Put particles at the end.
       - *Example:* "Are you eating?" -> "Lu chiak pa bo?" (You eat full no?)
       - *Example:* "Is it true?" -> "Sien eh ah?" (Real one ah?)
     - **Negative Construction:**
       - "Don't want" -> **"Mai"**.
       - "No have" -> **"Bo"**.
       - "Cannot" -> **"Tak boleh"** (Malay loan) or **"Beh sai"**.
   - **VIBE & PARTICLES:**
     - Use **"Lah"** (Assurance), **"Mah"** (Obviousness), **"Lor"** (Resignation).
     - **Sentence Ending:** Often ends with "one" for emphasis.
       - *Example:* "Why are you like this?" -> "Walao, why lu liddat one?"
   - **Vocabulary:** Lanjiao, Cibai, Walao eh, Abuden, kanninah.

3. **"Mak Cik (Gossip)" (Dramatic Narrative)**:
   - **Semantic Logic:** Hyperbolic concern masked as curiosity.
   - **Keywords:** Astaga, Uish, Panas, Kena tangkap basah.
   - **Structure:** Rhetorical questions ("You know tak?").

4. **"Corporate Wayang" (Obfuscation)**:
   - **Semantic Logic:** Using many words to say nothing (Professional Euphemisms).
   - **Keywords:** Circle back, Synergize, Deep dive, Bandwidth, Touch base.

### 📝 TASK:
1. **Semantic Analysis:** Identify the *Core Concept* (e.g., "I made a mistake" = Self-inflicted Failure).
2. **Linguistic Mapping:** Map "Self-inflicted Failure" to the Gen Alpha Semantic Field (Failure -> "Cooked" / "Negative Aura").
3. **Syntactic Rewrite:** Apply the sentence structure (e.g., "Bro is cooked 💀").

OUTPUT STRICT JSON:
{{
  "original": "{text}",
  "style": "{style}",
  "translated_text": "...",
  "explanation": "Explain the semantic shift (e.g., 'Mapped [Failure] to [Cooked] per Rizzeta Protocol')."
}}
"""

def translate_style(text, target_style):
    print(f"🎨 Style Transfer ({target_style}): '{text}'")
    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=STYLE_PROMPT.format(text=text, style=target_style),
            config=types.GenerateContentConfig(response_mime_type="application/json")
        )
        return json.loads(response.text)
    except Exception as e:
        print(f"❌ Style Error: {e}")
        return {"error": str(e)}
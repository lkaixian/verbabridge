import re
import unicodedata
from taibun import Converter

# --- CONFIGURATION ---
# We use 'Tailo' as the base because it preserves tone marks accurately,
# which allows us to convert them to Penang style numbers later. 
try:
    t_converter = Converter(system='Tailo', dialect='south')
except ImportError:
    print("⚠ Warning: 'taibun' library not found. Install with: pip install taibun")
    t_converter = None

def _get_tone_number(word_with_diacritics):
    """
    Analyzes a Tâi-lô word and determines its Taiji Tone Number.
    Mapping:
    - No Mark -> 1
    - Acute (á) -> 4
    - Grave (à) -> 3
    - Circumflex (â) -> 2
    - Macron (ā) -> 33
    - Vertical (a̍) -> 1
    - Checked (p/t/k/h with no mark) -> 3
    """
    norm_word = unicodedata.normalize('NFD', word_with_diacritics)
    
    # 1. Check Diacritics
    for char in norm_word:
        if char == '\u0301': return 4  # Acute (á)
        if char == '\u0300': return 3  # Grave (à)
        if char == '\u0302': return 2  # Circumflex (â)
        if char == '\u0304': return 33 # Macron (ā)
        if char == '\u030d': return 1  # Vertical line (a̍)

    # 2. Check for "Checked Tones" (Stop consonants p, t, k, h without diacritics)
    # Remove all diacritics to check the base letters
    clean_word = "".join(c for c in norm_word if unicodedata.category(c) != 'Mn')
    if clean_word and clean_word[-1] in "ptkh":
        return 3

    # 3. Default (Tone 1)
    return 1

def penang_patch(tailo_text):
    """
    Converts Standard Taiwanese Tailo -> Penang Hokkien (Taiji Romanisation).
    Example: "Lí hó" -> "Lu1 ho4"
    """
    if not tailo_text: return ""
    
    # 1. Normalize
    text = tailo_text.lower().strip()

    # 2. Hardcoded Common Substitutions (Pronouns & Particles)
    # These are irregularities in Penang dialect compared to Taiwan
    replacements = {
        r'\blí\b': 'lu1',      # You
        r'\bgóa\b': 'wa1',     # Me
        r'\bguá\b': 'wa1',     # Me (variant)
        r'\bko̍k\b': 'lor1',    # Particle
        r'\bkoh\b': 'lor1',    # Particle
        r'\bni\b': 'ni1',      # Particle
        r'\btāi-tsì\b': 'dai3-ci3' # "Matter/Problem"
    }
    
    for pattern, repl in replacements.items():
        text = re.sub(pattern, repl, text)

    # 3. Word Processing Function
    def process_word(match):
        word = match.group(0)
        # Skip if it already has a number (handled by step 2)
        if re.search(r'\d', word): return word
        
        # Determine Tone
        tone = _get_tone_number(word)
        
        # Strip Diacritics for the final spelling
        # Normalize to NFD, filter out non-spacing marks (Mn)
        base_word = "".join(c for c in unicodedata.normalize('NFD', word) 
                            if unicodedata.category(c) != 'Mn')
        
        # Apply Penang Spelling Rules
        base_word = base_word.replace("ts", "c")   # ts -> c
        base_word = base_word.replace("tsh", "ch") # tsh -> ch
        base_word = base_word.replace("ue", "ua")  # ue -> ua
        base_word = base_word.replace("ing", "eng")# ing -> eng
        base_word = base_word.replace("oo", "or")  # oo -> or
        base_word = base_word.replace("ou", "au")  # ou -> au
        base_word = base_word.replace("ph", "p")   # (Optional preference, keep ph if standard)
        
        return f"{base_word}{tone}"

    # 4. Apply Logic to every word
    # Regex finds words that contain letters or diacritics
    cleaned_text = re.sub(r'(?<!\d)\b[a-z\u00C0-\u024F\u1E00-\u1EFF\u0300-\u036F]+\b', process_word, text)

    return cleaned_text

def get_hokkien_romanization(hanzi):
    """
    Main entry point: Hanzi -> Penang Romanization
    """
    if not t_converter:
        return "[Error: Library Missing]"
        
    try:
        # Get raw Tâi-lô from library (e.g., "Lí hó")
        raw_tailo = t_converter.get(hanzi)
        # Convert to Penang Style (e.g., "Lu1 ho4")
        return penang_patch(raw_tailo)
    except Exception as e:
        print(f"Hokkien conversion error for '{hanzi}': {e}")
        return ""
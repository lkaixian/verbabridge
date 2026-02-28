import os
import json
import hashlib
from core.client import CACHE_DIR

class FileSystemCache:
    def __init__(self, cache_file=None):
        """
        Initialize the cache system.
        
        Args:
            cache_file (str, optional): 
                - If provided (e.g., 'ocr_map.json'), runs in SINGLE FILE MODE (Map).
                  Used for: OCR translations (fast, small lookups).
                - If None, runs in DIRECTORY MODE (Hash -> File).
                  Used for: Main translation system (complex JSON objects).
        """
        # Ensure base cache directory exists
        if not os.path.exists(CACHE_DIR):
            os.makedirs(CACHE_DIR)
            print(f"📁 Created cache directory: {CACHE_DIR}/")

        self.cache_file = None
        self.memory_cache = {}

        if cache_file:
            # --- MODE A: SINGLE FILE (OCR) ---
            self.mode = "single_file"
            self.cache_file = os.path.join(CACHE_DIR, cache_file)
            self._load_single_file()
        else:
            # --- MODE B: DIRECTORY HASH (Main System) ---
            self.mode = "directory"

    # --- SHARED METHODS ---
    
    def get(self, key):
        if self.mode == "single_file":
            return self.memory_cache.get(key)
        else:
            return self._get_from_dir(key)

    def set(self, key, value):
        if self.mode == "single_file":
            self.memory_cache[key] = value
            self._save_single_file()
        else:
            self._save_to_dir(key, value)

    # --- DIRECTORY MODE HELPERS (Original Logic) ---

    def _get_hash(self, text):
        """
        Normalizes the text to prevent case-sensitivity cache misses,
        then generates an MD5 hash.
        """
        # 1. Normalize: convert to lowercase and remove accidental edge spaces
        normalized_text = str(text).strip().lower()
        
        # 2. Hash the normalized string
        return hashlib.md5(normalized_text.encode('utf-8')).hexdigest()

    def _get_from_dir(self, text):
        file_hash = self._get_hash(text)
        file_path = os.path.join(CACHE_DIR, f"{file_hash}.json")
        
        if os.path.exists(file_path):
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                print(f"⚠ Cache Read Error: {e}")
                return None
        return None

    def _save_to_dir(self, text, data):
        file_hash = self._get_hash(text)
        file_path = os.path.join(CACHE_DIR, f"{file_hash}.json")
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"⚠ Cache Write Error: {e}")

    # --- SINGLE FILE MODE HELPERS ---

    def _load_single_file(self):
        if os.path.exists(self.cache_file):
            try:
                with open(self.cache_file, 'r', encoding='utf-8') as f:
                    self.memory_cache = json.load(f)
            except Exception as e:
                print(f"⚠ Map Cache Read Error: {e}")
                self.memory_cache = {}
        else:
            self.memory_cache = {}

    def _save_single_file(self):
        try:
            with open(self.cache_file, 'w', encoding='utf-8') as f:
                json.dump(self.memory_cache, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"⚠ Map Cache Write Error: {e}")
import os
from google import genai
from dotenv import load_dotenv

# --- 1. CONFIGURATION SETUP ---
load_dotenv()

API_KEY = os.getenv("GEMINI_API_KEY")
if not API_KEY:
    # Print warning but don't crash immediately (allows debugging)
    print("⚠ WARNING: API Key not found in .env. Please set GEMINI_API_KEY.")

# Define the Cache Directory here so it's accessible globally
CACHE_DIR = "cache_data"

# --- 2. INITIALIZE CLIENT ---
# This 'client' object will be imported by ai.py, style.py, etc.
client = genai.Client(api_key=API_KEY)
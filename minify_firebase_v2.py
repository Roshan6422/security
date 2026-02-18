import base64
import json
import re

try:
    with open('backend_dart/.env', 'r', encoding='utf-8') as f:
        env_text = f.read()

    # Find the variable start
    marker = 'FIREBASE_SERVICE_ACCOUNT_BASE64="'
    start_idx = env_text.find(marker)
    if start_idx == -1:
        print("Error: Marker not found")
        exit(1)
        
    start_idx += len(marker)
    # Find the closing quote for THIS variable
    end_idx = env_text.find('"', start_idx)
    
    b64_raw = env_text[start_idx:end_idx]
    
    # Remove literal backslash-n, backslash-r, spaces, and real newlines
    b64_clean = b64_raw.replace('\\n', '').replace('\\r', '').replace('\n', '').replace('\r', '').replace(' ', '')
    
    # Fix padding
    missing_padding = len(b64_clean) % 4
    if missing_padding:
        b64_clean += '=' * (4 - missing_padding)
    
    # Decode
    decoded_bytes = base64.b64decode(b64_clean)
    data = json.loads(decoded_bytes.decode('utf-8'))
    
    # Minify JSON
    minified_json = json.dumps(data, separators=(',', ':'))
    
    # Re-encode
    final_b64 = base64.b64encode(minified_json.encode('utf-8')).decode('utf-8')
    
    print(final_b64)
except Exception as e:
    print(f"Error: {str(e)}")

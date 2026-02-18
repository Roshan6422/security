import base64
import json

try:
    with open('backend_dart/.env', 'rb') as f:
        data_bin = f.read()
    
    marker = b'FIREBASE_SERVICE_ACCOUNT_BASE64="'
    start_idx = data_bin.find(marker)
    if start_idx == -1:
        print("Error: Marker not found")
        exit(1)
        
    start_idx += len(marker)
    end_idx = data_bin.find(b'"', start_idx)
    if end_idx == -1:
        print("Error: End marker not found")
        exit(1)
        
    b64_raw = data_bin[start_idx:end_idx]
    
    # Clean the bytes
    # Remove literal \n (backslash then n), real newlines, and spaces
    cleaned = b64_raw.replace(b'\\n', b'').replace(b' ', b'').replace(b'\n', b'').replace(b'\r', b'')
    
    # Fix padding
    while len(cleaned) % 4 != 0:
        cleaned += b'='
        
    decoded = base64.b64decode(cleaned)
    # Decode the JSON from bytes using utf-8, but replace errors just in case
    json_str = decoded.decode('utf-8', errors='replace')
    json_data = json.loads(json_str, strict=False)
    minified = json.dumps(json_data, separators=(',', ':'))
    print(base64.b64encode(minified.encode('utf-8')).decode('utf-8'))
    
except Exception as e:
    print(f"Error: {e}")

import base64
import json

try:
    with open('backend_dart/.env', 'rb') as f:
        env_bin = f.read()

    marker = b'FIREBASE_SERVICE_ACCOUNT_BASE64="'
    start_idx = env_bin.find(marker)
    if start_idx == -1:
        print("Error: Marker not found")
        exit(1)
        
    start_idx += len(marker)
    end_idx = env_bin.find(b'"', start_idx)
    
    b64_part = env_bin[start_idx:end_idx]
    
    # Remove literal \n sequences and real newlines/spaces
    b64_clean = b64_part.replace(b'\\n', b'').replace(b'\\r', b'').replace(b'\n', b'').replace(b'\r', b'').replace(b' ', b'')
    
    # Fix padding
    missing_padding = len(b64_clean) % 4
    if missing_padding:
        b64_clean += b'=' * (4 - missing_padding)
    
    # Decode
    decoded_bytes = base64.b64decode(b64_clean)
    
    # Use latin-1 to avoid any encoding errors during string conversion
    decoded_str = decoded_bytes.decode('latin-1')
    
    # Use strict=False to allow control characters and some invalid escapes
    data = json.loads(decoded_str, strict=False)
    
    # Minify
    minified = json.dumps(data, separators=(',', ':'))
    
    # Encode
    final_b64 = base64.b64encode(minified.encode('utf-8')).decode('utf-8')
    print(final_b64)
except Exception as e:
    print(f"Error: {str(e)}")

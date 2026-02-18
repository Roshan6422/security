import base64

try:
    with open('backend_dart/.env', 'rb') as f:
        env_bin = f.read()

    marker = b'FIREBASE_SERVICE_ACCOUNT_BASE64="'
    start_idx = env_bin.find(marker)
    start_idx += len(marker)
    end_idx = env_bin.find(b'"', start_idx)
    b64_part = env_bin[start_idx:end_idx]
    
    b64_clean = b64_part.replace(b'\\n', b'').replace(b'\\r', b'').replace(b'\n', b'').replace(b'\r', b'').replace(b' ', b'')
    
    missing_padding = len(b64_clean) % 4
    if missing_padding:
        b64_clean += b'=' * (4 - missing_padding)
    
    decoded = base64.b64decode(b64_clean)
    # Print the first 1000 chars to see what's up
    print(decoded[:1000].decode('latin-1'))
except Exception as e:
    print(f"Error: {str(e)}")

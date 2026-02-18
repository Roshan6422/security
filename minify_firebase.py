import base64
import json
import re

try:
    with open('backend_dart/.env', 'r', encoding='utf-8') as f:
        env_text = f.read()

    # Extract content between FIREBASE_SERVICE_ACCOUNT_BASE64=" and the last "
    match = re.search(r'FIREBASE_SERVICE_ACCOUNT_BASE64=\"(.*?)\"', env_text, re.DOTALL)
    if not match:
        print("Error: Could not find FIREBASE_SERVICE_ACCOUNT_BASE64 in .env")
        exit(1)

    b64_raw = match.group(1)
    
    # Clean the string: remove literal \n, \r, spaces, and real newlines
    b64_clean = b64_raw.replace('\\n', '').replace('\\r', '').replace('\n', '').replace('\r', '').replace(' ', '')
    
    # Decode
    decoded_bytes = base64.b64decode(b64_clean)
    data = json.loads(decoded_bytes.decode('utf-8'))
    
    # Minify
    minified_json = json.dumps(data, separators=(',', ':'))
    
    # Re-encode
    final_b64 = base64.b64encode(minified_json.encode('utf-8')).decode('utf-8')
    
    with open('minified_b64.txt', 'w') as f:
        f.write(final_b64)
    print("Success")
except Exception as e:
    print(f"Error: {str(e)}")

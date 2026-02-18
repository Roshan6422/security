import base64
import json
import sys

try:
    with open(r'd:\security\firebase_key_b64.txt', 'r') as f:
        b64_content = f.read().strip()
    
    decoded_bytes = base64.b64decode(b64_content)
    decoded_text = decoded_bytes.decode('utf-8')
    data = json.loads(decoded_text)
    
    pk = data.get('private_key', '')
    print(f"Project ID: {data.get('project_id')}")
    print(f"Client Email: {data.get('client_email')}")
    print(f"Private Key length: {len(pk)}")
    print(f"Private Key starts with: {repr(pk[:50])}")
    print(f"Private Key ends with: {repr(pk[-50:])}")
    
    # Check for actual newlines vs \n strings
    if '\n' in pk:
        print("Found actual newlines in private_key")
    else:
        print("No actual newlines found in private_key")
        
    if '\\n' in pk:
        print("Found literal '\\n' strings in private_key")
    else:
        print("No literal '\\n' strings found in private_key")

except Exception as e:
    print(f"Error: {e}")

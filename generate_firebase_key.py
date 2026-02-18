import json
import base64
import os

def generate_key():
    try:
        # Read the service account key
        with open('d:/security/admin/serviceAccountKey.json', 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Minify the JSON (remove whitespace)
        minified_json = json.dumps(data, separators=(',', ':'))
        
        # Base64 encode
        b64_encoded = base64.b64encode(minified_json.encode('utf-8')).decode('utf-8')
        
        print("SUCCESS: Key generated successfully.")
        
        # Write to a file for easy copying/usage
        with open('d:/security/firebase_key_b64.txt', 'w', encoding='utf-8') as f:
            f.write(b64_encoded)
            
        print("Key saved to d:/security/firebase_key_b64.txt")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    generate_key()

import base64
import json
import re

def main():
    try:
        with open('backend_dart/.env', 'rb') as f:
            content = f.read()

        marker = b'FIREBASE_SERVICE_ACCOUNT_BASE64="'
        start = content.find(marker) + len(marker)
        end = content.find(b'"', start)
        b64_raw = content[start:end].decode('latin-1')
        
        # Keep ONLY valid base64 chars: A-Z, a-z, 0-9, +, /, =
        b64_clean = "".join(re.findall(r'[A-Za-z0-9+/=]', b64_raw))
        
        # Base64 length must be a multiple of 4.
        # If it's not, it's likely truncated.
        print(f"Original length: {len(b64_raw)}")
        print(f"Cleaned length: {len(b64_clean)}")
        
        # Attempt to fix padding by adding up to 3 '='
        for i in range(4):
            try:
                test_b64 = b64_clean + ("=" * i)
                decoded = base64.b64decode(test_b64)
                # Try to parse as JSON
                json_str = decoded.decode('utf-8', errors='ignore')
                # Remove any leading/trailing garbage
                json_str = json_str[json_str.find('{'):json_str.rfind('}')+1]
                data = json.loads(json_str, strict=False)
                minified = json.dumps(data, separators=(',', ':'))
                print("SUCCESS_START")
                print(base64.b64encode(minified.encode('utf-8')).decode('utf-8'))
                print("SUCCESS_END")
                return
            except Exception as e:
                continue
        
        print("Error: Could not decode even with padding fixes")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()

import base64
import json
import re

def main():
    try:
        # Read as bytes to avoid encoding issues
        with open('backend_dart/.env', 'rb') as f:
            content = f.read()

        marker = b'FIREBASE_SERVICE_ACCOUNT_BASE64="'
        start = content.find(marker)
        if start == -1:
            print("Error: Marker not found")
            return
        
        start += len(marker)
        end = content.find(b'"', start)
        if end == -1:
            print("Error: End marker not found")
            return
            
        b64_raw = content[start:end].decode('latin-1')
        
        # Keep only valid base64 chars
        b64_clean = "".join(re.findall(r'[A-Za-z0-9+/=]', b64_raw))
        
        # Decode
        decoded_bytes = base64.b64decode(b64_clean)
        
        # Clean the decoded JSON (handle potential literal newlines)
        decoded_str = decoded_bytes.decode('utf-8', errors='ignore')
        
        # Use simple cleaning: replace real control chars with nothing or escaped versions
        # Actually, let's just use json.loads with strict=False
        try:
            data = json.loads(decoded_str, strict=False)
        except:
            # Last resort: strip real newlines and try again
            data = json.loads(re.sub(r'[\r\n]+', ' ', decoded_str), strict=False)
            
        # Minify
        minified = json.dumps(data, separators=(',', ':'))
        
        # Encode
        print(base64.b64encode(minified.encode('utf-8')).decode('utf-8'))
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()

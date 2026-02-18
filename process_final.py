import base64
import json
import re

try:
    with open('raw_bytes.bin', 'rb') as f:
        raw_bytes = f.read()

    # The file contents might have literal \n \r sequences.
    # Base64 is strictly A-Z, a-z, 0-9, +, /, =.
    # Everything else (newlines, spaces, backslashes) should be removed.
    
    # regex to keep only valid base64 chars
    b64_str = "".join(re.findall(r'[A-Za-z0-9+/=]', raw_bytes.decode('ascii', errors='ignore')))
    
    print(f"Cleaned string length: {len(b64_str)}")
    
    # Try multiple padding lengths just in case it was truncated
    best_json = None
    for i in range(4):
        try:
            candidate = b64_str + ("=" * i)
            decoded = base64.b64decode(candidate)
            # UTF-8 decode
            text = decoded.decode('utf-8', errors='ignore')
            # Extract the JSON part if there is garbage around it
            start_bracket = text.find('{')
            end_bracket = text.rfind('}')
            if start_bracket != -1 and end_bracket != -1:
                json_part = text[start_bracket:end_bracket+1]
                # Minify it
                data = json.loads(json_part, strict=False)
                best_json = json.dumps(data, separators=(',', ':'))
                print(f"Success with +{i} padding chars")
                break
        except Exception:
            continue

    if best_json:
        # Final encode
        final_b64 = base64.b64encode(best_json.encode('utf-8')).decode('utf-8')
        print("---RESULT_START---")
        print(final_b64)
        print("---RESULT_END---")
    else:
        print("Failed to reconstruct valid JSON from the Base64 data.")

except Exception as e:
    print(f"Error during final processing: {e}")

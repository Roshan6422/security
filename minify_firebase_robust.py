import base64
import json
import re

try:
    with open('backend_dart/.env', 'rb') as f:
        env_bin = f.read()

    marker = b'FIREBASE_SERVICE_ACCOUNT_BASE64="'
    start_idx = env_bin.find(marker)
    start_idx += len(marker)
    end_idx = env_bin.find(b'"', start_idx)
    b64_part = env_bin[start_idx:end_idx]
    
    # Remove literal backslash-n, real newlines, and spaces from the BASE64 string itself
    b64_clean = b64_part.replace(b'\\n', b'').replace(b'\\r', b'').replace(b'\n', b'').replace(b'\r', b'').replace(b' ', b'')
    
    missing_padding = len(b64_clean) % 4
    if missing_padding:
        b64_clean += b'=' * (4 - missing_padding)
    
    # Get the decoded bytes
    decoded_bytes = base64.b64decode(b64_clean)
    
    # Convert to string, handling potential encoding issues
    try:
        decoded_text = decoded_bytes.decode('utf-8')
    except:
        decoded_text = decoded_bytes.decode('latin-1')

    # The issue: the decoded_text has literal newlines (0x0A) which are invalid in JSON strings.
    # We need to escape them. However, we also have nested escaped strings potentially.
    # A safe way is to replace all real newlines with "\n" 
    # BUT only if they are not already part of an escape sequence.
    # Actually, the most reliable way to fix a "pretty" JSON is to just strip the real newlines
    # if they are outside or inside.
    
    # Let's try to just parse it as "mostly" JSON by escaping control characters.
    def escape_control_chars(s):
        return "".join(i if ord(i) >= 32 else "\\n" if i == "\n" else "\\r" if i == "\r" else i for i in s)

    # But wait, if we just do that, we might break existing escapes.
    # Let's try to just load it with strict=False first
    try:
        data = json.loads(decoded_text, strict=False)
    except:
        # If that fails, it's really messy. Let's try to minify by regex.
        # Just remove all real newlines and extra spaces between tokens
        minified = re.sub(r'\s+', ' ', decoded_text)
        # This might still be invalid.
        # Let's try the escape_control_chars hack
        data = json.loads(escape_control_chars(decoded_text), strict=False)

    final_minified = json.dumps(data, separators=(',', ':'))
    print(base64.b64encode(final_minified.encode('utf-8')).decode('utf-8'))

except Exception as e:
    print(f"Error: {str(e)}")

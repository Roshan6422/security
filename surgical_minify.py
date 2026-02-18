import base64
import json

try:
    with open('backend_dart/.env', 'r') as f:
        lines = f.readlines()
    
    b64_str = ""
    target_line = ""
    for line in lines:
        if line.startswith('FIREBASE_SERVICE_ACCOUNT_BASE64'):
            target_line = line
            break
            
    if not target_line:
        print("Error: Line not found")
        exit(1)
        
    val = target_line.split('=', 1)[1].strip()
    if val.startswith('"') and val.endswith('"'):
        val = val[1:-1]
        
    # Clean the string
    cleaned = val.replace('\\n', '').replace(' ', '').replace('\n', '').replace('\r', '')
    
    # Fix padding
    while len(cleaned) % 4 != 0:
        cleaned += '='
        
    decoded = base64.b64decode(cleaned)
    json_data = json.loads(decoded.decode('utf-8'))
    minified = json.dumps(json_data, separators=(',', ':'))
    print(base64.b64encode(minified.encode('utf-8')).decode('utf-8'))
    
except Exception as e:
    print(f"Error: {e}")

import os

def update_env():
    try:
        # Read the key
        with open('d:/security/firebase_key_b64.txt', 'r', encoding='utf-8') as f:
            key_content = f.read().strip()
        
        env_path = 'd:/security/backend_dart/.env'
        
        # Read existing .env
        if os.path.exists(env_path):
            with open(env_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        else:
            lines = []
            
        new_lines = []
        key_found = False
        
        for line in lines:
            if line.startswith('FIREBASE_SERVICE_ACCOUNT_BASE64='):
                new_lines.append(f'FIREBASE_SERVICE_ACCOUNT_BASE64={key_content}\n')
                key_found = True
            else:
                new_lines.append(line)
                
        if not key_found:
            if new_lines and not new_lines[-1].endswith('\n'):
                 new_lines.append('\n')
            new_lines.append(f'FIREBASE_SERVICE_ACCOUNT_BASE64={key_content}\n')
            
        with open(env_path, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
            
        print("SUCCESS: .env updated successfully.")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    update_env()

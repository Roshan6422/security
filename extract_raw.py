import os

# Read the file as binary
with open('backend_dart/.env', 'rb') as f:
    data = f.read()

# Find the start of the value
marker = b'FIREBASE_SERVICE_ACCOUNT_BASE64="'
start = data.find(marker)
if start == -1:
    print("Marker not found")
    exit(1)

start += len(marker)
# Find the end quote
end = data.find(b'"', start)
if end == -1:
    print("End quote not found")
    exit(1)

# Extract and save the raw bytes to a file for inspection
raw_val = data[start:end]
with open('raw_bytes.bin', 'wb') as f:
    f.write(raw_val)

print(f"Extraction successful. Length: {len(raw_val)}")

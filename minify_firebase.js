const fs = require('fs');
try {
    let env = fs.readFileSync('backend_dart/.env', 'utf8');
    let b64 = env.split('FIREBASE_SERVICE_ACCOUNT_BASE64="')[1];
    b64 = b64.substring(0, b64.lastIndexOf('"'));

    // Remove all types of newlines and spaces
    b64 = b64.replace(/\\n/g, '').replace(/\n/g, '').replace(/\r/g, '').replace(/\s/g, '');

    const decoded = Buffer.from(b64, 'base64').toString('utf8');
    const json = JSON.parse(decoded);
    const minified = JSON.stringify(json);
    const result = Buffer.from(minified).toString('base64');

    fs.writeFileSync('minified_b64.txt', result);
    console.log('Success');
} catch (e) {
    console.error('Error:', e.message);
}

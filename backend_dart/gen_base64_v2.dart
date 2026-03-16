import 'dart:convert';
import 'dart:io';

void main() {
  final file = File(r'c:\Users\Roshan\AppData\Local\Temp\safeshell_sa.json');
  if (!file.existsSync()) {
    print('File not found');
    return;
  }
  final content = file.readAsStringSync();
  final base64 = base64Encode(utf8.encode(content));
  File('b64_utf8.txt').writeAsStringSync(base64);
  print('Done. Base64 written to b64_utf8.txt');
}

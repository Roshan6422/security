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
  print('--- BASE64 START ---');
  print(base64);
  print('--- BASE64 END ---');
}

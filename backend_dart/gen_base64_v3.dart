import 'dart:convert';
import 'dart:io';

void main() {
  final file = File(r'c:\Users\Roshan\AppData\Local\Temp\safeshell_sa.json');
  if (!file.existsSync()) {
    print('File not found');
    return;
  }
  final content = file.readAsStringSync();
  final dynamic json = jsonDecode(content);
  final minified = jsonEncode(json);
  final base64 = base64Encode(utf8.encode(minified));
  
  File('b64_minified.txt').writeAsStringSync(base64);
  print('Done. Minified Base64 written to b64_minified.txt');
  print('Original length: ${content.length}');
  print('Minified length: ${minified.length}');
  print('Base64 length: ${base64.length}');
}

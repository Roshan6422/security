import 'dart:convert';
import 'dart:io';

void main() {
  try {
    final b64 = File('b64_utf8.txt').readAsStringSync().trim();
    final bytes = base64Decode(b64);
    
    print('Total bytes: ${bytes.length}');
    
    // Reported error at offset 1806
    final start = 1800;
    final end = 1820;
    print('Bytes around 1806:');
    for (var i = start; i < end && i < bytes.length; i++) {
        print('$i: ${bytes[i]} (${String.fromCharCode(bytes[i])})');
    }

    // Try to find ANY non-ASCII or invalid bytes
    for (var i = 0; i < bytes.length; i++) {
        if (bytes[i] > 127) {
            print('Non-ASCII byte at $i: ${bytes[i]}');
        }
    }
  } catch (e) {
    print('Error: $e');
  }
}

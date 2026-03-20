import 'package:intl/intl.dart';

class DateFormatter {
  static String formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'unknown';
    
    DateTime dateTime;
    if (timestamp is DateTime) {
      dateTime = timestamp;
    } else if (timestamp is String) {
      dateTime = DateTime.parse(timestamp);
    } else {
      return 'unknown';
    }

    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return DateFormat('MMM d, yyyy').format(dateTime);
  }
}

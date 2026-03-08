import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Fire-and-forget audit logger for vault operations.
/// Logs are posted to the backend `/audit` endpoint.
class AuditLogger {
  static final ApiService _api = ApiService();

  /// Log a file upload event.
  static void logFileUpload(String fileName, String fileType, {String? fileUrl}) {
    _log(
      type: 'file',
      action: 'File Uploaded',
      detail: '$fileName',
      fileType: fileType,
      fileUrl: fileUrl,
    );
  }

  /// Log a file deletion (moved to recycle bin).
  static void logFileDelete(String fileName, String fileType) {
    _log(
      type: 'file',
      action: 'File Deleted',
      detail: '$fileName',
      fileType: fileType,
    );
  }

  /// Log a permanent deletion.
  static void logFilePermanentDelete(String fileName, String fileType) {
    _log(
      type: 'file',
      action: 'File Permanently Deleted',
      detail: '$fileName',
      fileType: fileType,
    );
  }

  /// Log a file view/open event.
  static void logFileView(String fileName, String fileType, {String? fileUrl}) {
    _log(
      type: 'file',
      action: 'File Viewed',
      detail: '$fileName',
      fileType: fileType,
      fileUrl: fileUrl,
    );
  }

  /// Log a file restore from recycle bin.
  static void logFileRestore(String fileName, String fileType) {
    _log(
      type: 'file',
      action: 'File Restored',
      detail: '$fileName',
      fileType: fileType,
    );
  }

  /// Log a login event.
  static void logLogin() {
    _log(type: 'security', action: 'Login', detail: 'User logged in');
  }

  /// Log a logout event.
  static void logLogout() {
    _log(type: 'security', action: 'Logout', detail: 'User logged out');
  }

  /// Log a note creation.
  static void logNoteCreate(String noteTitle) {
    _log(type: 'file', action: 'Note Created', detail: noteTitle, fileType: 'note');
  }

  /// Log a note deletion.
  static void logNoteDelete(String noteTitle) {
    _log(type: 'file', action: 'Note Deleted', detail: noteTitle, fileType: 'note');
  }

  /// Log a backup event.
  static void logBackup(String detail) {
    _log(type: 'backup', action: 'Backup Created', detail: detail);
  }

  /// Log a settings change.
  static void logSettingsChange(String detail) {
    _log(type: 'settings', action: 'Settings Changed', detail: detail);
  }

  /// Log recycle bin emptied.
  static void logEmptyBin(int count) {
    _log(type: 'file', action: 'Recycle Bin Emptied', detail: '$count items permanently deleted');
  }

  /// Internal fire-and-forget POST to /audit.
  static void _log({
    required String type,
    required String action,
    required String detail,
    String? fileType,
    String? fileUrl,
  }) {
    // Fire-and-forget — don't await, don't block UI
    _api.post('/audit', {
      'type': type,
      'action': action,
      'detail': detail,
      if (fileType != null) 'fileType': fileType,
      if (fileUrl != null) 'fileUrl': fileUrl,
    }).catchError((e) {
      if (kDebugMode) debugPrint('AuditLogger error: $e');
    });
  }
}

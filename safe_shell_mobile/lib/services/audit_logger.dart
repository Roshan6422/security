import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Fire-and-forget audit logger for vault operations.
/// Logs are posted to Firestore `security_logs` collection.
class AuditLogger {
  static void logFileUpload(String fileName, String fileType, {String? fileUrl}) {
    _log(
      type: 'file',
      action: 'File Uploaded',
      detail: fileName,
      fileType: fileType,
      fileUrl: fileUrl,
    );
  }

  /// Log a file deletion (moved to recycle bin).
  static void logFileDelete(String fileName, String fileType) {
    _log(
      type: 'file',
      action: 'File Deleted',
      detail: fileName,
      fileType: fileType,
    );
  }

  /// Log a permanent deletion.
  static void logFilePermanentDelete(String fileName, String fileType) {
    _log(
      type: 'file',
      action: 'File Permanently Deleted',
      detail: fileName,
      fileType: fileType,
    );
  }

  /// Log a file view/open event.
  static void logFileView(String fileName, String fileType, {String? fileUrl}) {
    _log(
      type: 'file',
      action: 'File Viewed',
      detail: fileName,
      fileType: fileType,
      fileUrl: fileUrl,
    );
  }

  /// Log a file restore from recycle bin.
  static void logFileRestore(String fileName, String fileType) {
    _log(
      type: 'file',
      action: 'File Restored',
      detail: fileName,
      fileType: fileType,
    );
  }

  /// Log a login event.
  static void logLogin() {
    _log(type: 'security', action: 'Login', detail: 'User logged in');
  }

  /// Log a failed login event.
  static void logLoginFailure(String email) {
    _log(type: 'security', action: 'Login Failed', detail: 'Failed login attempt for $email');
  }

  /// Log a logout event.
  static void logLogout() {
    _log(type: 'security', action: 'Logout', detail: 'User logged out');
  }

  /// Log a note creation.
  static void logNoteCreate(String noteTitle) {
    _log(type: 'file', action: 'Note Created', detail: noteTitle, fileType: 'note');
  }

  /// Log a note update.
  static void logNoteUpdate(String noteTitle) {
    _log(type: 'file', action: 'Note Updated', detail: noteTitle, fileType: 'note');
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      FirebaseFirestore.instance.collection('security_logs').add({
        'uid': uid,
        'type': type,
        'action': action,
        'detail': detail,
        'fileType': ?fileType,
        'fileUrl': ?fileUrl,
        'timestamp': DateTime.now().toIso8601String(),
        'ipAddress': '127.0.0.1', // Placeholder
        'deviceName': 'Mobile Device', // Placeholder
      });
    } catch (e) {
      if (kDebugMode) debugPrint('AuditLogger error: $e');
    }
  }
}

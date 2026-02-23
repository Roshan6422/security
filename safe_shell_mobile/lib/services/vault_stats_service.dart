import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

class VaultStats {
  final int totalCount;
  final int photoCount;
  final int videoCount;
  final int docCount;
  final int audioCount;
  final int zipCount;
  final int totalSizeBytes;
  final String sizeFormatted;

  VaultStats({
    required this.totalCount,
    required this.photoCount,
    required this.videoCount,
    required this.docCount,
    this.audioCount = 0,
    this.zipCount = 0,
    required this.totalSizeBytes,
    required this.sizeFormatted,
  });

  factory VaultStats.empty() => VaultStats(
    totalCount: 0,
    photoCount: 0,
    videoCount: 0,
    docCount: 0,
    audioCount: 0,
    zipCount: 0,
    totalSizeBytes: 0,
    sizeFormatted: '0 B',
  );
}

class VaultStatsService {
  final ApiService _apiService = ApiService();

  Future<VaultStats> getAggregatedStats() async {
    try {
      // 1. Fetch Cloud Stats
      Map<String, dynamic> cloudStats = {};
      try {
        final response = await _apiService.get('/vault/stats');
        if (response is Map<String, dynamic>) {
          cloudStats = response;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('VaultStatsService: Cloud stats fetch failed: $e');
      }

      // 2. Fetch Local Stats (Cloaked Files)
      final localStats = await _getLocalStats();

      // 3. Aggregate
      final int cloudTotalSize = cloudStats['totalSize'] is int ? cloudStats['totalSize'] as int : 0;
      final int cloudTotalCount = cloudStats['count'] is int ? cloudStats['count'] as int : 0;
      final int cloudPhotoCount = cloudStats['photoCount'] is int ? cloudStats['photoCount'] as int : 0;
      final int cloudVideoCount = cloudStats['videoCount'] is int ? cloudStats['videoCount'] as int : 0;
      final int cloudDocCount = cloudStats['docCount'] is int ? cloudStats['docCount'] as int : 0;
      final int cloudAudioCount = cloudStats['audioCount'] is int ? cloudStats['audioCount'] as int : 0;
      final int cloudZipCount = cloudStats['zipCount'] is int ? cloudStats['zipCount'] as int : 0;

      final int totalSizeBytes = cloudTotalSize + localStats['totalSize']!;
      final int totalCount = cloudTotalCount + localStats['totalCount']!;
      final int photoCount = cloudPhotoCount + localStats['photoCount']!;
      final int videoCount = cloudVideoCount + localStats['videoCount']!;
      final int docCount = cloudDocCount + localStats['docCount']!;
      final int audioCount = cloudAudioCount + localStats['audioCount']!;
      final int zipCount = cloudZipCount + localStats['zipCount']!;

      return VaultStats(
        totalCount: totalCount,
        photoCount: photoCount,
        videoCount: videoCount,
        docCount: docCount,
        audioCount: audioCount,
        zipCount: zipCount,
        totalSizeBytes: totalSizeBytes,
        sizeFormatted: _formatSize(totalSizeBytes),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('VaultStatsService Error: $e');
      return VaultStats.empty();
    }
  }

  Future<Map<String, int>> _getLocalStats() async {
    int totalCount = 0;
    int photoCount = 0;
    int videoCount = 0;
    int docCount = 0;
    int audioCount = 0;
    int zipCount = 0;
    int totalSize = 0;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cloakDir = Directory(p.join(appDir.path, 'vault_storage'));

      if (await cloakDir.exists()) {
        final entities = cloakDir.listSync(recursive: false);
        for (var entity in entities) {
          if (entity is File && entity.path.endsWith('.shell')) {
            totalCount++;
            final length = await entity.length();
            totalSize += length;

            final fileName = p.basename(entity.path).replaceAll('.shell', '').toLowerCase();
            if (_isPhoto(fileName)) {
              photoCount++;
            } else if (_isVideo(fileName)) {
              videoCount++;
            } else if (_isAudio(fileName)) {
              audioCount++;
            } else if (_isZip(fileName)) {
              zipCount++;
            } else {
              docCount++;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('VaultStatsService: Local stats scan failed: $e');
    }

    return {
      'totalCount': totalCount,
      'photoCount': photoCount,
      'videoCount': videoCount,
      'docCount': docCount,
      'audioCount': audioCount,
      'zipCount': zipCount,
      'totalSize': totalSize,
    };
  }

  bool _isPhoto(String name) {
    return name.endsWith('.jpg') || name.endsWith('.jpeg') ||
           name.endsWith('.png') || name.endsWith('.gif') ||
           name.endsWith('.webp') || name.endsWith('.bmp') ||
           name.endsWith('.tiff') || name.endsWith('.ico');
  }

  bool _isVideo(String name) {
    return name.endsWith('.mp4') || name.endsWith('.mov') ||
           name.endsWith('.avi') || name.endsWith('.mkv') ||
           name.endsWith('.3gp') || name.endsWith('.webm') ||
           name.endsWith('.flv') || name.endsWith('.wmv');
  }

  bool _isAudio(String name) {
    return name.endsWith('.mp3') || name.endsWith('.wav') ||
           name.endsWith('.aac') || name.endsWith('.flac') ||
           name.endsWith('.m4a') || name.endsWith('.ogg');
  }

  bool _isZip(String name) {
    return name.endsWith('.zip') || name.endsWith('.rar') ||
           name.endsWith('.7z') || name.endsWith('.tar') ||
           name.endsWith('.gz');
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

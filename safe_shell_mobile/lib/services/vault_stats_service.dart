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

      // 2. Map Cloud Stats
      final int totalSizeBytes = cloudStats['totalSize'] is int ? cloudStats['totalSize'] as int : 0;
      final int totalCount = cloudStats['count'] is int ? cloudStats['count'] as int : 0;
      final int photoCount = cloudStats['photoCount'] is int ? cloudStats['photoCount'] as int : 0;
      final int videoCount = cloudStats['videoCount'] is int ? cloudStats['videoCount'] as int : 0;
      final int docCount = cloudStats['docCount'] is int ? cloudStats['docCount'] as int : 0;
      final int audioCount = cloudStats['audioCount'] is int ? cloudStats['audioCount'] as int : 0;
      final int zipCount = cloudStats['zipCount'] is int ? cloudStats['zipCount'] as int : 0;

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


  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

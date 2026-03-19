import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/network_service.dart';
import '../core/constants.dart';

class VaultStats {
  final int totalCount;
  final int photoCount;
  final int videoCount;
  final int docCount;
  final int noteCount;
  final int audioCount;
  final int zipCount;
  final int totalSizeBytes;
  final String sizeFormatted;
  final List<dynamic> recentItems;

  VaultStats({
    required this.totalCount,
    required this.photoCount,
    required this.videoCount,
    required this.docCount,
    this.noteCount = 0,
    this.audioCount = 0,
    this.zipCount = 0,
    required this.totalSizeBytes,
    required this.sizeFormatted,
    this.recentItems = const [],
  });

  factory VaultStats.empty() => VaultStats(
    totalCount: 0,
    photoCount: 0,
    videoCount: 0,
    docCount: 0,
    noteCount: 0,
    audioCount: 0,
    zipCount: 0,
    totalSizeBytes: 0,
    sizeFormatted: '0 B',
    recentItems: [],
  );

  Map<String, dynamic> toJson() => {
    'totalCount': totalCount,
    'photoCount': photoCount,
    'videoCount': videoCount,
    'docCount': docCount,
    'noteCount': noteCount,
    'audioCount': audioCount,
    'zipCount': zipCount,
    'totalSizeBytes': totalSizeBytes,
    'sizeFormatted': sizeFormatted,
    'recentItems': recentItems,
  };

  factory VaultStats.fromJson(Map<String, dynamic> json) {
    return VaultStats(
      totalCount: json['count'] ?? json['totalCount'] ?? 0,
      photoCount: json['photoCount'] ?? 0,
      videoCount: json['videoCount'] ?? 0,
      docCount: json['docCount'] ?? 0,
      noteCount: json['noteCount'] ?? 0,
      audioCount: json['audioCount'] ?? 0,
      zipCount: json['zipCount'] ?? 0,
      totalSizeBytes: json['totalSize'] ?? json['totalSizeBytes'] ?? 0,
      sizeFormatted: json['sizeFormatted'] ?? _formatSizeStatic(json['totalSize'] ?? 0),
      recentItems: json['recentItems'] ?? [],
    );
  }

  static String _formatSizeStatic(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class VaultStatsService {
  static const _cacheKey = 'vault_stats_cache';
  final _storage = const FlutterSecureStorage();

  // Cache SharedPreferences to avoid repeated platform-channel round-trips
  static SharedPreferences? _prefs;
  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<VaultStats> getAggregatedStats({Function(VaultStats)? onRefresh}) async {
    VaultStats? cached;
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        cached = VaultStats.fromJson(jsonDecode(raw));
      }
    } catch (_) {}

    _fetchFresh().then((fresh) {
      if (onRefresh != null && fresh != null) onRefresh(fresh);
    });

    return cached ?? VaultStats.empty();
  }

  Future<VaultStats?> fetchFresh() => _fetchFresh();

  Future<VaultStats?> _fetchFresh() async {
    try {
      final token = await _storage.read(key: AppConstants.keyToken);
      if (token == null) return null;

      final response = await NetworkService.client.get(
        Uri.parse('${AppConstants.baseUrl}/vault/stats'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(NetworkService.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats = VaultStats.fromJson(data);

        // Cache for next launch
        try {
          final prefs = await _getPrefs();
          await prefs.setString(_cacheKey, jsonEncode(stats.toJson()));
        } catch (_) {}

        return stats;
      } else {
        debugPrint('VaultStatsService: Backend error ${response.statusCode}');
        return null;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('VaultStatsService Error (Offline?): $e');
      return null;
    }
  }
}

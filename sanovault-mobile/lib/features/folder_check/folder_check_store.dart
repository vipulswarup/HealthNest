import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FolderCheckPairing {
  const FolderCheckPairing({
    required this.patientId,
    required this.bookmark,
    required this.path,
    required this.displayPath,
    this.exclusions = const [],
  });

  final String patientId;
  final String bookmark;
  final String path;
  final String displayPath;
  final List<String> exclusions;

  FolderCheckPairing copyWith({
    String? bookmark,
    String? path,
    String? displayPath,
    List<String>? exclusions,
  }) {
    return FolderCheckPairing(
      patientId: patientId,
      bookmark: bookmark ?? this.bookmark,
      path: path ?? this.path,
      displayPath: displayPath ?? this.displayPath,
      exclusions: exclusions ?? this.exclusions,
    );
  }

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'bookmark': bookmark,
        'path': path,
        'displayPath': displayPath,
        'exclusions': exclusions,
      };

  factory FolderCheckPairing.fromJson(Map<String, dynamic> json) {
    return FolderCheckPairing(
      patientId: json['patientId'] as String? ?? '',
      bookmark: json['bookmark'] as String? ?? '',
      path: json['path'] as String? ?? '',
      displayPath: json['displayPath'] as String? ?? json['path'] as String? ?? '',
      exclusions: (json['exclusions'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }
}

class FolderCheckStore {
  static String _key(String patientId) => 'folder_check_pairing_v1_$patientId';

  Future<FolderCheckPairing?> load(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(patientId));
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return FolderCheckPairing.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> save(FolderCheckPairing pairing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(pairing.patientId), jsonEncode(pairing.toJson()));
  }
}

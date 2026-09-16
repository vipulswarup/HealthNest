import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class FolderCheckFile {
  const FolderCheckFile({
    required this.path,
    required this.relativePath,
    required this.parentName,
    required this.name,
    required this.size,
    required this.kind,
    required this.onlineOnly,
    this.sha256,
  });

  final String path;
  final String relativePath;
  final String parentName;
  final String name;
  final int size;
  final String kind;
  final bool onlineOnly;
  final String? sha256;

  factory FolderCheckFile.fromMap(Map<dynamic, dynamic> json) {
    return FolderCheckFile(
      path: json['path'] as String? ?? '',
      relativePath: json['relativePath'] as String? ?? '',
      parentName: json['parentName'] as String? ?? '',
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? '',
      onlineOnly: json['onlineOnly'] == true,
      sha256: json['sha256'] as String?,
    );
  }
}

class FolderCheckBookmark {
  const FolderCheckBookmark({required this.bookmark, required this.path, required this.displayPath});
  final String bookmark;
  final String path;
  final String displayPath;
}

class FolderCheckChannel {
  FolderCheckChannel([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('sanovault/folder_check');

  final MethodChannel _channel;

  static bool get supported => !kIsWeb && Platform.isMacOS;

  Future<FolderCheckBookmark?> pickFolder() async {
    final json = await _channel.invokeMapMethod<String, dynamic>('pickFolder');
    if (json == null) return null;
    return FolderCheckBookmark(
      bookmark: json['bookmark'] as String? ?? '',
      path: json['path'] as String? ?? '',
      displayPath: json['displayPath'] as String? ?? json['path'] as String? ?? '',
    );
  }

  Future<FolderCheckBookmark> restoreBookmark(String bookmark) async {
    final json = await _channel.invokeMapMethod<String, dynamic>('restoreBookmark', {
      'bookmark': bookmark,
    });
    if (json == null) throw PlatformException(code: 'RESTORE_FAILED', message: 'Could not open the saved folder.');
    return FolderCheckBookmark(
      bookmark: json['bookmark'] as String? ?? bookmark,
      path: json['path'] as String? ?? '',
      displayPath: json['displayPath'] as String? ?? json['path'] as String? ?? '',
    );
  }

  Future<void> stopAccess() => _channel.invokeMethod<void>('stopAccess');

  Future<List<String>> listSubfolders(String path) async {
    final json = await _channel.invokeListMethod<dynamic>('listSubfolders', {'path': path});
    return (json ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<List<FolderCheckFile>> scanTree(String path, List<String> exclusions) async {
    final json = await _channel.invokeListMethod<dynamic>('scanTree', {
      'path': path,
      'exclusions': exclusions,
    });
    return (json ?? const [])
        .whereType<Map>()
        .map((item) => FolderCheckFile.fromMap(item))
        .where((item) => item.path.isNotEmpty)
        .toList();
  }

  Future<Uint8List> readFile(String path) async {
    final bytes = await _channel.invokeMethod<dynamic>('readFile', {'path': path});
    if (bytes is Uint8List) return bytes;
    if (bytes is List<int>) return Uint8List.fromList(bytes);
    throw PlatformException(code: 'READ_FAILED', message: 'Could not read $path');
  }

  Future<String?> pdfWorkingPassword(String path, List<String> passwords) async {
    final json = await _channel.invokeMapMethod<String, dynamic>('pdfStatus', {
      'path': path,
      'passwords': passwords,
    });
    if (json == null || json['locked'] != true) return '';
    return json['password'] as String?;
  }
}

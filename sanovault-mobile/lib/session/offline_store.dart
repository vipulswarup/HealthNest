import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Small, device-scoped persistence layer for the offline-first mobile cache.
///
/// The cache contains metadata and lightweight tracking data. Large document
/// attachments live in the app documents directory until they can be uploaded.
/// The cache is cleared on sign-out so one account cannot see another's data.
class OfflineStore {
  OfflineStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _cachePrefix = 'offline.cache.';
  static const _pendingKey = 'offline.pending.v1';
  static const _lastOnlineKey = 'offline.last_online';
  static const _knownKeys = 'offline.known_keys.v1';
  static const maxAutomaticDocumentBytes = 500 * 1024 * 1024;

  Future<Directory> _attachmentsDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/offline-attachments');
    if (!directory.existsSync()) await directory.create(recursive: true);
    return directory;
  }

  Future<String> writeAttachment(String id, List<int> bytes) async {
    final directory = await _attachmentsDirectory();
    final file = File('${directory.path}/$id.bin');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<List<int>> readAttachment(String path) => File(path).readAsBytes();

  Future<void> deleteAttachment(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<Directory> _documentsDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/offline-documents');
    if (!directory.existsSync()) await directory.create(recursive: true);
    return directory;
  }

  Future<void> writeDocument(
    String id,
    List<int> bytes, {
    String? fileName,
    required bool isPdf,
  }) async {
    final directory = await _documentsDirectory();
    final path = '${directory.path}/$id.bin';
    await File(path).writeAsBytes(bytes, flush: true);
    final previous = await readJson('document.$id');
    await writeJson('document.$id', {
      'path': path,
      'fileName': fileName,
      'isPdf': isPdf,
      'size': bytes.length,
      'pinned': previous is Map && previous['pinned'] == true,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await _evictDocuments(except: id);
  }

  Future<Map<String, dynamic>?> documentInfo(String id) async {
    final value = await readJson('document.$id');
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Future<List<int>?> readDocument(String id) async {
    final info = await documentInfo(id);
    final path = info?['path'];
    if (path is! String) return null;
    final file = File(path);
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> setDocumentPinned(String id, bool pinned) async {
    final info = await documentInfo(id);
    if (info == null) return;
    info['pinned'] = pinned;
    await writeJson('document.$id', info);
  }

  Future<void> _evictDocuments({required String except}) async {
    final entries = <Map<String, dynamic>>[];
    for (final key in await _knownStorageKeys()) {
      if (!key.startsWith('${_cachePrefix}document.')) continue;
      final id = key.substring('${_cachePrefix}document.'.length);
      final info = await documentInfo(id);
      if (info != null) entries.add({'id': id, 'info': info});
    }
    var total = entries.fold<int>(
      0,
      (sum, entry) => sum + ((entry['info']['size'] as num?)?.toInt() ?? 0),
    );
    if (total <= maxAutomaticDocumentBytes) return;
    entries.sort(
      (a, b) => '${a['info']['updatedAt'] ?? ''}'.compareTo(
        '${b['info']['updatedAt'] ?? ''}',
      ),
    );
    for (final entry in entries) {
      if (total <= maxAutomaticDocumentBytes) break;
      final id = entry['id'] as String;
      final info = Map<String, dynamic>.from(entry['info'] as Map);
      if (id == except || info['pinned'] == true) continue;
      final path = info['path'];
      if (path is String) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      await _storage.delete(key: '${_cachePrefix}document.$id');
      total -= (info['size'] as num?)?.toInt() ?? 0;
    }
  }

  Future<void> writeJson(String key, Object value) async {
    final storageKey = '$_cachePrefix$key';
    await _storage.write(key: storageKey, value: jsonEncode(value));
    final keys = await _knownStorageKeys();
    if (!keys.contains(storageKey)) {
      keys.add(storageKey);
      await _storage.write(key: _knownKeys, value: jsonEncode(keys));
    }
  }

  Future<dynamic> readJson(String key) async {
    final value = await _storage.read(key: '$_cachePrefix$key');
    if (value == null || value.isEmpty) return null;
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> markOnline() async {
    await _storage.write(
      key: _lastOnlineKey,
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> lastOnline() async {
    final value = await _storage.read(key: _lastOnlineKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<List<String>> _knownStorageKeys() async {
    final value = await _storage.read(key: _knownKeys);
    if (value == null) return [];
    try {
      return (jsonDecode(value) as List).whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pending() async {
    final value = await _storage.read(key: _pendingKey);
    if (value == null || value.isEmpty) return [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addPending(Map<String, dynamic> operation) async {
    final items = await pending();
    items.add(operation);
    await _writePending(items);
  }

  Future<void> replacePending(List<Map<String, dynamic>> operations) =>
      _writePending(operations);

  Future<void> _writePending(List<Map<String, dynamic>> operations) =>
      _storage.write(key: _pendingKey, value: jsonEncode(operations));

  Future<void> clear() async {
    final existingPending = await pending();
    for (final key in await _knownStorageKeys()) {
      await _storage.delete(key: key);
    }
    await _storage.delete(key: _knownKeys);
    await _storage.delete(key: _pendingKey);
    await _storage.delete(key: _lastOnlineKey);
    if (existingPending.any(
      (operation) => operation['attachmentPath'] != null,
    )) {
      final directory = await _attachmentsDirectory();
      if (await directory.exists()) {
        await for (final entity in directory.list()) {
          if (entity is File) await entity.delete();
        }
      }
    }
    try {
      final directory = await _documentsDirectory();
      if (await directory.exists()) {
        await for (final entity in directory.list()) {
          if (entity is File) await entity.delete();
        }
      }
    } catch (_) {
      // The headless test harness has no path_provider implementation.
    }
  }
}

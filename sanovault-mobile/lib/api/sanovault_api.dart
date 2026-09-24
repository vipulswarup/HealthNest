import 'dart:async';
import 'dart:convert';

import 'package:sanovault/api/api_client.dart';
import 'package:sanovault/api/api_config.dart';
import 'package:sanovault/api/api_exception.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/offline_store.dart';

class SanoVaultApi {
  SanoVaultApi(this._client, {OfflineStore? offlineStore})
    : _offline = offlineStore;

  final ApiClient _client;
  final OfflineStore? _offline;
  bool usedOfflineData = false;

  Future<String> signInWithApple({
    required String identityToken,
    String? fullName,
    String? email,
  }) async {
    final json = await _client.post('/api/auth/mobile/apple', {
      'identityToken': identityToken,
      if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
      if (email != null && email.isNotEmpty) 'email': email,
    }) as Map<String, dynamic>;
    return _requireToken(json);
  }

  Future<String> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final json = await _client.post('/api/auth/mobile/password', {
      'email': email.trim().toLowerCase(),
      'password': password,
    }) as Map<String, dynamic>;
    return _requireToken(json);
  }

  Future<void> revokeSession() async {
    await _client.delete('/api/auth/mobile/session');
  }

  Future<BetaStatus> betaStatus() async {
    try {
      final json = await _client.get(
        '/api/users/beta-acknowledgement',
      ) as Map<String, dynamic>;
      await _offline?.writeJson('beta', json);
      await _offline?.markOnline();
      usedOfflineData = false;
      return BetaStatus.fromJson(json);
    } catch (_) {
      usedOfflineData = true;
      final cached = await _offline?.readJson('beta');
      if (cached is Map)
        return BetaStatus.fromJson(Map<String, dynamic>.from(cached));
      rethrow;
    }
  }

  Future<void> acceptBeta() async {
    await _client.post('/api/users/beta-acknowledgement', {
      'version': betaAcknowledgementVersion,
    });
  }

  Future<Profile> me() async {
    try {
      final json = await _client.get('/api/users/me') as Map<String, dynamic>;
      await _offline?.writeJson('profile', json);
      await _offline?.markOnline();
      usedOfflineData = false;
      return Profile.fromJson(json);
    } catch (_) {
      usedOfflineData = true;
      final cached = await _offline?.readJson('profile');
      if (cached is Map)
        return Profile.fromJson(Map<String, dynamic>.from(cached));
      rethrow;
    }
  }

  Future<DashboardHome> dashboard() async {
    try {
      final json = await _client.get('/api/dashboard') as Map<String, dynamic>;
      await _offline?.writeJson('dashboard', json);
      // The dashboard already contains the lightweight patient rows needed by
      // every picker. Seed that cache so Reports and tracking screens can open
      // even when their first patient request happens offline.
      if (json['patients'] is List) {
        await _offline?.writeJson('patients', json['patients'] as List);
        final patientIds = (json['patients'] as List)
            .whereType<Map>()
            .map((item) => item['id']?.toString())
            .whereType<String>()
            .toList();
        unawaited(_prefetchRecentForPatients(patientIds));
      }
      await _offline?.markOnline();
      usedOfflineData = false;
      return DashboardHome.fromJson(json);
    } catch (_) {
      usedOfflineData = true;
      final cached = await _offline?.readJson('dashboard');
      if (cached is Map)
        return DashboardHome.fromJson(Map<String, dynamic>.from(cached));
      rethrow;
    }
  }

  Future<void> setActiveHousehold(String householdId) async {
    await _client.patch('/api/me/active-household', {
      'householdId': householdId,
    });
  }

  Future<Household> createHousehold(String name) async {
    return Household.fromJson(
      await _client.post('/api/households', {'name': name})
          as Map<String, dynamic>,
    );
  }

  Future<void> acceptInvite(String token) async {
    await _client.post('/api/households/invites/$token', {
      'patientIds': <String>[],
    });
  }

  Future<List<HouseholdMember>> householdMembers(String householdId) async {
    final json =
        await _client.get('/api/households/$householdId/members') as List;
    return json
        .whereType<Map>()
        .map(
          (item) => HouseholdMember.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<String> inviteToHousehold(String householdId, String email) async {
    final json = await _client.post('/api/households/$householdId/invites', {
      'email': email,
    }) as Map<String, dynamic>;
    return json['acceptUrl'] as String? ?? '';
  }

  Future<void> leaveHousehold(String householdId) async {
    await _client.post('/api/households/$householdId/leave');
  }

  Future<Person> addPerson({
    required String householdId,
    required String firstName,
    String? lastName,
    required String dateOfBirth,
    required String gender,
    String? bloodGroup,
    String? abhaNumber,
  }) async {
    return Person.fromJson(
      await _client.post('/api/patients', {
        'householdId': householdId,
        'firstName': firstName,
        if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        if (bloodGroup != null && bloodGroup.isNotEmpty)
          'bloodGroup': bloodGroup,
        if (abhaNumber != null && abhaNumber.isNotEmpty)
          'abhaNumber': abhaNumber,
      }) as Map<String, dynamic>,
    );
  }

  Future<List<Person>> patients() async {
    try {
      final json = await _client.get('/api/patients') as List;
      await _offline?.writeJson('patients', json);
      await _offline?.markOnline();
      usedOfflineData = false;
      return _peopleFromJson(json);
    } catch (_) {
      usedOfflineData = true;
      final cached = await _offline?.readJson('patients');
      if (cached is List) return _peopleFromJson(cached);
      rethrow;
    }
  }

  Future<Person> patient(String id) async {
    return Person.fromJson(
      await _client.get('/api/patients/$id') as Map<String, dynamic>,
    );
  }

  Future<Person> updatePatient(String id, Map<String, dynamic> body) async {
    return Person.fromJson(
      await _client.put('/api/patients/$id', body) as Map<String, dynamic>,
    );
  }

  Future<List<HealthRecord>> healthRecords({
    String? patientId,
    String? keyword,
    String? recordType,
    String? tag,
  }) async {
    final key = _recordsCacheKey(
      patientId: patientId,
      keyword: keyword,
      recordType: recordType,
      tag: tag,
    );
    try {
      final json = await _client.get(
        '/api/health-records',
        query: {
          'patientId': patientId,
          'keyword': keyword,
          'recordType': recordType,
          'tag': tag,
        },
      ) as List;
      await _offline?.writeJson(key, json);
      await _offline?.markOnline();
      usedOfflineData = false;
      final records = _recordsFromJson(json);
      unawaited(_cacheRecentDocuments(records));
      return records;
    } catch (_) {
      usedOfflineData = true;
      final cached = await _offline?.readJson(key);
      if (cached is List) return _recordsFromJson(cached);
      rethrow;
    }
  }

  Future<HealthRecord> updateHealthRecord(
    String id,
    Map<String, dynamic> body,
  ) async {
    return HealthRecord.fromJson(
      await _client.put('/api/health-records/$id', body)
          as Map<String, dynamic>,
    );
  }

  Future<HealthRecord> healthRecord(String id) async {
    return HealthRecord.fromJson(
      await _client.get('/api/health-records/$id') as Map<String, dynamic>,
    );
  }

  Future<HealthRecord> createHealthRecord(Map<String, dynamic> body) async {
    return HealthRecord.fromJson(
      await _client.post('/api/health-records', body) as Map<String, dynamic>,
    );
  }

  Future<List<Category>> categories() async {
    final json = await _client.get('/api/health-record-categories') as List;
    return json
        .whereType<Map>()
        .map((item) => Category.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> uploadDocument(
    List<int> bytes,
    String filename, {
    String? patientId,
    String? pdfPassword,
    Duration? timeout,
  }) async {
    return await _client.postMultipart(
      path: '/api/documents/upload',
      field: 'file',
      bytes: bytes,
      filename: filename,
      fields: {
        if (patientId != null && patientId.isNotEmpty) 'patientId': patientId,
        if (pdfPassword != null && pdfPassword.isNotEmpty)
          'pdfPassword': pdfPassword,
      },
      timeout: timeout,
    ) as Map<String, dynamic>;
  }

  Future<bool> lookupDocumentHash({
    required String patientId,
    required String sha256,
  }) async {
    final json = await _client.post('/api/documents/lookup-hash', {
      'patientId': patientId,
      'sha256': sha256,
    }) as Map<String, dynamic>;
    return json['duplicate'] == true;
  }

  Future<List<FilePassword>> filePasswords(String patientId) async {
    final json =
        await _client.get('/api/patients/$patientId/file-passwords') as List;
    return json
        .whereType<Map>()
        .map((item) => FilePassword.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<FilePassword> addFilePassword(
    String patientId,
    String password,
  ) async {
    return FilePassword.fromJson(
      await _client.post('/api/patients/$patientId/file-passwords', {
        'password': password,
      }) as Map<String, dynamic>,
    );
  }

  Future<void> deleteFilePassword(String patientId, String passwordId) async {
    await _client.delete('/api/patients/$patientId/file-passwords/$passwordId');
  }

  Future<String> ocrDocument(
    String documentId, {
    String mode = 'intake',
    List<String>? extraPasswords,
  }) async {
    final json = await _client.post('/api/ocr/process', {
      'documentId': documentId,
      'mode': mode,
      if (extraPasswords != null && extraPasswords.isNotEmpty)
        'extraPasswords': extraPasswords,
    }, const Duration(seconds: 120)) as Map<String, dynamic>;
    return json['text'] as String? ?? '';
  }

  Future<String> classifyDocument(String documentId, String text) async {
    final json = await _client.post('/api/ai/classify', {
      'documentId': documentId,
      'text': text,
    }) as Map<String, dynamic>;
    return json['classification'] as String? ?? 'OTHER';
  }

  Future<List<String>> suggestTags(String documentId, String text) async {
    final json = await _client.post('/api/ai/suggest-tags', {
      'documentId': documentId,
      'text': text,
    }) as Map<String, dynamic>;
    return (json['autoSelected'] as List? ?? json['tags'] as List? ?? const [])
        .map((item) => item.toString())
        .toList();
  }

  Future<String> matchSource(String name) async {
    final json = await _client.post('/api/healthcare-sources/match', {
      'name': name,
    }) as Map<String, dynamic>;
    return json['matched'] as String? ?? name;
  }

  Future<String> matchDoctor(String name) async {
    final json = await _client.post('/api/doctors/match', {
      'name': name,
    }) as Map<String, dynamic>;
    return json['matched'] as String? ?? name;
  }

  Future<List<int>> documentPreview(String documentId) {
    return _client.getBytes(
      '/api/documents/preview',
      query: {'documentId': documentId},
    );
  }

  Future<List<int>> documentFile(String documentId) {
    return _client.getBytes('/api/documents/$documentId/file');
  }

  Future<DocumentView> documentView(String documentId) async {
    return DocumentView.fromJson(
      await _client.post('/api/documents/view', {'documentId': documentId})
          as Map<String, dynamic>,
    );
  }

  Future<List<Medication>> medications(String patientId, {bool? active}) async {
    final json = await _client.get(
      '/api/medications',
      query: {
        'patientId': patientId,
        if (active != null) 'isActive': active.toString(),
      },
    ) as List;
    return json
        .whereType<Map>()
        .map((item) => Medication.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Medication> createMedication(Map<String, dynamic> body) async {
    return Medication.fromJson(
      await _client.post('/api/medications', body) as Map<String, dynamic>,
    );
  }

  Future<Medication> updateMedication(
    String id,
    Map<String, dynamic> body,
  ) async {
    return Medication.fromJson(
      await _client.put('/api/medications/$id', body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> extractMedication(
    List<int> bytes,
    String filename,
  ) async {
    return await _client.postMultipart(
      path: '/api/medications/extract-from-photo',
      field: 'file',
      bytes: bytes,
      filename: filename,
      fields: {'country': 'IN'},
      timeout: const Duration(seconds: 90),
    ) as Map<String, dynamic>;
  }

  Future<DoctorPacket> doctorPacket(String patientId) async {
    return DoctorPacket.fromJson(
      await _client.get(
        '/api/reports/doctor-packet',
        query: {'patientId': patientId},
      ) as Map<String, dynamic>,
    );
  }

  Future<BloodPressureWeek> bloodPressure(String patientId) async {
    final key = 'bp.$patientId';
    try {
      final json = await _client.get(
        '/api/vitals/blood-pressure',
        query: {'patientId': patientId},
      ) as Map<String, dynamic>;
      await _offline?.writeJson(key, json);
      await _offline?.markOnline();
      usedOfflineData = false;
      return BloodPressureWeek.fromJson(json);
    } catch (_) {
      usedOfflineData = true;
      final cached = await _offline?.readJson(key);
      if (cached is Map)
        return BloodPressureWeek.fromJson(Map<String, dynamic>.from(cached));
      rethrow;
    }
  }

  Future<BloodPressureWeek> logBloodPressure({
    required String patientId,
    required int systolic,
    required int diastolic,
    int? pulse,
  }) async {
    final body = <String, dynamic>{
      'patientId': patientId,
      'systolic': systolic,
      'diastolic': diastolic,
      if (pulse != null) 'pulse': pulse,
    };
    try {
      final json = await _client.post(
        '/api/vitals/blood-pressure',
        body,
      ) as Map<String, dynamic>;
      await _offline?.writeJson('bp.$patientId', json);
      await _offline?.markOnline();
      return BloodPressureWeek.fromJson(json);
    } catch (_) {
      if (_offline == null) rethrow;
      await _offline.addPending({
        'type': 'blood_pressure',
        'id': _operationId(),
        'body': body,
      });
      final cached = await _offline.readJson('bp.$patientId');
      final json = cached is Map
          ? Map<String, dynamic>.from(cached)
          : <String, dynamic>{'lines': [], 'readings': []};
      final readings = (json['readings'] is List
          ? [...json['readings'] as List]
          : <dynamic>[]);
      readings.insert(0, {
        'id':
            'pending-${body['systolic']}-${DateTime.now().millisecondsSinceEpoch}',
        'patientId': patientId,
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
        'systolic': systolic,
        'diastolic': diastolic,
        if (pulse != null) 'pulse': pulse,
        'source': 'offline',
      });
      json['readings'] = readings;
      await _offline.writeJson('bp.$patientId', json);
      return BloodPressureWeek.fromJson(json);
    }
  }

  Future<GrowthHistory> growth(String patientId) async {
    return GrowthHistory.fromJson(
      await _client.get('/api/vitals/growth', query: {'patientId': patientId})
          as Map<String, dynamic>,
    );
  }

  Future<GrowthHistory> logGrowth({
    required String patientId,
    double? heightCm,
    double? weightKg,
  }) async {
    final json = await _client.post('/api/vitals/growth', {
      'patientId': patientId,
      if (heightCm != null) 'heightCm': heightCm,
      if (weightKg != null) 'weightKg': weightKg,
    }) as Map<String, dynamic>;
    return GrowthHistory.fromJson(json);
  }

  Future<VaccinationList> vaccinations(String patientId) async {
    return VaccinationList.fromJson(
      await _client.get('/api/vaccinations', query: {'patientId': patientId})
          as Map<String, dynamic>,
    );
  }

  Future<VaccinationList> addVaccination({
    required String patientId,
    required String vaccineName,
    required String administeredDate,
    String? doseLabel,
  }) async {
    final json = await _client.post('/api/vaccinations', {
      'patientId': patientId,
      'vaccineName': vaccineName,
      'administeredDate': administeredDate,
      if (doseLabel != null && doseLabel.isNotEmpty) 'doseLabel': doseLabel,
    }) as Map<String, dynamic>;
    return VaccinationList.fromJson(json);
  }

  Future<VisitNoteList> visitNotes(String patientId) async {
    final key = 'notes.$patientId';
    try {
      final json = await _client.get(
        '/api/visit-notes',
        query: {'patientId': patientId},
      ) as Map<String, dynamic>;
      await _offline?.writeJson(key, json);
      await _offline?.markOnline();
      usedOfflineData = false;
      return VisitNoteList.fromJson(json);
    } catch (_) {
      usedOfflineData = true;
      final cached = await _offline?.readJson(key);
      if (cached is Map)
        return VisitNoteList.fromJson(Map<String, dynamic>.from(cached));
      rethrow;
    }
  }

  Future<VisitNoteList> addVisitNote({
    required String patientId,
    required String noteDate,
    required String observed,
    required String askDoctor,
  }) async {
    final body = <String, dynamic>{
      'patientId': patientId,
      'noteDate': noteDate,
      'observed': observed,
      'askDoctor': askDoctor,
    };
    try {
      final json =
          await _client.post('/api/visit-notes', body) as Map<String, dynamic>;
      await _offline?.writeJson('notes.$patientId', json);
      await _offline?.markOnline();
      return VisitNoteList.fromJson(json);
    } catch (_) {
      if (_offline == null) rethrow;
      await _offline.addPending({
        'type': 'visit_note',
        'id': _operationId(),
        'body': body,
      });
      final cached = await _offline.readJson('notes.$patientId');
      final json = cached is Map
          ? Map<String, dynamic>.from(cached)
          : <String, dynamic>{'notes': []};
      final notes = (json['notes'] is List
          ? [...json['notes'] as List]
          : <dynamic>[]);
      notes.insert(0, {
        'id': 'pending-${DateTime.now().millisecondsSinceEpoch}',
        ...body,
        'source': 'offline',
      });
      json['notes'] = notes;
      await _offline.writeJson('notes.$patientId', json);
      return VisitNoteList.fromJson(json);
    }
  }

  Future<void> queueOfflineReport({
    required List<int> bytes,
    required String filename,
    required String patientId,
    required String recordType,
    required String source,
    String? doctorName,
    required String documentDate,
    String? ocrText,
  }) async {
    final store = _offline;
    if (store == null)
      throw const ApiException('Offline storage is unavailable.');
    final operationId = _operationId();
    final attachmentPath = await store.writeAttachment(operationId, bytes);
    await store.addPending({
      'type': 'report',
      'id': operationId,
      'filename': filename,
      'attachmentPath': attachmentPath,
      'patientId': patientId,
      'recordType': recordType,
      'source': source,
      if (doctorName != null && doctorName.isNotEmpty) 'doctorName': doctorName,
      'documentDate': documentDate,
      if (ocrText != null && ocrText.isNotEmpty) 'ocrText': ocrText,
    });
    final key = _recordsCacheKey(patientId: patientId);
    final cached = await store.readJson(key);
    final records = cached is List ? [...cached] : <dynamic>[];
    records.insert(0, {
      'id': 'pending-$operationId',
      'patientId': patientId,
      'recordType': recordType,
      'source': source,
      'documentDate': documentDate,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'title': filename,
      'tags': <String>['waiting_to_sync'],
    });
    await store.writeJson(key, records);
  }

  Future<int> pendingOperationCount() async =>
      (await _offline?.pending() ?? const []).length;

  Future<void> flushPendingOperations() async {
    final store = _offline;
    if (store == null) return;
    final operations = await store.pending();
    if (operations.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (final operation in operations) {
      try {
        final type = operation['type'];
        if (type == 'blood_pressure' || type == 'visit_note') {
          final body = Map<String, dynamic>.from(operation['body'] as Map);
          final path = type == 'blood_pressure'
              ? '/api/vitals/blood-pressure'
              : '/api/visit-notes';
          final json = await _client.post(path, body) as Map<String, dynamic>;
          await store.writeJson(
            type == 'blood_pressure'
                ? 'bp.${body['patientId']}'
                : 'notes.${body['patientId']}',
            json,
          );
        } else if (type == 'report') {
          final bytes = operation['attachmentPath'] is String
              ? await store.readAttachment(
                  operation['attachmentPath'] as String,
                )
              : base64Decode(operation['bytes'] as String);
          final uploaded = await uploadDocument(
            bytes,
            operation['filename'] as String,
            patientId: operation['patientId'] as String,
          );
          final documentId =
              uploaded['id'] as String? ??
              uploaded['_id'] as String? ??
              uploaded['documentId'] as String?;
          if (documentId == null)
            throw const ApiException(
              'Offline report upload did not return a document.',
            );
          await createHealthRecord({
            'patientId': operation['patientId'],
            'recordType': operation['recordType'],
            'data': <String, dynamic>{},
            'source': operation['source'],
            if (operation['doctorName'] != null)
              'doctorName': operation['doctorName'],
            'documentDate': operation['documentDate'],
            'documentId': documentId,
            if (operation['ocrText'] != null) 'ocrText': operation['ocrText'],
          });
          if (operation['attachmentPath'] is String) {
            await store.deleteAttachment(operation['attachmentPath'] as String);
          }
        }
      } catch (_) {
        remaining.add(operation);
      }
    }
    await store.replacePending(remaining);
  }

  List<Person> _peopleFromJson(List value) => value
      .whereType<Map>()
      .map((item) => Person.fromJson(Map<String, dynamic>.from(item)))
      .toList();

  List<HealthRecord> _recordsFromJson(List value) => value
      .whereType<Map>()
      .map((item) => HealthRecord.fromJson(Map<String, dynamic>.from(item)))
      .toList();

  String _recordsCacheKey({
    String? patientId,
    String? keyword,
    String? recordType,
    String? tag,
  }) =>
      'records.${Uri(queryParameters: {'patientId': patientId, 'keyword': keyword, 'recordType': recordType, 'tag': tag}).query}';

  String _operationId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';

  Future<void> _cacheRecentDocuments(List<HealthRecord> records) async {
    final store = _offline;
    if (store == null) return;
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));
    for (final record in records) {
      final documentId = record.documentId;
      if (documentId == null) continue;
      final date = DateTime.tryParse(
        record.documentDate ?? record.createdAt ?? '',
      );
      if (date != null && date.toUtc().isBefore(cutoff)) continue;
      if (await store.documentInfo(documentId) != null) continue;
      try {
        final view = await documentView(documentId);
        final type = (view.fileType ?? '').toLowerCase();
        final isImage =
            type.contains('jpeg') ||
            type.contains('jpg') ||
            type.contains('png') ||
            type.contains('webp') ||
            type.contains('gif') ||
            type.contains('bmp');
        final bytes = isImage
            ? await documentPreview(documentId)
            : await documentFile(documentId);
        await store.writeDocument(
          documentId,
          bytes,
          fileName: view.fileName,
          isPdf: !isImage,
        );
      } catch (_) {
        // A background download must never prevent the report index loading.
      }
    }
  }

  Future<void> _prefetchRecentForPatients(List<String> patientIds) async {
    for (final patientId in patientIds) {
      try {
        await healthRecords(patientId: patientId);
      } catch (_) {
        // Background prefetch is best effort and must not affect Home.
      }
    }
  }

  Future<void> registerDevice(String token, String platform) async {
    await _client.post('/api/devices', {'token': token, 'platform': platform});
  }

  String _requireToken(Map<String, dynamic> json) {
    final token = json['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Sign-in did not return a session');
    }
    return token;
  }
}

import 'package:sanovault/api/api_client.dart';
import 'package:sanovault/api/api_config.dart';
import 'package:sanovault/api/models.dart';

class SanoVaultApi {
  SanoVaultApi(this._client);

  final ApiClient _client;

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

  Future<String> signInWithPassword({required String email, required String password}) async {
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
    return BetaStatus.fromJson(await _client.get('/api/users/beta-acknowledgement') as Map<String, dynamic>);
  }

  Future<void> acceptBeta() async {
    await _client.post('/api/users/beta-acknowledgement', {'version': betaAcknowledgementVersion});
  }

  Future<Profile> me() async {
    return Profile.fromJson(await _client.get('/api/users/me') as Map<String, dynamic>);
  }

  Future<DashboardHome> dashboard() async {
    return DashboardHome.fromJson(await _client.get('/api/dashboard') as Map<String, dynamic>);
  }

  Future<void> setActiveHousehold(String householdId) async {
    await _client.patch('/api/me/active-household', {'householdId': householdId});
  }

  Future<Household> createHousehold(String name) async {
    return Household.fromJson(await _client.post('/api/households', {'name': name}) as Map<String, dynamic>);
  }

  Future<void> acceptInvite(String token) async {
    await _client.post('/api/households/invites/$token', {'patientIds': <String>[]});
  }

  Future<List<HouseholdMember>> householdMembers(String householdId) async {
    final json = await _client.get('/api/households/$householdId/members') as List;
    return json.whereType<Map>().map((item) => HouseholdMember.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<String> inviteToHousehold(String householdId, String email) async {
    final json = await _client.post('/api/households/$householdId/invites', {'email': email}) as Map<String, dynamic>;
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
    return Person.fromJson(await _client.post('/api/patients', {
      'householdId': householdId,
      'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      if (bloodGroup != null && bloodGroup.isNotEmpty) 'bloodGroup': bloodGroup,
      if (abhaNumber != null && abhaNumber.isNotEmpty) 'abhaNumber': abhaNumber,
    }) as Map<String, dynamic>);
  }

  Future<List<Person>> patients() async {
    final json = await _client.get('/api/patients') as List;
    return json.whereType<Map>().map((item) => Person.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<Person> patient(String id) async {
    return Person.fromJson(await _client.get('/api/patients/$id') as Map<String, dynamic>);
  }

  Future<Person> updatePatient(String id, Map<String, dynamic> body) async {
    return Person.fromJson(await _client.put('/api/patients/$id', body) as Map<String, dynamic>);
  }

  Future<List<HealthRecord>> healthRecords({String? patientId, String? keyword, String? recordType}) async {
    final json = await _client.get('/api/health-records', query: {
      'patientId': patientId,
      'keyword': keyword,
      'recordType': recordType,
    }) as List;
    return json.whereType<Map>().map((item) => HealthRecord.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<HealthRecord> healthRecord(String id) async {
    return HealthRecord.fromJson(await _client.get('/api/health-records/$id') as Map<String, dynamic>);
  }

  Future<HealthRecord> createHealthRecord(Map<String, dynamic> body) async {
    return HealthRecord.fromJson(await _client.post('/api/health-records', body) as Map<String, dynamic>);
  }

  Future<List<Category>> categories() async {
    final json = await _client.get('/api/health-record-categories') as List;
    return json.whereType<Map>().map((item) => Category.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<Map<String, dynamic>> uploadDocument(List<int> bytes, String filename) async {
    return await _client.postMultipart(
      path: '/api/documents/upload',
      field: 'file',
      bytes: bytes,
      filename: filename,
    ) as Map<String, dynamic>;
  }

  Future<String> ocrDocument(String documentId, {String mode = 'intake'}) async {
    final json = await _client.post(
      '/api/ocr/process',
      {'documentId': documentId, 'mode': mode},
      const Duration(seconds: 120),
    ) as Map<String, dynamic>;
    return json['text'] as String? ?? '';
  }

  Future<String> classifyDocument(String documentId, String text) async {
    final json = await _client.post('/api/ai/classify', {'documentId': documentId, 'text': text}) as Map<String, dynamic>;
    return json['classification'] as String? ?? 'OTHER';
  }

  Future<List<String>> suggestTags(String documentId, String text) async {
    final json = await _client.post('/api/ai/suggest-tags', {'documentId': documentId, 'text': text}) as Map<String, dynamic>;
    return (json['autoSelected'] as List? ?? json['tags'] as List? ?? const []).map((item) => item.toString()).toList();
  }

  Future<String> matchSource(String name) async {
    final json = await _client.post('/api/healthcare-sources/match', {'name': name}) as Map<String, dynamic>;
    return json['matched'] as String? ?? name;
  }

  Future<String> matchDoctor(String name) async {
    final json = await _client.post('/api/doctors/match', {'name': name}) as Map<String, dynamic>;
    return json['matched'] as String? ?? name;
  }

  Future<List<int>> documentPreview(String documentId) {
    return _client.getBytes('/api/documents/preview', query: {'documentId': documentId});
  }

  Future<DocumentView> documentView(String documentId) async {
    return DocumentView.fromJson(
      await _client.post('/api/documents/view', {'documentId': documentId}) as Map<String, dynamic>,
    );
  }

  Future<List<Medication>> medications(String patientId, {bool? active}) async {
    final json = await _client.get('/api/medications', query: {
      'patientId': patientId,
      if (active != null) 'isActive': active.toString(),
    }) as List;
    return json.whereType<Map>().map((item) => Medication.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<Medication> createMedication(Map<String, dynamic> body) async {
    return Medication.fromJson(await _client.post('/api/medications', body) as Map<String, dynamic>);
  }

  Future<Medication> updateMedication(String id, Map<String, dynamic> body) async {
    return Medication.fromJson(await _client.put('/api/medications/$id', body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> extractMedication(List<int> bytes, String filename) async {
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
      await _client.get('/api/reports/doctor-packet', query: {'patientId': patientId}) as Map<String, dynamic>,
    );
  }

  Future<BloodPressureWeek> bloodPressure(String patientId) async {
    return BloodPressureWeek.fromJson(
      await _client.get('/api/vitals/blood-pressure', query: {'patientId': patientId}) as Map<String, dynamic>,
    );
  }

  Future<BloodPressureWeek> logBloodPressure({
    required String patientId,
    required int systolic,
    required int diastolic,
    int? pulse,
  }) async {
    final json = await _client.post('/api/vitals/blood-pressure', {
      'patientId': patientId,
      'systolic': systolic,
      'diastolic': diastolic,
      if (pulse != null) 'pulse': pulse,
    }) as Map<String, dynamic>;
    return BloodPressureWeek.fromJson(json);
  }

  Future<GrowthHistory> growth(String patientId) async {
    return GrowthHistory.fromJson(
      await _client.get('/api/vitals/growth', query: {'patientId': patientId}) as Map<String, dynamic>,
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
      await _client.get('/api/vaccinations', query: {'patientId': patientId}) as Map<String, dynamic>,
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
    return VisitNoteList.fromJson(
      await _client.get('/api/visit-notes', query: {'patientId': patientId}) as Map<String, dynamic>,
    );
  }

  Future<VisitNoteList> addVisitNote({
    required String patientId,
    required String noteDate,
    required String observed,
    required String askDoctor,
  }) async {
    final json = await _client.post('/api/visit-notes', {
      'patientId': patientId,
      'noteDate': noteDate,
      'observed': observed,
      'askDoctor': askDoctor,
    }) as Map<String, dynamic>;
    return VisitNoteList.fromJson(json);
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

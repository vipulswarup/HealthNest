import '../models/user.dart';
import '../models/patient.dart';
import '../models/health_record.dart';
import 'storage_service.dart';
import 'local_storage_service.dart';
import 'google_drive_service.dart';

class HybridStorageService implements StorageService {
  final LocalStorageService _localStorage;
  final GoogleDriveService _cloudStorage;
  bool _isInitialized = false;

  HybridStorageService()
      : _localStorage = LocalStorageService(),
        _cloudStorage = GoogleDriveService();

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _localStorage.initialize();
    await _cloudStorage.initialize();
    _isInitialized = true;
  }

  @override
  Future<void> close() async {
    await _localStorage.close();
    _isInitialized = false;
  }

  // User operations
  @override
  Future<User?> getCurrentUser() async {
    // Try local first, then cloud
    User? user = await _localStorage.getCurrentUser();
    
    if (user == null && await _cloudStorage.isAuthenticated()) {
      user = await _cloudStorage.syncUserFromCloud();
      if (user != null) {
        await _localStorage.saveUser(user);
      }
    }
    
    return user;
  }

  @override
  Future<void> saveUser(User user) async {
    // Save locally first for immediate access
    await _localStorage.saveUser(user);
    
    // Then sync to cloud if authenticated
    if (await _cloudStorage.isAuthenticated()) {
      await _cloudStorage.syncUserToCloud(user);
    }
  }

  @override
  Future<void> deleteUser(String id) async {
    await _localStorage.deleteUser(id);
    // TODO: Implement cloud deletion when Google Drive is implemented
  }

  @override
  Future<bool> hasUser() async {
    return await _localStorage.hasUser();
  }

  // Patient operations
  @override
  Future<List<Patient>> getPatients() async {
    List<Patient> patients = await _localStorage.getPatients();
    
    // If no local patients and cloud is available, try to sync
    if (patients.isEmpty && await _cloudStorage.isAuthenticated()) {
      patients = await _cloudStorage.syncPatientsFromCloud();
      for (final patient in patients) {
        await _localStorage.savePatient(patient);
      }
    }
    
    return patients;
  }

  @override
  Future<Patient?> getPatient(String id) async {
    return await _localStorage.getPatient(id);
  }

  @override
  Future<void> savePatient(Patient patient) async {
    // Save locally first
    await _localStorage.savePatient(patient);
    
    // Then sync to cloud if authenticated
    if (await _cloudStorage.isAuthenticated()) {
      final allPatients = await _localStorage.getPatients();
      await _cloudStorage.syncPatientsToCloud(allPatients);
    }
  }

  @override
  Future<void> deletePatient(String id) async {
    await _localStorage.deletePatient(id);
    // TODO: Implement cloud deletion when Google Drive is implemented
  }

  // Health record operations
  @override
  Future<List<HealthRecord>> getHealthRecords(String patientId) async {
    return await _localStorage.getHealthRecords(patientId);
  }

  @override
  Future<HealthRecord?> getHealthRecord(String id) async {
    return await _localStorage.getHealthRecord(id);
  }

  @override
  Future<void> saveHealthRecord(HealthRecord record) async {
    // Save locally first
    await _localStorage.saveHealthRecord(record);
    
    // Then sync to cloud if authenticated
    if (await _cloudStorage.isAuthenticated()) {
      final allRecords = await _localStorage.getHealthRecords(record.patientId);
      await _cloudStorage.syncHealthRecordsToCloud(allRecords);
    }
  }

  @override
  Future<void> deleteHealthRecord(String id) async {
    await _localStorage.deleteHealthRecord(id);
    // TODO: Implement cloud deletion when Google Drive is implemented
  }

  // Cloud sync operations
  @override
  Future<void> syncToCloud() async {
    if (!await _cloudStorage.isAuthenticated()) return;
    
    // Sync user
    final user = await _localStorage.getCurrentUser();
    if (user != null) {
      await _cloudStorage.syncUserToCloud(user);
    }
    
    // Sync patients
    final patients = await _localStorage.getPatients();
    if (patients.isNotEmpty) {
      await _cloudStorage.syncPatientsToCloud(patients);
    }
    
    // Sync health records for each patient
    for (final patient in patients) {
      final records = await _localStorage.getHealthRecords(patient.id);
      if (records.isNotEmpty) {
        await _cloudStorage.syncHealthRecordsToCloud(records);
      }
    }
  }

  @override
  Future<void> syncFromCloud() async {
    if (!await _cloudStorage.isAuthenticated()) return;
    
    // Sync user
    final cloudUser = await _cloudStorage.syncUserFromCloud();
    if (cloudUser != null) {
      await _localStorage.saveUser(cloudUser);
    }
    
    // Sync patients
    final cloudPatients = await _cloudStorage.syncPatientsFromCloud();
    for (final patient in cloudPatients) {
      await _localStorage.savePatient(patient);
    }
    
    // Sync health records
    for (final patient in cloudPatients) {
      final cloudRecords = await _cloudStorage.syncHealthRecordsFromCloud();
      for (final record in cloudRecords) {
        if (record.patientId == patient.id) {
          await _localStorage.saveHealthRecord(record);
        }
      }
    }
  }

  @override
  Future<bool> isCloudConnected() async {
    return await _cloudStorage.isAuthenticated();
  }

  // Document storage
  @override
  Future<String> saveDocument(String filePath, String patientId) async {
    // For now, just return the local path
    // TODO: Implement cloud document storage when Google Drive is implemented
    return filePath;
  }

  @override
  Future<void> deleteDocument(String documentPath) async {
    // TODO: Implement document deletion
  }

  @override
  Future<String?> getDocumentPath(String documentId) async {
    // TODO: Implement document path retrieval
    return null;
  }

  // Query operations
  @override
  Future<List<Patient>> getPatientsByHospitalIdentifier(String systemName, String identifierType, String value) async {
    return await _localStorage.getPatientsByHospitalIdentifier(systemName, identifierType, value);
  }

  @override
  Future<List<Patient>> getPatientsByMobileNumber(String mobileNumber) async {
    return await _localStorage.getPatientsByMobileNumber(mobileNumber);
  }

  // Additional methods for cloud authentication
  Future<void> authenticateCloud() async {
    await _cloudStorage.authenticate();
  }

  Future<bool> isCloudAuthenticated() async {
    return await _cloudStorage.isAuthenticated();
  }
} 
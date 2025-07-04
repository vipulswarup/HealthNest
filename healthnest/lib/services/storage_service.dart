// Storage service interface for local and cloud storage
// Supports SQLite for local storage and Google Drive/Sheets for cloud sync

import '../models/health_record.dart';
import '../models/patient.dart';

abstract class StorageService {
  // Local storage operations
  Future<void> initialize();
  Future<void> close();
  
  // Health record operations
  Future<List<HealthRecord>> getHealthRecords(String patientId);
  Future<HealthRecord?> getHealthRecord(String id);
  Future<void> saveHealthRecord(HealthRecord record);
  Future<void> deleteHealthRecord(String id);
  
  // Patient operations
  Future<List<Patient>> getPatients();
  Future<Patient?> getPatient(String id);
  Future<void> savePatient(Patient patient);
  Future<void> deletePatient(String id);
  
  // Cloud sync operations
  Future<void> syncToCloud();
  Future<void> syncFromCloud();
  Future<bool> isCloudConnected();
  
  // Document storage
  Future<String> saveDocument(String filePath, String patientId);
  Future<void> deleteDocument(String documentPath);
  Future<String?> getDocumentPath(String documentId);
  
  // Query by hospital/lab identifier
  Future<List<Patient>> getPatientsByHospitalIdentifier(String systemName, String identifierType, String value);
  Future<List<Patient>> getPatientsByMobileNumber(String mobileNumber);
}

// Implementation will be provided for SQLite and Google Drive/Sheets 
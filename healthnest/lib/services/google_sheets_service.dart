import 'dart:convert';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis_auth/auth_browser.dart';
import '../models/health_record.dart';
import '../models/patient.dart';
import '../models/user.dart';

class GoogleSheetsService {
  static const String _spreadsheetId = 'YOUR_SPREADSHEET_ID'; // User's private spreadsheet
  static const List<String> _scopes = [SheetsApi.spreadsheetsScope];
  
  SheetsApi? _sheetsApi;
  bool _isInitialized = false;

  // Sheet names for different data types
  static const String _usersSheet = 'Users';
  static const String _patientsSheet = 'Patients';
  static const String _healthRecordsSheet = 'HealthRecords';
  static const String _medicationsSheet = 'Medications';
  static const String _voiceNotesSheet = 'VoiceNotes';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Google Sheets API
      // This will need to be configured with user's Google account
      // For now, we'll create a placeholder implementation
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize Google Sheets service: $e');
    }
  }

  // User operations
  Future<User?> getUser(String id) async {
    if (!_isInitialized) await initialize();
    
    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId,
        '$_usersSheet!A:Z',
      );
      
      if (response.values == null) return null;
      
      for (final row in response.values!) {
        if (row.isNotEmpty && row[0] == id) {
          return _parseUserFromRow(row);
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  Future<void> saveUser(User user) async {
    if (!_isInitialized) await initialize();
    
    try {
      final row = _userToRow(user);
      final valueRange = ValueRange(values: [row]);
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId,
        '$_usersSheet!A:Z',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      throw Exception('Failed to save user: $e');
    }
  }

  // Patient operations
  Future<List<Patient>> getPatients() async {
    if (!_isInitialized) await initialize();
    
    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId,
        '$_patientsSheet!A:Z',
      );
      
      if (response.values == null) return [];
      
      return response.values!
          .skip(1) // Skip header row
          .map((row) => _parsePatientFromRow(row))
          .where((patient) => patient != null)
          .cast<Patient>()
          .toList();
    } catch (e) {
      throw Exception('Failed to get patients: $e');
    }
  }

  Future<void> savePatient(Patient patient) async {
    if (!_isInitialized) await initialize();
    
    try {
      final row = _patientToRow(patient);
      final valueRange = ValueRange(values: [row]);
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId,
        '$_patientsSheet!A:Z',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      throw Exception('Failed to save patient: $e');
    }
  }

  // Health record operations
  Future<List<HealthRecord>> getHealthRecords(String patientId) async {
    if (!_isInitialized) await initialize();
    
    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId,
        '$_healthRecordsSheet!A:Z',
      );
      
      if (response.values == null) return [];
      
      return response.values!
          .skip(1) // Skip header row
          .where((row) => row.isNotEmpty && row[1] == patientId) // Filter by patientId
          .map((row) => _parseHealthRecordFromRow(row))
          .where((record) => record != null)
          .cast<HealthRecord>()
          .toList();
    } catch (e) {
      throw Exception('Failed to get health records: $e');
    }
  }

  Future<void> saveHealthRecord(HealthRecord record) async {
    if (!_isInitialized) await initialize();
    
    try {
      final row = _healthRecordToRow(record);
      final valueRange = ValueRange(values: [row]);
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId,
        '$_healthRecordsSheet!A:Z',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      throw Exception('Failed to save health record: $e');
    }
  }

  // Helper methods for parsing data
  User _parseUserFromRow(List<dynamic> row) {
    return User(
      id: row[0],
      name: row[1],
      email: row[2],
      phoneNumber: row[3],
      createdAt: DateTime.parse(row[4]),
      updatedAt: DateTime.parse(row[5]),
      preferences: jsonDecode(row[6]),
      onboardingCompleted: row[7] == '1',
    );
  }

  List<dynamic> _userToRow(User user) {
    return [
      user.id,
      user.name,
      user.email,
      user.phoneNumber ?? '',
      user.createdAt.toIso8601String(),
      user.updatedAt.toIso8601String(),
      jsonEncode(user.preferences),
      user.onboardingCompleted ? '1' : '0',
    ];
  }

  Patient? _parsePatientFromRow(List<dynamic> row) {
    if (row.length < 8) return null;
    
    return Patient(
      id: row[0],
      name: row[1],
      dateOfBirth: DateTime.parse(row[2]),
      gender: row[3],
      abhaNumber: row[4].isNotEmpty ? row[4] : null,
      bloodGroup: row[5].isNotEmpty ? row[5] : null,
      emergencyContacts: jsonDecode(row[6]),
      preferences: jsonDecode(row[7]),
      createdAt: DateTime.parse(row[8]),
      updatedAt: DateTime.parse(row[9]),
      hospitalIdentifiers: jsonDecode(row[10]),
      mobileNumbers: jsonDecode(row[11]),
    );
  }

  List<dynamic> _patientToRow(Patient patient) {
    return [
      patient.id,
      patient.name,
      patient.dateOfBirth.toIso8601String(),
      patient.gender,
      patient.abhaNumber ?? '',
      patient.bloodGroup ?? '',
      jsonEncode(patient.emergencyContacts),
      jsonEncode(patient.preferences),
      patient.createdAt.toIso8601String(),
      patient.updatedAt.toIso8601String(),
      jsonEncode(patient.hospitalIdentifiers.map((h) => h.toJson()).toList()),
      jsonEncode(patient.mobileNumbers),
    ];
  }

  HealthRecord? _parseHealthRecordFromRow(List<dynamic> row) {
    if (row.length < 10) return null;
    
    return HealthRecord(
      id: row[0],
      patientId: row[1],
      createdAt: DateTime.parse(row[2]),
      updatedAt: DateTime.parse(row[3]),
      recordType: row[4],
      data: jsonDecode(row[5]),
      tags: jsonDecode(row[6]),
      source: row[7],
      documentPath: row[8].isNotEmpty ? row[8] : null,
      hospitalSystemName: row[9].isNotEmpty ? row[9] : null,
      hospitalIdentifierType: row[10].isNotEmpty ? row[10] : null,
      hospitalIdentifierValue: row[11].isNotEmpty ? row[11] : null,
    );
  }

  List<dynamic> _healthRecordToRow(HealthRecord record) {
    return [
      record.id,
      record.patientId,
      record.createdAt.toIso8601String(),
      record.updatedAt.toIso8601String(),
      record.recordType,
      jsonEncode(record.data),
      jsonEncode(record.tags),
      record.source,
      record.documentPath ?? '',
      record.hospitalSystemName ?? '',
      record.hospitalIdentifierType ?? '',
      record.hospitalIdentifierValue ?? '',
    ];
  }

  // Sync operations
  Future<void> syncToCloud() async {
    // Implementation for syncing local data to Google Sheets
  }

  Future<void> syncFromCloud() async {
    // Implementation for syncing data from Google Sheets to local
  }

  Future<bool> isCloudConnected() async {
    return _isInitialized;
  }
} 
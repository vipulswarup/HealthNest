import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/patient.dart';
import '../models/health_record.dart';
import 'storage_service.dart';

class LocalStorageService implements StorageService {
  Database? _db;
  static const String _dbName = 'healthnest.db';

  @override
  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, _dbName),
      version: 1,
      onCreate: (db, version) async {
        // Create users table
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            firstName TEXT NOT NULL,
            middleName TEXT,
            lastName TEXT,
            title TEXT,
            suffix TEXT,
            emails TEXT NOT NULL,
            phoneNumbers TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            preferences TEXT NOT NULL,
            onboardingCompleted INTEGER NOT NULL
          )
        ''');

        // Create patients table
        await db.execute('''
          CREATE TABLE patients (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            dateOfBirth TEXT NOT NULL,
            gender TEXT NOT NULL,
            abhaNumber TEXT,
            bloodGroup TEXT,
            emergencyContacts TEXT NOT NULL,
            preferences TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            hospitalIdentifiers TEXT NOT NULL,
            mobileNumbers TEXT NOT NULL
          )
        ''');

        // Create health_records table
        await db.execute('''
          CREATE TABLE health_records (
            id TEXT PRIMARY KEY,
            patientId TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            recordType TEXT NOT NULL,
            data TEXT NOT NULL,
            tags TEXT NOT NULL,
            source TEXT NOT NULL,
            documentPath TEXT,
            hospitalSystemName TEXT,
            hospitalIdentifierType TEXT,
            hospitalIdentifierValue TEXT,
            FOREIGN KEY (patientId) REFERENCES patients (id)
          )
        ''');
      },
    );
  }

  @override
  Future<void> close() async {
    await _db?.close();
  }

  // User operations
  @override
  Future<User?> getCurrentUser() async {
    if (_db == null) return null;
    
    final List<Map<String, dynamic>> maps = await _db!.query('users', limit: 1);
    if (maps.isEmpty) return null;
    
    return User.fromJson(maps.first);
  }

  @override
  Future<void> saveUser(User user) async {
    if (_db == null) return;
    
    await _db!.insert(
      'users',
      user.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteUser(String id) async {
    if (_db == null) return;
    
    await _db!.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<bool> hasUser() async {
    final user = await getCurrentUser();
    return user != null;
  }

  // Patient operations
  @override
  Future<List<Patient>> getPatients() async {
    if (_db == null) return [];
    
    final List<Map<String, dynamic>> maps = await _db!.query('patients');
    return maps.map((map) => Patient.fromJson(map)).toList();
  }

  @override
  Future<Patient?> getPatient(String id) async {
    if (_db == null) return null;
    
    final List<Map<String, dynamic>> maps = await _db!.query(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    return Patient.fromJson(maps.first);
  }

  @override
  Future<void> savePatient(Patient patient) async {
    if (_db == null) return;
    
    await _db!.insert(
      'patients',
      patient.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deletePatient(String id) async {
    if (_db == null) return;
    
    await _db!.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  // Health record operations
  @override
  Future<List<HealthRecord>> getHealthRecords(String patientId) async {
    if (_db == null) return [];
    
    final List<Map<String, dynamic>> maps = await _db!.query(
      'health_records',
      where: 'patientId = ?',
      whereArgs: [patientId],
    );
    
    return maps.map((map) => HealthRecord.fromJson(map)).toList();
  }

  @override
  Future<HealthRecord?> getHealthRecord(String id) async {
    if (_db == null) return null;
    
    final List<Map<String, dynamic>> maps = await _db!.query(
      'health_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    return HealthRecord.fromJson(maps.first);
  }

  @override
  Future<void> saveHealthRecord(HealthRecord record) async {
    if (_db == null) return;
    
    await _db!.insert(
      'health_records',
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteHealthRecord(String id) async {
    if (_db == null) return;
    
    await _db!.delete('health_records', where: 'id = ?', whereArgs: [id]);
  }

  // Cloud sync operations
  @override
  Future<void> syncToCloud() async {}
  @override
  Future<void> syncFromCloud() async {}
  @override
  Future<bool> isCloudConnected() async => false;

  // Document storage
  @override
  Future<String> saveDocument(String filePath, String patientId) async {
    // TODO: Implement
    return '';
  }
  @override
  Future<void> deleteDocument(String documentPath) async {}
  @override
  Future<String?> getDocumentPath(String documentId) async => null;

  // Query by hospital/lab identifier
  @override
  Future<List<Patient>> getPatientsByHospitalIdentifier(String systemName, String identifierType, String value) async {
    if (_db == null) return [];
    
    final List<Map<String, dynamic>> maps = await _db!.query(
      'patients',
      where: 'hospitalIdentifiers LIKE ?',
      whereArgs: ['%$systemName%$identifierType%$value%'],
    );
    
    return maps.map((map) => Patient.fromJson(map)).toList();
  }
  @override
  Future<List<Patient>> getPatientsByMobileNumber(String mobileNumber) async {
    if (_db == null) return [];
    
    final List<Map<String, dynamic>> maps = await _db!.query(
      'patients',
      where: 'mobileNumbers LIKE ?',
      whereArgs: ['%$mobileNumber%'],
    );
    
    return maps.map((map) => Patient.fromJson(map)).toList();
  }
} 
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart' as app_models;
import '../models/patient.dart';
import '../models/health_record.dart';
import '../config/supabase_config.dart';
import 'storage_service.dart';

class SupabaseStorageService implements StorageService {
  SupabaseClient? _supabase;
  bool _isInitialized = false;

    @override
  Future<void> initialize() async {
    print('HealthNest: SupabaseStorageService.initialize() called');
    if (_isInitialized) {
      print('HealthNest: SupabaseStorageService already initialized, returning');
      return;
    }

    // Check if Supabase is properly configured
    print('HealthNest: Checking Supabase configuration...');
    if (!SupabaseConfig.isValid) {
      print('HealthNest: ERROR - Supabase configuration is invalid');
      throw Exception('Supabase configuration is invalid. Please check your environment variables.');
    }
    print('HealthNest: Supabase configuration is valid');

    // Initialize Supabase client
    print('HealthNest: Initializing Supabase client...');
    _supabase = Supabase.instance.client;
    print('HealthNest: Supabase client initialized');

    // Check if user is authenticated
    print('HealthNest: Checking authentication status...');
    final user = _supabase!.auth.currentUser;
    if (user == null) {
      print('HealthNest: No authenticated user, creating anonymous session...');
      try {
        await _getClient().auth.signInAnonymously();
        print('HealthNest: Anonymous session created successfully');
      } catch (e) {
        print('HealthNest: ERROR creating anonymous session: $e');
        rethrow;
      }
    } else {
      print('HealthNest: User already authenticated: ${user.id}');
    }

    _isInitialized = true;
    print('HealthNest: SupabaseStorageService initialization complete');
  }

  SupabaseClient _getClient() {
    if (_supabase == null) {
      throw Exception('Supabase client not initialized. Call initialize() first.');
    }
    return _supabase!;
  }

  @override
  Future<void> close() async {
    if (_supabase != null) {
      await _supabase!.auth.signOut();
    }
    _isInitialized = false;
  }

  // User operations
  @override
  Future<app_models.User?> getCurrentUser() async {
    print('HealthNest: getCurrentUser() called');
    if (!_isInitialized) await initialize();
    
    try {
      print('HealthNest: Querying users table...');
      final response = await _getClient()
          .from(SupabaseConfig.usersTable)
          .select()
          .limit(1)
          .single();
      
      if (response != null) {
        print('HealthNest: User found: ${response['firstName']}');
        return app_models.User.fromJson(response);
      }
    } catch (e) {
      print('HealthNest: getCurrentUser error: $e');
      // User not found or other error
      return null;
    }
    
    print('HealthNest: No user found');
    return null;
  }

  @override
  Future<void> saveUser(app_models.User user) async {
    print('HealthNest: saveUser() called for user: ${user.firstName}');
    if (!_isInitialized) await initialize();
    
    try {
      print('HealthNest: Saving user to Supabase...');
      await _getClient()
          .from(SupabaseConfig.usersTable)
          .upsert(user.toJson(), onConflict: 'id');
      print('HealthNest: User saved successfully');
    } catch (e) {
      print('HealthNest: Error saving user: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteUser(String id) async {
    if (!_isInitialized) await initialize();
    
    await _supabase
        .from(SupabaseConfig.usersTable)
        .delete()
        .eq('id', id);
  }

  @override
  Future<bool> hasUser() async {
    final user = await getCurrentUser();
    return user != null;
  }

  // Patient operations
  @override
  Future<List<Patient>> getPatients() async {
    if (!_isInitialized) await initialize();
    
    try {
      final response = await _supabase
          .from(SupabaseConfig.patientsTable)
          .select()
          .order('createdAt', ascending: false);
      
      return response.map((json) => Patient.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Patient?> getPatient(String id) async {
    if (!_isInitialized) await initialize();
    
    try {
      final response = await _supabase
          .from(SupabaseConfig.patientsTable)
          .select()
          .eq('id', id)
          .single();
      
      return Patient.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> savePatient(Patient patient) async {
    if (!_isInitialized) await initialize();
    
    await _supabase
        .from(SupabaseConfig.patientsTable)
        .upsert(patient.toJson(), onConflict: 'id');
  }

  @override
  Future<void> deletePatient(String id) async {
    if (!_isInitialized) await initialize();
    
    await _supabase
        .from(SupabaseConfig.patientsTable)
        .delete()
        .eq('id', id);
  }

  // Health Record operations
  @override
  Future<List<HealthRecord>> getHealthRecords(String patientId) async {
    if (!_isInitialized) await initialize();
    
    try {
      final response = await _supabase
          .from(SupabaseConfig.healthRecordsTable)
          .select()
          .eq('patientId', patientId)
          .order('createdAt', ascending: false);
      
      return response.map((json) => HealthRecord.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<HealthRecord?> getHealthRecord(String id) async {
    if (!_isInitialized) await initialize();
    
    try {
      final response = await _supabase
          .from(SupabaseConfig.healthRecordsTable)
          .select()
          .eq('id', id)
          .single();
      
      return HealthRecord.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveHealthRecord(HealthRecord record) async {
    if (!_isInitialized) await initialize();
    
    await _supabase
        .from(SupabaseConfig.healthRecordsTable)
        .upsert(record.toJson(), onConflict: 'id');
  }

  @override
  Future<void> deleteHealthRecord(String id) async {
    if (!_isInitialized) await initialize();
    
    await _supabase
        .from(SupabaseConfig.healthRecordsTable)
        .delete()
        .eq('id', id);
  }

  // Authentication helper
  Future<void> signInAnonymously() async {
    await _supabase.auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  bool get isAuthenticated => _supabase.auth.currentUser != null;

  // Additional methods required by StorageService interface
  @override
  Future<void> syncToCloud() async {
    // Supabase handles sync automatically
  }

  @override
  Future<void> syncFromCloud() async {
    // Supabase handles sync automatically
  }

  @override
  Future<bool> isCloudConnected() async {
    return _supabase.auth.currentUser != null;
  }

  @override
  Future<String> saveDocument(String filePath, String patientId) async {
    // For now, return the file path as document path
    // In a real implementation, you'd upload to Supabase Storage
    return filePath;
  }

  @override
  Future<String?> getDocumentPath(String documentId) async {
    // For now, return the document ID as path
    // In a real implementation, you'd get the URL from Supabase Storage
    return documentId;
  }

  @override
  Future<void> deleteDocument(String documentPath) async {
    // In a real implementation, you'd delete from Supabase Storage
  }

  @override
  Future<List<Patient>> getPatientsByHospitalIdentifier(String systemName, String identifierType, String value) async {
    if (!_isInitialized) await initialize();
    
    try {
      final response = await _supabase
          .from(SupabaseConfig.patientsTable)
          .select()
          .contains('hospitalIdentifiers', '{"$systemName": {"$identifierType": "$value"}}');
      
      return response.map((json) => Patient.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Patient>> getPatientsByMobileNumber(String mobileNumber) async {
    if (!_isInitialized) await initialize();
    
    try {
      final response = await _supabase
          .from(SupabaseConfig.patientsTable)
          .select()
          .contains('mobileNumbers', mobileNumber);
      
      return response.map((json) => Patient.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
}

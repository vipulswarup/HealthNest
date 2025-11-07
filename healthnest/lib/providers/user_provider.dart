import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';
import '../models/patient.dart';
import '../models/health_record.dart';
import '../services/storage_service.dart';
import '../services/supabase_storage_service.dart';
import '../config/supabase_config.dart';

class UserProvider with ChangeNotifier {
  StorageService? _storage;
  User? _currentUser;
  List<Patient> _patients = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  UserProvider();

  // Getters
  User? get currentUser => _currentUser;
  List<Patient> get patients => _patients;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get hasUser => _currentUser != null;
  bool get onboardingCompleted => _currentUser?.onboardingCompleted ?? false;

  // Initialize the provider
  Future<void> initialize() async {
    print('HealthNest: UserProvider.initialize() called');
    debugPrint('UserProvider: initialize called');
    if (_isInitialized) {
      print('HealthNest: UserProvider already initialized, returning');
      debugPrint('UserProvider: already initialized, returning');
      return;
    }
    
    print('HealthNest: UserProvider setting loading state');
    _setLoading(true);
    
    try {
      // Initialize storage service first
      print('HealthNest: UserProvider creating storage service...');
      _storage = SupabaseStorageService();
      
      // Initialize Supabase first
      print('HealthNest: Initializing Supabase...');
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      print('HealthNest: Supabase initialization successful');
      
      print('HealthNest: UserProvider initializing storage service...');
      debugPrint('UserProvider: initializing storage');
      await _storage!.initialize();
      print('HealthNest: UserProvider storage service initialized successfully');
      
      print('HealthNest: UserProvider checking for existing user...');
      debugPrint('UserProvider: checking for existing user');
      final user = await _storage!.getCurrentUser();
      if (user != null) {
        print('HealthNest: UserProvider found existing user: ${user.firstName}');
        debugPrint('UserProvider: found existing user');
        _currentUser = user;
        
        if (user.onboardingCompleted) {
          print('HealthNest: UserProvider onboarding completed, loading patients...');
          debugPrint('UserProvider: onboarding completed, loading patients');
          await _loadPatients();
        }
      } else {
        print('HealthNest: UserProvider no existing user found');
        debugPrint('UserProvider: no existing user found');
        
        // No user exists - this is normal for first-time setup
        print('HealthNest: No user found - user will need to complete onboarding');
      }
      
      _isInitialized = true;
      print('HealthNest: UserProvider initialization complete');
      debugPrint('UserProvider: initialization complete');
    } catch (e) {
      print('HealthNest: ERROR initializing UserProvider: $e');
      debugPrint('Error initializing UserProvider: $e');
      // Re-throw the error so it can be handled by the UI
      rethrow;
    } finally {
      print('HealthNest: UserProvider setting loading state to false');
      _setLoading(false);
    }
  }

  // User operations
  Future<void> createUser({
    required String firstName,
    String? middleName,
    String? lastName,
    String? title,
    String? suffix,
    required List<String> emails,
    required List<Map<String, String>> mobileNumbers,
  }) async {
    _setLoading(true);
    
    try {
      final user = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        title: title,
        suffix: suffix,
        emails: emails,
        mobileNumbers: mobileNumbers,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        preferences: {},
        onboardingCompleted: false,
      );
      
      await _storage!.saveUser(user);
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> completeOnboarding() async {
    if (_currentUser == null) return;
    
    _setLoading(true);
    
    try {
      final updatedUser = _currentUser!.copyWith(
        onboardingCompleted: true,
        updatedAt: DateTime.now(),
      );
      
      await _storage!.saveUser(updatedUser);
      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Patient operations
  Future<void> addPatient(Patient patient) async {
    _setLoading(true);
    
    try {
      await _getStorage().savePatient(patient);
      _patients.add(patient);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding patient: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updatePatient(Patient patient) async {
    _setLoading(true);
    
    try {
      await _getStorage().savePatient(patient);
      final index = _patients.indexWhere((p) => p.id == patient.id);
      if (index != -1) {
        _patients[index] = patient;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating patient: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deletePatient(String patientId) async {
    _setLoading(true);
    
    try {
      await _getStorage().deletePatient(patientId);
      _patients.removeWhere((p) => p.id == patientId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting patient: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPatients() async {
    if (!onboardingCompleted) return;
    await _loadPatients();
  }

  Future<void> _loadPatients() async {
    _setLoading(true);
    
    try {
      _patients = await _getStorage().getPatients();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading patients: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Cloud sync operations
  Future<void> syncToCloud() async {
    _setLoading(true);
    
    try {
      await _getStorage().syncToCloud();
    } catch (e) {
      debugPrint('Error syncing to cloud: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> syncFromCloud() async {
    _setLoading(true);
    
    try {
      await _getStorage().syncFromCloud();
      
      final user = await _getStorage().getCurrentUser();
      if (user != null) {
        _currentUser = user;
        if (user.onboardingCompleted) {
          await _loadPatients();
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing from cloud: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Health record operations
  Future<List<HealthRecord>> getHealthRecords(String patientId) async {
    try {
      return await _getStorage().getHealthRecords(patientId);
    } catch (e) {
      debugPrint('Error getting health records: $e');
      rethrow;
    }
  }

  Future<void> saveHealthRecord(HealthRecord record) async {
    _setLoading(true);
    try {
      await _getStorage().saveHealthRecord(record);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving health record: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteHealthRecord(String id) async {
    _setLoading(true);
    try {
      await _getStorage().deleteHealthRecord(id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting health record: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> isCloudConnected() async {
    return await _getStorage().isCloudConnected();
  }

  // Helper methods
  void _setLoading(bool loading) {
    debugPrint('UserProvider: _setLoading($loading)');
    _isLoading = loading;
    notifyListeners();
  }

  StorageService _getStorage() {
    if (_storage == null) {
      throw Exception('Storage service not initialized. Call initialize() first.');
    }
    return _storage!;
  }







  // Cleanup
  @override
  Future<void> dispose() async {
    await _getStorage().close();
    super.dispose();
  }
} 
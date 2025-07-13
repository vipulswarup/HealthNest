import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/patient.dart';
import '../services/storage_service.dart';
import '../services/hybrid_storage_service.dart';

class UserProvider with ChangeNotifier {
  final StorageService _storage;
  User? _currentUser;
  List<Patient> _patients = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  UserProvider() : _storage = HybridStorageService();

  // Getters
  User? get currentUser => _currentUser;
  List<Patient> get patients => _patients;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get hasUser => _currentUser != null;
  bool get onboardingCompleted => _currentUser?.onboardingCompleted ?? false;

  // Initialize the provider
  Future<void> initialize() async {
    debugPrint('UserProvider: initialize called');
    if (_isInitialized) {
      debugPrint('UserProvider: already initialized, returning');
      return;
    }
    
    _setLoading(true);
    
    try {
      debugPrint('UserProvider: initializing storage');
      await _storage.initialize();
      
      debugPrint('UserProvider: checking for existing user');
      final user = await _storage.getCurrentUser();
      if (user != null) {
        debugPrint('UserProvider: found existing user');
        _currentUser = user;
        
        if (user.onboardingCompleted) {
          debugPrint('UserProvider: onboarding completed, loading patients');
          await _loadPatients();
        }
      } else {
        debugPrint('UserProvider: no existing user found');
      }
      
      _isInitialized = true;
      debugPrint('UserProvider: initialization complete');
    } catch (e) {
      debugPrint('Error initializing UserProvider: $e');
    } finally {
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
      
      await _storage.saveUser(user);
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
      
      await _storage.saveUser(updatedUser);
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
      await _storage.savePatient(patient);
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
      await _storage.savePatient(patient);
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
      await _storage.deletePatient(patientId);
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
      _patients = await _storage.getPatients();
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
      await _storage.syncToCloud();
    } catch (e) {
      debugPrint('Error syncing to cloud: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> syncFromCloud() async {
    _setLoading(true);
    
    try {
      await _storage.syncFromCloud();
      
      final user = await _storage.getCurrentUser();
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

  Future<bool> isCloudConnected() async {
    return await _storage.isCloudConnected();
  }

  // Helper methods
  void _setLoading(bool loading) {
    debugPrint('UserProvider: _setLoading($loading)');
    _isLoading = loading;
    notifyListeners();
  }

  // Cleanup
  @override
  Future<void> dispose() async {
    await _storage.close();
    super.dispose();
  }
} 
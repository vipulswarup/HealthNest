// App-wide constants and configuration

class AppConstants {
  // App information
  static const String appName = 'HealthNest';
  static const String appVersion = '1.0.0';
  
  // Storage keys
  static const String storageKeyPrefix = 'healthnest_';
  static const String databaseName = 'healthnest.db';
  
  // File paths
  static const String documentsFolder = 'documents';
  static const String tempFolder = 'temp';
  
  // Supported file types
  static const List<String> supportedImageTypes = [
    'jpg', 'jpeg', 'png', 'heic', 'heif'
  ];
  static const List<String> supportedDocumentTypes = [
    'pdf', 'doc', 'docx'
  ];
  
  // Default tags
  static const List<String> defaultTags = [
    'prescription',
    'lab_report',
    'scan_result',
    'discharge_summary',
    'consultation',
    'medication',
    'symptom',
    'vital_signs',
  ];
  
  // Record types (openEHR archetypes)
  static const List<String> recordTypes = [
    'openEHR-EHR-OBSERVATION.lab_test.v1',
    'openEHR-EHR-OBSERVATION.vital_signs.v2',
    'openEHR-EHR-EVALUATION.problem_diagnosis.v1',
    'openEHR-EHR-INSTRUCTION.medication_order.v1',
    'openEHR-EHR-ACTION.medication.v1',
    'openEHR-EHR-EVALUATION.clinical_synopsis.v1',
  ];
  
  // Privacy settings
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
  static const bool enableTelemetry = false;
} 
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url {
    try {
      final envUrl = dotenv.env['SUPABASE_URL'];
      if (envUrl == null || envUrl.isEmpty) {
        throw Exception('SUPABASE_URL not found in environment variables. Please create a .env file with your Supabase configuration. See SUPABASE_SETUP.md for instructions.');
      }
      print('HealthNest: Supabase URL loaded from environment: ${envUrl.substring(0, 20)}...');
      return envUrl;
    } catch (e) {
      print('HealthNest: Error getting Supabase URL from env: $e');
      throw Exception('Failed to load Supabase URL from environment variables. Please ensure you have created a .env file with SUPABASE_URL. See SUPABASE_SETUP.md for setup instructions.');
    }
  }
  
  static String get anonKey {
    try {
      final envKey = dotenv.env['SUPABASE_ANON_KEY'];
      if (envKey == null || envKey.isEmpty) {
        throw Exception('SUPABASE_ANON_KEY not found in environment variables. Please create a .env file with your Supabase configuration. See SUPABASE_SETUP.md for instructions.');
      }
      print('HealthNest: Supabase Key loaded from environment: ${envKey.substring(0, 20)}...');
      return envKey;
    } catch (e) {
      print('HealthNest: Error getting Supabase key from env: $e');
      throw Exception('Failed to load Supabase key from environment variables. Please ensure you have created a .env file with SUPABASE_ANON_KEY. See SUPABASE_SETUP.md for setup instructions.');
    }
  }
  
  // Database table names
  static const String usersTable = 'users';
  static const String patientsTable = 'patients';
  static const String healthRecordsTable = 'health_records';
  
  // Validation
  static bool get isValid {
    return url.isNotEmpty && anonKey.isNotEmpty;
  }
}

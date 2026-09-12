import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const _lastPatientKey = 'last_patient_id';

  Future<String?> lastPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastPatientKey);
  }

  Future<void> setLastPatientId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPatientKey, id);
  }
}

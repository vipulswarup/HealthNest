import 'package:sanovault/api/api_client.dart';
import 'package:sanovault/api/api_config.dart';
import 'package:sanovault/api/models.dart';

class SanoVaultApi {
  SanoVaultApi(this._client);

  final ApiClient _client;

  Future<String> signInWithApple({
    required String identityToken,
    String? fullName,
    String? email,
  }) async {
    final json = await _client.post('/api/auth/mobile/apple', {
      'identityToken': identityToken,
      if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
      if (email != null && email.isNotEmpty) 'email': email,
    }) as Map<String, dynamic>;
    final token = json['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Apple sign-in did not return a session');
    }
    return token;
  }

  Future<void> revokeSession() async {
    await _client.delete('/api/auth/mobile/session');
  }

  Future<BetaStatus> betaStatus() async {
    final json = await _client.get('/api/users/beta-acknowledgement') as Map<String, dynamic>;
    return BetaStatus.fromJson(json);
  }

  Future<void> acceptBeta() async {
    await _client.post('/api/users/beta-acknowledgement', {
      'version': betaAcknowledgementVersion,
    });
  }

  Future<Profile> me() async {
    final json = await _client.get('/api/users/me') as Map<String, dynamic>;
    return Profile.fromJson(json);
  }

  Future<DashboardHome> dashboard() async {
    final json = await _client.get('/api/dashboard') as Map<String, dynamic>;
    return DashboardHome.fromJson(json);
  }

  Future<void> setActiveHousehold(String householdId) async {
    await _client.patch('/api/me/active-household', {'householdId': householdId});
  }

  Future<Household> createHousehold(String name) async {
    final json = await _client.post('/api/households', {'name': name}) as Map<String, dynamic>;
    return Household.fromJson(json);
  }

  Future<void> acceptInvite(String token) async {
    await _client.post('/api/households/invites/$token', {'patientIds': <String>[]});
  }

  Future<void> addPerson({
    required String householdId,
    required String firstName,
    String? lastName,
    required String dateOfBirth,
    required String gender,
  }) async {
    await _client.post('/api/patients', {
      'householdId': householdId,
      'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
    });
  }
}

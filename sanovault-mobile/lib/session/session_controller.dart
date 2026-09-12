import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:sanovault/api/api_config.dart';
import 'package:sanovault/api/api_exception.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/api/sanovault_api.dart';
import 'package:sanovault/session/session_store.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum SessionStatus { restoring, signedOut, needsAcknowledgement, ready }

class SessionController extends ChangeNotifier {
  SessionController({required this.api, required this.store});

  final SanoVaultApi api;
  final SessionStore store;

  SessionStatus status = SessionStatus.restoring;
  Profile? profile;
  String? error;

  Future<void> restore() async {
    error = null;
    final token = await store.readToken();
    if (token == null || token.isEmpty) {
      status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }
    await _loadAfterToken();
  }

  Future<void> signInWithApple() async {
    error = null;
    notifyListeners();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw const ApiException('Apple did not return a sign-in token.');
      }
      final fullName = [
        credential.givenName,
        credential.familyName,
      ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
      final token = await api.signInWithApple(
        identityToken: identityToken,
        fullName: fullName,
        email: credential.email,
      );
      await store.writeToken(token);
      await _loadAfterToken();
    } on SignInWithAppleAuthorizationException catch (caught) {
      if (caught.code == AuthorizationErrorCode.canceled) return;
      error = caught.message;
      status = SessionStatus.signedOut;
      notifyListeners();
    } catch (caught) {
      error = caught is ApiException ? caught.message : 'Apple sign-in failed.';
      status = SessionStatus.signedOut;
      notifyListeners();
    }
  }

  Future<void> signInWithWeb() async {
    error = null;
    notifyListeners();
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: '$apiBaseUrl/auth/signin?native=1',
        callbackUrlScheme: nativeAuthScheme,
      );
      final token = Uri.parse(result).queryParameters['token'];
      if (token == null || token.isEmpty) {
        throw const ApiException('Sign-in did not return a session.');
      }
      await store.writeToken(token);
      await _loadAfterToken();
    } catch (caught) {
      final text = caught.toString().toLowerCase();
      if (text.contains('cancel') || text.contains('c16')) return;
      error = caught is ApiException ? caught.message : 'Could not finish web sign-in.';
      status = SessionStatus.signedOut;
      notifyListeners();
    }
  }

  Future<void> acceptBeta() async {
    error = null;
    notifyListeners();
    try {
      await api.acceptBeta();
      profile = await api.me();
      status = SessionStatus.ready;
      notifyListeners();
    } catch (caught) {
      error = caught is ApiException ? caught.message : 'Could not save your acknowledgement.';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await api.revokeSession();
    } catch (_) {}
    await store.clear();
    profile = null;
    error = null;
    status = SessionStatus.signedOut;
    notifyListeners();
  }

  Future<void> _loadAfterToken() async {
    try {
      final beta = await api.betaStatus();
      if (!beta.acknowledged) {
        profile = null;
        status = SessionStatus.needsAcknowledgement;
        notifyListeners();
        return;
      }
      profile = await api.me();
      status = SessionStatus.ready;
      notifyListeners();
    } on ApiException catch (caught) {
      if (caught.isUnauthorized) {
        await store.clear();
        profile = null;
        status = SessionStatus.signedOut;
        error = null;
        notifyListeners();
        return;
      }
      error = caught.message;
      status = SessionStatus.signedOut;
      notifyListeners();
    } catch (_) {
      error = 'Could not restore your session.';
      status = SessionStatus.signedOut;
      notifyListeners();
    }
  }
}

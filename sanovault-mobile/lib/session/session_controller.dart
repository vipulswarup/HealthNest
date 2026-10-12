import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:sanovault/api/api_config.dart';
import 'package:sanovault/api/api_exception.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/api/sanovault_api.dart';
import 'package:sanovault/session/auth_link_listener.dart';
import 'package:sanovault/session/session_store.dart';
import 'package:sanovault/session/offline_store.dart';
import 'package:sanovault/session/people_store.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum SessionStatus { restoring, signedOut, needsAcknowledgement, ready }

class SessionController extends ChangeNotifier {
  SessionController({
    required this.api,
    required this.store,
    required this.offline,
  });

  final SanoVaultApi api;
  final SessionStore store;
  final OfflineStore offline;
  late final PeopleStore people = PeopleStore(api);

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

  int dataEpoch = 0;

  void invalidateData() {
    dataEpoch += 1;
    people.markStale();
    notifyListeners();
  }

  Future<void> signInWithPassword(String email, String password) async {
    error = null;
    notifyListeners();
    try {
      final token = await api.signInWithPassword(
        email: email,
        password: password,
      );
      await store.writeToken(token);
      await _loadAfterToken();
    } catch (caught) {
      error = caught is ApiException
          ? caught.message
          : 'Could not sign in with email.';
      status = SessionStatus.signedOut;
      notifyListeners();
    }
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
        authorizationCode: credential.authorizationCode,
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
      final result = !kIsWeb && Platform.isMacOS
          ? await _authenticateMacOS()
          : await FlutterWebAuth2.authenticate(
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
      if (text.contains('cancel') ||
          text.contains('c16') ||
          text.contains('timeout'))
        return;
      error = caught is ApiException
          ? caught.message
          : 'Could not finish web sign-in.';
      status = SessionStatus.signedOut;
      notifyListeners();
    }
  }

  /// Brave/Chrome as the default browser often breaks ASWebAuthenticationSession
  /// on macOS. Open Safari and accept the sanovault:// callback via AppDelegate.
  Future<String> _authenticateMacOS() async {
    final authUrl = '$apiBaseUrl/auth/signin?native=1';
    final pending = AuthLinkListener.waitForScheme(nativeAuthScheme);
    await AuthLinkListener.openSafari(authUrl);
    final uri = await pending;
    return uri.toString();
  }

  Future<void> acceptBeta({required bool groqAiEnabled}) async {
    error = null;
    notifyListeners();
    try {
      await api.acceptBeta(groqAiEnabled: groqAiEnabled);
      profile = await api.me();
      status = SessionStatus.ready;
      notifyListeners();
    } catch (caught) {
      error = caught is ApiException
          ? caught.message
          : 'Could not save your acknowledgement.';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await api.revokeSession();
    } catch (_) {}
    await store.clear();
    await offline.clear();
    people.reset();
    profile = null;
    error = null;
    status = SessionStatus.signedOut;
    notifyListeners();
  }

  Future<void> _loadAfterToken() async {
    try {
      // These two checks are independent; run them together.
      // `me()` is refused until the terms are accepted, so a failure there is
      // only an error if the terms were in fact accepted.
      Object? meFailure;
      final results = await Future.wait<Object?>([
        api.betaStatus(),
        api.me().then<Object?>((value) => value).catchError((Object error) {
          meFailure = error;
          return null;
        }),
      ]);
      final beta = results[0] as BetaStatus;
      if (!beta.acknowledged) {
        profile = null;
        status = SessionStatus.needsAcknowledgement;
        notifyListeners();
        return;
      }
      if (meFailure != null) throw meFailure!;
      profile = results[1] as Profile;
      if (api.usedOfflineData) {
        final lastOnline = await offline.lastOnline();
        final withinOfflineWindow =
            lastOnline != null &&
            DateTime.now().toUtc().difference(lastOnline.toUtc()) <=
                const Duration(days: 30);
        if (!withinOfflineWindow) {
          status = SessionStatus.signedOut;
          error = 'Reconnect to verify your session before using offline data.';
          notifyListeners();
          return;
        }
      }
      status = SessionStatus.ready;
      if (!api.usedOfflineData) await offline.markOnline();
      notifyListeners();
      // Warm the people list so every screen opens with it, and retry additions
      // recorded while offline, without keeping the first screen waiting.
      unawaited(people.ensure().then((_) {}).catchError((Object _) {}));
      unawaited(api.flushPendingOperations());
    } on ApiException catch (caught) {
      if (caught.isUnauthorized) {
        await store.clear();
        await offline.clear();
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

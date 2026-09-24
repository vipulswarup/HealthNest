import 'package:flutter/cupertino.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _confirmation = TextEditingController();
  Map<String, dynamic>? _preview;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final preview = await SessionScope.of(context).api
          .accountDeletionPreview();
      if (mounted)
        setState(() {
          _preview = preview;
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _delete() async {
    final session = SessionScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? code;
      if (_preview?['needsAppleReauthentication'] == true) {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [],
        );
        code = credential.authorizationCode;
      }
      await session.api.deleteAccount(appleAuthorizationCode: code);
      await session.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Delete account'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Permanently delete your login account',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your profile, login access and sessions will be removed. Families with other members and their shared patient records remain; a remaining member takes over families you created. Families where you are the last member are deleted, including patients belonging only to them. A patient profile is separate from a login account. Download anything you need first.',
            ),
            const SizedBox(height: 16),
            const Text(
              'This device’s cached records and pending offline uploads will be discarded. Stored files and sign-in-provider access are cleaned up in the background. This cannot be undone.',
            ),
            if (_preview != null) ...[
              const SizedBox(height: 20),
              for (final family in _preview!['families'] as List)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${family['name']}: ${family['will_delete'] == true ? 'will be deleted' : 'will remain for other members'}',
                  ),
                ),
              if (_preview!['needsAppleReauthentication'] == true)
                const Text(
                  'Apple will ask you to confirm your identity so we can revoke your Apple sign-in.',
                ),
              const SizedBox(height: 16),
              const Text('Type DELETE to confirm'),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _confirmation,
                enabled: !_busy,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                color: SvColors.danger,
                onPressed: !_busy && _confirmation.text == 'DELETE'
                    ? _delete
                    : null,
                child: Text(
                  _busy ? 'Deleting…' : 'Permanently delete my account',
                ),
              ),
            ] else if (_error == null)
              const CupertinoActivityIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: SvColors.danger)),
              if (_preview == null)
                CupertinoButton(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
            ],
            const SizedBox(height: 24),
            const Text(
              'For help or to request deletion without signing in, email support@eisenvault.com with your account email. Do not send passwords or medical records. Details: www.sanovault.com/delete-account',
            ),
          ],
        ),
      ),
    ),
  );
}

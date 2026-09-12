import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Theme, ThemeData;
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const _testEmail = String.fromEnvironment('TEST_EMAIL');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: _testEmail);
    _password = TextEditingController(text: _testPassword);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await SessionScope.of(context).signInWithPassword(_email.text, _password.text);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return CupertinoPageScaffold(
      backgroundColor: SvColors.groupedBackground,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset('assets/logo.png', width: 72, height: 72),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SanoVault',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: SvColors.ink),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your family folder, on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, color: SvColors.slate),
                ),
                const SizedBox(height: 28),
                if (session.error != null) ...[
                  SvErrorBanner(message: session.error!),
                  const SizedBox(height: 16),
                ],
                CupertinoTextField(
                  controller: _email,
                  placeholder: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  padding: const EdgeInsets.all(14),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: _password,
                  placeholder: 'Password',
                  obscureText: true,
                  padding: const EdgeInsets.all(14),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                SvFilledButton(
                  label: _busy ? 'Signing in…' : 'Sign In',
                  enabled: !_busy,
                  onPressed: _busy ? null : _submit,
                ),
                const SizedBox(height: 20),
                Theme(
                  data: ThemeData.light(),
                  child: const Material(color: Color(0x00000000), child: _AppleButton()),
                ),
                CupertinoButton(
                  onPressed: () => session.signInWithWeb(),
                  child: const Text('Use Google or a magic link', style: TextStyle(color: SvColors.coral)),
                ),
                const Text(
                  'Records stay in your SanoVault account. This app uses the same family folder as the website.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: SvColors.slate, height: 1.4),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton();

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return SignInWithAppleButton(
      onPressed: () => session.signInWithApple(),
      borderRadius: BorderRadius.circular(12),
      height: 52,
    );
  }
}

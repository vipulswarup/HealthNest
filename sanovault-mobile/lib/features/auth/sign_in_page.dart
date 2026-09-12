import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Theme, ThemeData;
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return CupertinoPageScaffold(
      backgroundColor: SvColors.groupedBackground,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 72),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              'assets/logo.png',
                              width: 88,
                              height: 88,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'SanoVault',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: SvColors.ink,
                            letterSpacing: 0.37,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your family folder, on this iPhone.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, color: SvColors.slate),
                        ),
                        const SizedBox(height: 40),
                        if (session.error != null) ...[
                          SvErrorBanner(message: session.error!),
                          const SizedBox(height: 16),
                        ],
                        Theme(
                          data: ThemeData.light(),
                          child: const Material(
                            color: Color(0x00000000),
                            child: _AppleButton(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CupertinoButton(
                          onPressed: () => session.signInWithWeb(),
                          child: const Text(
                            'Use email, Google, or a magic link',
                            style: TextStyle(fontSize: 16, color: SvColors.coral),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Records stay in your SanoVault account. This app uses the same family folder as the website.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: SvColors.slate, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                );
              },
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

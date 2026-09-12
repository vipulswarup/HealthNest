import 'package:flutter/cupertino.dart';
import 'package:sanovault/features/auth/sign_in_page.dart';
import 'package:sanovault/features/legal/beta_page.dart';
import 'package:sanovault/features/shell/tab_shell.dart';
import 'package:sanovault/session/session_controller.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        switch (session.status) {
          case SessionStatus.restoring:
            return const CupertinoPageScaffold(
              backgroundColor: SvColors.groupedBackground,
              child: Center(child: CupertinoActivityIndicator()),
            );
          case SessionStatus.signedOut:
            return const SignInPage();
          case SessionStatus.needsAcknowledgement:
            return const BetaPage();
          case SessionStatus.ready:
            return const TabShell();
        }
      },
    );
  }
}

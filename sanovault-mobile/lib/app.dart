import 'package:flutter/cupertino.dart';
import 'package:sanovault/features/shell/app_gate.dart';
import 'package:sanovault/features/shell/share_intent_host.dart';
import 'package:sanovault/session/session_controller.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_theme.dart';

final sanovaultNavigatorKey = GlobalKey<NavigatorState>();

class SanoVaultApp extends StatelessWidget {
  const SanoVaultApp({super.key, required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: session,
      child: CupertinoApp(
        title: 'SanoVault',
        navigatorKey: sanovaultNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: buildSvTheme(),
        home: ShareIntentHost(
          navigatorKey: sanovaultNavigatorKey,
          child: const AppGate(),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/api_config.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/widgets/sv_controls.dart';

class BetaPage extends StatefulWidget {
  const BetaPage({super.key});

  @override
  State<BetaPage> createState() => _BetaPageState();
}

class _BetaPageState extends State<BetaPage> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return CupertinoPageScaffold(
      backgroundColor: SvColors.groupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('SanoVault'),
        automaticallyImplyLeading: false,
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    betaAcknowledgementTitle,
                    style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    betaAcknowledgementText,
                    style: const TextStyle(fontSize: 17, height: 1.45, color: SvColors.ink),
                  ),
                  const Spacer(),
                  if (session.error != null) ...[
                    SvErrorBanner(message: session.error!),
                    const SizedBox(height: 16),
                  ],
                  GestureDetector(
                    onTap: () => setState(() => _agreed = !_agreed),
                    child: Row(
                      children: [
                        Icon(
                          _agreed ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                          color: _agreed ? SvColors.coral : SvColors.slate,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'I understand and want to continue',
                            style: TextStyle(fontSize: 17, color: SvColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SvFilledButton(
                    label: 'Continue',
                    enabled: _agreed,
                    onPressed: _agreed ? () => session.acceptBeta() : null,
                  ),
                  CupertinoButton(
                    onPressed: () => session.signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

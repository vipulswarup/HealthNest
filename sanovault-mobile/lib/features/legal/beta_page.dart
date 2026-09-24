import 'package:sanovault/features/legal/privacy_page.dart';
import 'package:sanovault/features/account/delete_account_page.dart';
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
  bool _groqAiEnabled = true;

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
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              children: [
                Text(
                  betaAcknowledgementTitle,
                  style: CupertinoTheme.of(context)
                      .textTheme
                      .navLargeTitleTextStyle,
                ),
                const SizedBox(height: 16),
                Text(
                  betaAcknowledgementText,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.45,
                    color: SvColors.ink,
                  ),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const PrivacyPage(),
                    ),
                  ),
                  child: const Text('Read privacy policy'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SvColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: SvColors.slate.withValues(alpha: .2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Optional AI document processing',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: SvColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        groqAiConsentText,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: SvColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoListTile(
                        padding: EdgeInsets.zero,
                        title: const Text(
                          'Enable Groq AI document processing (on by default)',
                        ),
                        trailing: CupertinoSwitch(
                          value: _groqAiEnabled,
                          onChanged: (value) =>
                              setState(() => _groqAiEnabled = value),
                        ),
                      ),
                      const Text(
                        'You can change this later in More settings.',
                        style: TextStyle(fontSize: 13, color: SvColors.slate),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        groqAiConsentAcknowledgement,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: SvColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (session.error != null) ...[
                  SvErrorBanner(message: session.error!),
                  const SizedBox(height: 16),
                ],
                GestureDetector(
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: Row(
                    children: [
                      Icon(
                        _agreed
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.circle,
                        color: _agreed ? SvColors.sage : SvColors.slate,
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
                  onPressed: _agreed
                      ? () => session.acceptBeta(groqAiEnabled: _groqAiEnabled)
                      : null,
                ),
                CupertinoButton(
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const DeleteAccountPage(),
                    ),
                  ),
                  child: const Text('Delete account'),
                ),
                CupertinoButton(
                  onPressed: () => session.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/api_config.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';

class GroqAiSettingsPage extends StatefulWidget {
  const GroqAiSettingsPage({super.key});

  @override
  State<GroqAiSettingsPage> createState() => _GroqAiSettingsPageState();
}

class _GroqAiSettingsPageState extends State<GroqAiSettingsPage> {
  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;
  int _loadAttempt = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final status = await SessionScope.of(context).api.betaStatus();
        if (mounted)
          setState(() {
            _enabled = status.groqAiEnabled;
            _loading = false;
            if (!status.acknowledged) {
              _error = 'Complete onboarding before changing this setting.';
            }
          });
      } catch (_) {
        if (mounted)
          setState(() {
            _enabled = false;
            _loading = false;
            _error = 'Could not load this setting. Please try again.';
          });
      }
    });
  }

  Future<void> _setEnabled(bool value) async {
    final attempt = ++_loadAttempt;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).api.setGroqAiEnabled(value);
      if (mounted && attempt == _loadAttempt)
        setState(() {
          _enabled = value;
          _saving = false;
        });
    } catch (_) {
      if (mounted && attempt == _loadAttempt)
        setState(() {
          _saving = false;
          _error = 'Could not save this setting. Please try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: SvColors.groupedBackground,
    navigationBar: const CupertinoNavigationBar(
      middle: Text('AI document processing'),
    ),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            groqAiConsentText,
            style: TextStyle(fontSize: 16, height: 1.5, color: SvColors.ink),
          ),
          const SizedBox(height: 20),
          CupertinoListSection.insetGrouped(
            children: [
              CupertinoListTile(
                title: const Text('Enable Groq AI'),
                trailing: CupertinoSwitch(
                  value: _enabled,
                  onChanged: _saving || _loading || _error != null
                      ? null
                      : _setEnabled,
                ),
              ),
            ],
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: SvColors.danger)),
          if (_saving) const Center(child: CupertinoActivityIndicator()),
          if (_loading) const Center(child: CupertinoActivityIndicator()),
          const Text(
            'When turned off, you can still save files and enter record details yourself. SanoVault will not send your uploads for Groq AI processing.',
            style: TextStyle(fontSize: 14, height: 1.4, color: SvColors.slate),
          ),
        ],
      ),
    ),
  );
}

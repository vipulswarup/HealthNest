import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sanovault/widgets/sv_page.dart';
import 'package:share_plus/share_plus.dart';

class HouseholdsPage extends StatefulWidget {
  const HouseholdsPage({super.key});

  @override
  State<HouseholdsPage> createState() => _HouseholdsPageState();
}

class _HouseholdsPageState extends State<HouseholdsPage> {
  DashboardHome? _home;
  List<HouseholdMember> _members = const [];
  String? _error;
  final _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = SessionScope.of(context).api;
    try {
      final home = await api.dashboard();
      final members = home.householdId == null ? <HouseholdMember>[] : await api.householdMembers(home.householdId!);
      if (!mounted) return;
      setState(() {
        _home = home;
        _members = members;
        _error = null;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  Future<void> _invite() async {
    final householdId = _home?.householdId;
    if (householdId == null || _email.text.trim().isEmpty) return;
    try {
      final url = await SessionScope.of(context).api.inviteToHousehold(householdId, _email.text.trim());
      _email.clear();
      await _load();
      if (url.isNotEmpty) {
        await SharePlus.instance.share(ShareParams(text: 'Join our SanoVault family folder: $url'));
      }
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  Future<void> _leave() async {
    final householdId = _home?.householdId;
    if (householdId == null) return;
    await SessionScope.of(context).api.leaveHousehold(householdId);
    await _load();
    if (mounted) SessionScope.of(context).invalidateData();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return SvLargePage(
      title: 'Who Can See This',
      error: _error,
      onRefresh: _load,
      child: Column(
        children: [
          if ((_home?.households.length ?? 0) > 1)
            CupertinoListSection.insetGrouped(
              header: const Text('Folders'),
              children: [
                for (final household in _home!.households)
                  CupertinoListTile(
                    title: Text(household.name),
                    trailing: household.id == _home!.householdId
                        ? const Icon(CupertinoIcons.check_mark, color: SvColors.coral)
                        : null,
                    onTap: () async {
                      await session.api.setActiveHousehold(household.id);
                      session.invalidateData();
                      await _load();
                    },
                  ),
              ],
            ),
          CupertinoListSection.insetGrouped(
            header: const Text('Members'),
            children: [
              if (_members.isEmpty)
                const CupertinoListTile(title: Text('No folder yet.'))
              else
                for (final member in _members) CupertinoListTile(title: Text(member.label), subtitle: Text(member.email ?? '')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CupertinoTextField(controller: _email, placeholder: 'Invite by email', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                SvFilledButton(label: 'Send invite', onPressed: _invite),
                CupertinoButton(onPressed: _leave, child: const Text('Leave this folder', style: TextStyle(color: SvColors.danger))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:sanovault/widgets/confirm_deletion.dart';
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
  bool _deleting = false;
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
      final members = home.householdId == null
          ? <HouseholdMember>[]
          : await api.householdMembers(home.householdId!);
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
      final url = await SessionScope.of(context).api
          .inviteToHousehold(householdId, _email.text.trim());
      _email.clear();
      await _load();
      if (url.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(text: 'Join our SanoVault family folder: $url'),
        );
      }
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  Future<void> _leave() async {
    final householdId = _home?.householdId;
    if (householdId == null) return;
    try {
      final session = SessionScope.of(context);
      await session.api.leaveHousehold(householdId);
      session.invalidateData();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _deleteFamily() async {
    final session = SessionScope.of(context);
    final familyId = _home?.householdId;
    if (familyId == null) return;
    final family = _home!.households.firstWhere((h) => h.id == familyId);
    final confirmed = await confirmDeletion(
      context,
      title: 'Delete ${family.name}?',
      message: 'This permanently deletes the family for everyone, its invitations and WhatsApp links. Patients and records belonging only to it are deleted. Patients linked to another family remain there. Login accounts are not deleted.',
      action: 'Delete family',
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await session.api.deleteFamily(familyId);
      session.invalidateData();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
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
                        ? const Icon(
                            CupertinoIcons.check_mark,
                            color: SvColors.sage,
                          )
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
                for (final member in _members)
                  CupertinoListTile(
                    title: Text(member.label),
                    subtitle: Text(member.email ?? ''),
                  ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CupertinoTextField(
                  controller: _email,
                  placeholder: 'Invite by email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                SvFilledButton(label: 'Send invite', onPressed: _invite),
                if (_home?.households.any(
                      (h) =>
                          h.id == _home?.householdId &&
                          h.createdBy == session.profile?.id,
                    ) ==
                    true)
                  CupertinoButton(
                    onPressed: _deleting ? null : _deleteFamily,
                    child: Text(
                      _deleting ? 'Deleting…' : 'Delete this family',
                      style: const TextStyle(color: SvColors.danger),
                    ),
                  ),
                CupertinoButton(
                  onPressed: _deleting ? null : _leave,
                  child: const Text(
                    'Leave this folder',
                    style: TextStyle(color: SvColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

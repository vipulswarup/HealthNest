import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/features/placeholder/coming_soon_page.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';

class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  List<Household> _households = const [];
  String? _activeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final home = await SessionScope.of(context).api.dashboard();
      if (!mounted) return;
      setState(() {
        _households = home.households;
        _activeId = home.householdId;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _switchHousehold(String id) async {
    if (id == _activeId) return;
    await SessionScope.of(context).api.setActiveHousehold(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final profile = session.profile;
    return CupertinoPageScaffold(
      backgroundColor: SvColors.groupedBackground,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('More'),
            border: null,
            backgroundColor: SvColors.groupedBackground,
          ),
          SliverList.list(
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              CupertinoListSection.insetGrouped(
                header: const Text('Account'),
                children: [
                  CupertinoListTile(
                    title: Text(profile?.displayName ?? 'Signed in'),
                    subtitle: Text(profile?.email ?? ''),
                  ),
                ],
              ),
              if (_households.isNotEmpty)
                CupertinoListSection.insetGrouped(
                  header: const Text('Family Folder'),
                  children: [
                    for (final household in _households)
                      CupertinoListTile(
                        title: Text(household.name),
                        trailing: household.id == _activeId
                            ? const Icon(CupertinoIcons.check_mark, color: SvColors.coral)
                            : null,
                        onTap: () => _switchHousehold(household.id),
                      ),
                  ],
                ),
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    title: const Text('Who Can See This'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => const ComingSoonPage(
                            title: 'Who Can See This',
                            body: 'Invites, members, and leaving a folder land in Phase 8.',
                          ),
                        ),
                      );
                    },
                  ),
                  CupertinoListTile(
                    title: const Text('Sign Out', style: TextStyle(color: SvColors.danger)),
                    onTap: () => session.signOut(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

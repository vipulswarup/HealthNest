import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/features/doctor/doctor_page.dart';
import 'package:sanovault/features/households/households_page.dart';
import 'package:sanovault/features/reports/add_report_page.dart';
import 'package:sanovault/features/tracking/vaccinations_page.dart';
import 'package:sanovault/features/tracking/visit_notes_page.dart';
import 'package:sanovault/features/vitals/bp_page.dart';
import 'package:sanovault/features/vitals/growth_page.dart';
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
  int _epoch = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final epoch = SessionScope.of(context).dataEpoch;
    if (epoch != _epoch) {
      _epoch = epoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
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
    final session = SessionScope.of(context);
    await session.api.setActiveHousehold(id);
    session.invalidateData();
    await _load();
  }

  void _open(Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
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
                  CupertinoListTile(title: const Text('Add a Report'), trailing: const CupertinoListTileChevron(), onTap: () => _open(const AddReportPage())),
                  CupertinoListTile(title: const Text('For the Doctor'), trailing: const CupertinoListTileChevron(), onTap: () => _open(const DoctorPage())),
                  CupertinoListTile(title: const Text('Blood Pressure'), trailing: const CupertinoListTileChevron(), onTap: () => _open(const BpPage())),
                  CupertinoListTile(title: const Text('Height & Weight'), trailing: const CupertinoListTileChevron(), onTap: () => _open(const GrowthPage())),
                  CupertinoListTile(title: const Text('Vaccinations'), trailing: const CupertinoListTileChevron(), onTap: () => _open(const VaccinationsPage())),
                  CupertinoListTile(title: const Text('Visit Notes'), trailing: const CupertinoListTileChevron(), onTap: () => _open(const VisitNotesPage())),
                  CupertinoListTile(title: const Text('Who Can See This'), trailing: const CupertinoListTileChevron(), onTap: () => _open(const HouseholdsPage())),
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

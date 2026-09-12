import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/api_exception.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/features/home/add_person_page.dart';
import 'package:sanovault/features/home/create_household_page.dart';
import 'package:sanovault/features/placeholder/coming_soon_page.dart';
import 'package:sanovault/session/app_preferences.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/util/labels.dart';
import 'package:sanovault/widgets/sv_controls.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _preferences = AppPreferences();
  DashboardHome? _home;
  String? _error;
  String? _lastPatientId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    setState(() {
      _loading = _home == null;
      _error = null;
    });
    try {
      final home = await session.api.dashboard();
      final stored = await _preferences.lastPatientId();
      if (!mounted) return;
      setState(() {
        _home = home;
        _lastPatientId = home.patients.any((person) => person.id == stored) ? stored : null;
        _loading = false;
      });
    } on ApiException catch (caught) {
      if (!mounted) return;
      if (caught.isUnauthorized) {
        await session.signOut();
        return;
      }
      setState(() {
        _error = caught.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your home screen.';
        _loading = false;
      });
    }
  }

  Future<void> _markLast(String id) async {
    await _preferences.setLastPatientId(id);
    if (mounted) setState(() => _lastPatientId = id);
  }

  void _openComingSoon(String title, String body) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ComingSoonPage(title: title, body: body),
      ),
    );
  }

  void _openAddPerson() {
    final householdId = _home?.householdId;
    if (householdId == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => AddPersonPage(householdId: householdId, onCreated: _load),
      ),
    );
  }

  void _openCreateHousehold() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => CreateHouseholdPage(onCreated: _load),
      ),
    );
  }

  Future<void> _acceptInvite(PendingInvite invite) async {
    try {
      await SessionScope.of(context).api.acceptInvite(invite.token);
      await _load();
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final firstName = session.profile?.firstName ?? '';
    return CupertinoPageScaffold(
      backgroundColor: SvColors.groupedBackground,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(firstName.isEmpty ? 'Family' : 'Family, $firstName'),
            border: null,
            backgroundColor: SvColors.groupedBackground,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _home?.householdId == null ? _openCreateHousehold : _openAddPerson,
              child: const Text('Add'),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: _load),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverList.list(
              children: [
                const Text(
                  'Choose a Person, Add a Report, or Open What a Doctor Needs.',
                  style: TextStyle(fontSize: 16, color: SvColors.slate, height: 1.35),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
                if (_error != null) ...[
                  SvErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],
                if (!_loading && _home != null) ..._body(_home!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(DashboardHome home) {
    final people = [...home.patients];
    if (_lastPatientId != null) {
      people.sort((a, b) => (b.id == _lastPatientId ? 1 : 0) - (a.id == _lastPatientId ? 1 : 0));
    }
    final recordsByPerson = <String, List<DashboardRecord>>{};
    for (final record in home.records) {
      recordsByPerson.putIfAbsent(record.patientId, () => []).add(record);
    }

    return [
      if (home.households.isEmpty)
        SvCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No Family Folder Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: SvColors.ink)),
              const SizedBox(height: 8),
              const Text(
                'If someone invited you, open the invite below. Otherwise create a folder for this family.',
                style: TextStyle(fontSize: 16, color: SvColors.slate),
              ),
              const SizedBox(height: 16),
              SvFilledButton(label: 'Create a Folder', onPressed: _openCreateHousehold),
            ],
          ),
        ),
      for (final invite in home.pending) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SvColors.inviteFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${invite.invitedByName ?? 'A Family Member'} invited you to ${invite.householdName ?? 'the family folder'}.',
                style: const TextStyle(fontSize: 16, color: SvColors.inviteInk),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _acceptInvite(invite),
                child: const Text('Join this folder'),
              ),
            ],
          ),
        ),
      ],
      if (home.households.isNotEmpty && people.isEmpty) ...[
        const SizedBox(height: 12),
        SvCard(
          child: Column(
            children: [
              const Text('Add Someone to This Folder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: SvColors.ink)),
              const SizedBox(height: 8),
              const Text(
                'Add Dad, your daughter, or anyone whose reports you keep here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: SvColors.slate),
              ),
              const SizedBox(height: 16),
              SvFilledButton(label: 'Add a Person', onPressed: _openAddPerson),
            ],
          ),
        ),
      ],
      for (final person in people) ...[
        const SizedBox(height: 12),
        _PersonCard(
          person: person,
          lastUsed: person.id == _lastPatientId,
          recent: recordsByPerson[person.id] ?? const [],
          onAddReport: () {
            _markLast(person.id);
            _openComingSoon(
              'Add a Report',
              'Camera, files, and OCR land in Phase 4. On the website this is Health Records, New.',
            );
          },
          onDoctor: () {
            _markLast(person.id);
            _openComingSoon(
              'For the Doctor',
              'The doctor packet lands in Phase 6. It will use the same API as the website.',
            );
          },
          onLogBp: () {
            _markLast(person.id);
            _openComingSoon(
              'Log BP',
              'Blood pressure logging lands in Phase 7, then Apple Health.',
            );
          },
          onViewAll: () {
            _markLast(person.id);
            _openComingSoon(
              'Reports',
              'Browsing and opening reports lands in Phase 3.',
            );
          },
          onOpenRecord: (record) {
            _markLast(person.id);
            _openComingSoon(
              humanizeLabel(record.recordType),
              'Record detail and document viewing land in Phase 3.',
            );
          },
        ),
      ],
    ];
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.lastUsed,
    required this.recent,
    required this.onAddReport,
    required this.onDoctor,
    required this.onLogBp,
    required this.onViewAll,
    required this.onOpenRecord,
  });

  final DashboardPerson person;
  final bool lastUsed;
  final List<DashboardRecord> recent;
  final VoidCallback onAddReport;
  final VoidCallback onDoctor;
  final VoidCallback onLogBp;
  final VoidCallback onViewAll;
  final ValueChanged<DashboardRecord> onOpenRecord;

  @override
  Widget build(BuildContext context) {
    final name = personName(person.firstName, person.lastName);
    return SvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: SvColors.ink)),
          const SizedBox(height: 4),
          Text(
            lastUsed ? 'Last Used' : ' ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: lastUsed ? SvColors.coral : const Color(0x00000000),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniButton(label: 'Add a Report', filled: true, onPressed: onAddReport)),
              const SizedBox(width: 8),
              Expanded(child: _MiniButton(label: 'For the Doctor', onPressed: onDoctor)),
              const SizedBox(width: 8),
              Expanded(child: _MiniButton(label: 'Log BP', outlined: true, onPressed: onLogBp)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Recent Files', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SvColors.slate)),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                onPressed: onViewAll,
                child: const Text('View All', style: TextStyle(fontSize: 15, color: SvColors.coral)),
              ),
            ],
          ),
          if (recent.isEmpty)
            const Text('None yet.', style: TextStyle(fontSize: 16, color: SvColors.slate))
          else
            for (final record in recent)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 10),
                onPressed: () => onOpenRecord(record),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        humanizeLabel(record.recordType),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, color: SvColors.ink),
                      ),
                    ),
                    Text(
                      formatDisplayDate(record.documentDate ?? record.createdAt),
                      style: const TextStyle(fontSize: 15, color: SvColors.slate),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final background = filled ? SvColors.coral : SvColors.surface;
    final foreground = filled ? CupertinoColors.white : SvColors.ink;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 44),
      onPressed: onPressed,
      child: Container(
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: outlined || !filled ? Border.all(color: SvColors.silver) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground, height: 1.15),
        ),
      ),
    );
  }
}

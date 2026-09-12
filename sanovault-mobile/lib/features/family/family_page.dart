import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/features/family/person_detail_page.dart';
import 'package:sanovault/features/home/add_person_page.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/widgets/sv_page.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  List<Person> _people = const [];
  String? _householdId;
  String? _error;
  bool _loading = true;
  String _query = '';
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
    final session = SessionScope.of(context);
    setState(() {
      _loading = _people.isEmpty;
      _error = null;
    });
    try {
      final home = await session.api.dashboard();
      final people = home.householdId == null ? <Person>[] : await session.api.patients();
      if (!mounted) return;
      setState(() {
        _householdId = home.householdId;
        _people = people;
        _loading = false;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _error = caught.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _people.where((person) {
      if (_query.trim().isEmpty) return true;
      return person.displayName.toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();
    return SvLargePage(
      title: 'Family',
      error: _error,
      onRefresh: _load,
      trailing: _householdId == null
          ? null
          : CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => AddPersonPage(householdId: _householdId!, onCreated: _load),
                  ),
                );
              },
              child: const Text('Add'),
            ),
      child: _loading
          ? const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CupertinoActivityIndicator()))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: CupertinoSearchTextField(
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No people in this folder yet.', style: TextStyle(color: SvColors.slate)),
                  )
                else
                  CupertinoListSection.insetGrouped(
                    children: [
                      for (final person in filtered)
                        CupertinoListTile(
                          title: Text(person.displayName),
                          subtitle: Text([person.gender, person.bloodGroup].where((item) => item != null && item.isNotEmpty).join(' · ')),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () async {
                            await Navigator.of(context).push(
                              CupertinoPageRoute<void>(builder: (_) => PersonDetailPage(personId: person.id)),
                            );
                            _load();
                          },
                        ),
                    ],
                  ),
              ],
            ),
    );
  }
}

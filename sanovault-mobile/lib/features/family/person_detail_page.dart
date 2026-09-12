import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/features/doctor/doctor_page.dart';
import 'package:sanovault/features/family/edit_person_page.dart';
import 'package:sanovault/features/medicines/medicines_page.dart';
import 'package:sanovault/features/reports/add_report_page.dart';
import 'package:sanovault/features/reports/reports_page.dart';
import 'package:sanovault/features/tracking/vaccinations_page.dart';
import 'package:sanovault/features/tracking/visit_notes_page.dart';
import 'package:sanovault/features/vitals/bp_page.dart';
import 'package:sanovault/features/vitals/growth_page.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sanovault/widgets/sv_page.dart';

class PersonDetailPage extends StatefulWidget {
  const PersonDetailPage({super.key, required this.personId});
  final String personId;

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  Person? _person;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final person = await SessionScope.of(context).api.patient(widget.personId);
      await rememberPerson(context, person.id);
      if (!mounted) return;
      setState(() {
        _person = person;
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
    final person = _person;
    return SvLargePage(
      title: person?.displayName ?? 'Person',
      error: _error,
      onRefresh: _load,
      trailing: person == null
          ? null
          : CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                await Navigator.of(context).push(
                  CupertinoPageRoute<void>(builder: (_) => EditPersonPage(person: person)),
                );
                _load();
              },
              child: const Text('Edit'),
            ),
      child: _loading || person == null
          ? const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CupertinoActivityIndicator()))
          : Column(
              children: [
                CupertinoListSection.insetGrouped(
                  header: const Text('Details'),
                  children: [
                    CupertinoListTile(title: const Text('Born'), additionalInfo: Text(formatDisplayDate(person.dateOfBirth))),
                    CupertinoListTile(title: const Text('Gender'), additionalInfo: Text(person.gender ?? '—')),
                    CupertinoListTile(title: const Text('Blood group'), additionalInfo: Text(person.bloodGroup ?? '—')),
                    CupertinoListTile(title: const Text('ABHA'), additionalInfo: Text(person.abhaNumber ?? '—')),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      Expanded(child: SvFilledButton(label: 'Add a Report', onPressed: () {
                        Navigator.of(context).push(CupertinoPageRoute<void>(
                          builder: (_) => AddReportPage(patientId: person.id),
                        ));
                      })),
                    ],
                  ),
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('Open'),
                  children: [
                    _link('Reports', ReportsPage(patientId: person.id)),
                    _link('For the Doctor', DoctorPage(patientId: person.id)),
                    _link('Medicines', MedicinesPage(patientId: person.id)),
                    _link('Blood Pressure', BpPage(patientId: person.id)),
                    _link('Height & Weight', GrowthPage(patientId: person.id)),
                    _link('Vaccinations', VaccinationsPage(patientId: person.id)),
                    _link('Visit Notes', VisitNotesPage(patientId: person.id)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _link(String label, Widget page) {
    return CupertinoListTile(
      title: Text(label),
      trailing: const CupertinoListTileChevron(),
      onTap: () => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page)),
    );
  }
}

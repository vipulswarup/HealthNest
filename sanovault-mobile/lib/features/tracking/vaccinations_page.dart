import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sanovault/widgets/sv_page.dart';

class VaccinationsPage extends StatefulWidget {
  const VaccinationsPage({super.key, this.patientId});
  final String? patientId;

  @override
  State<VaccinationsPage> createState() => _VaccinationsPageState();
}

class _VaccinationsPageState extends State<VaccinationsPage> {
  List<Person> _people = const [];
  VaccinationList? _data;
  String? _patientId;
  String? _error;
  final _name = TextEditingController();
  final _dose = TextEditingController();

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = SessionScope.of(context).api;
    try {
      final people = await api.patients();
      _patientId ??= await loadInitialPersonId(people);
      final data = _patientId == null ? null : await api.vaccinations(_patientId!);
      if (!mounted) return;
      setState(() {
        _people = people;
        _data = data;
        _error = null;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  Future<void> _save() async {
    if (_patientId == null || _name.text.trim().isEmpty) return;
    try {
      await SessionScope.of(context).api.addVaccination(
        patientId: _patientId!,
        vaccineName: _name.text.trim(),
        administeredDate: formatIsoDate(DateTime.now()),
        doseLabel: _dose.text.trim(),
      );
      _name.clear();
      _dose.clear();
      await _load();
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _data?.items ?? const [];
    return SvLargePage(
      title: 'Vaccinations',
      error: _error,
      onRefresh: _load,
      child: Column(
        children: [
          PersonPicker(
            people: _people,
            selectedId: _patientId,
            onSelected: (id) {
              setState(() => _patientId = id);
              rememberPerson(context, id);
              _load();
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CupertinoTextField(controller: _name, placeholder: 'Vaccine name'),
                const SizedBox(height: 8),
                CupertinoTextField(controller: _dose, placeholder: 'Dose label (optional)'),
                const SizedBox(height: 12),
                SvFilledButton(label: 'Add vaccination', onPressed: _save),
              ],
            ),
          ),
          CupertinoListSection.insetGrouped(
            children: [
              if (items.isEmpty)
                const CupertinoListTile(title: Text('None yet.'))
              else
                for (final item in items)
                  CupertinoListTile(
                    title: Text('${item['vaccineName'] ?? ''}'),
                    subtitle: Text('${item['doseLabel'] ?? ''} ${item['administeredDate'] ?? ''}'.trim()),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

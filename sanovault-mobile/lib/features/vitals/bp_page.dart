import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sanovault/widgets/sv_page.dart';

class BpPage extends StatefulWidget {
  const BpPage({super.key, this.patientId});
  final String? patientId;

  @override
  State<BpPage> createState() => _BpPageState();
}

class _BpPageState extends State<BpPage> {
  List<Person> _people = const [];
  BloodPressureWeek? _week;
  String? _patientId;
  String? _error;
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  final _pulse = TextEditingController();

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _sys.dispose();
    _dia.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = SessionScope.of(context).api;
    try {
      final people = await api.patients();
      _patientId ??= await loadInitialPersonId(people);
      final week = _patientId == null ? null : await api.bloodPressure(_patientId!);
      if (!mounted) return;
      setState(() {
        _people = people;
        _week = week;
        _error = null;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  Future<void> _save() async {
    if (_patientId == null) return;
    final sys = int.tryParse(_sys.text.trim());
    final dia = int.tryParse(_dia.text.trim());
    if (sys == null || dia == null) {
      setState(() => _error = 'Enter systolic and diastolic numbers.');
      return;
    }
    try {
      await SessionScope.of(context).api.logBloodPressure(
        patientId: _patientId!,
        systolic: sys,
        diastolic: dia,
        pulse: int.tryParse(_pulse.text.trim()),
      );
      _sys.clear();
      _dia.clear();
      _pulse.clear();
      await _load();
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvLargePage(
      title: 'Blood Pressure',
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
                CupertinoTextField(controller: _sys, placeholder: 'Systolic', keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                CupertinoTextField(controller: _dia, placeholder: 'Diastolic', keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                CupertinoTextField(controller: _pulse, placeholder: 'Pulse (optional)', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                SvFilledButton(label: 'Save reading', onPressed: _save),
              ],
            ),
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('This week'),
            children: [
              if (_week == null || _week!.lines.isEmpty)
                const CupertinoListTile(title: Text('No readings yet.'))
              else
                for (final line in _week!.lines) CupertinoListTile(title: Text(line)),
            ],
          ),
        ],
      ),
    );
  }
}

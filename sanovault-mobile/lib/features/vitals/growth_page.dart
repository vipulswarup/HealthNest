import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sanovault/widgets/sv_page.dart';

class GrowthPage extends StatefulWidget {
  const GrowthPage({super.key, this.patientId});
  final String? patientId;

  @override
  State<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends State<GrowthPage> {
  List<Person> _people = const [];
  GrowthHistory? _history;
  String? _patientId;
  String? _error;
  final _height = TextEditingController();
  final _weight = TextEditingController();

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = SessionScope.of(context).api;
    try {
      final people = await api.patients();
      _patientId ??= await loadInitialPersonId(people);
      final history = _patientId == null ? null : await api.growth(_patientId!);
      if (!mounted) return;
      setState(() {
        _people = people;
        _history = history;
        _error = null;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  Future<void> _save() async {
    if (_patientId == null) return;
    try {
      await SessionScope.of(context).api.logGrowth(
        patientId: _patientId!,
        heightCm: double.tryParse(_height.text.trim()),
        weightKg: double.tryParse(_weight.text.trim()),
      );
      _height.clear();
      _weight.clear();
      await _load();
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvLargePage(
      title: 'Height & Weight',
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
                CupertinoTextField(controller: _height, placeholder: 'Height (cm)', keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                CupertinoTextField(controller: _weight, placeholder: 'Weight (kg)', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                SvFilledButton(label: 'Save measurement', onPressed: _save),
              ],
            ),
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('History'),
            children: [
              if (_history == null || _history!.lines.isEmpty)
                const CupertinoListTile(title: Text('No measurements yet.'))
              else
                for (final line in _history!.lines) CupertinoListTile(title: Text(line)),
            ],
          ),
        ],
      ),
    );
  }
}

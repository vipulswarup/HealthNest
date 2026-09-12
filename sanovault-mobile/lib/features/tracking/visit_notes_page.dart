import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sanovault/widgets/sv_page.dart';

class VisitNotesPage extends StatefulWidget {
  const VisitNotesPage({super.key, this.patientId});
  final String? patientId;

  @override
  State<VisitNotesPage> createState() => _VisitNotesPageState();
}

class _VisitNotesPageState extends State<VisitNotesPage> {
  List<Person> _people = const [];
  VisitNoteList? _data;
  String? _patientId;
  String? _error;
  final _observed = TextEditingController();
  final _ask = TextEditingController();

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _observed.dispose();
    _ask.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = SessionScope.of(context).api;
    try {
      final people = await api.patients();
      _patientId ??= await loadInitialPersonId(people);
      final data = _patientId == null ? null : await api.visitNotes(_patientId!);
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
    if (_patientId == null) return;
    try {
      await SessionScope.of(context).api.addVisitNote(
        patientId: _patientId!,
        noteDate: formatIsoDate(DateTime.now()),
        observed: _observed.text.trim(),
        askDoctor: _ask.text.trim(),
      );
      _observed.clear();
      _ask.clear();
      await _load();
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = _data?.notes ?? const [];
    return SvLargePage(
      title: 'Visit Notes',
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
                CupertinoTextField(controller: _observed, placeholder: 'What you noticed', minLines: 2, maxLines: 4),
                const SizedBox(height: 8),
                CupertinoTextField(controller: _ask, placeholder: 'What to ask the doctor', minLines: 2, maxLines: 4),
                const SizedBox(height: 12),
                SvFilledButton(label: 'Save note', onPressed: _save),
              ],
            ),
          ),
          CupertinoListSection.insetGrouped(
            children: [
              if (notes.isEmpty)
                const CupertinoListTile(title: Text('None yet.'))
              else
                for (final note in notes)
                  CupertinoListTile(
                    title: Text('${note['observed'] ?? note['askDoctor'] ?? ''}'),
                    subtitle: Text('${note['noteDate'] ?? ''}'),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

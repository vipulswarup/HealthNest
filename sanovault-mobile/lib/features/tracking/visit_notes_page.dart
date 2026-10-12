import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/api_exception.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/app_preferences.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/widgets/date_picker.dart';
import 'package:sanovault/widgets/people_aware.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sanovault/widgets/sv_page.dart';

/// Symptoms & Notes: log what you noticed (and what to ask the doctor), dated,
/// newest first, and fix or remove entries later.
class VisitNotesPage extends StatefulWidget {
  const VisitNotesPage({super.key, this.patientId});
  final String? patientId;

  @override
  State<VisitNotesPage> createState() => _VisitNotesPageState();
}

class _VisitNotesPageState extends State<VisitNotesPage>
    with PeopleAware<VisitNotesPage> {
  VisitNoteList? _data;
  String? _patientId;
  String? _error;
  bool _refreshing = false;
  bool _saving = false;
  int _generation = 0;
  DateTime _noteDate = DateTime.now();
  final _observed = TextEditingController();
  final _ask = TextEditingController();

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _observed.dispose();
    _ask.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final list = await ensurePeople();
      final lastUsed = await AppPreferences().lastPatientId();
      if (!mounted) return;
      final id = initialPersonFrom(list, _patientId, lastUsed);
      setState(() => _patientId = id);
      if (id != null) await _load(id);
    } catch (caught) {
      if (mounted) setState(() => _error = _message(caught));
    }
  }

  @override
  void onPeopleChanged() {
    if (_patientId != null && !people.any((person) => person.id == _patientId)) {
      final id = people.isEmpty ? null : people.first.id;
      setState(() {
        _patientId = id;
        _data = null;
      });
      if (id != null) _load(id);
    }
  }

  String _message(Object caught) =>
      caught is ApiException ? caught.message : caught.toString();

  Future<void> _load([String? requestedId]) async {
    final patientId = requestedId ?? _patientId;
    if (patientId == null) return;
    final generation = ++_generation;
    final api = SessionScope.of(context).api;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    if (_data == null) {
      final cached = await api.cachedVisitNotes(patientId);
      if (!mounted || generation != _generation) return;
      if (cached != null) setState(() => _data = cached);
    }
    try {
      final data = await api.visitNotes(patientId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _refreshing = false;
      });
    } catch (caught) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _refreshing = false;
        if (_data == null) _error = _message(caught);
      });
    }
  }

  Future<void> _save() async {
    final patientId = _patientId;
    if (patientId == null || _saving) return;
    final observed = _observed.text.trim();
    final ask = _ask.text.trim();
    if (observed.isEmpty && ask.isEmpty) {
      setState(() => _error = 'Write what you noticed or what to ask the doctor.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await SessionScope.of(context).api.addVisitNote(
        patientId: patientId,
        noteDate: formatIsoDate(_noteDate),
        observed: observed,
        askDoctor: ask,
      );
      await AppPreferences().setLastPatientId(patientId);
      if (!mounted) return;
      _observed.clear();
      _ask.clear();
      setState(() {
        if (patientId == _patientId) _data = updated;
        _noteDate = DateTime.now();
        _saving = false;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _message(caught);
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await pickDate(context, initial: _noteDate);
    if (picked != null && mounted) setState(() => _noteDate = picked);
  }

  Future<void> _showActions(VisitNote note) async {
    if (note.isPending) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Waiting to sync'),
          content: const Text(
            'This note was saved offline. You can edit it once it has synced.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(formatDisplayDate(note.noteDate)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'edit'),
            child: const Text('Edit'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'edit') {
      final updated = await Navigator.of(context).push<VisitNoteList>(
        CupertinoPageRoute(builder: (_) => _EditNotePage(note: note)),
      );
      if (updated != null && mounted) setState(() => _data = updated);
    } else if (choice == 'delete') {
      await _delete(note);
    }
  }

  Future<void> _delete(VisitNote note) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete this note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SessionScope.of(context).api.deleteVisitNote(
        noteId: note.id,
        patientId: note.patientId,
      );
      if (!mounted) return;
      final current = _data;
      if (current != null) {
        setState(() {
          _data = VisitNoteList(
            notes: current.notes.where((n) => n.id != note.id).toList(),
            nextAppointment: current.nextAppointment,
          );
        });
      }
    } catch (caught) {
      if (mounted) setState(() => _error = _message(caught));
    }
  }

  Widget _timeline(List<VisitNote> notes) {
    if (_data == null && _refreshing) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: CupertinoActivityIndicator(),
      );
    }
    if (notes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Nothing logged yet.',
          style: TextStyle(color: SvColors.slate),
        ),
      );
    }
    // Notes are already newest first; start a new section whenever the date changes.
    final sections = <Widget>[];
    var rows = <Widget>[];
    String? currentDate;
    void flush() {
      if (currentDate == null) return;
      sections.add(
        CupertinoListSection.insetGrouped(
          header: Text(formatDisplayDate(currentDate)),
          children: rows,
        ),
      );
      rows = <Widget>[];
    }

    for (final note in notes) {
      if (note.noteDate != currentDate) {
        flush();
        currentDate = note.noteDate;
      }
      rows.add(
        CupertinoListTile(
          onTap: () => _showActions(note),
          title: Text(
            note.observed.isNotEmpty ? note.observed : 'Ask: ${note.askDoctor}',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: note.observed.isNotEmpty && note.askDoctor.isNotEmpty
              ? Text('Ask: ${note.askDoctor}', maxLines: 3)
              : (note.isPending ? const Text('Waiting to sync') : null),
          trailing: const CupertinoListTileChevron(),
        ),
      );
    }
    flush();
    return Column(children: sections);
  }

  @override
  Widget build(BuildContext context) {
    final notes = _data?.notes ?? const <VisitNote>[];
    return SvLargePage(
      title: 'Symptoms & Notes',
      error: _error,
      onRefresh: _load,
      child: Column(
        children: [
          PersonPicker(
            people: people,
            selectedId: _patientId,
            enabled: !_saving,
            loading: peopleLoading && people.isEmpty,
            onSelected: (id) {
              setState(() {
                _patientId = id;
                _data = null;
              });
              AppPreferences().setLastPatientId(id);
              _load(id);
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _pickDate,
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.calendar, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'When: ${formatDisplayDate(formatIsoDate(_noteDate))}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                CupertinoTextField(
                  controller: _observed,
                  placeholder: 'What you noticed (symptoms, side effects…)',
                  minLines: 2,
                  maxLines: 5,
                  padding: const EdgeInsets.all(14),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _ask,
                  placeholder: 'What to ask the doctor',
                  minLines: 2,
                  maxLines: 4,
                  padding: const EdgeInsets.all(14),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SvFilledButton(
                    label: _saving ? 'Saving…' : 'Save',
                    onPressed: _saving ? null : _save,
                    enabled: !_saving && _patientId != null,
                  ),
                ),
              ],
            ),
          ),
          _timeline(notes),
        ],
      ),
    );
  }
}

class _EditNotePage extends StatefulWidget {
  const _EditNotePage({required this.note});
  final VisitNote note;

  @override
  State<_EditNotePage> createState() => _EditNotePageState();
}

class _EditNotePageState extends State<_EditNotePage> {
  late final _observed = TextEditingController(text: widget.note.observed);
  late final _ask = TextEditingController(text: widget.note.askDoctor);
  late DateTime _date =
      parseApiDate(widget.note.noteDate) ?? DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _observed.dispose();
    _ask.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final observed = _observed.text.trim();
    final ask = _ask.text.trim();
    if (observed.isEmpty && ask.isEmpty) {
      setState(() => _error = 'Write what you noticed or what to ask the doctor.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await SessionScope.of(context).api.updateVisitNote(
        noteId: widget.note.id,
        patientId: widget.note.patientId,
        noteDate: formatIsoDate(_date),
        observed: observed,
        askDoctor: ask,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = caught is ApiException ? caught.message : caught.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: SvColors.groupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Edit note'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              SvErrorBanner(message: _error!),
              const SizedBox(height: 12),
            ],
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                final picked = await pickDate(context, initial: _date);
                if (picked != null && mounted) setState(() => _date = picked);
              },
              child: Row(
                children: [
                  const Icon(CupertinoIcons.calendar, size: 20),
                  const SizedBox(width: 8),
                  Text('When: ${formatDisplayDate(formatIsoDate(_date))}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _observed,
              placeholder: 'What you noticed',
              minLines: 3,
              maxLines: 8,
              padding: const EdgeInsets.all(14),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _ask,
              placeholder: 'What to ask the doctor',
              minLines: 3,
              maxLines: 6,
              padding: const EdgeInsets.all(14),
            ),
          ],
        ),
      ),
    );
  }
}

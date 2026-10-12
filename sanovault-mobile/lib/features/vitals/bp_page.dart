import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/api_exception.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/app_preferences.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/widgets/people_aware.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sanovault/widgets/sv_page.dart';

class BpPage extends StatefulWidget {
  const BpPage({super.key, this.patientId});
  final String? patientId;

  @override
  State<BpPage> createState() => _BpPageState();
}

class _BpPageState extends State<BpPage> with PeopleAware<BpPage> {
  BloodPressureWeek? _week;
  String? _patientId;
  String? _error;
  String? _savedMessage;
  bool _refreshing = false;
  bool _saving = false;
  int _loadGeneration = 0;
  int _historyDays = 7;
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  final _pulse = TextEditingController();
  final _sysFocus = FocusNode();
  final _diaFocus = FocusNode();
  final _pulseFocus = FocusNode();

  static const _historyOptions = {7: '7 days', 30: '30 days', 90: '90 days'};

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _sys.dispose();
    _dia.dispose();
    _pulse.dispose();
    _sysFocus.dispose();
    _diaFocus.dispose();
    _pulseFocus.dispose();
    super.dispose();
  }

  /// The entry form is usable as soon as the person is known, which is
  /// immediate from memory or the on-device cache. Readings fill in behind it.
  Future<void> _start() async {
    try {
      final list = await ensurePeople();
      if (!mounted) return;
      final lastUsed = await AppPreferences().lastPatientId();
      if (!mounted) return;
      final id = initialPersonFrom(list, _patientId, lastUsed);
      setState(() => _patientId = id);
      if (id != null) await _load(id);
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = _message(caught));
    }
  }

  @override
  void onPeopleChanged() {
    if (_patientId != null && !people.any((person) => person.id == _patientId)) {
      final id = people.isEmpty ? null : people.first.id;
      setState(() {
        _patientId = id;
        _week = null;
      });
      if (id != null) _load(id);
    }
  }

  String _message(Object caught) =>
      caught is ApiException ? caught.message : caught.toString();

  Future<void> _load([String? requestedId]) async {
    final patientId = requestedId ?? _patientId;
    if (patientId == null) return;
    final generation = ++_loadGeneration;
    final api = SessionScope.of(context).api;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    // Cached readings first, so the list is on screen while the network answers.
    if (_week == null && _historyDays == 7) {
      final cached = await api.cachedBloodPressure(patientId);
      if (!mounted || generation != _loadGeneration) return;
      if (cached != null) setState(() => _week = cached);
    }
    try {
      final week = await api.bloodPressure(
        patientId,
        days: _historyDays == 7 ? null : _historyDays,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _week = week;
        _refreshing = false;
      });
    } catch (caught) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _refreshing = false;
        if (_week == null) _error = _message(caught);
      });
    }
  }

  String? _validate() {
    final sys = int.tryParse(_sys.text.trim());
    final dia = int.tryParse(_dia.text.trim());
    final pulseText = _pulse.text.trim();
    final pulse = pulseText.isEmpty ? null : int.tryParse(pulseText);
    return _validateValues(sys, dia, pulseText, pulse);
  }

  String? _validateValues(int? sys, int? dia, String pulseText, int? pulse) {
    if (sys == null || sys < 50 || sys > 250) {
      return 'Systolic must be a whole number from 50 to 250 mmHg.';
    }
    if (dia == null || dia < 30 || dia > 180) {
      return 'Diastolic must be a whole number from 30 to 180 mmHg.';
    }
    if (dia >= sys) return 'Diastolic must be lower than systolic.';
    if (pulseText.isNotEmpty && (pulse == null || pulse < 20 || pulse > 220)) {
      return 'Pulse must be a whole number from 20 to 220 bpm.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || _patientId == null) return;
    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      if (validation.startsWith('Systolic')) {
        _sysFocus.requestFocus();
      } else if (validation.startsWith('Diastolic')) {
        _diaFocus.requestFocus();
      } else {
        _pulseFocus.requestFocus();
      }
      return;
    }
    final patientId = _patientId!;
    final sys = int.parse(_sys.text.trim());
    final dia = int.parse(_dia.text.trim());
    final pulseText = _pulse.text.trim();
    final pulse = pulseText.isEmpty ? null : int.parse(pulseText);
    setState(() {
      _saving = true;
      _error = null;
      _savedMessage = null;
    });
    try {
      final updated = await SessionScope.of(context).api.logBloodPressure(
        patientId: patientId,
        systolic: sys,
        diastolic: dia,
        pulse: pulse,
      );
      await AppPreferences().setLastPatientId(patientId);
      if (!mounted) return;
      setState(() {
        if (patientId == _patientId) _week = updated;
        _saving = false;
        _savedMessage = 'Reading saved.';
      });
      _sys.clear();
      _dia.clear();
      _pulse.clear();
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _message(caught);
      });
    }
  }

  Future<void> _showActions(BloodPressureReading reading) async {
    if (reading.isPending) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Waiting to sync'),
          content: const Text(
            'This reading was saved offline. You can edit it once it has synced.',
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
        title: Text('${reading.systolic} / ${reading.diastolic} mmHg'),
        message: Text(_readingDate(reading)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'edit'),
            child: const Text('Edit'),
          ),
          if (reading.vaultOwned)
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
    if (choice == 'edit') await _edit(reading);
    if (choice == 'delete') await _delete(reading);
  }

  Future<void> _edit(BloodPressureReading reading) async {
    final sys = TextEditingController(text: '${reading.systolic}');
    final dia = TextEditingController(text: '${reading.diastolic}');
    final pulse = TextEditingController(text: '${reading.pulse ?? ''}');
    String? problem;
    final saved = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => CupertinoAlertDialog(
          title: const Text('Edit reading'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: sys,
                placeholder: 'Systolic',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: dia,
                placeholder: 'Diastolic',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: pulse,
                placeholder: 'Pulse (optional)',
                keyboardType: TextInputType.number,
              ),
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    problem!,
                    style: const TextStyle(color: SvColors.danger, fontSize: 13),
                  ),
                ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final pulseText = pulse.text.trim();
                final message = _validateValues(
                  int.tryParse(sys.text.trim()),
                  int.tryParse(dia.text.trim()),
                  pulseText,
                  pulseText.isEmpty ? null : int.tryParse(pulseText),
                );
                if (message != null) {
                  setDialog(() => problem = message);
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final pulseText = pulse.text.trim();
    final values = (
      int.tryParse(sys.text.trim()),
      int.tryParse(dia.text.trim()),
      pulseText.isEmpty ? null : int.tryParse(pulseText),
    );
    sys.dispose();
    dia.dispose();
    pulse.dispose();
    if (saved != true || !mounted) return;
    try {
      final week = await SessionScope.of(context).api.updateBloodPressure(
        readingId: reading.id,
        patientId: reading.patientId,
        systolic: values.$1!,
        diastolic: values.$2!,
        pulse: values.$3,
      );
      if (!mounted) return;
      setState(() {
        _week = week;
        _savedMessage = 'Reading updated.';
      });
      if (_historyDays != 7) _load();
    } catch (caught) {
      if (mounted) setState(() => _error = _message(caught));
    }
  }

  Future<void> _delete(BloodPressureReading reading) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete this reading?'),
        content: Text(
          '${reading.systolic} / ${reading.diastolic} mmHg on ${_readingDate(reading)}',
        ),
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
      final week = await SessionScope.of(context).api.deleteBloodPressure(
        readingId: reading.id,
        patientId: reading.patientId,
      );
      if (!mounted) return;
      setState(() {
        _week = week;
        _savedMessage = 'Reading deleted.';
      });
      if (_historyDays != 7) _load();
    } catch (caught) {
      if (mounted) setState(() => _error = _message(caught));
    }
  }

  String _readingDate(BloodPressureReading reading) {
    final date = reading.recordedAt;
    if (date == null) return 'Time unavailable';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final meridiem = date.hour >= 12 ? 'PM' : 'AM';
    return '${formatDisplayDate(date.toIso8601String())} · $hour:$minute $meridiem';
  }

  Widget _field({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? next,
    bool optional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: SvColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          focusNode: focusNode,
          placeholder: placeholder,
          keyboardType: TextInputType.number,
          textInputAction: next == null
              ? TextInputAction.done
              : TextInputAction.next,
          onSubmitted: (_) => next?.requestFocus(),
          enabled: !_saving,
          clearButtonMode: OverlayVisibilityMode.editing,
          padding: const EdgeInsets.all(14),
          suffix: optional
              ? const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Text('Optional'),
                )
              : null,
        ),
      ],
    );
  }

  Widget? _summary(List<BloodPressureReading> readings) {
    if (readings.isEmpty) return null;
    final cutoff = DateTime.now().subtract(Duration(days: _historyDays));
    final inWindow = readings
        .where((r) => r.recordedAt == null || r.recordedAt!.isAfter(cutoff))
        .toList();
    if (inWindow.isEmpty) return null;
    final sys = inWindow.map((r) => r.systolic).reduce((a, b) => a + b) /
        inWindow.length;
    final dia = inWindow.map((r) => r.diastolic).reduce((a, b) => a + b) /
        inWindow.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        'Average ${sys.round()} / ${dia.round()} mmHg over ${inWindow.length} reading${inWindow.length == 1 ? '' : 's'}',
        style: const TextStyle(color: SvColors.slate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readings = _week?.readings ?? const <BloodPressureReading>[];
    final selected = people.where((person) => person.id == _patientId).firstOrNull;
    return SvLargePage(
      title: 'Blood Pressure',
      error: _error,
      onRefresh: _saving ? null : _load,
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
                _week = null;
              });
              AppPreferences().setLastPatientId(id);
              _load(id);
            },
          ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recording for ${selected.displayName}',
                  style: const TextStyle(color: SvColors.slate),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _field(
                  label: 'Systolic (mmHg)',
                  placeholder: 'e.g. 120',
                  controller: _sys,
                  focusNode: _sysFocus,
                  next: _diaFocus,
                ),
                const SizedBox(height: 12),
                _field(
                  label: 'Diastolic (mmHg)',
                  placeholder: 'e.g. 80',
                  controller: _dia,
                  focusNode: _diaFocus,
                  next: _pulseFocus,
                ),
                const SizedBox(height: 12),
                _field(
                  label: 'Pulse (bpm)',
                  placeholder: 'e.g. 72',
                  controller: _pulse,
                  focusNode: _pulseFocus,
                  optional: true,
                ),
                const SizedBox(height: 14),
                SvFilledButton(
                  label: _saving ? 'Saving…' : 'Save reading',
                  onPressed: _saving ? null : _save,
                  enabled: !_saving && _patientId != null,
                ),
                if (_savedMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _savedMessage!,
                        style: const TextStyle(color: SvColors.success),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _historyDays,
              children: {
                for (final entry in _historyOptions.entries)
                  entry.key: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(entry.value),
                  ),
              },
              onValueChanged: (days) {
                if (days == null || days == _historyDays) return;
                setState(() => _historyDays = days);
                _load();
              },
            ),
          ),
          ?_summary(readings),
          CupertinoListSection.insetGrouped(
            header: Row(
              children: [
                const Expanded(child: Text('Readings, newest first')),
                if (_refreshing) const CupertinoActivityIndicator(radius: 8),
              ],
            ),
            children: [
              if (_week == null && _refreshing)
                const CupertinoListTile(title: Text('Loading readings…'))
              else if (readings.isEmpty)
                CupertinoListTile(
                  title: Text('No readings in the last $_historyDays days.'),
                )
              else
                for (var index = 0; index < readings.length; index++)
                  CupertinoListTile(
                    onTap: () => _showActions(readings[index]),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${readings[index].systolic} / ${readings[index].diastolic} mmHg',
                            style: TextStyle(
                              color: _isHigh(readings[index])
                                  ? SvColors.danger
                                  : SvColors.ink,
                            ),
                          ),
                        ),
                        if (index == 0 && readings[index].recordedAt != null)
                          const Text(
                            'Latest',
                            style: TextStyle(
                              color: SvColors.brand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      [
                        _readingDate(readings[index]),
                        if (readings[index].pulse != null)
                          'Pulse ${readings[index].pulse} bpm',
                        if (readings[index].isPending) 'Waiting to sync',
                      ].join(' · '),
                    ),
                    trailing: const CupertinoListTileChevron(),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isHigh(BloodPressureReading reading) =>
      reading.systolic >= 140 || reading.diastolic >= 90;
}

extension on Iterable<Person> {
  Person? get firstOrNull => isEmpty ? null : first;
}

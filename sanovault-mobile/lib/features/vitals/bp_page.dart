import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/util/dates.dart';
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
  String? _savedMessage;
  bool _loading = true;
  bool _saving = false;
  int _loadGeneration = 0;
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  final _pulse = TextEditingController();
  final _sysFocus = FocusNode();
  final _diaFocus = FocusNode();
  final _pulseFocus = FocusNode();

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
    _sysFocus.dispose();
    _diaFocus.dispose();
    _pulseFocus.dispose();
    super.dispose();
  }

  Future<void> _load({String? requestedPatientId}) async {
    final generation = ++_loadGeneration;
    final api = SessionScope.of(context).api;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _savedMessage = null;
        if (requestedPatientId != null) {
          _week = null;
        }
      });
    }
    try {
      final people = await api.patients();
      var patientId = requestedPatientId ?? _patientId;
      if (patientId == null ||
          !people.any((person) => person.id == patientId)) {
        patientId = await loadInitialPersonId(people);
      }
      final week = patientId == null
          ? null
          : await api.bloodPressure(patientId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _people = people;
        _patientId = patientId;
        _week = week;
        _loading = false;
      });
    } catch (caught) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = caught.toString();
      });
    }
  }

  String? _validate() {
    final sys = int.tryParse(_sys.text.trim());
    final dia = int.tryParse(_dia.text.trim());
    final pulseText = _pulse.text.trim();
    final pulse = pulseText.isEmpty ? null : int.tryParse(pulseText);
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
      if (!mounted) return;
      setState(() {
        _week = updated;
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
        _error = caught.toString();
      });
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
            color: CupertinoColors.label,
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

  @override
  Widget build(BuildContext context) {
    final readings = [...?_week?.readings];
    readings.sort((a, b) {
      final aDate = a.recordedAt;
      final bDate = b.recordedAt;
      if (aDate == null && bDate == null) return a.id.compareTo(b.id);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      final byDate = bDate.compareTo(aDate);
      return byDate == 0 ? b.id.compareTo(a.id) : byDate;
    });
    final selected = _patientId == null
        ? null
        : _people.where((person) => person.id == _patientId).firstOrNull;
    return SvLargePage(
      title: 'Blood Pressure',
      error: _error,
      onRefresh: _saving ? null : _load,
      child: Column(
        children: [
          PersonPicker(
            people: _people,
            selectedId: _patientId,
            enabled: !_saving,
            loading: _loading && _people.isEmpty,
            onSelected: (id) {
              setState(() => _patientId = id);
              _load(requestedPatientId: id);
            },
          ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recording for ${selected.displayName}',
                  style: const TextStyle(color: CupertinoColors.secondaryLabel),
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
                  enabled: !_saving,
                ),
                if (_savedMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _savedMessage!,
                        style: const TextStyle(
                          color: CupertinoColors.systemGreen,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('Recent readings'),
            children: [
              if (_loading && _week == null)
                const CupertinoListTile(title: Text('Loading readings…'))
              else if (readings.isEmpty)
                const CupertinoListTile(
                  title: Text('No readings in the recent history window.'),
                )
              else
                for (var index = 0; index < readings.length; index++)
                  CupertinoListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${readings[index].systolic} / ${readings[index].diastolic} mmHg',
                          ),
                        ),
                        if (index == 0 && readings[index].recordedAt != null)
                          const Text(
                            'Latest',
                            style: TextStyle(
                              color: SvColors.primaryButton,
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
                      ].join(' · '),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on Iterable<Person> {
  Person? get firstOrNull => isEmpty ? null : first;
}

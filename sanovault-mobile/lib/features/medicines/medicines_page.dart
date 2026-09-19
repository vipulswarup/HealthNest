import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sanovault/widgets/sv_page.dart';
import 'package:share_plus/share_plus.dart';

class MedicinesPage extends StatefulWidget {
  const MedicinesPage({super.key, this.patientId});
  final String? patientId;

  @override
  State<MedicinesPage> createState() => _MedicinesPageState();
}

class _MedicinesPageState extends State<MedicinesPage> {
  List<Person> _people = const [];
  List<Medication> _meds = const [];
  String? _patientId;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  int _epoch = -1;
  int _loadGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _patientId ??= widget.patientId;
    final epoch = SessionScope.of(context).dataEpoch;
    if (epoch != _epoch) {
      _epoch = epoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load({String? requestedPatientId}) async {
    final generation = ++_loadGeneration;
    final api = SessionScope.of(context).api;
    setState(() {
      _loading = _meds.isEmpty;
      _error = null;
    });
    try {
      final people = await api.patients();
      var patientId = requestedPatientId ?? _patientId;
      if (patientId == null ||
          !people.any((person) => person.id == patientId)) {
        patientId = await loadInitialPersonId(people);
      }
      final meds = patientId == null
          ? <Medication>[]
          : await api.medications(patientId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _people = people;
        _patientId = patientId;
        _meds = meds;
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

  Future<void> _addFromPhoto() async {
    final patientId = _patientId;
    if (patientId == null || _busy) return;
    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Medicine photo'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Photo Library'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = SessionScope.of(context).api;
    try {
      final shot = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      final extracted = await api.extractMedication(bytes, shot.name);
      if (!mounted) return;
      final values = await _showMedicineReview(
        patientName: _personName(patientId),
        initial: {
          'name': extracted['brandName']?.toString() ?? '',
          'dosage': extracted['dosage']?.toString() ?? '',
          'frequency': extracted['frequency']?.toString() ?? '',
          'route': extracted['route']?.toString() ?? '',
        },
      );
      if (values != null && mounted) await _createMedication(patientId, values);
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _personName(String id) {
    for (final person in _people) {
      if (person.id == id) return person.displayName;
    }
    return 'this person';
  }

  Future<void> _manualAdd() async {
    final patientId = _patientId;
    if (patientId == null || _busy) return;
    final values = await _showMedicineReview(
      patientName: _personName(patientId),
    );
    if (values == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _createMedication(patientId, values);
    } catch (caught) {
      if (mounted) setState(() => _error = caught.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>?> _showMedicineReview({
    required String patientName,
    Map<String, dynamic> initial = const {},
  }) {
    return showCupertinoModalPopup<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _MedicineReviewSheet(patientName: patientName, initial: initial),
    );
  }

  Future<void> _createMedication(
    String patientId,
    Map<String, dynamic> values,
  ) async {
    await SessionScope.of(context).api.createMedication({
      'patientId': patientId,
      ...values,
      'startDate': formatIsoDate(DateTime.now()),
      'purchaseCountry': 'IN',
    });
    await _load();
  }

  Future<void> _stop(Medication med) async {
    if (_busy) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Mark ${med.name} as stopped?'),
        content: const Text('This will move the medicine to Past.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark as stopped'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).api.updateMedication(med.id, {
        'isActive': false,
        'endDate': formatIsoDate(DateTime.now()),
      });
      await _load();
    } catch (caught) {
      if (mounted) setState(() => _error = caught.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _meds.where((med) => med.isActive).toList();
    final past = _meds.where((med) => !med.isActive).toList();
    return SvLargePage(
      title: 'Medicines',
      error: _error,
      onRefresh: _load,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: active.isEmpty
            ? null
            : () => SharePlus.instance.share(
                ShareParams(text: active.map((med) => med.line).join('\n')),
              ),
        child: const Text('Share'),
      ),
      child: Column(
        children: [
          PersonPicker(
            people: _people,
            selectedId: _patientId,
            enabled: !_busy,
            loading: _loading && _people.isEmpty,
            onSelected: (id) {
              setState(() => _patientId = id);
              rememberPerson(context, id);
              _load(requestedPatientId: id);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: SvFilledButton(
                    label: 'Scan medicine',
                    onPressed: _busy ? null : _addFromPhoto,
                    enabled: !_busy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SvFilledButton(
                    label: 'Add manually',
                    onPressed: _busy ? null : _manualAdd,
                    enabled: !_busy,
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: CupertinoActivityIndicator(),
            )
          else ...[
            CupertinoListSection.insetGrouped(
              header: const Text('Active'),
              children: [
                if (active.isEmpty)
                  const CupertinoListTile(title: Text('None yet.'))
                else
                  for (final med in active)
                    CupertinoListTile(
                      title: Text(med.name),
                      subtitle: Text(med.line),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _stop(med),
                        child: const Text('Stop'),
                      ),
                    ),
              ],
            ),
            if (past.isNotEmpty)
              CupertinoListSection.insetGrouped(
                header: const Text('Past'),
                children: [
                  for (final med in past)
                    CupertinoListTile(
                      title: Text(med.name),
                      subtitle: Text(med.line),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _MedicineReviewSheet extends StatefulWidget {
  const _MedicineReviewSheet({
    required this.patientName,
    this.initial = const {},
  });

  final String patientName;
  final Map<String, dynamic> initial;

  @override
  State<_MedicineReviewSheet> createState() => _MedicineReviewSheetState();
}

class _MedicineReviewSheetState extends State<_MedicineReviewSheet> {
  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _frequency;
  late final TextEditingController _route;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.initial['name']?.toString() ?? '',
    );
    _dosage = TextEditingController(
      text: widget.initial['dosage']?.toString() ?? '',
    );
    _frequency = TextEditingController(
      text: widget.initial['frequency']?.toString() ?? '',
    );
    _route = TextEditingController(
      text: widget.initial['route']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _frequency.dispose();
    _route.dispose();
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String placeholder,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            padding: const EdgeInsets.all(12),
            maxLines: label == 'Instructions' ? 3 : 1,
          ),
        ],
      ),
    );
  }

  void _save() {
    final values = <String, String>{
      'name': _name.text.trim(),
      'dosage': _dosage.text.trim(),
      'frequency': _frequency.text.trim(),
      'route': _route.text.trim(),
    };
    final missing = values.entries
        .where((entry) => entry.value.isEmpty)
        .map((entry) => entry.key)
        .toList();
    if (missing.isNotEmpty) {
      setState(
        () => _error = 'Complete medicine name, dosage, frequency, and route before saving.',
      );
      return;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.82;
    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height.clamp(420.0, 720.0),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Review medicine',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
              Text(
                'For ${widget.patientName}',
                style: const TextStyle(color: SvColors.slate),
              ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: SvColors.danger)),
                const SizedBox(height: 10),
              ],
              _field('Medicine name', _name, 'Brand or generic name'),
              _field('Dosage', _dosage, 'e.g. 500 mg'),
              _field('Frequency', _frequency, 'e.g. twice daily'),
              _field('Route', _route, 'e.g. oral'),
              const SizedBox(height: 4),
              SvFilledButton(label: 'Save medicine', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

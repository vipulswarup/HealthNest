import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
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
  int _epoch = -1;

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

  Future<void> _load() async {
    final api = SessionScope.of(context).api;
    setState(() {
      _loading = _meds.isEmpty;
      _error = null;
    });
    try {
      final people = await api.patients();
      _patientId ??= await loadInitialPersonId(people);
      final meds = _patientId == null ? <Medication>[] : await api.medications(_patientId!);
      if (!mounted) return;
      setState(() {
        _people = people;
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
    if (_patientId == null) return;
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
    if (source == null) return;
    try {
      final shot = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      final extracted = await SessionScope.of(context).api.extractMedication(bytes, shot.name);
      if (!mounted) return;
      await _createFromExtract(extracted);
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  Future<void> _createFromExtract(Map<String, dynamic> extracted) async {
    final name = (extracted['brandName'] as String?)?.trim();
    if (name == null || name.isEmpty || _patientId == null) {
      setState(() => _error = 'Could not read a medicine name from that photo.');
      return;
    }
    await SessionScope.of(context).api.createMedication({
      'patientId': _patientId,
      'name': name,
      'dosage': extracted['dosage'] ?? 'as prescribed',
      'frequency': extracted['frequency'] ?? 'daily',
      'route': extracted['route'] ?? 'oral',
      'startDate': formatIsoDate(DateTime.now()),
      'purchaseCountry': extracted['purchaseCountry'] ?? 'IN',
    });
    await _load();
  }

  Future<void> _manualAdd() async {
    if (_patientId == null) return;
    final name = TextEditingController();
    final dosage = TextEditingController(text: 'as prescribed');
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Add a medicine'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(controller: name, placeholder: 'Brand name'),
            const SizedBox(height: 8),
            CupertinoTextField(controller: dosage, placeholder: 'Dosage'),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            onPressed: () async {
              Navigator.pop(context);
              await SessionScope.of(context).api.createMedication({
                'patientId': _patientId,
                'name': name.text.trim(),
                'dosage': dosage.text.trim(),
                'frequency': 'daily',
                'route': 'oral',
                'startDate': formatIsoDate(DateTime.now()),
              });
              await _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _stop(Medication med) async {
    await SessionScope.of(context).api.updateMedication(med.id, {
      'isActive': false,
      'endDate': formatIsoDate(DateTime.now()),
    });
    await _load();
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
            : () => SharePlus.instance.share(ShareParams(text: active.map((med) => med.line).join('\n'))),
        child: const Text('Share'),
      ),
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                Expanded(child: SvFilledButton(label: 'Photo', onPressed: _addFromPhoto)),
                const SizedBox(width: 12),
                Expanded(child: SvFilledButton(label: 'Add', onPressed: _manualAdd)),
              ],
            ),
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 32), child: CupertinoActivityIndicator())
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
                    CupertinoListTile(title: Text(med.name), subtitle: Text(med.line)),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

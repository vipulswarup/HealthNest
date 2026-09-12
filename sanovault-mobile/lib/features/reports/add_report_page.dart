import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sanovault/widgets/sv_page.dart';

class AddReportPage extends StatefulWidget {
  const AddReportPage({super.key, this.patientId});
  final String? patientId;

  @override
  State<AddReportPage> createState() => _AddReportPageState();
}

class _AddReportPageState extends State<AddReportPage> {
  List<Person> _people = const [];
  List<Category> _categories = const [];
  String? _patientId;
  String? _documentId;
  String _ocrText = '';
  String _recordType = 'LAB_REPORT';
  final _source = TextEditingController();
  final _doctor = TextEditingController();
  final _date = DateTime.now();
  String _status = '';
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _source.dispose();
    _doctor.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final api = SessionScope.of(context).api;
    try {
      final people = await api.patients();
      final categories = await api.categories();
      final selected = _patientId ?? await loadInitialPersonId(people);
      if (!mounted) return;
      setState(() {
        _people = people;
        _categories = categories;
        _patientId = selected;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  Future<void> _pick(ImageSource? cameraOrGallery) async {
    setState(() {
      _error = null;
      _status = 'Reading the file…';
    });
    try {
      late List<int> bytes;
      var filename = 'report.jpg';
      if (cameraOrGallery != null) {
        final shot = await ImagePicker().pickImage(source: cameraOrGallery, imageQuality: 85);
        if (shot == null) {
          setState(() => _status = '');
          return;
        }
        bytes = await shot.readAsBytes();
        filename = shot.name;
      } else {
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
        );
        if (file == null) {
          setState(() => _status = '');
          return;
        }
        filename = file.name;
        bytes = await file.readAsBytes();
      }
      await _process(bytes, filename);
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _error = caught.toString();
        _status = '';
      });
    }
  }

  Future<void> _process(List<int> bytes, String filename) async {
    final api = SessionScope.of(context).api;
    setState(() => _status = 'Uploading…');
    final uploaded = await api.uploadDocument(bytes, filename);
    final documentId = uploaded['id'] as String? ?? uploaded['_id'] as String? ?? uploaded['documentId'] as String?;
    if (documentId == null) throw Exception('Upload did not return a document.');
    setState(() {
      _documentId = documentId;
      _status = 'Reading the pages…';
    });
    var text = await api.ocrDocument(documentId, mode: 'intake');
    try {
      text = await api.ocrDocument(documentId, mode: 'full');
    } catch (_) {}
    setState(() => _status = 'Classifying…');
    var type = 'OTHER';
    try {
      type = await api.classifyDocument(documentId, text);
    } catch (_) {}
    try {
      await api.suggestTags(documentId, text);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _ocrText = text;
      _recordType = type;
      _status = 'Ready to save.';
    });
  }

  Future<void> _save() async {
    if (_patientId == null || _documentId == null) {
      setState(() => _error = 'Choose a person and add a file first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var source = _source.text.trim();
      if (source.isNotEmpty) {
        try {
          source = await SessionScope.of(context).api.matchSource(source);
        } catch (_) {}
      }
      var doctor = _doctor.text.trim();
      if (doctor.isNotEmpty) {
        try {
          doctor = await SessionScope.of(context).api.matchDoctor(doctor);
        } catch (_) {}
      }
      await SessionScope.of(context).api.createHealthRecord({
        'patientId': _patientId,
        'recordType': _recordType,
        'data': <String, dynamic>{},
        'source': source.isEmpty ? 'Not specified' : source,
        if (doctor.isNotEmpty) 'doctorName': doctor,
        'documentDate': formatIsoDate(_date),
        'documentId': _documentId,
        if (_ocrText.isNotEmpty) 'ocrText': _ocrText,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = caught.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvLargePage(
      title: 'Add a Report',
      error: _error,
      trailing: _saving
          ? const CupertinoActivityIndicator()
          : CupertinoButton(padding: EdgeInsets.zero, onPressed: _save, child: const Text('Save')),
      child: Column(
        children: [
          PersonPicker(
            people: _people,
            selectedId: _patientId,
            onSelected: (id) => setState(() => _patientId = id),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: SvFilledButton(label: 'Camera', onPressed: () => _pick(ImageSource.camera))),
                    const SizedBox(width: 12),
                    Expanded(child: SvFilledButton(label: 'Photos', onPressed: () => _pick(ImageSource.gallery))),
                  ],
                ),
                const SizedBox(height: 12),
                SvFilledButton(label: 'Files', onPressed: () => _pick(null)),
              ],
            ),
          ),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_status, style: const TextStyle(color: SvColors.slate)),
            ),
          CupertinoFormSection.insetGrouped(
            children: [
              CupertinoFormRow(
                prefix: const Text('Type'),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _categories.isEmpty
                      ? null
                      : () async {
                          await showCupertinoModalPopup<void>(
                            context: context,
                            builder: (context) => CupertinoActionSheet(
                              actions: [
                                for (final category in _categories)
                                  CupertinoActionSheetAction(
                                    onPressed: () {
                                      setState(() => _recordType = category.code);
                                      Navigator.pop(context);
                                    },
                                    child: Text(category.displayName),
                                  ),
                              ],
                              cancelButton: CupertinoActionSheetAction(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                          );
                        },
                  child: Text(_recordType.replaceAll('_', ' ')),
                ),
              ),
              CupertinoTextFormFieldRow(controller: _source, prefix: const Text('Source'), placeholder: 'Lab or hospital'),
              CupertinoTextFormFieldRow(controller: _doctor, prefix: const Text('Doctor'), placeholder: 'Optional'),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sanovault/widgets/sv_page.dart';

class SharedImportFile {
  const SharedImportFile({required this.path, required this.name});
  final String path;
  final String name;
}

class ShareImportPage extends StatefulWidget {
  const ShareImportPage({super.key, required this.files});
  final List<SharedImportFile> files;

  @override
  State<ShareImportPage> createState() => _ShareImportPageState();
}

class _ShareImportPageState extends State<ShareImportPage> {
  List<Person> _people = const [];
  String? _patientId;
  String? _error;
  String _status = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final people = await SessionScope.of(context).api.patients();
      final selected = await loadInitialPersonId(people);
      if (!mounted) return;
      setState(() {
        _people = people;
        _patientId = selected;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  Future<void> _save() async {
    final patientId = _patientId;
    if (patientId == null) {
      setState(() => _error = 'Choose a person first.');
      return;
    }
    if (widget.files.isEmpty) {
      setState(() => _error = 'Nothing was shared.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _status = 'Uploading…';
    });

    try {
      final api = SessionScope.of(context).api;
      for (var i = 0; i < widget.files.length; i++) {
        final file = widget.files[i];
        if (!mounted) return;
        setState(() => _status = widget.files.length == 1 ? 'Uploading…' : 'Uploading ${i + 1} of ${widget.files.length}…');
        final bytes = await File(file.path).readAsBytes();
        final uploaded = await api.uploadDocument(Uint8List.fromList(bytes), file.name);
        final documentId =
            uploaded['id'] as String? ?? uploaded['_id'] as String? ?? uploaded['documentId'] as String?;
        if (documentId == null) throw Exception('Upload did not return a document.');
        await api.createHealthRecord({
          'patientId': patientId,
          'recordType': 'OTHER',
          'data': <String, dynamic>{},
          'source': 'Share',
          'documentId': documentId,
          'tags': ['needs_review', 'mobile_share'],
          'processAsync': true,
        });
      }
      if (!mounted) return;
      await rememberPerson(context, patientId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = '';
        _error = caught.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.files.map((f) => f.name).join(', ');
    return SvLargePage(
      title: 'Save shared report',
      error: _error,
      trailing: _saving
          ? const CupertinoActivityIndicator()
          : CupertinoButton(padding: EdgeInsets.zero, onPressed: _save, child: const Text('Save')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              names.isEmpty ? 'Shared file' : names,
              style: const TextStyle(color: SvColors.slate),
            ),
          ),
          PersonPicker(
            people: _people,
            selectedId: _patientId,
            onSelected: (id) => setState(() => _patientId = id),
          ),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_status, style: const TextStyle(color: SvColors.slate)),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'SanoVault will read and categorize the report in the background. Confirm it later under Reports.',
              style: TextStyle(color: SvColors.slate, height: 1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: SvFilledButton(
              label: _saving ? 'Saving…' : 'Save report',
              enabled: !_saving && _patientId != null && widget.files.isNotEmpty,
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

String sharedFileName(String path) {
  final base = p.basename(path);
  return base.isEmpty ? 'shared-file' : base;
}

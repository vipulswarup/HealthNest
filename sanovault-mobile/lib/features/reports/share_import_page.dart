import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:sanovault/session/app_preferences.dart';
import 'package:sanovault/widgets/people_aware.dart';
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

class _ShareImportPageState extends State<ShareImportPage>
    with PeopleAware<ShareImportPage> {
  String? _patientId;
  String? _error;
  String _status = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// People come from memory or the on-device cache, so the person is chosen
  /// and Save is enabled almost immediately.
  Future<void> _bootstrap() async {
    try {
      final list = await ensurePeople();
      final lastUsed = await AppPreferences().lastPatientId();
      if (!mounted) return;
      setState(() => _patientId = initialPersonFrom(list, null, lastUsed));
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  @override
  void onPeopleChanged() {
    if (_patientId == null && people.isNotEmpty) {
      setState(() => _patientId = people.first.id);
    }
  }

  Future<void> _uploadOne(SharedImportFile file, String patientId) async {
    final api = SessionScope.of(context).api;
    final bytes = await File(file.path).readAsBytes();
    final uploaded = await api.uploadDocument(
      Uint8List.fromList(bytes),
      file.name,
      patientId: patientId,
    );
    final documentId =
        uploaded['id'] as String? ??
        uploaded['_id'] as String? ??
        uploaded['documentId'] as String?;
    if (documentId == null) throw Exception('Upload did not return a document.');
    // The server reads and files the document in the background, unlocking PDFs
    // with the passwords saved for this person, so nothing waits on OCR here.
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
      // Upload a couple of files at a time instead of strictly one by one.
      const parallel = 3;
      var done = 0;
      for (var start = 0; start < widget.files.length; start += parallel) {
        final batch = widget.files.skip(start).take(parallel).toList();
        await Future.wait([
          for (final file in batch)
            _uploadOne(file, patientId).then((_) {
              done += 1;
              if (mounted && widget.files.length > 1) {
                setState(
                  () => _status = 'Uploaded $done of ${widget.files.length}…',
                );
              }
            }),
        ]);
      }
      if (!mounted) return;
      await AppPreferences().setLastPatientId(patientId);
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
            people: people,
            selectedId: _patientId,
            loading: peopleLoading && people.isEmpty,
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

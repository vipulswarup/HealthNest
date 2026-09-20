import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/features/folder_check/folder_check_channel.dart';
import 'package:sanovault/features/folder_check/folder_check_hints.dart';
import 'package:sanovault/features/folder_check/folder_check_store.dart';
import 'package:sanovault/features/reports/pdf_password_prompt.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_controls.dart';
import 'package:sanovault/widgets/sv_page.dart';

const _maxBytes = 50 * 1024 * 1024;

class FolderCheckPage extends StatefulWidget {
  const FolderCheckPage({super.key});

  @override
  State<FolderCheckPage> createState() => _FolderCheckPageState();
}

class _FolderCheckSummary {
  int uploaded = 0;
  int duplicates = 0;
  final oversized = <String>[];
  final failed = <String>[];
  final onlineOnly = <String>[];
  bool aborted = false;
  bool cancelled = false;
}

class _FolderCheckPageState extends State<FolderCheckPage> {
  final _channel = FolderCheckChannel();
  final _store = FolderCheckStore();
  List<Person> _people = const [];
  String? _patientId;
  FolderCheckPairing? _pairing;
  String? _error;
  bool _loading = true;
  bool _running = false;
  bool _cancelled = false;
  String _status = '';
  _FolderCheckSummary? _summary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _cancelled = true;
    _channel.stopAccess();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final people = await SessionScope.of(context).api.patients();
      final selected = await loadInitialPersonId(people);
      if (!mounted) return;
      setState(() {
        _people = people;
        _patientId = selected;
        _loading = false;
      });
      if (selected != null) await _loadPairing(selected);
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _error = caught.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadPairing(String patientId) async {
    final pairing = await _store.load(patientId);
    if (!mounted) return;
    setState(() {
      _pairing = pairing;
      _summary = null;
      _error = null;
    });
    if (pairing == null) return;
    try {
      final restored = await _channel.restoreBookmark(pairing.bookmark);
      final next = pairing.copyWith(
        bookmark: restored.bookmark,
        path: restored.path,
        displayPath: restored.displayPath,
      );
      await _store.save(next);
      if (!mounted) return;
      setState(() => _pairing = next);
    } on PlatformException catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.message ?? 'Could not open the saved folder. Pick it again.');
    }
  }

  Future<void> _selectPerson(String id) async {
    await rememberPerson(context, id);
    setState(() {
      _patientId = id;
      _summary = null;
    });
    await _loadPairing(id);
  }

  Future<void> _pickFolder() async {
    final patientId = _patientId;
    if (patientId == null) return;
    setState(() => _error = null);
    try {
      final picked = await _channel.pickFolder();
      if (picked == null || !mounted) return;
      final pairing = FolderCheckPairing(
        patientId: patientId,
        bookmark: picked.bookmark,
        path: picked.path,
        displayPath: picked.displayPath,
      );
      await _store.save(pairing);
      if (!mounted) return;
      setState(() {
        _pairing = pairing;
        _summary = null;
      });
    } on PlatformException catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.message ?? 'Could not save that folder.');
    }
  }

  Future<void> _editExclusions() async {
    final pairing = _pairing;
    if (pairing == null) return;
    try {
      await _channel.restoreBookmark(pairing.bookmark);
      final folders = await _channel.listSubfolders(pairing.path);
      if (!mounted) return;
      final updated = await Navigator.of(context).push<List<String>>(
        CupertinoPageRoute(
          builder: (_) => _ExclusionPage(
            folders: folders,
            selected: pairing.exclusions,
          ),
        ),
      );
      if (updated == null || !mounted) return;
      final next = pairing.copyWith(exclusions: updated);
      await _store.save(next);
      if (!mounted) return;
      setState(() => _pairing = next);
    } on PlatformException catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.message ?? 'Could not list subfolders.');
    }
  }

  Future<void> _run() async {
    final patientId = _patientId;
    var pairing = _pairing;
    if (patientId == null || pairing == null || _running) return;
    setState(() {
      _running = true;
      _cancelled = false;
      _error = null;
      _summary = null;
      _status = 'Opening the folder…';
    });
    final summary = _FolderCheckSummary();
    try {
      final restored = await _channel.restoreBookmark(pairing.bookmark);
      pairing = pairing.copyWith(
        bookmark: restored.bookmark,
        path: restored.path,
        displayPath: restored.displayPath,
      );
      await _store.save(pairing);
      if (!mounted) return;
      setState(() {
        _pairing = pairing;
        _status = 'Scanning files…';
      });

      final files = await _channel.scanTree(pairing.path, pairing.exclusions);
      if (_cancelled) {
        summary.cancelled = true;
        return;
      }
      final onlineOnly = files.where((file) => file.onlineOnly).toList();
      if (onlineOnly.isNotEmpty) {
        summary.aborted = true;
        summary.onlineOnly.addAll(onlineOnly.map((file) => file.relativePath));
        return;
      }

      final oversized = files.where((file) => file.size > _maxBytes).toList();
      summary.oversized.addAll(oversized.map((file) => '${file.relativePath} (${_mb(file.size)})'));
      for (final file in files.where((file) => file.size <= _maxBytes && (file.sha256 == null || file.sha256!.isEmpty))) {
        summary.failed.add('${file.relativePath} (could not hash)');
      }
      final ready = files.where((file) => file.size <= _maxBytes && file.sha256 != null && file.sha256!.isNotEmpty).toList();

      final api = SessionScope.of(context).api;
      final savedPasswords = (await api.filePasswords(patientId)).map((row) => row.password).where((item) => item.isNotEmpty).toList();
      var index = 0;
      for (final file in ready) {
        if (_cancelled || !mounted) {
          summary.cancelled = true;
          break;
        }
        index += 1;
        setState(() => _status = 'File $index of ${ready.length}: ${file.relativePath}');
        try {
          final duplicate = await api.lookupDocumentHash(patientId: patientId, sha256: file.sha256!);
          if (duplicate) {
            summary.duplicates += 1;
            continue;
          }
          String? pdfPassword;
          if (file.kind == 'pdf') {
            pdfPassword = await _unlockPdf(file, savedPasswords, patientId);
            if (pdfPassword == null) {
              summary.failed.add('${file.relativePath} (password needed)');
              continue;
            }
          }
          final bytes = await _channel.readFile(file.path);
          final uploaded = await api.uploadDocument(
            bytes,
            file.name,
            patientId: patientId,
            pdfPassword: pdfPassword != null && pdfPassword.isNotEmpty ? pdfPassword : null,
            timeout: const Duration(minutes: 5),
          );
          final documentId =
              uploaded['id'] as String? ?? uploaded['_id'] as String? ?? uploaded['documentId'] as String?;
          if (documentId == null) throw Exception('Upload did not return a document.');
          if (uploaded['duplicate'] == true) {
            summary.duplicates += 1;
            continue;
          }
          final hints = hintsFromFolderName(file.parentName);
          await api.createHealthRecord({
            'patientId': patientId,
            'recordType': 'OTHER',
            'data': <String, dynamic>{
              if (file.relativePath.isNotEmpty) 'folderRelativePath': file.relativePath,
            },
            'source': 'Folder Check',
            if (hints.doctorName != null) 'doctorName': hints.doctorName,
            if (hints.documentDate != null) 'documentDate': hints.documentDate,
            'documentId': documentId,
            'tags': [
              'needs_review',
              'folder_check',
              if (file.parentName.isNotEmpty) file.parentName,
            ],
            'processAsync': true,
          });
          summary.uploaded += 1;
        } catch (caught) {
          summary.failed.add('${file.relativePath} ($caught)');
        }
      }
    } on PlatformException catch (caught) {
      _error = caught.message ?? 'Folder Check failed.';
    } catch (caught) {
      _error = caught.toString();
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _status = '';
          _summary = summary;
        });
      }
    }
  }

  Future<String?> _unlockPdf(FolderCheckFile file, List<String> savedPasswords, String patientId) async {
    var status = await _channel.pdfWorkingPassword(file.path, savedPasswords);
    if (status != null && status.isEmpty) return '';
    if (status != null && status.isNotEmpty) return status;
    while (mounted && !_cancelled) {
      final entered = await askPdfPassword(context, fileName: file.relativePath);
      if (entered == null) return null;
      status = await _channel.pdfWorkingPassword(file.path, [entered]);
      if (status != null && status.isNotEmpty) {
        if (!savedPasswords.contains(status)) savedPasswords.add(status);
        try {
          await SessionScope.of(context).api.addFilePassword(patientId, status);
        } catch (_) {}
        return status;
      }
    }
    return null;
  }

  String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final pairing = _pairing;
    final summary = _summary;
    return SvLargePage(
      title: 'Folder Check',
      error: _error,
      trailing: _running
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _cancelled = true),
              child: const Text('Stop'),
            )
          : null,
      child: _loading
          ? const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CupertinoActivityIndicator()))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    'Import files from a folder on this Mac. Nothing is written back to the folder. Records stay on needs review until you confirm them.',
                    style: const TextStyle(color: SvColors.slate, height: 1.4),
                  ),
                ),
                PersonPicker(people: _people, selectedId: _patientId, onSelected: _selectPerson),
                CupertinoListSection.insetGrouped(
                  header: const Text('Folder on this Mac'),
                  children: [
                    CupertinoListTile(
                      title: Text(pairing?.displayPath ?? 'No folder chosen'),
                      subtitle: pairing == null ? const Text('Pick the person’s health folder') : null,
                      trailing: const CupertinoListTileChevron(),
                      onTap: _running ? null : _pickFolder,
                    ),
                    CupertinoListTile(
                      title: const Text('Excluded subfolders'),
                      additionalInfo: Text(
                        pairing == null || pairing.exclusions.isEmpty
                            ? 'None'
                            : '${pairing.exclusions.length}',
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: _running || pairing == null ? null : _editExclusions,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: SvFilledButton(
                    label: _running ? 'Checking…' : 'Run folder check',
                    enabled: !_running && _patientId != null && pairing != null,
                    onPressed: _running ? null : _run,
                  ),
                ),
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Text(_status, style: const TextStyle(color: SvColors.slate)),
                  ),
                if (summary != null) _summarySection(summary),
              ],
            ),
    );
  }

  Widget _summarySection(_FolderCheckSummary summary) {
    final lines = <String>[];
    if (summary.aborted) {
      lines.add('Stopped before uploading. One or more files are online-only. Make the folder available offline, then run Folder Check again.');
    } else if (summary.cancelled) {
      lines.add('Stopped. Files that already reached the vault will be skipped next time.');
    }
    if (!summary.aborted) {
      lines.add('Uploaded ${summary.uploaded}');
      lines.add('Skipped duplicates ${summary.duplicates}');
      lines.add('Skipped oversized ${summary.oversized.length}');
      lines.add('Failed ${summary.failed.length}');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line, style: const TextStyle(height: 1.4)),
            ),
          for (final row in summary.onlineOnly.take(40))
            Text(row, style: const TextStyle(color: SvColors.slate, fontSize: 13)),
          for (final row in summary.oversized.take(40))
            Text(row, style: const TextStyle(color: SvColors.slate, fontSize: 13)),
          for (final row in summary.failed.take(40))
            Text(row, style: const TextStyle(color: SvColors.danger, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ExclusionPage extends StatefulWidget {
  const _ExclusionPage({required this.folders, required this.selected});
  final List<String> folders;
  final List<String> selected;

  @override
  State<_ExclusionPage> createState() => _ExclusionPageState();
}

class _ExclusionPageState extends State<_ExclusionPage> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selected};
  }

  @override
  Widget build(BuildContext context) {
    return SvLargePage(
      title: 'Exclude folders',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.pop(context, _selected.toList()..sort()),
        child: const Text('Done'),
      ),
      child: widget.folders.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text('This folder has no subfolders.', style: TextStyle(color: SvColors.slate)),
            )
          : CupertinoListSection.insetGrouped(
              header: const Text('Skip these subfolders and everything inside them'),
              children: [
                for (final folder in widget.folders)
                  CupertinoListTile(
                    title: Text(folder),
                    trailing: Icon(
                      _selected.contains(folder) ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                      color: _selected.contains(folder) ? SvColors.coral : SvColors.silver,
                    ),
                    onTap: () {
                      setState(() {
                        if (_selected.contains(folder)) {
                          _selected.remove(folder);
                        } else {
                          _selected.add(folder);
                        }
                      });
                    },
                  ),
              ],
            ),
    );
  }
}

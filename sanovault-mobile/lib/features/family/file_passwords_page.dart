import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/widgets/sv_page.dart';

class FilePasswordsPage extends StatefulWidget {
  const FilePasswordsPage({super.key, required this.personId, required this.personName});
  final String personId;
  final String personName;

  @override
  State<FilePasswordsPage> createState() => _FilePasswordsPageState();
}

class _FilePasswordsPageState extends State<FilePasswordsPage> {
  List<FilePassword> _passwords = const [];
  String? _error;
  bool _loading = true;
  bool _busy = false;
  final _draft = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _passwords.isEmpty;
      _error = null;
    });
    try {
      final passwords = await SessionScope.of(context).api.filePasswords(widget.personId);
      if (!mounted) return;
      setState(() {
        _passwords = passwords;
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

  Future<void> _add() async {
    final password = _draft.text.trim();
    if (password.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).api.addFilePassword(widget.personId, password);
      _draft.clear();
      await _load();
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(FilePassword row) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).api.deleteFilePassword(widget.personId, row.id);
      await _load();
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvLargePage(
      title: 'File passwords',
      error: _error,
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'Saved passwords unlock PDFs for ${widget.personName} on the website, this app, and Folder Check.',
              style: const TextStyle(color: SvColors.slate, height: 1.4),
            ),
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CupertinoActivityIndicator()))
          else
            CupertinoListSection.insetGrouped(
              header: const Text('Saved'),
              children: [
                if (_passwords.isEmpty)
                  const CupertinoListTile(title: Text('None yet.'))
                else
                  for (final row in _passwords)
                    CupertinoListTile(
                      title: Text(row.password),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _busy ? null : () => _delete(row),
                        child: const Text('Delete'),
                      ),
                    ),
              ],
            ),
          CupertinoFormSection.insetGrouped(
            header: const Text('Add'),
            children: [
              CupertinoTextFormFieldRow(
                controller: _draft,
                placeholder: 'Password from a locked PDF',
                enabled: !_busy,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: CupertinoButton.filled(
              onPressed: _busy ? null : _add,
              child: const Text('Save password'),
            ),
          ),
        ],
      ),
    );
  }
}

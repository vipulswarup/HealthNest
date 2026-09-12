import 'package:flutter/cupertino.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/widgets/sv_controls.dart';

class CreateHouseholdPage extends StatefulWidget {
  const CreateHouseholdPage({super.key, required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<CreateHouseholdPage> createState() => _CreateHouseholdPageState();
}

class _CreateHouseholdPageState extends State<CreateHouseholdPage> {
  final _name = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give this folder a name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).api.createHousehold(name);
      if (!mounted) return;
      widget.onCreated();
      Navigator.of(context).pop();
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
    return CupertinoPageScaffold(
      backgroundColor: SvColors.groupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Create a Folder'),
        trailing: _saving
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _save,
                child: const Text('Create'),
              ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 20),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SvErrorBanner(message: _error!),
              ),
            CupertinoFormSection.insetGrouped(
              footer: const Text('This is the family folder other people can be invited into.'),
              children: [
                CupertinoTextFormFieldRow(
                  controller: _name,
                  prefix: const Text('Name'),
                  placeholder: 'The Swarup Family',
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

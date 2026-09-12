import 'package:flutter/cupertino.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/widgets/sv_controls.dart';

const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

class AddPersonPage extends StatefulWidget {
  const AddPersonPage({super.key, required this.householdId, required this.onCreated});

  final String householdId;
  final VoidCallback onCreated;

  @override
  State<AddPersonPage> createState() => _AddPersonPageState();
}

class _AddPersonPageState extends State<AddPersonPage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  DateTime? _dob;
  String? _gender;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    var selected = _dob ?? DateTime(2000, 1, 1);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return Container(
          height: 280,
          color: SvColors.surface,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selected,
                  maximumDate: DateTime.now(),
                  minimumDate: DateTime(1900),
                  onDateTimeChanged: (value) => selected = value,
                ),
              ),
            ],
          ),
        );
      },
    );
    setState(() => _dob = selected);
  }

  Future<void> _pickGender() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Gender'),
          actions: [
            for (final gender in _genders)
              CupertinoActionSheetAction(
                onPressed: () {
                  setState(() => _gender = gender);
                  Navigator.of(context).pop();
                },
                child: Text(gender),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final firstName = _firstName.text.trim();
    if (firstName.isEmpty || _dob == null || _gender == null) {
      setState(() => _error = 'First name, date of birth, and gender are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).api.addPerson(
        householdId: widget.householdId,
        firstName: firstName,
        lastName: _lastName.text.trim(),
        dateOfBirth: formatIsoDate(_dob!),
        gender: _gender!,
      );
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
        middle: const Text('Add a Person'),
        trailing: _saving
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _save,
                child: const Text('Save'),
              ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 20, bottom: 40),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SvErrorBanner(message: _error!),
              ),
            CupertinoFormSection.insetGrouped(
              header: const Text('Name'),
              children: [
                CupertinoTextFormFieldRow(
                  controller: _firstName,
                  prefix: const Text('First'),
                  placeholder: 'Required',
                  textCapitalization: TextCapitalization.words,
                ),
                CupertinoTextFormFieldRow(
                  controller: _lastName,
                  prefix: const Text('Last'),
                  placeholder: 'Optional',
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('Details'),
              children: [
                CupertinoListTile(
                  title: const Text('Date of Birth'),
                  additionalInfo: Text(
                    _dob == null ? 'Required' : formatIsoDate(_dob!),
                    style: TextStyle(color: _dob == null ? SvColors.slate : SvColors.ink),
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _pickDate,
                ),
                CupertinoListTile(
                  title: const Text('Gender'),
                  additionalInfo: Text(
                    _gender ?? 'Required',
                    style: TextStyle(color: _gender == null ? SvColors.slate : SvColors.ink),
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _pickGender,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

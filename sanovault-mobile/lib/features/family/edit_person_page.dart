import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/widgets/sv_controls.dart';

const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

class EditPersonPage extends StatefulWidget {
  const EditPersonPage({super.key, required this.person});
  final Person person;

  @override
  State<EditPersonPage> createState() => _EditPersonPageState();
}

class _EditPersonPageState extends State<EditPersonPage> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _blood;
  late final TextEditingController _abha;
  late String _gender;
  late DateTime _dob;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _first = TextEditingController(text: widget.person.firstName);
    _last = TextEditingController(text: widget.person.lastName ?? '');
    _blood = TextEditingController(text: widget.person.bloodGroup ?? '');
    _abha = TextEditingController(text: widget.person.abhaNumber ?? '');
    _gender = widget.person.gender ?? 'Prefer not to say';
    _dob = DateTime.tryParse(widget.person.dateOfBirth ?? '') ?? DateTime(2000, 1, 1);
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _blood.dispose();
    _abha.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    var selected = _dob;
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
    if (_first.text.trim().isEmpty) {
      setState(() => _error = 'First name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).api.updatePatient(widget.person.id, {
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'gender': _gender,
        'dateOfBirth': formatIsoDate(_dob),
        'bloodGroup': _blood.text.trim(),
        'abhaNumber': _abha.text.trim(),
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
    return CupertinoPageScaffold(
      backgroundColor: SvColors.groupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Edit Person'),
        trailing: _saving
            ? const CupertinoActivityIndicator()
            : CupertinoButton(padding: EdgeInsets.zero, onPressed: _save, child: const Text('Save')),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            if (_error != null)
              Padding(padding: const EdgeInsets.all(16), child: SvErrorBanner(message: _error!)),
            CupertinoFormSection.insetGrouped(
              children: [
                CupertinoTextFormFieldRow(controller: _first, prefix: const Text('First')),
                CupertinoTextFormFieldRow(controller: _last, prefix: const Text('Last')),
                CupertinoFormRow(
                  prefix: const Text('Born'),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _pickDate,
                    child: Text(formatIsoDate(_dob), style: const TextStyle(color: SvColors.ink)),
                  ),
                ),
                CupertinoFormRow(
                  prefix: const Text('Gender'),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _pickGender,
                    child: Text(_gender, style: const TextStyle(color: SvColors.ink)),
                  ),
                ),
                CupertinoTextFormFieldRow(controller: _blood, prefix: const Text('Blood')),
                CupertinoTextFormFieldRow(controller: _abha, prefix: const Text('ABHA')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

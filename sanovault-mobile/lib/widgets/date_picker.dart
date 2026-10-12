import 'package:flutter/cupertino.dart';
import 'package:sanovault/theme/sv_colors.dart';

/// Shows a bottom-sheet date wheel. Returns null if dismissed with Cancel.
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initial,
  DateTime? minimum,
  DateTime? maximum,
}) async {
  var chosen = initial;
  final confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) => Container(
      height: 300,
      color: SvColors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Done'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initial,
                minimumDate: minimum,
                maximumDate: maximum ?? DateTime.now().add(const Duration(days: 1)),
                onDateTimeChanged: (value) => chosen = value,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed == true ? chosen : null;
}

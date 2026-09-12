import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/app_preferences.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';

class PersonPicker extends StatelessWidget {
  const PersonPicker({
    super.key,
    required this.people,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Person> people;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Add a person on Home first.', style: TextStyle(color: SvColors.slate)),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final person in people) ...[
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => onSelected(person.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: person.id == selectedId ? SvColors.coral : SvColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: person.id == selectedId ? SvColors.coral : SvColors.silver),
                ),
                child: Text(
                  person.displayName,
                  style: TextStyle(
                    color: person.id == selectedId ? CupertinoColors.white : SvColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

Future<String?> loadInitialPersonId(List<Person> people) async {
  if (people.isEmpty) return null;
  final stored = await AppPreferences().lastPatientId();
  if (stored != null && people.any((person) => person.id == stored)) return stored;
  return people.first.id;
}

Future<void> rememberPerson(BuildContext context, String id) async {
  await AppPreferences().setLastPatientId(id);
  SessionScope.of(context).invalidateData();
}

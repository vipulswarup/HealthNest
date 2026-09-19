import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/app_preferences.dart';
import 'package:sanovault/theme/sv_colors.dart';

class PersonPicker extends StatelessWidget {
  const PersonPicker({
    super.key,
    required this.people,
    required this.selectedId,
    required this.onSelected,
    this.enabled = true,
    this.loading = false,
  });

  final List<Person> people;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final bool enabled;
  final bool loading;

  Person? get _selected {
    for (final person in people) {
      if (person.id == selectedId) return person;
    }
    return people.isEmpty ? null : people.first;
  }

  Future<void> _choose(BuildContext context) async {
    if (!enabled || loading || people.isEmpty) return;
    final controller = TextEditingController();
    final picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => _PersonPickerSheet(
        people: people,
        selectedId: selectedId,
        searchController: controller,
      ),
    );
    controller.dispose();
    if (picked != null && picked != selectedId) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CupertinoActivityIndicator(),
            ),
            SizedBox(width: 10),
            Text('Loading people…', style: TextStyle(color: SvColors.slate)),
          ],
        ),
      );
    }
    final selected = _selected;
    if (selected == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Text(
          'Add a person on Home first.',
          style: TextStyle(color: SvColors.slate),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: 'Person, ${selected.displayName}, change person',
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: enabled ? () => _choose(context) : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: SvColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SvColors.separator),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.person_fill,
                  size: 20,
                  color: SvColors.slate,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Person',
                  style: TextStyle(color: SvColors.slate, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected.displayName,
                    maxLines: 2,
                    style: const TextStyle(
                      color: SvColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Change',
                  style: TextStyle(
                    color: SvColors.primaryButton,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 16,
                  color: SvColors.slate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonPickerSheet extends StatefulWidget {
  const _PersonPickerSheet({
    required this.people,
    required this.selectedId,
    required this.searchController,
  });

  final List<Person> people;
  final String? selectedId;
  final TextEditingController searchController;

  @override
  State<_PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends State<_PersonPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final people = query.isEmpty
        ? widget.people
        : widget.people
              .where(
                (person) => person.displayName.toLowerCase().contains(query),
              )
              .toList();
    final height = MediaQuery.sizeOf(context).height * 0.7;
    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height.clamp(280.0, 620.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choose a person',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: CupertinoSearchTextField(
                  controller: widget.searchController,
                  autofocus: widget.people.length > 4,
                  onChanged: (value) => setState(() => _query = value),
                  placeholder: 'Search people',
                ),
              ),
              Expanded(
                child: people.isEmpty
                    ? const Center(
                        child: Text(
                          'No matching people.',
                          style: TextStyle(color: SvColors.slate),
                        ),
                      )
                    : ListView.builder(
                        itemCount: people.length,
                        itemBuilder: (context, index) {
                          final person = people[index];
                          final selected = person.id == widget.selectedId;
                          final details = [person.gender, person.bloodGroup]
                              .where((item) => item != null && item.isNotEmpty)
                              .join(' · ');
                          return CupertinoListTile(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            title: Text(person.displayName),
                            subtitle: details.isEmpty ? null : Text(details),
                            trailing: selected
                                ? const Icon(
                                    CupertinoIcons.check_mark,
                                    color: SvColors.primaryButton,
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, person.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> loadInitialPersonId(List<Person> people) async {
  if (people.isEmpty) return null;
  final stored = await AppPreferences().lastPatientId();
  if (stored != null && people.any((person) => person.id == stored)) {
    return stored;
  }
  return people.first.id;
}

Future<void> rememberPerson(BuildContext context, String id) async {
  await AppPreferences().setLastPatientId(id);
}

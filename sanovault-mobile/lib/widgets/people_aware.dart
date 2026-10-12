import 'package:flutter/widgets.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/people_store.dart';
import 'package:sanovault/session/session_scope.dart';

/// Gives a screen the shared people list without fetching it itself.
///
/// The list is available immediately from memory or the on-device cache and
/// the screen rebuilds when a background refresh brings changes.
mixin PeopleAware<T extends StatefulWidget> on State<T> {
  PeopleStore? _peopleStore;

  List<Person> get people => _peopleStore?.people ?? const [];

  /// True until the first list (cached or fresh) has been read.
  bool get peopleLoading => !(_peopleStore?.loaded ?? false);

  /// Called after the list changes; override to fix up the selection.
  void onPeopleChanged() {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = SessionScope.of(context).people;
    if (!identical(store, _peopleStore)) {
      _peopleStore?.removeListener(_handleChange);
      _peopleStore = store;
      store.addListener(_handleChange);
    }
  }

  void _handleChange() {
    if (!mounted) return;
    setState(() {});
    onPeopleChanged();
  }

  /// Loads the list (cache first). Errors only surface when nothing is cached.
  Future<List<Person>> ensurePeople() async {
    final store = SessionScope.of(context).people;
    final result = await store.ensure();
    if (mounted) setState(() {});
    return result;
  }

  @override
  void dispose() {
    _peopleStore?.removeListener(_handleChange);
    super.dispose();
  }
}

/// Picks which person a screen starts on: an explicit one if still valid, then
/// the last-used one, then the first.
String? initialPersonFrom(List<Person> people, String? preferred, String? lastUsed) {
  if (people.isEmpty) return null;
  for (final id in [preferred, lastUsed]) {
    if (id != null && people.any((person) => person.id == id)) return id;
  }
  return people.first.id;
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/api/sanovault_api.dart';

/// The family's people, shared by every screen.
///
/// Screens used to fetch this list themselves before they would show a form,
/// which put a network round-trip in front of every entry. Now the list is
/// served from memory (or the on-device cache) immediately and refreshed in
/// the background.
class PeopleStore extends ChangeNotifier {
  PeopleStore(this._api);

  final SanoVaultApi _api;
  List<Person> _people = const [];
  bool _loaded = false;
  Future<void>? _refreshing;
  DateTime? _refreshedAt;

  static const _freshFor = Duration(seconds: 45);

  List<Person> get people => _people;
  bool get loaded => _loaded;

  /// Returns the best list available right now. Waits for the network only
  /// when nothing at all is cached.
  Future<List<Person>> ensure() async {
    if (_loaded) {
      final at = _refreshedAt;
      if (at == null || DateTime.now().difference(at) > _freshFor) {
        unawaited(refresh());
      }
      return _people;
    }
    final cached = await _api.cachedPatients();
    if (cached != null) {
      _people = cached;
      _loaded = true;
      notifyListeners();
      unawaited(refresh());
      return _people;
    }
    await refresh();
    return _people;
  }

  Future<void> refresh() {
    return _refreshing ??= _fetch().whenComplete(() => _refreshing = null);
  }

  Future<void> _fetch() async {
    try {
      final fresh = await _api.patients();
      _people = fresh;
      _loaded = true;
      _refreshedAt = DateTime.now();
      notifyListeners();
    } catch (_) {
      // Keep showing what we have; callers that need the network will say so.
      if (!_loaded) rethrow;
    }
  }

  /// Something changed on the server (a person was added or removed): keep
  /// showing the current list but fetch again on next use.
  void markStale() {
    _refreshedAt = null;
  }

  /// Forget everything, e.g. after sign-out or a change of family folder.
  void reset() {
    _people = const [];
    _loaded = false;
    _refreshedAt = null;
    notifyListeners();
  }
}

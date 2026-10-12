import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/api_exception.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/features/reports/add_report_page.dart';
import 'package:sanovault/features/reports/record_detail_page.dart';
import 'package:sanovault/session/app_preferences.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/widgets/people_aware.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_page.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// The date a report is about: the document's own date, else the upload date.
DateTime? reportDate(HealthRecord record) =>
    parseApiDate(record.documentDate) ?? parseApiDate(record.createdAt);

/// Newest document date first; upload time breaks ties.
List<HealthRecord> sortByDocumentDate(List<HealthRecord> records) {
  final sorted = [...records];
  sorted.sort((a, b) {
    final aDate = reportDate(a);
    final bDate = reportDate(b);
    if (aDate == null && bDate == null) return b.id.compareTo(a.id);
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    final byDate = bDate.compareTo(aDate);
    if (byDate != 0) return byDate;
    final aAdded = parseApiDate(a.createdAt);
    final bAdded = parseApiDate(b.createdAt);
    if (aAdded != null && bAdded != null) {
      final byAdded = bAdded.compareTo(aAdded);
      if (byAdded != 0) return byAdded;
    }
    return b.id.compareTo(a.id);
  });
  return sorted;
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, this.patientId});
  final String? patientId;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with PeopleAware<ReportsPage> {
  List<HealthRecord> _records = const [];
  String? _patientId;
  String _query = '';
  bool _needsReviewOnly = false;
  String? _error;
  bool _loadedOnce = false;
  bool _refreshing = false;
  int _epoch = -1;
  Timer? _searchDebounce;
  int _loadGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _patientId ??= widget.patientId;
    final epoch = SessionScope.of(context).dataEpoch;
    if (epoch != _epoch) {
      _epoch = epoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final list = await ensurePeople();
      final lastUsed = await AppPreferences().lastPatientId();
      if (!mounted) return;
      final id = initialPersonFrom(list, _patientId, lastUsed);
      setState(() => _patientId = id);
      await _load();
    } catch (caught) {
      if (mounted) setState(() => _error = _message(caught));
    }
  }

  @override
  void onPeopleChanged() {
    if (_patientId != null && !people.any((p) => p.id == _patientId)) {
      setState(() => _patientId = people.isEmpty ? null : people.first.id);
      _load();
    }
  }

  String _message(Object caught) =>
      caught is ApiException ? caught.message : caught.toString();

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final api = SessionScope.of(context).api;
    final patientId = _patientId;
    final plain = _query.isEmpty && !_needsReviewOnly;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    if (plain && !_loadedOnce) {
      final cached = await api.cachedHealthRecords(patientId: patientId);
      if (!mounted || generation != _loadGeneration) return;
      if (cached != null) {
        setState(() {
          _records = sortByDocumentDate(cached);
          _loadedOnce = true;
        });
      }
    }
    try {
      final records = await api.healthRecords(
        patientId: patientId,
        keyword: _query,
        tag: _needsReviewOnly ? 'needs_review' : null,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _records = sortByDocumentDate(records);
        _loadedOnce = true;
        _refreshing = false;
      });
    } catch (caught) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _refreshing = false;
        if (!_loadedOnce) _error = _message(caught);
      });
    }
  }

  Future<void> _addReport() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => AddReportPage(patientId: _patientId),
      ),
    );
    if (mounted) _load();
  }

  String _dateLabel(HealthRecord record) {
    final documentDate = parseApiDate(record.documentDate);
    if (documentDate != null) return formatDisplayDate(record.documentDate);
    return 'Uploaded ${formatDisplayDate(record.createdAt)}';
  }

  List<Widget> _sections() {
    final sections = <Widget>[];
    var rows = <Widget>[];
    String? currentKey;
    String currentTitle = '';
    void flush() {
      if (currentKey == null) return;
      sections.add(
        CupertinoListSection.insetGrouped(
          header: Text(currentTitle),
          children: rows,
        ),
      );
      rows = <Widget>[];
    }

    for (final record in _records) {
      final date = reportDate(record);
      final key = date == null ? 'unknown' : '${date.year}-${date.month}';
      if (key != currentKey) {
        flush();
        currentKey = key;
        currentTitle = date == null
            ? 'Undated'
            : '${_monthNames[date.month - 1]} ${date.year}';
      }
      rows.add(
        CupertinoListTile(
          title: Row(
            children: [
              Expanded(child: Text(record.displayTitle)),
              if (record.tags.contains('needs_review'))
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: SvColors.warningTint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Review',
                    style: TextStyle(fontSize: 12, color: SvColors.warning),
                  ),
                ),
            ],
          ),
          subtitle: Text(record.source),
          additionalInfo: Text(_dateLabel(record)),
          trailing: const CupertinoListTileChevron(),
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => RecordDetailPage(recordId: record.id),
            ),
          ),
        ),
      );
    }
    flush();
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return SvLargePage(
      title: 'Reports',
      error: _error,
      onRefresh: _load,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _addReport,
        child: const Icon(CupertinoIcons.add_circled, size: 28),
      ),
      child: Column(
        children: [
          PersonPicker(
            people: people,
            selectedId: _patientId,
            loading: peopleLoading && people.isEmpty,
            onSelected: (id) {
              setState(() {
                _patientId = id;
                _records = const [];
                _loadedOnce = false;
              });
              AppPreferences().setLastPatientId(id);
              _load();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  color: _needsReviewOnly ? SvColors.brand : SvColors.brandTint,
                  onPressed: () {
                    setState(() => _needsReviewOnly = !_needsReviewOnly);
                    _load();
                  },
                  child: Text(
                    'Needs review',
                    style: TextStyle(
                      color: _needsReviewOnly
                          ? CupertinoColors.white
                          : SvColors.brandStrong,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
                if (_refreshing) const CupertinoActivityIndicator(radius: 8),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: CupertinoSearchTextField(
              onChanged: (value) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                  if (!mounted) return;
                  setState(() => _query = value);
                  _load();
                });
              },
              onSubmitted: (value) {
                _searchDebounce?.cancel();
                setState(() => _query = value);
                _load();
              },
            ),
          ),
          if (!_loadedOnce && _refreshing)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: CupertinoActivityIndicator(),
            )
          else if (_records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No matching reports. Tap + to add one.',
                style: TextStyle(color: SvColors.slate),
              ),
            )
          else
            ..._sections(),
        ],
      ),
    );
  }
}

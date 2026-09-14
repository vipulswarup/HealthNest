import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/features/reports/record_detail_page.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/util/labels.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, this.patientId});
  final String? patientId;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Person> _people = const [];
  List<HealthRecord> _records = const [];
  String? _patientId;
  String _query = '';
  bool _needsReviewOnly = false;
  String? _error;
  bool _loading = true;
  int _epoch = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _patientId ??= widget.patientId;
    final epoch = SessionScope.of(context).dataEpoch;
    if (epoch != _epoch) {
      _epoch = epoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    final api = SessionScope.of(context).api;
    setState(() {
      _loading = _records.isEmpty;
      _error = null;
    });
    try {
      final people = await api.patients();
      _patientId ??= await loadInitialPersonId(people);
      final records = await api.healthRecords(
        patientId: _needsReviewOnly ? null : _patientId,
        keyword: _query,
        tag: _needsReviewOnly ? 'needs_review' : null,
      );
      if (!mounted) return;
      setState(() {
        _people = people;
        _records = records;
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

  @override
  Widget build(BuildContext context) {
    return SvLargePage(
      title: 'Reports',
      error: _error,
      onRefresh: _load,
      child: Column(
        children: [
          PersonPicker(
            people: _people,
            selectedId: _patientId,
            onSelected: (id) {
              setState(() => _patientId = id);
              rememberPerson(context, id);
              _load();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: _needsReviewOnly ? SvColors.coral : CupertinoColors.systemGrey5,
                  onPressed: () {
                    setState(() => _needsReviewOnly = !_needsReviewOnly);
                    _load();
                  },
                  child: Text(
                    'Needs review',
                    style: TextStyle(
                      color: _needsReviewOnly ? CupertinoColors.white : SvColors.ink,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: CupertinoSearchTextField(
              onSubmitted: (value) {
                setState(() => _query = value);
                _load();
              },
            ),
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 32), child: CupertinoActivityIndicator())
          else if (_records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No reports yet.', style: TextStyle(color: SvColors.slate)),
            )
          else
            CupertinoListSection.insetGrouped(
              children: [
                for (final record in _records)
                  CupertinoListTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(humanizeLabel(record.recordType))),
                        if (record.tags.contains('needs_review'))
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemYellow.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Review', style: TextStyle(fontSize: 12, color: SvColors.ink)),
                          ),
                      ],
                    ),
                    subtitle: Text(record.source),
                    additionalInfo: Text(formatDisplayDate(record.documentDate ?? record.createdAt)),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(builder: (_) => RecordDetailPage(recordId: record.id)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

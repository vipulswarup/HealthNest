import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/features/reports/document_view_page.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/util/dates.dart';
import 'package:sanovault/util/labels.dart';
import 'package:sanovault/widgets/sv_page.dart';

class RecordDetailPage extends StatefulWidget {
  const RecordDetailPage({super.key, required this.recordId});
  final String recordId;

  @override
  State<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  HealthRecord? _record;
  List<Person> _people = const [];
  String? _error;
  bool _approving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = SessionScope.of(context).api;
      final record = await api.healthRecord(widget.recordId);
      final people = await api.patients();
      if (!mounted) return;
      setState(() {
        _record = record;
        _people = people;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  Future<void> _approveReview() async {
    final record = _record;
    if (record == null) return;
    setState(() => _approving = true);
    try {
      final updated = await SessionScope.of(context).api.updateHealthRecord(
        record.id,
        {'approveReview': true},
      );
      if (!mounted) return;
      setState(() {
        _record = updated;
        _approving = false;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _error = caught.toString();
        _approving = false;
      });
    }
  }

  String _personName(String patientId) {
    for (final person in _people) {
      if (person.id == patientId) {
        return personName(person.firstName, person.lastName);
      }
    }
    return 'This person';
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    final needsReview = record?.tags.contains('needs_review') ?? false;
    return SvLargePage(
      title: record == null ? 'Report' : humanizeLabel(record.recordType),
      error: _error,
      child: record == null
          ? const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CupertinoActivityIndicator()))
          : Column(
              children: [
                if (needsReview)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemYellow.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Needs review', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Filed for ${_personName(record.patientId)} via WhatsApp.'),
                          const SizedBox(height: 10),
                          CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            onPressed: _approving ? null : _approveReview,
                            child: _approving
                                ? const CupertinoActivityIndicator()
                                : const Text('Confirm filing'),
                          ),
                        ],
                      ),
                    ),
                  ),
                CupertinoListSection.insetGrouped(
                  children: [
                    CupertinoListTile(title: const Text('Source'), additionalInfo: Text(record.source)),
                    CupertinoListTile(title: const Text('Doctor'), additionalInfo: Text(record.doctorName ?? '—')),
                    CupertinoListTile(title: const Text('Date'), additionalInfo: Text(formatDisplayDate(record.documentDate ?? record.createdAt))),
                    if (record.tags.isNotEmpty)
                      CupertinoListTile(title: const Text('Tags'), subtitle: Text(record.tags.join(', '))),
                    if (record.documentId != null)
                      CupertinoListTile(
                        title: const Text('Open file'),
                        trailing: const CupertinoListTileChevron(),
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => DocumentViewPage(documentId: record.documentId!, title: humanizeLabel(record.recordType)),
                          ),
                        ),
                      ),
                    if (record.ocrText != null && record.ocrText!.isNotEmpty)
                      CupertinoListTile(
                        title: const Text('Extracted text'),
                        subtitle: Text(record.ocrText!, maxLines: 8),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

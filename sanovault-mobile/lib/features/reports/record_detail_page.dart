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
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final record = await SessionScope.of(context).api.healthRecord(widget.recordId);
      if (!mounted) return;
      setState(() => _record = record);
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return SvLargePage(
      title: record == null ? 'Report' : humanizeLabel(record.recordType),
      error: _error,
      child: record == null
          ? const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CupertinoActivityIndicator()))
          : CupertinoListSection.insetGrouped(
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
    );
  }
}

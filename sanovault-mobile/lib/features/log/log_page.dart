import 'package:flutter/cupertino.dart';
import 'package:sanovault/features/medicines/medicines_page.dart';
import 'package:sanovault/features/reports/add_report_page.dart';
import 'package:sanovault/features/tracking/visit_notes_page.dart';
import 'package:sanovault/features/vitals/bp_page.dart';
import 'package:sanovault/features/vitals/growth_page.dart';
import 'package:sanovault/theme/sv_colors.dart';

/// One place to record anything. Symptoms come first because they are the
/// thing people most often want to jot down in a hurry.
class LogPage extends StatelessWidget {
  const LogPage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Widget)>[
      (
        CupertinoIcons.pencil_circle_fill,
        'Symptom or note',
        'What you noticed, and what to ask the doctor',
        const VisitNotesPage(),
      ),
      (
        CupertinoIcons.heart_circle_fill,
        'Blood pressure',
        'Add a reading and see recent ones',
        const BpPage(),
      ),
      (
        CupertinoIcons.arrow_up_arrow_down_circle_fill,
        'Height & weight',
        'Track growth and weight',
        const GrowthPage(),
      ),
      (
        CupertinoIcons.capsule_fill,
        'Medicine',
        'Add or update a medicine',
        const MedicinesPage(),
      ),
      (
        CupertinoIcons.doc_fill,
        'Report',
        'Scan or upload a lab report or prescription',
        const AddReportPage(),
      ),
    ];
    return CupertinoPageScaffold(
      backgroundColor: SvColors.groupedBackground,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Log'),
            border: null,
            backgroundColor: SvColors.groupedBackground,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final (icon, title, subtitle, page) = items[index];
                return GestureDetector(
                  onTap: () => _open(context, page),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SvColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SvColors.separator),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 34, color: SvColors.brand),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: SvColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: SvColors.slate,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const CupertinoListTileChevron(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/features/reports/reports_page.dart';

HealthRecord record(String id, {String? documentDate, String? createdAt}) =>
    HealthRecord(
      id: id,
      patientId: 'p',
      recordType: 'LAB_REPORT',
      source: 's',
      documentDate: documentDate,
      createdAt: createdAt,
    );

void main() {
  test('reports sort by document date, not upload date', () {
    final sorted = sortByDocumentDate([
      record('old-doc-new-upload',
          documentDate: '2024-01-05', createdAt: '2026-10-01T10:00:00Z'),
      record('new-doc-old-upload',
          documentDate: '2026-03-02', createdAt: '2026-03-03T10:00:00Z'),
      record('no-doc-date', createdAt: '2025-06-01T10:00:00Z'),
    ]);
    expect(sorted.map((r) => r.id), [
      'new-doc-old-upload',
      'no-doc-date',
      'old-doc-new-upload',
    ]);
  });

  test('symptom notes are newest first by note date, ignoring pinned order', () {
    final list = VisitNoteList.fromJson({
      'notes': [
        {'id': 'a', 'patientId': 'p', 'noteDate': '2026-01-01', 'observed': 'x',
         'createdAt': '2026-01-01T08:00:00Z'},
        {'id': 'b', 'patientId': 'p', 'noteDate': '2026-05-01', 'observed': 'y',
         'createdAt': '2026-05-01T08:00:00Z'},
        {'id': 'c', 'patientId': 'p', 'noteDate': '2026-05-01', 'observed': 'z',
         'createdAt': '2026-05-01T09:00:00Z'},
      ],
    });
    expect(list.notes.map((n) => n.id), ['c', 'b', 'a']);
  });

  test('blood pressure readings are newest first', () {
    final week = BloodPressureWeek.fromJson({
      'readings': [
        {'id': '1', 'systolic': 120, 'diastolic': 80, 'recordedAt': '2026-10-10T06:00:00Z'},
        {'id': '2', 'systolic': 130, 'diastolic': 85, 'recordedAt': '2026-10-12T06:00:00Z'},
        {'id': '3', 'systolic': 125, 'diastolic': 82, 'recordedAt': 'not a date'},
      ],
    });
    expect(week.readings.map((r) => r.id), ['2', '1', '3']);
  });
}

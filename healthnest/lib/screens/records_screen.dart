// Health records screen for viewing and managing health records

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/patient.dart';
import '../models/health_record.dart';
import '../widgets/health_record_card.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String? _selectedPatientId;
  List<Patient> _patients = [];
  List<HealthRecord> _records = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPatientsAndRecords();
  }

  Future<void> _loadPatientsAndRecords() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final patients = userProvider.patients;
      setState(() {
        _patients = patients;
        if (_selectedPatientId == null && patients.isNotEmpty) {
          _selectedPatientId = patients.first.id;
        }
      });
      await _loadRecords();
    } catch (_) {}
  }

  Future<void> _loadRecords() async {
    if (_selectedPatientId == null) return;
    setState(() => _loading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final records = await userProvider.getHealthRecords(_selectedPatientId!);
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() => _records = records);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteRecord(String recordId) async {
    final confirm = await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Delete Record'),
            content: const Text('Are you sure you want to delete this record?'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context, false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('Delete'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.deleteHealthRecord(recordId);
    await _loadRecords();
  }

  void _showRecordDetails(HealthRecord record) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(record.recordType),
        content: Column(
          children: [
            const SizedBox(height: 8),
            Text('Source: ${record.source}'),
            const SizedBox(height: 4),
            Text('Date: ${record.createdAt.toLocal()}'),
            const SizedBox(height: 8),
            if (record.tags.isNotEmpty) Text('Tags: ${record.tags.join(', ')}'),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Health Records'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_patients.isNotEmpty) ...[
                const Text(
                  'Select Patient:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CupertinoPicker(
                    itemExtent: 40,
                    onSelectedItemChanged: (index) async {
                      setState(() {
                        _selectedPatientId = _patients[index].id;
                      });
                      await _loadRecords();
                    },
                    children:
                        _patients.map((p) => Center(child: Text(p.displayName))).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Expanded(
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _records.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(CupertinoIcons.doc_text, size: 48, color: CupertinoColors.systemGrey),
                                const SizedBox(height: 12),
                                const Text('No records yet'),
                                const SizedBox(height: 8),
                                const Text('Scan a document from the Dashboard'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _records.length,
                            itemBuilder: (context, index) {
                              final record = _records[index];
                              return HealthRecordCard(
                                record: record,
                                onTap: () => _showRecordDetails(record),
                                onDelete: () => _deleteRecord(record.id),
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
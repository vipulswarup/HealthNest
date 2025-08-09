// Document scanning screen for AI-powered document processing

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:provider/provider.dart';
import '../models/health_record.dart';
import '../models/patient.dart';
import '../services/ml_service.dart';
import '../providers/user_provider.dart';
import '../widgets/health_record_card.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final MLService _mlService = MLService();
  
  bool _isProcessing = false;
  String? _selectedPatientId;
  List<Patient> _patients = [];
  List<HealthRecord> _recentRecords = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _loadRecentRecords();
  }

  Future<void> _loadPatients() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final patients = userProvider.patients;
      setState(() {
        _patients = patients;
        if (patients.isNotEmpty && _selectedPatientId == null) {
          _selectedPatientId = patients.first.id;
        }
      });
    } catch (e) {
      _showError('Failed to load patients: $e');
    }
  }

  Future<void> _loadRecentRecords() async {
    if (_selectedPatientId == null) return;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final records = await userProvider.getHealthRecords(_selectedPatientId!);
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _recentRecords = records.take(5).toList();
      });
    } catch (e) {
      _showError('Failed to load recent records: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        await _processDocument(image.path);
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _scanWithSystemScanner() async {
    try {
      setState(() => _isProcessing = true);
      final scanner = FlutterDocScanner();
      final result = await scanner.getScanDocuments(page: 1);
      if (result is List && result.isNotEmpty) {
        final path = result.first.toString();
        await _processDocument(path);
      }
    } catch (e) {
      _showError('Failed to scan document: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processDocument(String imagePath) async {
    if (_selectedPatientId == null) {
      _showError('Please select a patient first');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Analyze document using ML service
      final DocumentAnalysisResult result = await _mlService.analyzeDocument(imagePath);
      
      // Show analysis results for user confirmation
      final bool confirmed = await _showAnalysisConfirmation(result, imagePath);
      
      if (confirmed) {
        await _saveHealthRecord(result, imagePath);
        await _loadRecentRecords(); // Refresh the list
      }
    } catch (e) {
      _showError('Failed to process document: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<bool> _showAnalysisConfirmation(DocumentAnalysisResult result, String imagePath) async {
    return await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Document Analysis'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            Text('Document Type: ${_getDocumentTypeName(result.documentType)}'),
            const SizedBox(height: 8),
            Text('Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            Text('Tags: ${result.tags.join(', ')}'),
            const SizedBox(height: 16),
            const Text('Extracted Text:'),
            const SizedBox(height: 8),
            Container(
              height: 100,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: CupertinoColors.systemGrey4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  result.extractedText,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            child: const Text('Save'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _saveHealthRecord(DocumentAnalysisResult result, String imagePath) async {
    try {
      // Create health record
      final HealthRecord record = HealthRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: _selectedPatientId!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recordType: _getRecordType(result.documentType),
        data: result.extractedData,
        tags: result.tags,
        source: 'Document Scan',
        documentPath: imagePath, // Use original path for now
      );

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.saveHealthRecord(record);
      await _loadRecentRecords();
      _showSuccess('Document saved successfully');
    } catch (e) {
      _showError('Failed to save document: $e');
    }
  }

  String _getDocumentTypeName(DocumentType type) {
    switch (type) {
      case DocumentType.prescription:
        return 'Prescription';
      case DocumentType.labReport:
        return 'Lab Report';
      case DocumentType.scanReport:
        return 'Scan Report';
      case DocumentType.dischargeSummary:
        return 'Discharge Summary';
      case DocumentType.consultationNote:
        return 'Consultation Note';
      case DocumentType.medicationList:
        return 'Medication List';
      case DocumentType.vitalSigns:
        return 'Vital Signs';
      case DocumentType.unknown:
        return 'Unknown';
    }
  }

  String _getRecordType(DocumentType type) {
    switch (type) {
      case DocumentType.prescription:
        return 'prescription';
      case DocumentType.labReport:
        return 'lab_report';
      case DocumentType.scanReport:
        return 'scan_report';
      case DocumentType.dischargeSummary:
        return 'discharge_summary';
      case DocumentType.consultationNote:
        return 'consultation_note';
      case DocumentType.medicationList:
        return 'medication_list';
      case DocumentType.vitalSigns:
        return 'vital_signs';
      case DocumentType.unknown:
        return 'unknown';
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Scan Documents'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Selection
              if (_patients.isNotEmpty) ...[
                const Text(
                  'Select Patient:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedPatientId = _patients[index].id;
                      });
                      _loadRecentRecords();
                    },
                    children: _patients.map((patient) => 
                      Center(child: Text(patient.displayName))
                    ).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Scan Options
              const Text(
                'Scan Document:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      color: CupertinoColors.systemBlue,
                      onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.camera),
                          SizedBox(width: 8),
                          Text('Camera'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      color: CupertinoColors.systemGrey,
                      onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.photo),
                          SizedBox(width: 8),
                          Text('Gallery'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      color: CupertinoColors.activeGreen,
                      onPressed: _isProcessing ? null : _scanWithSystemScanner,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.doc_text_viewfinder),
                          SizedBox(width: 8),
                          Text('Scan'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              if (_isProcessing) ...[
                const SizedBox(height: 24),
                const Center(
                  child: Column(
                    children: [
                      CupertinoActivityIndicator(),
                      SizedBox(height: 8),
                      Text('Processing document...'),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Recent Records
              if (_recentRecords.isNotEmpty) ...[
                const Text(
                  'Recent Records:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _recentRecords.length,
                    itemBuilder: (context, index) {
                      return HealthRecordCard(
                        record: _recentRecords[index],
                        onTap: () {
                          // Navigate to record details
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 
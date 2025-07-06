import 'dart:io';
import 'dart:typed_data';
import 'package:google_ml_kit/google_ml_kit.dart';

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  final TextRecognizer _textRecognizer = GoogleMlKit.vision.textRecognizer();
  final ImageLabeler _imageLabeler = GoogleMlKit.vision.imageLabeler();

  // Predefined medical document categories
  static const List<String> _documentCategories = [
    'prescription',
    'lab_report',
    'scan_report',
    'discharge_summary',
    'consultation_note',
    'medication_list',
    'vital_signs',
    'symptom_log',
  ];

  // Medical terms for automatic tagging
  static const Map<String, List<String>> _medicalTerms = {
    'blood_test': ['hemoglobin', 'creatinine', 'urea', 'glucose', 'cholesterol', 'wbc', 'rbc', 'platelets'],
    'urine_test': ['protein', 'glucose', 'ketones', 'blood', 'leukocytes', 'nitrites'],
    'imaging': ['x-ray', 'ct scan', 'mri', 'ultrasound', 'ecg', 'echo'],
    'medication': ['tablet', 'capsule', 'injection', 'syrup', 'dose', 'mg', 'ml'],
    'vitals': ['blood pressure', 'temperature', 'pulse', 'heart rate', 'oxygen saturation'],
  };

  Future<DocumentAnalysisResult> analyzeDocument(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Perform text recognition
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );

      // Extract text content
      final String extractedText = recognizedText.text;

      // Analyze document type and extract relevant information
      final DocumentType documentType = _classifyDocumentType(extractedText);
      final List<String> tags = _extractTags(extractedText);
      final Map<String, dynamic> extractedData = _extractStructuredData(extractedText, documentType);

      return DocumentAnalysisResult(
        documentType: documentType,
        extractedText: extractedText,
        tags: tags,
        extractedData: extractedData,
        confidence: 0.85, // Placeholder confidence score
      );
    } catch (e) {
      throw Exception('Failed to analyze document: $e');
    }
  }

  DocumentType _classifyDocumentType(String text) {
    final String lowerText = text.toLowerCase();
    
    if (_containsMedicalTerms(lowerText, _medicalTerms['medication']!)) {
      return DocumentType.prescription;
    } else if (_containsMedicalTerms(lowerText, _medicalTerms['blood_test']!) || 
               _containsMedicalTerms(lowerText, _medicalTerms['urine_test']!)) {
      return DocumentType.labReport;
    } else if (_containsMedicalTerms(lowerText, _medicalTerms['imaging']!)) {
      return DocumentType.scanReport;
    } else if (lowerText.contains('discharge') || lowerText.contains('summary')) {
      return DocumentType.dischargeSummary;
    } else if (lowerText.contains('consultation') || lowerText.contains('visit')) {
      return DocumentType.consultationNote;
    } else if (_containsMedicalTerms(lowerText, _medicalTerms['vitals']!)) {
      return DocumentType.vitalSigns;
    }
    
    return DocumentType.unknown;
  }

  List<String> _extractTags(String text) {
    final String lowerText = text.toLowerCase();
    final List<String> tags = <String>[];
    
    // Extract tags based on medical terms
    for (final entry in _medicalTerms.entries) {
      if (_containsMedicalTerms(lowerText, entry.value)) {
        tags.add(entry.key);
      }
    }
    
    // Extract hospital/provider names
    final List<String> hospitalNames = _extractHospitalNames(text);
    tags.addAll(hospitalNames);
    
    // Extract dates
    final List<String> dates = _extractDates(text);
    if (dates.isNotEmpty) {
      tags.add('dated_${dates.first}');
    }
    
    return tags;
  }

  Map<String, dynamic> _extractStructuredData(String text, DocumentType documentType) {
    final Map<String, dynamic> data = {};
    
    switch (documentType) {
      case DocumentType.prescription:
        data['medications'] = _extractMedications(text);
        data['dosage'] = _extractDosage(text);
        data['duration'] = _extractDuration(text);
        break;
      case DocumentType.labReport:
        data['test_results'] = _extractLabResults(text);
        data['reference_ranges'] = _extractReferenceRanges(text);
        break;
      case DocumentType.scanReport:
        data['findings'] = _extractScanFindings(text);
        data['impression'] = _extractImpression(text);
        break;
      case DocumentType.vitalSigns:
        data['vitals'] = _extractVitalSigns(text);
        break;
      default:
        data['raw_text'] = text;
    }
    
    return data;
  }

  List<String> _extractMedications(String text) {
    // Simple regex-based medication extraction
    final RegExp medicationRegex = RegExp(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\s+\d+mg?\b');
    return medicationRegex.allMatches(text).map((match) => match.group(0)!).toList();
  }

  Map<String, dynamic> _extractLabResults(String text) {
    final Map<String, dynamic> results = {};
    final RegExp resultRegex = RegExp(r'(\w+):\s*([\d.]+)\s*([a-zA-Z/%]+)');
    
    for (final match in resultRegex.allMatches(text)) {
      final String testName = match.group(1)!;
      final String value = match.group(2)!;
      final String unit = match.group(3)!;
      results[testName] = {'value': value, 'unit': unit};
    }
    
    return results;
  }

  Map<String, dynamic> _extractVitalSigns(String text) {
    final Map<String, dynamic> vitals = {};
    
    // Extract blood pressure
    final RegExp bpRegex = RegExp(r'(\d+)/(\d+)\s*mmHg');
    final bpMatch = bpRegex.firstMatch(text);
    if (bpMatch != null) {
      vitals['blood_pressure'] = {
        'systolic': bpMatch.group(1),
        'diastolic': bpMatch.group(2),
        'unit': 'mmHg'
      };
    }
    
    // Extract temperature
    final RegExp tempRegex = RegExp(r'(\d+\.?\d*)\s*°?[CF]');
    final tempMatch = tempRegex.firstMatch(text);
    if (tempMatch != null) {
      vitals['temperature'] = {
        'value': tempMatch.group(1),
        'unit': '°C'
      };
    }
    
    return vitals;
  }

  List<String> _extractHospitalNames(String text) {
    // Common hospital names in India
    final List<String> hospitalNames = [
      'AIIMS', 'Max Healthcare', 'Apollo', 'Fortis', 'Medanta', 'BLK', 'Safdarjung',
      'Ram Manohar Lohia', 'Lady Hardinge', 'Gangaram', 'Indraprastha Apollo'
    ];
    
    return hospitalNames.where((name) => text.contains(name)).toList();
  }

  List<String> _extractDates(String text) {
    final RegExp dateRegex = RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}');
    return dateRegex.allMatches(text).map((match) => match.group(0)!).toList();
  }

  bool _containsMedicalTerms(String text, List<String> terms) {
    return terms.any((term) => text.contains(term));
  }

  String _extractDosage(String text) {
    final RegExp dosageRegex = RegExp(r'(\d+)\s*(mg|ml|mcg)');
    final match = dosageRegex.firstMatch(text);
    return match?.group(0) ?? '';
  }

  String _extractDuration(String text) {
    final RegExp durationRegex = RegExp(r'(\d+)\s*(days?|weeks?|months?)');
    final match = durationRegex.firstMatch(text);
    return match?.group(0) ?? '';
  }

  Map<String, dynamic> _extractReferenceRanges(String text) {
    // Extract reference ranges from lab reports
    final Map<String, dynamic> ranges = {};
    final RegExp rangeRegex = RegExp(r'(\w+):\s*([\d.]+)\s*-\s*([\d.]+)');
    
    for (final match in rangeRegex.allMatches(text)) {
      final String testName = match.group(1)!;
      final String minValue = match.group(2)!;
      final String maxValue = match.group(3)!;
      ranges[testName] = {'min': minValue, 'max': maxValue};
    }
    
    return ranges;
  }

  String _extractScanFindings(String text) {
    // Extract findings section from scan reports
    final RegExp findingsRegex = RegExp(r'findings?:?\s*(.*?)(?=\n\n|\n[A-Z]|$)');
    final match = findingsRegex.firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }

  String _extractImpression(String text) {
    // Extract impression section from scan reports
    final RegExp impressionRegex = RegExp(r'impression?:?\s*(.*?)(?=\n\n|\n[A-Z]|$)');
    final match = impressionRegex.firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }

  void dispose() {
    _textRecognizer.close();
    _imageLabeler.close();
  }
}

enum DocumentType {
  prescription,
  labReport,
  scanReport,
  dischargeSummary,
  consultationNote,
  medicationList,
  vitalSigns,
  unknown,
}

class DocumentAnalysisResult {
  final DocumentType documentType;
  final String extractedText;
  final List<String> tags;
  final Map<String, dynamic> extractedData;
  final double confidence;

  DocumentAnalysisResult({
    required this.documentType,
    required this.extractedText,
    required this.tags,
    required this.extractedData,
    required this.confidence,
  });
} 
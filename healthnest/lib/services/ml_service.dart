// ML service interface for AI-powered document processing
// Supports on-device ML for document scanning and tagging

import '../models/health_record.dart';

abstract class MLService {
  // Document processing
  Future<Map<String, dynamic>> processDocument(String imagePath);
  Future<List<String>> extractTags(String imagePath);
  Future<String> classifyDocumentType(String imagePath);
  
  // Text extraction and analysis
  Future<String> extractText(String imagePath);
  Future<Map<String, dynamic>> extractStructuredData(String text);
  
  // Tagging and categorization
  Future<List<String>> suggestTags(String text, String documentType);
  Future<bool> validateTag(String tag);
  
  // Model management
  Future<void> initializeModels();
  Future<void> updateModels();
  Future<bool> isModelReady();
}

// Implementation will be provided for Core ML (iOS) and ML Kit (Android) 
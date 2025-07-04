// Core health record model based on openEHR archetypes
// This will be expanded to include SNOMED CT and LOINC coding

class HealthRecord {
  final String id;
  final String patientId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String recordType; // openEHR archetype type
  final Map<String, dynamic> data;
  final List<String> tags;
  final String source; // Provider/hospital name
  final String? documentPath; // Path to scanned document if applicable
  final String? hospitalSystemName; // e.g., "AIIMS", "Max Healthcare"
  final String? hospitalIdentifierType; // e.g., "UHID", "Patient Number"
  final String? hospitalIdentifierValue; // e.g., the actual UHID or number

  HealthRecord({
    required this.id,
    required this.patientId,
    required this.createdAt,
    required this.updatedAt,
    required this.recordType,
    required this.data,
    required this.tags,
    required this.source,
    this.documentPath,
    this.hospitalSystemName,
    this.hospitalIdentifierType,
    this.hospitalIdentifierValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'recordType': recordType,
      'data': data,
      'tags': tags,
      'source': source,
      'documentPath': documentPath,
      'hospitalSystemName': hospitalSystemName,
      'hospitalIdentifierType': hospitalIdentifierType,
      'hospitalIdentifierValue': hospitalIdentifierValue,
    };
  }

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'],
      patientId: json['patientId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      recordType: json['recordType'],
      data: json['data'],
      tags: List<String>.from(json['tags']),
      source: json['source'],
      documentPath: json['documentPath'],
      hospitalSystemName: json['hospitalSystemName'],
      hospitalIdentifierType: json['hospitalIdentifierType'],
      hospitalIdentifierValue: json['hospitalIdentifierValue'],
    );
  }
} 
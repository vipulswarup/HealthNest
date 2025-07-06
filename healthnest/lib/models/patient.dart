import 'dart:convert';

// Patient model for family member management
// Supports multiple family members with access controls

// Hospital/lab identifier model
class HospitalIdentifier {
  final String systemName; // e.g., "AIIMS", "Max Healthcare"
  final String identifierType; // e.g., "UHID", "Patient Number"
  final String value;

  HospitalIdentifier({
    required this.systemName,
    required this.identifierType,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
        'systemName': systemName,
        'identifierType': identifierType,
        'value': value,
      };

  factory HospitalIdentifier.fromJson(Map<String, dynamic> json) => HospitalIdentifier(
        systemName: json['systemName'],
        identifierType: json['identifierType'],
        value: json['value'],
      );
}

class Patient {
  final String id;
  final String name;
  final DateTime dateOfBirth;
  final String gender;
  final String? abhaNumber; // Ayushman Bharat Health Account Number
  final String? bloodGroup;
  final List<String> emergencyContacts;
  final Map<String, dynamic> preferences;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<HospitalIdentifier> hospitalIdentifiers;
  final List<String> mobileNumbers;

  Patient({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    this.abhaNumber,
    this.bloodGroup,
    required this.emergencyContacts,
    required this.preferences,
    required this.createdAt,
    required this.updatedAt,
    required this.hospitalIdentifiers,
    required this.mobileNumbers,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'abhaNumber': abhaNumber,
      'bloodGroup': bloodGroup,
      'emergencyContacts': jsonEncode(emergencyContacts),
      'preferences': jsonEncode(preferences),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'hospitalIdentifiers': jsonEncode(hospitalIdentifiers.map((h) => h.toJson()).toList()),
      'mobileNumbers': jsonEncode(mobileNumbers),
    };
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      name: json['name'],
      dateOfBirth: DateTime.parse(json['dateOfBirth']),
      gender: json['gender'],
      abhaNumber: json['abhaNumber'],
      bloodGroup: json['bloodGroup'],
      emergencyContacts: json['emergencyContacts'] != null 
          ? List<String>.from(jsonDecode(json['emergencyContacts']))
          : [],
      preferences: json['preferences'] != null 
          ? Map<String, dynamic>.from(jsonDecode(json['preferences']))
          : {},
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      hospitalIdentifiers: json['hospitalIdentifiers'] != null 
          ? (jsonDecode(json['hospitalIdentifiers']) as List<dynamic>)
              .map((h) => HospitalIdentifier.fromJson(h))
              .toList()
          : [],
      mobileNumbers: json['mobileNumbers'] != null 
          ? List<String>.from(jsonDecode(json['mobileNumbers']))
          : [],
    );
  }
} 
import 'dart:convert';

class Medication {
  final String id;
  final String patientId;
  final String name;
  final String dosage;
  final String frequency;
  final String route; // oral, injection, topical, etc.
  final DateTime startDate;
  final DateTime? endDate;
  final String? instructions;
  final String? prescribedBy;
  final String? source; // hospital/provider name
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;

  Medication({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.route,
    required this.startDate,
    this.endDate,
    this.instructions,
    this.prescribedBy,
    this.source,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'route': route,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'instructions': instructions,
      'prescribedBy': prescribedBy,
      'source': source,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': jsonEncode(tags),
    };
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'],
      patientId: json['patientId'],
      name: json['name'],
      dosage: json['dosage'],
      frequency: json['frequency'],
      route: json['route'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      instructions: json['instructions'],
      prescribedBy: json['prescribedBy'],
      source: json['source'],
      isActive: json['isActive'] == 1,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      tags: json['tags'] != null 
          ? List<String>.from(jsonDecode(json['tags']))
          : [],
    );
  }

  Medication copyWith({
    String? id,
    String? patientId,
    String? name,
    String? dosage,
    String? frequency,
    String? route,
    DateTime? startDate,
    DateTime? endDate,
    String? instructions,
    String? prescribedBy,
    String? source,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
  }) {
    return Medication(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      route: route ?? this.route,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      instructions: instructions ?? this.instructions,
      prescribedBy: prescribedBy ?? this.prescribedBy,
      source: source ?? this.source,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }
}

class MedicationDose {
  final String id;
  final String medicationId;
  final DateTime scheduledTime;
  final DateTime? takenTime;
  final bool isTaken;
  final String? notes;
  final DateTime createdAt;

  MedicationDose({
    required this.id,
    required this.medicationId,
    required this.scheduledTime,
    this.takenTime,
    required this.isTaken,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicationId': medicationId,
      'scheduledTime': scheduledTime.toIso8601String(),
      'takenTime': takenTime?.toIso8601String(),
      'isTaken': isTaken ? 1 : 0,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MedicationDose.fromJson(Map<String, dynamic> json) {
    return MedicationDose(
      id: json['id'],
      medicationId: json['medicationId'],
      scheduledTime: DateTime.parse(json['scheduledTime']),
      takenTime: json['takenTime'] != null ? DateTime.parse(json['takenTime']) : null,
      isTaken: json['isTaken'] == 1,
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class MedicationReminder {
  final String id;
  final String medicationId;
  final String title;
  final String message;
  final DateTime scheduledTime;
  final bool isEnabled;
  final String frequency; // daily, weekly, custom
  final List<int> daysOfWeek; // 1-7 for Monday-Sunday
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicationReminder({
    required this.id,
    required this.medicationId,
    required this.title,
    required this.message,
    required this.scheduledTime,
    required this.isEnabled,
    required this.frequency,
    required this.daysOfWeek,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicationId': medicationId,
      'title': title,
      'message': message,
      'scheduledTime': scheduledTime.toIso8601String(),
      'isEnabled': isEnabled ? 1 : 0,
      'frequency': frequency,
      'daysOfWeek': jsonEncode(daysOfWeek),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MedicationReminder.fromJson(Map<String, dynamic> json) {
    return MedicationReminder(
      id: json['id'],
      medicationId: json['medicationId'],
      title: json['title'],
      message: json['message'],
      scheduledTime: DateTime.parse(json['scheduledTime']),
      isEnabled: json['isEnabled'] == 1,
      frequency: json['frequency'],
      daysOfWeek: json['daysOfWeek'] != null 
          ? List<int>.from(jsonDecode(json['daysOfWeek']))
          : [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
} 
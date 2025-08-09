import 'dart:convert';

// App owner/primary user model
// This user manages multiple patient profiles (family members)

class User {
  final String id;
  final String firstName;
  final String? middleName;
  final String? lastName;
  final String? title;
  final String? suffix;
  final List<String> emails;
  final List<Map<String, String>> mobileNumbers; // [{countryCode: '+91', number: '1234567890'}]
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> preferences;
  final bool onboardingCompleted;

  User({
    required this.id,
    required this.firstName,
    this.middleName,
    this.lastName,
    this.title,
    this.suffix,
    required this.emails,
    required this.mobileNumbers,
    required this.createdAt,
    required this.updatedAt,
    required this.preferences,
    required this.onboardingCompleted,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'title': title,
      'suffix': suffix,
      'emails': jsonEncode(emails),
      // Persist under 'phoneNumbers' to match SQLite schema
      'phoneNumbers': jsonEncode(mobileNumbers),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'preferences': jsonEncode(preferences),
      'onboardingCompleted': onboardingCompleted ? 1 : 0,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      firstName: json['firstName'],
      middleName: json['middleName'],
      lastName: json['lastName'],
      title: json['title'],
      suffix: json['suffix'],
      emails: json['emails'] != null ? List<String>.from(jsonDecode(json['emails'])) : [],
      // Read from either 'mobileNumbers' (cloud) or 'phoneNumbers' (SQLite schema)
      mobileNumbers: () {
        final dynamic raw = json['mobileNumbers'] ?? json['phoneNumbers'];
        if (raw == null) return <Map<String, String>>[];
        final dynamic decoded = raw is String ? jsonDecode(raw) : raw;
        if (decoded is List) {
          return decoded
              .whereType<dynamic>()
              .map((e) {
                final map = Map<String, dynamic>.from(e as Map);
                return <String, String>{
                  'countryCode': map['countryCode']?.toString() ?? '',
                  'number': map['number']?.toString() ?? '',
                };
              })
              .toList();
        }
        return <Map<String, String>>[];
      }(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      preferences: json['preferences'] != null 
          ? Map<String, dynamic>.from(jsonDecode(json['preferences']))
          : {},
      onboardingCompleted: json['onboardingCompleted'] == 1,
    );
  }

  User copyWith({
    String? id,
    String? firstName,
    String? middleName,
    String? lastName,
    String? title,
    String? suffix,
    List<String>? emails,
    List<Map<String, String>>? mobileNumbers,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? preferences,
    bool? onboardingCompleted,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      title: title ?? this.title,
      suffix: suffix ?? this.suffix,
      emails: emails ?? this.emails,
      mobileNumbers: mobileNumbers ?? this.mobileNumbers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferences: preferences ?? this.preferences,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  String get displayName {
    final parts = [
      if (title != null && title!.isNotEmpty) title,
      firstName,
      if (middleName != null && middleName!.isNotEmpty) middleName,
      if (lastName != null && lastName!.isNotEmpty) lastName,
      if (suffix != null && suffix!.isNotEmpty) suffix,
    ];
    return parts.whereType<String>().join(' ').replaceAll(RegExp(' +'), ' ').trim();
  }
} 
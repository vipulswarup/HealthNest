import 'dart:convert';

// App owner/primary user model
// This user manages multiple patient profiles (family members)

class User {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> preferences;
  final bool onboardingCompleted;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
    required this.preferences,
    required this.onboardingCompleted,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'preferences': jsonEncode(preferences),
      'onboardingCompleted': onboardingCompleted ? 1 : 0,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
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
    String? name,
    String? email,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? preferences,
    bool? onboardingCompleted,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferences: preferences ?? this.preferences,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
} 
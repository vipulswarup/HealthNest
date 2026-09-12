class BetaStatus {
  const BetaStatus({required this.acknowledged, required this.version});

  final bool acknowledged;
  final String version;

  factory BetaStatus.fromJson(Map<String, dynamic> json) {
    return BetaStatus(
      acknowledged: json['acknowledged'] == true,
      version: json['version'] as String? ?? '',
    );
  }
}

class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.firstName,
    this.lastName,
  });

  final String id;
  final String email;
  final String firstName;
  final String? lastName;

  String get displayName {
    final full = '$firstName ${lastName ?? ''}'.trim();
    return full.isEmpty ? email : full;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String?,
    );
  }
}

class Household {
  const Household({required this.id, required this.name});

  final String id;
  final String name;

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
    );
  }
}

class PendingInvite {
  const PendingInvite({
    required this.id,
    required this.token,
    this.householdName,
    this.invitedByName,
  });

  final String id;
  final String token;
  final String? householdName;
  final String? invitedByName;

  factory PendingInvite.fromJson(Map<String, dynamic> json) {
    return PendingInvite(
      id: json['id'] as String,
      token: json['token'] as String,
      householdName: json['householdName'] as String?,
      invitedByName: json['invitedByName'] as String?,
    );
  }
}

class DashboardPerson {
  const DashboardPerson({
    required this.id,
    required this.firstName,
    this.lastName,
  });

  final String id;
  final String firstName;
  final String? lastName;

  factory DashboardPerson.fromJson(Map<String, dynamic> json) {
    return DashboardPerson(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String?,
    );
  }
}

class DashboardRecord {
  const DashboardRecord({
    required this.id,
    required this.patientId,
    required this.recordType,
    required this.source,
    this.documentDate,
    required this.createdAt,
  });

  final String id;
  final String patientId;
  final String recordType;
  final String source;
  final String? documentDate;
  final String createdAt;

  factory DashboardRecord.fromJson(Map<String, dynamic> json) {
    return DashboardRecord(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      recordType: json['recordType'] as String? ?? '',
      source: json['source'] as String? ?? '',
      documentDate: json['documentDate'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class DashboardHome {
  const DashboardHome({
    required this.householdId,
    required this.acknowledged,
    required this.households,
    required this.pending,
    required this.patients,
    required this.records,
  });

  final String? householdId;
  final bool acknowledged;
  final List<Household> households;
  final List<PendingInvite> pending;
  final List<DashboardPerson> patients;
  final List<DashboardRecord> records;

  factory DashboardHome.fromJson(Map<String, dynamic> json) {
    return DashboardHome(
      householdId: json['householdId'] as String?,
      acknowledged: json['acknowledged'] == true,
      households: _mapList(json['households'], Household.fromJson),
      pending: _mapList(json['pending'], PendingInvite.fromJson),
      patients: _mapList(json['patients'], DashboardPerson.fromJson),
      records: _mapList(json['records'], DashboardRecord.fromJson),
    );
  }
}

List<T> _mapList<T>(
  Object? value,
  T Function(Map<String, dynamic> json) parse,
) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => parse(Map<String, dynamic>.from(item)))
      .toList();
}

String? _string(Object? value) => value == null ? null : value.toString();

class EmergencyContact {
  const EmergencyContact({required this.name, required this.phone, required this.relation});
  final String name;
  final String phone;
  final String relation;
  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    relation: json['relation'] as String? ?? '',
  );
  Map<String, String> toJson() => {'name': name, 'phone': phone, 'relation': relation};
}

class Person {
  const Person({
    required this.id,
    required this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.abhaNumber,
    this.householdId,
    this.emails = const [],
    this.emergencyContacts = const [],
  });

  final String id;
  final String firstName;
  final String? lastName;
  final String? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String? abhaNumber;
  final String? householdId;
  final List<String> emails;
  final List<EmergencyContact> emergencyContacts;

  String get displayName => '$firstName ${lastName ?? ''}'.trim();

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String?,
      dateOfBirth: _string(json['dateOfBirth']),
      gender: json['gender'] as String?,
      bloodGroup: json['bloodGroup'] as String?,
      abhaNumber: json['abhaNumber'] as String?,
      householdId: json['householdId'] as String?,
      emails: (json['emails'] as List?)?.map((item) => item.toString()).toList() ?? const [],
      emergencyContacts: _mapList(json['emergencyContacts'], EmergencyContact.fromJson),
    );
  }
}

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.patientId,
    required this.recordType,
    required this.source,
    this.doctorName,
    this.documentDate,
    this.documentId,
    this.ocrText,
    this.tags = const [],
    this.data = const {},
    this.createdAt,
  });

  final String id;
  final String patientId;
  final String recordType;
  final String source;
  final String? doctorName;
  final String? documentDate;
  final String? documentId;
  final String? ocrText;
  final List<String> tags;
  final Map<String, dynamic> data;
  final String? createdAt;

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      recordType: json['recordType'] as String? ?? '',
      source: json['source'] as String? ?? '',
      doctorName: json['doctorName'] as String?,
      documentDate: _string(json['documentDate']),
      documentId: json['documentId'] as String?,
      ocrText: json['ocrText'] as String?,
      tags: (json['tags'] as List?)?.map((item) => item.toString()).toList() ?? const [],
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : const {},
      createdAt: _string(json['createdAt']),
    );
  }
}

class Medication {
  const Medication({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.route,
    required this.isActive,
    this.startDate,
    this.endDate,
    this.prescribedBy,
    this.instructions,
    this.indication,
  });

  final String id;
  final String patientId;
  final String name;
  final String dosage;
  final String frequency;
  final String route;
  final bool isActive;
  final String? startDate;
  final String? endDate;
  final String? prescribedBy;
  final String? instructions;
  final String? indication;

  String get line => '$name · $dosage · $frequency';

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      route: json['route'] as String? ?? '',
      isActive: json['isActive'] == true,
      startDate: _string(json['startDate']),
      endDate: _string(json['endDate']),
      prescribedBy: json['prescribedBy'] as String?,
      instructions: json['instructions'] as String?,
      indication: json['indication'] as String?,
    );
  }
}

class DoctorPacket {
  const DoctorPacket({
    required this.patientName,
    required this.age,
    required this.gender,
    required this.bloodGroup,
    required this.conditions,
    required this.medicines,
    required this.labHighlights,
    required this.bloodPressure,
    required this.growth,
    required this.vaccinations,
    required this.visitNotes,
  });

  final String patientName;
  final int? age;
  final String gender;
  final String bloodGroup;
  final List<String> conditions;
  final List<String> medicines;
  final List<String> labHighlights;
  final List<String> bloodPressure;
  final List<String> growth;
  final List<String> vaccinations;
  final List<String> visitNotes;

  factory DoctorPacket.fromJson(Map<String, dynamic> json) {
    final patient = Map<String, dynamic>.from(json['patient'] as Map? ?? {});
    final first = patient['firstName'] as String? ?? '';
    final last = patient['lastName'] as String? ?? '';
    List<String> lines(Object? value, [String key = 'lines']) {
      if (value is List) return value.map((item) => item.toString()).toList();
      if (value is Map && value[key] is List) {
        return (value[key] as List).map((item) => item.toString()).toList();
      }
      return const [];
    }

    return DoctorPacket(
      patientName: '$first $last'.trim(),
      age: patient['age'] is int ? patient['age'] as int : int.tryParse('${patient['age'] ?? ''}'),
      gender: patient['gender'] as String? ?? '',
      bloodGroup: patient['bloodGroup'] as String? ?? '',
      conditions: lines(json['conditions']),
      medicines: ((json['medicines'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => (item['line'] ?? item['detailLine'] ?? '').toString())
          .where((line) => line.isNotEmpty)
          .toList(),
      labHighlights: lines(json['labHighlights']),
      bloodPressure: lines(json['bloodPressure']),
      growth: lines(json['growth']),
      vaccinations: lines(json['vaccinations']),
      visitNotes: lines(json['visitNotes']),
    );
  }
}

class BloodPressureWeek {
  const BloodPressureWeek({required this.lines, required this.readings});
  final List<String> lines;
  final List<Map<String, dynamic>> readings;
  factory BloodPressureWeek.fromJson(Map<String, dynamic> json) {
    return BloodPressureWeek(
      lines: (json['lines'] as List?)?.map((item) => item.toString()).toList() ?? const [],
      readings: (json['readings'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const [],
    );
  }
}

class GrowthHistory {
  const GrowthHistory({required this.lines, required this.measurements, this.latestHeight, this.latestWeight});
  final List<String> lines;
  final List<Map<String, dynamic>> measurements;
  final num? latestHeight;
  final num? latestWeight;
  factory GrowthHistory.fromJson(Map<String, dynamic> json) {
    final latest = json['latest'] is Map ? Map<String, dynamic>.from(json['latest'] as Map) : const <String, dynamic>{};
    return GrowthHistory(
      lines: (json['lines'] as List?)?.map((item) => item.toString()).toList() ?? const [],
      measurements: (json['measurements'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const [],
      latestHeight: latest['heightCm'] as num?,
      latestWeight: latest['weightKg'] as num?,
    );
  }
}

class VaccinationList {
  const VaccinationList({required this.items, required this.upcoming});
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> upcoming;
  factory VaccinationList.fromJson(Map<String, dynamic> json) {
    return VaccinationList(
      items: (json['vaccinations'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const [],
      upcoming: (json['upcoming'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const [],
    );
  }
}

class VisitNoteList {
  const VisitNoteList({required this.notes, this.nextAppointment});
  final List<Map<String, dynamic>> notes;
  final String? nextAppointment;
  factory VisitNoteList.fromJson(Map<String, dynamic> json) {
    return VisitNoteList(
      notes: (json['notes'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const [],
      nextAppointment: json['nextAppointment'] as String?,
    );
  }
}

class HouseholdMember {
  const HouseholdMember({required this.userId, this.email, this.firstName, this.lastName});
  final String userId;
  final String? email;
  final String? firstName;
  final String? lastName;
  String get label => '${firstName ?? ''} ${lastName ?? ''}'.trim().isEmpty ? (email ?? userId) : '${firstName ?? ''} ${lastName ?? ''}'.trim();
  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    return HouseholdMember(
      userId: json['userId'] as String,
      email: json['email'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
    );
  }
}

class DocumentView {
  const DocumentView({required this.url, this.downloadUrl, this.fileName, this.fileType});
  final String url;
  final String? downloadUrl;
  final String? fileName;
  final String? fileType;
  factory DocumentView.fromJson(Map<String, dynamic> json) {
    return DocumentView(
      url: json['url'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String?,
      fileName: json['fileName'] as String?,
      fileType: json['fileType'] as String?,
    );
  }
}

class Category {
  const Category({required this.code, required this.displayName});
  final String code;
  final String displayName;
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      code: json['code'] as String? ?? json['displayName'] as String? ?? 'OTHER',
      displayName: json['displayName'] as String? ?? json['code'] as String? ?? 'Other',
    );
  }
}

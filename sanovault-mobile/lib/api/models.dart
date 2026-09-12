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

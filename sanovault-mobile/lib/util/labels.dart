const recordTypeLabels = <String, String>{
  'LAB_REPORT': 'Lab Report',
  'PRESCRIPTION': 'Prescription',
  'CONSULTATION_NOTE': 'Consultation Note',
  'IMAGING_REPORT': 'Imaging Report',
  'DISCHARGE_SUMMARY': 'Discharge Summary',
  'VACCINATION_RECORD': 'Vaccination Record',
  'VITAL_SIGNS': 'Vital Signs',
  'ID_DOCUMENT': 'ID Document',
  'OTHER': 'Other',
};

String humanizeLabel(String value) {
  final key = value.trim();
  if (key.isEmpty) return '';
  return recordTypeLabels[key] ??
      recordTypeLabels[key.toUpperCase()] ??
      key
          .replaceAll('_', ' ')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
          .join(' ');
}

String personName(String firstName, String? lastName) {
  return '$firstName ${lastName ?? ''}'.trim();
}

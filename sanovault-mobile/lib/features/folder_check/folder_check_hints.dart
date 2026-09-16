import 'package:sanovault/util/dates.dart';

class FolderHints {
  const FolderHints({this.documentDate, this.doctorName});
  final String? documentDate;
  final String? doctorName;
}

final _monthNumber = <String, int>{
  'jan': 1, 'january': 1,
  'feb': 2, 'february': 2,
  'mar': 3, 'march': 3,
  'apr': 4, 'april': 4,
  'may': 5,
  'jun': 6, 'june': 6,
  'jul': 7, 'july': 7,
  'aug': 8, 'august': 8,
  'sep': 9, 'sept': 9, 'september': 9,
  'oct': 10, 'october': 10,
  'nov': 11, 'november': 11,
  'dec': 12, 'december': 12,
};

FolderHints hintsFromFolderName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return const FolderHints();
  final doctor = RegExp(r'^(dr\.?|doctor)\s+\S', caseSensitive: false).hasMatch(trimmed);
  if (doctor) return FolderHints(doctorName: trimmed);

  final monthYear = RegExp(
    r'^(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{4})\b',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (monthYear != null) {
    final month = _monthNumber[monthYear.group(1)!.toLowerCase()];
    final year = int.tryParse(monthYear.group(2)!);
    if (month != null && year != null) {
      return FolderHints(documentDate: formatIsoDate(DateTime(year, month, 1)));
    }
  }

  final iso = RegExp(r'^(\d{4})[-/](\d{1,2})\b').firstMatch(trimmed);
  if (iso != null) {
    final year = int.tryParse(iso.group(1)!);
    final month = int.tryParse(iso.group(2)!);
    if (year != null && month != null && month >= 1 && month <= 12) {
      return FolderHints(documentDate: formatIsoDate(DateTime(year, month, 1)));
    }
  }
  return const FolderHints();
}

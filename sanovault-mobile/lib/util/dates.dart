const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _monthIndex = {
  'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
  'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
};

DateTime? parseApiDate(String? value) {
  if (value == null || value.isEmpty) return null;
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;
  final day = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(value);
  if (day != null) return DateTime.tryParse(day.group(1)!);
  final js = RegExp(r'^[A-Za-z]{3} ([A-Za-z]{3}) (\d{1,2}) (\d{4})').firstMatch(value);
  if (js != null) {
    final month = _monthIndex[js.group(1)!];
    final date = int.tryParse(js.group(2)!);
    final year = int.tryParse(js.group(3)!);
    if (month != null && date != null && year != null) {
      return DateTime(year, month, date);
    }
  }
  return null;
}

String formatDisplayDate(String? value) {
  final parsed = parseApiDate(value);
  if (parsed == null) return value ?? '';
  return '${parsed.day} ${_months[parsed.month - 1]} ${parsed.year}';
}

String formatIsoDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

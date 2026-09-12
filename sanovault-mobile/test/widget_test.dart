import 'package:flutter_test/flutter_test.dart';
import 'package:sanovault/util/labels.dart';

void main() {
  test('humanizeLabel maps known record types', () {
    expect(humanizeLabel('LAB_REPORT'), 'Lab Report');
  });
}

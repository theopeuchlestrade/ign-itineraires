import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blocking CI audits both Dart and npm lockfiles', () {
    final ci = File('.github/workflows/ci.yml').readAsStringSync();
    final scheduledAudit = File(
      '.github/workflows/osv-scanner.yml',
    ).readAsStringSync();

    for (final workflow in [ci, scheduledAudit]) {
      expect(workflow, contains('--lockfile=pubspec.lock'));
      expect(workflow, contains('--lockfile=package-lock.json'));
    }
    expect(ci, contains('dependency-audit:'));
    expect(ci, contains('dependency-review:'));
    expect(
      RegExp(
        r'needs:[\s\S]*- dependency-audit[\s\S]*- dependency-review',
      ).hasMatch(ci),
      isTrue,
    );
  });

  test('golden tests use the exact Flutter comparator', () {
    final source = File('test/app_responsive_test.dart').readAsStringSync();

    expect(source, isNot(contains('diffPercent')));
    expect(source, isNot(contains('TolerantGoldenComparator')));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android requests foreground location only', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
    expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
  });

  test('iOS requests when-in-use location only', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('NSLocationWhenInUseUsageDescription'));
    expect(plist, isNot(contains('NSLocationAlwaysUsageDescription')));
    expect(
      plist,
      isNot(contains('NSLocationAlwaysAndWhenInUseUsageDescription')),
    );
  });
}

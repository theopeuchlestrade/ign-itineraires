import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() {
  return integrationDriver(
    onScreenshot: (name, bytes, [arguments]) async {
      final directory = Directory('build/test-screenshots');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes, flush: true);
      return true;
    },
  );
}

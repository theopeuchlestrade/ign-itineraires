import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';

void main(List<String> arguments) {
  if (arguments.isNotEmpty) {
    stderr.writeln('Usage: dart run tool/prepare_web_release.dart');
    exitCode = 2;
    return;
  }

  var flutterRoot = File(Platform.resolvedExecutable).parent;
  for (var level = 0; level < 4; level++) {
    flutterRoot = flutterRoot.parent;
  }
  final buildDirectory = Directory('build/web');
  final bootstrap = File('${buildDirectory.path}/flutter_bootstrap.js');
  final sourceFont = File(
    '${flutterRoot.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  );
  final sourceLicense = File(
    '${flutterRoot.path}/bin/cache/artifacts/material_fonts/Roboto_LICENSE.txt',
  );
  if (!bootstrap.existsSync() ||
      !sourceFont.existsSync() ||
      !sourceLicense.existsSync()) {
    stderr.writeln('Flutter web build or fallback font assets are missing.');
    exitCode = 2;
    return;
  }

  final fallbackDirectory = Directory(
    '${buildDirectory.path}/font-fallback/roboto/v32',
  )..createSync(recursive: true);
  sourceFont.copySync(
    '${fallbackDirectory.path}/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2',
  );
  final licenseDirectory = Directory('${buildDirectory.path}/font-fallback')
    ..createSync(recursive: true);
  sourceLicense.copySync('${licenseDirectory.path}/Roboto_LICENSE.txt');

  final contents = bootstrap.readAsStringSync();
  const loader = '_flutter.loader.load({';
  const localFallback =
      "_flutter.loader.load({\n  config: { fontFallbackBaseUrl: 'font-fallback/' },";
  if (!contents.contains('fontFallbackBaseUrl')) {
    if (!contents.contains(loader)) {
      stderr.writeln('Unexpected Flutter bootstrap format.');
      exitCode = 2;
      return;
    }
    bootstrap.writeAsStringSync(contents.replaceFirst(loader, localFallback));
  }

  // Pages has fixed cache headers. Give the executable files immutable names
  // and discover them through a manifest fetched without the HTTP cache.
  final entrypoint = File('${buildDirectory.path}/main.dart.js');
  final entrypointName =
      'main.${sha256.convert(entrypoint.readAsBytesSync())}.dart.js';
  entrypoint.copySync('${buildDirectory.path}/$entrypointName');
  final versionedBootstrap = bootstrap.readAsStringSync().replaceAll(
    '"mainJsPath":"main.dart.js"',
    '"mainJsPath":"$entrypointName"',
  );
  if (!versionedBootstrap.contains('"mainJsPath":"$entrypointName"')) {
    stderr.writeln('Unexpected Flutter entrypoint configuration.');
    exitCode = 2;
    return;
  }
  bootstrap.writeAsStringSync(versionedBootstrap);
  final bootstrapName =
      'flutter_bootstrap.${sha256.convert(utf8.encode(versionedBootstrap))}.js';
  bootstrap.copySync('${buildDirectory.path}/$bootstrapName');
  File('${buildDirectory.path}/release.json')
      .writeAsStringSync(jsonEncode({'bootstrap': bootstrapName}));
  File('web/retire_service_worker.js')
      .copySync('${buildDirectory.path}/flutter_service_worker.js');
}

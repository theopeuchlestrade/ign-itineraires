import 'dart:io';

const minimumCoverage = 90.0;

void main(List<String> arguments) {
  final file = File(arguments.isEmpty ? 'coverage/lcov.info' : arguments.first);
  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: ${file.path}');
    exitCode = 2;
    return;
  }

  final tracked = <String, Map<int, int>>{};
  String? currentFile;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      final path = line.substring(3).replaceAll('\\', '/');
      currentFile = _isCoreFile(path) ? path : null;
    } else if (currentFile != null && line.startsWith('DA:')) {
      final values = line.substring(3).split(',');
      final lineNumber = int.parse(values[0]);
      final hits = int.parse(values[1]);
      tracked.putIfAbsent(currentFile, () => {})[lineNumber] = hits;
    }
  }

  final lines = tracked.values.expand((entries) => entries.values).toList();
  if (lines.isEmpty) {
    stderr.writeln('No core routing files found in coverage report.');
    exitCode = 2;
    return;
  }
  final covered = lines.where((hits) => hits > 0).length;
  final percentage = covered * 100 / lines.length;
  stdout.writeln(
    'Core routing coverage: ${percentage.toStringAsFixed(1)}% '
    '($covered/${lines.length} lines, minimum ${minimumCoverage.toInt()}%)',
  );
  if (percentage < minimumCoverage) exitCode = 1;
}

bool _isCoreFile(String path) {
  return path.contains('lib/src/features/routing/domain/') ||
      path.endsWith('lib/src/features/routing/data/geoplateforme_api.dart') ||
      (path.contains('lib/src/features/routing/presentation/') &&
          path.endsWith('_controller.dart'));
}

// Removes iOS/macOS plugin entries from pdfium_flutter so Darwin builds do
// not embed PDFium.framework (upstream ships no matching dSYM).
// Re-run after every `flutter pub get`.
//
// Usage: dart run tool/remove_darwin_pdfium.dart
//        dart run tool/remove_darwin_pdfium.dart --revert

import 'dart:io';

import 'package:path/path.dart' as p;

const _markerStart = '# sanovault: darwin PDFium removed — do not edit by hand';
const _markerEnd = '# sanovault: end darwin PDFium removal';

const _darwinPluginBlock = '''
flutter:
  plugin:
    platforms:
      ios:
        pluginClass: PDFiumFlutterPlugin
        ffiPlugin: true
        sharedDarwinSource: true
      macos:
        pluginClass: PDFiumFlutterPlugin
        ffiPlugin: true
        sharedDarwinSource: true
''';

Future<void> main(List<String> args) async {
  final revert = args.contains('--revert') || args.contains('-r');
  final packageConfig = File('.dart_tool/package_config.json');
  if (!packageConfig.existsSync()) {
    stderr.writeln('Run flutter pub get first.');
    exit(3);
  }

  final configJson = packageConfig.readAsStringSync();
  final packagesMatch = RegExp(
    r'"name":\s*"pdfium_flutter"[^}]*"rootUri":\s*"([^"]+)"',
  ).firstMatch(configJson);
  if (packagesMatch == null) {
    stderr.writeln('pdfium_flutter not found in package_config.json');
    exit(3);
  }

  final rootUri = Uri.parse(packagesMatch.group(1)!);
  final packageConfigDir = p.dirname(packageConfig.absolute.path);
  final packageRoot = rootUri.isAbsolute
      ? rootUri.toFilePath()
      : p.normalize(p.join(packageConfigDir, rootUri.path));
  final pubspecFile = File(p.join(packageRoot, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    stderr.writeln('Missing ${pubspecFile.path}');
    exit(3);
  }

  var original = pubspecFile.readAsStringSync().replaceAll('\r\n', '\n');
  // Normalize prior partial strips before applying/reverting.
  original = _cleanupOrphanComments(original);

  final updated = revert ? _restore(original) : _strip(original);
  if (updated == original) {
    stdout.writeln(
      'No changes needed (${revert ? "already present" : "already removed"}).',
    );
    return;
  }
  pubspecFile.writeAsStringSync(updated);
  stdout.writeln(
    '${revert ? "Restored" : "Removed"} Darwin PDFium plugins in ${pubspecFile.path}',
  );
}

String _cleanupOrphanComments(String yaml) {
  // Drop leftover commented platform lines after a partial strip.
  return yaml.replaceAll(
    RegExp(
      r'(?:^# [ \t]*(?:ios|macos):\n(?:^# [ \t]+[^\n]*\n)*)+',
      multiLine: true,
    ),
    '',
  );
}

String _strip(String yaml) {
  if (yaml.contains(_markerStart) && !yaml.contains('flutter:\n  plugin:')) {
    return yaml;
  }

  final flutterPlugin = RegExp(
    r'\nflutter:\n'
    r'  plugin:\n'
    r'    platforms:\n'
    r'(?:[ \t#]*(?:ios|macos):\n(?:[ \t#]+[^\n]*\n)*)*',
  );

  if (!flutterPlugin.hasMatch(yaml)) {
    stderr.writeln('Could not find flutter.plugin.platforms block to strip.');
    exit(4);
  }

  return yaml.replaceFirstMapped(flutterPlugin, (_) {
    return '\n$_markerStart\n'
        '# (pdfium_flutter Darwin ffiPlugin block removed)\n'
        '$_markerEnd\n';
  });
}

String _restore(String yaml) {
  if (yaml.contains(_markerStart) && yaml.contains(_markerEnd)) {
    final block = RegExp(
      '$_markerStart\\n.*?$_markerEnd\\n',
      dotAll: true,
    );
    return yaml.replaceFirst(block, '\n$_darwinPluginBlock');
  }
  return yaml;
}

// Current Xcode PDFKit makes PDFDocument() / PDFPage() non-optional.
// pdfrx_coregraphics 0.4.0 still uses `guard let`, which fails the macOS build.
// Re-run after every `flutter pub get`.
//
// Usage: dart run tool/patch_pdfrx_coregraphics_sdk.dart

import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main() async {
  final packageConfig = File('.dart_tool/package_config.json');
  if (!packageConfig.existsSync()) {
    stderr.writeln('Run flutter pub get first.');
    exit(3);
  }

  final configJson = packageConfig.readAsStringSync();
  final packagesMatch = RegExp(
    r'"name":\s*"pdfrx_coregraphics"[^}]*"rootUri":\s*"([^"]+)"',
  ).firstMatch(configJson);
  if (packagesMatch == null) {
    stderr.writeln('pdfrx_coregraphics not found in package_config.json');
    exit(3);
  }

  final rootUri = Uri.parse(packagesMatch.group(1)!);
  final packageConfigDir = p.dirname(packageConfig.absolute.path);
  final packageRoot = rootUri.isAbsolute
      ? rootUri.toFilePath()
      : p.normalize(p.join(packageConfigDir, rootUri.path));
  final source = File(
    p.join(
      packageRoot,
      'darwin/pdfrx_coregraphics/Sources/PdfrxCoregraphicsPlugin.swift',
    ),
  );
  if (!source.existsSync()) {
    stderr.writeln('Missing ${source.path}');
    exit(3);
  }

  final original = source.readAsStringSync();
  var updated = original;
  updated = updated.replaceAll(
    '    guard let pdfDocument = PDFDocument() else {\n'
    '      result(\n'
    '        FlutterError(\n'
    '          code: "pdf-document-failure", message: "Failed to create empty PDFDocument.", details: nil\n'
    '        ))\n'
    '      return\n'
    '    }\n',
    '    let pdfDocument = PDFDocument()\n',
  );
  updated = updated.replaceAll(
    '    guard let pdfDocument = PDFDocument() else {\n'
    '      result(\n'
    '        FlutterError(\n'
    '          code: "pdf-document-failure", message: "Failed to create PDFDocument.", details: nil\n'
    '        ))\n'
    '      return\n'
    '    }\n',
    '    let pdfDocument = PDFDocument()\n',
  );
  updated = updated.replaceAll(
    '    guard let pdfPage = PDFPage() else {\n'
    '      result(\n'
    '        FlutterError(\n'
    '          code: "pdf-page-failure", message: "Failed to create PDF page.", details: nil\n'
    '        ))\n'
    '      return\n'
    '    }\n',
    '    let pdfPage = PDFPage()\n',
  );

  if (updated == original) {
    stdout.writeln('No changes needed (${source.path}).');
    return;
  }
  source.writeAsStringSync(updated);
  stdout.writeln('Patched PDFKit initializers in ${source.path}');
}

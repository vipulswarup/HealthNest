import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/api_exception.dart';
import 'package:sanovault/api/sanovault_api.dart';

Future<String?> askPdfPassword(BuildContext context, {String? fileName}) async {
  final controller = TextEditingController();
  final entered = await showCupertinoDialog<String>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('PDF password'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fileName != null && fileName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(fileName, style: const TextStyle(fontSize: 13)),
              ),
            CupertinoTextField(
              controller: controller,
              placeholder: 'Password from the lab PDF',
              obscureText: true,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Unlock'),
        ),
      ],
    ),
  );
  controller.dispose();
  final password = entered?.trim();
  if (password == null || password.isEmpty) return null;
  return password;
}

Future<List<String>> savedPdfPasswords(SanoVaultApi api, String? patientId) async {
  if (patientId == null || patientId.isEmpty) return const [];
  try {
    return (await api.filePasswords(patientId))
        .map((row) => row.password.trim())
        .where((password) => password.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<void> rememberPdfPassword(SanoVaultApi api, String? patientId, String password) async {
  final trimmed = password.trim();
  if (patientId == null || patientId.isEmpty || trimmed.isEmpty) return;
  try {
    await api.addFilePassword(patientId, trimmed);
  } catch (_) {}
}

Future<String> ocrWithPasswordPrompt({
  required BuildContext context,
  required SanoVaultApi api,
  required String documentId,
  String? patientId,
  String mode = 'intake',
}) async {
  final extras = await savedPdfPasswords(api, patientId);
  try {
    return await api.ocrDocument(
      documentId,
      mode: mode,
      extraPasswords: extras.isEmpty ? null : extras,
    );
  } on ApiException catch (caught) {
    if (caught.code != 'PDF_PASSWORD_REQUIRED' || patientId == null) rethrow;
  }

  while (context.mounted) {
    final password = await askPdfPassword(context);
    if (password == null) {
      throw const ApiException('This PDF needs a password.', statusCode: 409, code: 'PDF_PASSWORD_REQUIRED');
    }
    try {
      final text = await api.ocrDocument(documentId, mode: mode, extraPasswords: [password, ...extras]);
      await rememberPdfPassword(api, patientId, password);
      return text;
    } on ApiException catch (caught) {
      if (caught.code != 'PDF_PASSWORD_REQUIRED') rethrow;
    }
  }
  throw const ApiException('This PDF needs a password.', statusCode: 409, code: 'PDF_PASSWORD_REQUIRED');
}

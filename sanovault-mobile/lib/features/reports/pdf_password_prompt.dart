import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/api_exception.dart';
import 'package:sanovault/api/sanovault_api.dart';

Future<String?> askPdfPassword(BuildContext context) async {
  final controller = TextEditingController();
  final entered = await showCupertinoDialog<String>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('PDF password'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          placeholder: 'Password from the lab PDF',
          obscureText: true,
          autofocus: true,
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

Future<String> ocrWithPasswordPrompt({
  required BuildContext context,
  required SanoVaultApi api,
  required String documentId,
  String? patientId,
  String mode = 'intake',
}) async {
  try {
    return await api.ocrDocument(documentId, mode: mode);
  } on ApiException catch (caught) {
    if (caught.code != 'PDF_PASSWORD_REQUIRED' || patientId == null) rethrow;
  }

  while (context.mounted) {
    final password = await askPdfPassword(context);
    if (password == null) {
      throw const ApiException('This PDF needs a password.', statusCode: 409, code: 'PDF_PASSWORD_REQUIRED');
    }
    try {
      return await api.ocrDocument(documentId, mode: mode, extraPasswords: [password]);
    } on ApiException catch (caught) {
      if (caught.code != 'PDF_PASSWORD_REQUIRED') rethrow;
    }
  }
  throw const ApiException('This PDF needs a password.', statusCode: 409, code: 'PDF_PASSWORD_REQUIRED');
}

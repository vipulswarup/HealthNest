import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdfrx_coregraphics/pdfrx_coregraphics.dart';
import 'package:sanovault/api/api_client.dart';
import 'package:sanovault/api/sanovault_api.dart';
import 'package:sanovault/app.dart';
import 'package:sanovault/session/session_controller.dart';
import 'package:sanovault/session/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
    // Use Apple PDFKit instead of PDFium on Darwin so App Store archives
    // do not ship PDFium.framework without a matching dSYM.
    PdfrxEntryFunctions.instance = PdfrxCoreGraphicsEntryFunctions();
  }
  pdfrxFlutterInitialize();
  final store = SessionStore();
  final api = SanoVaultApi(ApiClient(readToken: store.readToken));
  final session = SessionController(api: api, store: store);
  await session.restore();
  runApp(SanoVaultApp(session: session));
}

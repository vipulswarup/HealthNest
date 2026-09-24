import 'dart:io';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdfrx_coregraphics/pdfrx_coregraphics.dart';
import 'package:sanovault/api/api_client.dart';
import 'package:sanovault/api/sanovault_api.dart';
import 'package:sanovault/app.dart';
import 'package:sanovault/session/session_controller.dart';
import 'package:sanovault/session/session_store.dart';
import 'package:sanovault/session/offline_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
    // Use Apple PDFKit instead of PDFium on Darwin so App Store archives
    // do not ship PDFium.framework without a matching dSYM.
    PdfrxEntryFunctions.instance = PdfrxCoreGraphicsEntryFunctions();
  }
  pdfrxFlutterInitialize();
  final store = SessionStore();
  final offline = OfflineStore();
  final api = SanoVaultApi(
    ApiClient(readToken: store.readToken),
    offlineStore: offline,
  );
  final session = SessionController(api: api, store: store, offline: offline);
  runApp(SanoVaultApp(session: session));
  // Render the shell immediately. Session restore can use the offline cache,
  // and the first frame no longer waits on a hospital's network connection.
  unawaited(session.restore());
}

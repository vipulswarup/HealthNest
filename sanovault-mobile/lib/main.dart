import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/api_client.dart';
import 'package:sanovault/api/sanovault_api.dart';
import 'package:sanovault/app.dart';
import 'package:sanovault/session/session_controller.dart';
import 'package:sanovault/session/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SessionStore();
  final api = SanoVaultApi(ApiClient(readToken: store.readToken));
  final session = SessionController(api: api, store: store);
  await session.restore();
  runApp(SanoVaultApp(session: session));
}

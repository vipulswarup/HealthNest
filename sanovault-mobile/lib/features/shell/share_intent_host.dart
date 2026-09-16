import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:sanovault/features/reports/share_import_page.dart';
import 'package:sanovault/session/session_controller.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:share_handler/share_handler.dart';

/// Listens for system share-sheet payloads on iOS/Android and opens import UI.
class ShareIntentHost extends StatefulWidget {
  const ShareIntentHost({super.key, required this.child, required this.navigatorKey});

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<ShareIntentHost> createState() => _ShareIntentHostState();
}

class _ShareIntentHostState extends State<ShareIntentHost> {
  StreamSubscription<SharedMedia>? _sub;
  SharedMedia? _pending;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      _initShareHandler();
    }
  }

  Future<void> _initShareHandler() async {
    final handler = ShareHandler.instance;
    final initial = await handler.getInitialSharedMedia();
    if (initial != null) _queue(initial);
    _sub = handler.sharedMediaStream.listen(_queue);
  }

  void _queue(SharedMedia media) {
    _pending = media;
    _tryOpen();
  }

  void _tryOpen() {
    if (!mounted || _opening || _pending == null) return;
    final session = SessionScope.of(context);
    if (session.status != SessionStatus.ready) return;

    final media = _pending!;
    _pending = null;
    final files = <SharedImportFile>[];
    for (final attachment in media.attachments ?? const <SharedAttachment?>[]) {
      if (attachment == null || attachment.path.isEmpty) continue;
      files.add(SharedImportFile(path: attachment.path, name: sharedFileName(attachment.path)));
    }
    if (files.isEmpty) return;

    _opening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final nav = widget.navigatorKey.currentState;
      if (nav != null) {
        await nav.push<void>(
          CupertinoPageRoute<void>(builder: (_) => ShareImportPage(files: files)),
        );
        try {
          await ShareHandler.instance.resetInitialSharedMedia();
        } catch (_) {}
      }
      _opening = false;
      if (_pending != null) _tryOpen();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionScope.of(context),
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryOpen());
        return widget.child;
      },
    );
  }
}

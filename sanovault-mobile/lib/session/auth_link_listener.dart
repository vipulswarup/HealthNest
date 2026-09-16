import 'dart:async';

import 'package:flutter/services.dart';

/// Receives custom-scheme opens forwarded from macOS AppDelegate.
class AuthLinkListener {
  AuthLinkListener._();

  static const _channel = MethodChannel('sanovault/links');
  static final _controller = StreamController<Uri>.broadcast();
  static bool _bound = false;

  static Stream<Uri> get stream {
    _ensureBound();
    return _controller.stream;
  }

  static Future<Uri> waitForScheme(String scheme, {Duration timeout = const Duration(minutes: 5)}) {
    _ensureBound();
    return stream.firstWhere((uri) => uri.scheme == scheme).timeout(timeout);
  }

  static Future<void> openSafari(String url) async {
    _ensureBound();
    await _channel.invokeMethod<void>('openSafari', url);
  }

  static void _ensureBound() {
    if (_bound) return;
    _bound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onOpenUrl') return null;
      final raw = call.arguments;
      if (raw is! String || raw.isEmpty) return null;
      final uri = Uri.tryParse(raw);
      if (uri != null) _controller.add(uri);
      return null;
    });
  }
}

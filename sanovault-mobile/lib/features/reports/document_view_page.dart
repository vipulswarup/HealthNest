import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/api_config.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentViewPage extends StatefulWidget {
  const DocumentViewPage({super.key, required this.documentId, required this.title});
  final String documentId;
  final String title;

  @override
  State<DocumentViewPage> createState() => _DocumentViewPageState();
}

class _DocumentViewPageState extends State<DocumentViewPage> {
  Uint8List? _bytes;
  String? _networkUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = SessionScope.of(context).api;
    try {
      final view = await api.documentView(widget.documentId);
      final type = (view.fileType ?? '').toLowerCase();
      final isImage = type.contains('jpeg') || type.contains('jpg') || type.contains('png') || type.contains('webp') || type.contains('gif');
      if (view.url.startsWith('/api/')) {
        final bytes = await api.documentPreview(widget.documentId);
        if (!mounted) return;
        setState(() => _bytes = Uint8List.fromList(bytes));
        return;
      }
      if (isImage) {
        if (!mounted) return;
        setState(() => _networkUrl = view.url);
        return;
      }
      final open = view.downloadUrl ?? view.url;
      final absolute = open.startsWith('http') ? open : '$apiBaseUrl$open';
      await launchUrl(Uri.parse(absolute), mode: LaunchMode.externalApplication);
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_error != null) {
      body = Center(child: Text(_error!, style: const TextStyle(color: SvColors.danger)));
    } else if (_bytes != null) {
      body = InteractiveViewer(child: Image.memory(_bytes!));
    } else if (_networkUrl != null) {
      body = InteractiveViewer(child: Image.network(_networkUrl!));
    } else {
      body = const Center(child: CupertinoActivityIndicator());
    }
    return CupertinoPageScaffold(
      backgroundColor: SvColors.groupedBackground,
      navigationBar: CupertinoNavigationBar(middle: Text(widget.title)),
      child: SafeArea(child: body),
    );
  }
}

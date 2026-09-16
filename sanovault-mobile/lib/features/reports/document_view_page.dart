import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';

class DocumentViewPage extends StatefulWidget {
  const DocumentViewPage({super.key, required this.documentId, required this.title});
  final String documentId;
  final String title;

  @override
  State<DocumentViewPage> createState() => _DocumentViewPageState();
}

class _DocumentViewPageState extends State<DocumentViewPage> {
  Uint8List? _imageBytes;
  Uint8List? _pdfBytes;
  String? _networkUrl;
  String? _fileName;
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
      final name = (view.fileName ?? '').toLowerCase();
      final isImage = type.contains('jpeg') ||
          type.contains('jpg') ||
          type.contains('png') ||
          type.contains('webp') ||
          type.contains('gif') ||
          type.contains('bmp');
      final isPdf = type.contains('pdf') || name.endsWith('.pdf');

      if (view.url.startsWith('/api/')) {
        final bytes = await api.documentPreview(widget.documentId);
        if (!mounted) return;
        setState(() {
          _imageBytes = Uint8List.fromList(bytes);
          _fileName = view.fileName;
        });
        return;
      }

      if (isImage) {
        if (!mounted) return;
        setState(() {
          _networkUrl = view.url;
          _fileName = view.fileName;
        });
        return;
      }

      if (isPdf) {
        final bytes = await api.documentFile(widget.documentId);
        if (!mounted) return;
        setState(() {
          _pdfBytes = Uint8List.fromList(bytes);
          _fileName = view.fileName;
        });
        return;
      }

      // Unknown type: still try authenticated file bytes as PDF when possible.
      final bytes = await api.documentFile(widget.documentId);
      if (!mounted) return;
      if (bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-') {
        setState(() {
          _pdfBytes = Uint8List.fromList(bytes);
          _fileName = view.fileName;
        });
        return;
      }
      setState(() => _error = 'This file type cannot be previewed in the app yet.');
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = caught.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: SvColors.danger)),
        ),
      );
    } else if (_pdfBytes != null) {
      body = PdfViewer.data(
        _pdfBytes!,
        sourceName: _fileName ?? widget.documentId,
      );
    } else if (_imageBytes != null) {
      body = InteractiveViewer(child: Image.memory(_imageBytes!));
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

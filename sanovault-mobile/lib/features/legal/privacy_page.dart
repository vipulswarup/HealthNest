import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:sanovault/api/api_config.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  Map<String, dynamic>? _policy;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/api/privacy'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw Exception('Unavailable');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (mounted)
        setState(() {
          _policy = data;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Connect to read the current privacy policy. You can also visit www.sanovault.com/privacy or contact support@eisenvault.com.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(middle: Text('Privacy policy')),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null) ...[
            Text(_error!),
            CupertinoButton(onPressed: _load, child: const Text('Try again')),
          ] else if (_policy == null)
            const CupertinoActivityIndicator()
          else ...[
            Text(
              _policy!['title'] as String,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Updated ${_policy!['updated']}'),
            for (final section in _policy!['sections'] as List) ...[
              const SizedBox(height: 24),
              Text(
                section['title'] as String,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                section['text'] as String,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

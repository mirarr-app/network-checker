import 'dart:convert';

import 'package:http/http.dart' as http;

const _releasesUrl =
    'https://api.github.com/repos/mirarr-app/network-checker/releases/latest';

const _releasesPageUrl = 'https://github.com/mirarr-app/network-checker/releases';

/// Fetches the latest release tag from GitHub and compares with [currentVersion].
/// Returns the latest version string if it's newer, null otherwise.
Future<String?> checkForUpdate(String currentVersion) async {
  try {
    final response = await http.get(Uri.parse(_releasesUrl)).timeout(
      const Duration(seconds: 10),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String?;
      if (tagName != null && tagName.isNotEmpty) {
        final latest = _normalizeVersion(tagName);
        final current = _normalizeVersion(currentVersion);
        if (_isNewer(latest, current)) {
          return tagName.startsWith('v') ? tagName.substring(1) : tagName;
        }
      }
    }
  } catch (_) {
    // Ignore network/parse errors
  }
  return null;
}

String get releasesPageUrl => _releasesPageUrl;

/// Normalize "v0.2.0" or "0.2.0" to [major, minor, patch] list.
List<int> _normalizeVersion(String version) {
  final s = version.trim().toLowerCase().replaceFirst(RegExp(r'^v'), '');
  final parts = s.split(RegExp(r'[.+\-]'));
  return parts.take(3).map((p) => int.tryParse(p) ?? 0).toList();
}

/// Returns true if [a] is newer than [b].
bool _isNewer(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    final va = i < a.length ? a[i] : 0;
    final vb = i < b.length ? b[i] : 0;
    if (va > vb) return true;
    if (va < vb) return false;
  }
  return false;
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/services/proxy_parser_service.dart';

class ChainController extends ChangeNotifier {
  // Links for each hop (hop 0 = Entry, hop 1 = Exit, or multi-hop)
  List<String> _hopLinks = ['', ''];
  int _socksPort = 10808;
  int _httpPort = 10809;

  String? _generatedJson;
  String? _errorMessage;
  bool _isGenerating = false;

  List<String> get hopLinks => List.unmodifiable(_hopLinks);
  int get socksPort => _socksPort;
  int get httpPort => _httpPort;
  String? get generatedJson => _generatedJson;
  String? get errorMessage => _errorMessage;
  bool get isGenerating => _isGenerating;

  /// Update the link for a specific hop index
  void setHopLink(int index, String value) {
    if (index >= 0 && index < _hopLinks.length) {
      _hopLinks[index] = value.trim();
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Add an intermediate hop
  void addHopLink() {
    _hopLinks.add('');
    _errorMessage = null;
    notifyListeners();
  }

  /// Remove a hop link if there are more than 2 hops
  void removeHopLink(int index) {
    if (_hopLinks.length > 2 && index >= 0 && index < _hopLinks.length) {
      _hopLinks.removeAt(index);
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Swap two hop links (e.g. Entry and Exit)
  void swapHops(int indexA, int indexB) {
    if (indexA >= 0 && indexA < _hopLinks.length && indexB >= 0 && indexB < _hopLinks.length) {
      final temp = _hopLinks[indexA];
      _hopLinks[indexA] = _hopLinks[indexB];
      _hopLinks[indexB] = temp;
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Set the SOCKS inbound port
  void setSocksPort(int port) {
    _socksPort = port;
    notifyListeners();
  }

  /// Set the HTTP inbound port
  void setHttpPort(int port) {
    _httpPort = port;
    notifyListeners();
  }

  /// Clear inputs and output
  void clear() {
    _hopLinks = ['', ''];
    _generatedJson = null;
    _errorMessage = null;
    _isGenerating = false;
    notifyListeners();
  }

  /// Generate the chained Xray JSON config
  Future<void> generateChain() async {
    final validLinks = _hopLinks.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (validLinks.length < 2) {
      _errorMessage = 'Please provide at least 2 valid proxy links or Xray JSON configs (Entry and Exit).';
      _generatedJson = null;
      notifyListeners();
      return;
    }

    _isGenerating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = ProxyParserService.generateChainProfile(
        nodeShareLinks: validLinks,
        socksPort: _socksPort,
        httpPort: _httpPort,
      );

      const encoder = JsonEncoder.withIndent('  ');
      _generatedJson = encoder.convert(profile);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('FormatException: ', '');
      _generatedJson = null;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }
}

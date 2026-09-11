import 'package:flutter/foundation.dart';
import '../../../core/services/cloudflare_fix_service.dart';

class CloudflareFixController extends ChangeNotifier {
  String _inputText = '';
  String get inputText => _inputText;

  int _socksPort = 10808;
  int get socksPort => _socksPort;

  int _httpPort = 10809;
  int get httpPort => _httpPort;

  String _dnsServer = CloudflareFixService.defaultDnsServer;
  String get dnsServer => _dnsServer;

  String _remarkSuffix = '-custom';
  String get remarkSuffix => _remarkSuffix;

  // TLS Options
  String _fingerprint = 'unsafe';
  String get fingerprint => _fingerprint;

  String _alpnText = 'http/1.1';
  String get alpnText => _alpnText;

  String _cipherSuites = CloudflareFixService.defaultCipherSuites;
  String get cipherSuites => _cipherSuites;

  // Finalmask TCP Fragmentation Options
  bool _enableFinalmask = true;
  bool get enableFinalmask => _enableFinalmask;

  String _frag1Packets = 'tlshello';
  String get frag1Packets => _frag1Packets;

  String _frag1Lengths = '0,104,1';
  String get frag1Lengths => _frag1Lengths;

  String _frag1Delays = '0';
  String get frag1Delays => _frag1Delays;

  String _frag1MaxSplit = '0';
  String get frag1MaxSplit => _frag1MaxSplit;

  String _frag2Packets = '1-1';
  String get frag2Packets => _frag2Packets;

  String _frag2Lengths = '114,1';
  String get frag2Lengths => _frag2Lengths;

  String _frag2Delays = '1';
  String get frag2Delays => _frag2Delays;

  String _frag2MaxSplit = '11';
  String get frag2MaxSplit => _frag2MaxSplit;

  List<CloudflareFixResult> _results = [];
  List<CloudflareFixResult> get results => _results;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  void setInputText(String value) {
    _inputText = value;
    _errorMessage = null;
    notifyListeners();
  }

  void setSocksPort(int value) {
    _socksPort = value;
    notifyListeners();
  }

  void setHttpPort(int value) {
    _httpPort = value;
    notifyListeners();
  }

  void setDnsServer(String value) {
    _dnsServer = value;
    notifyListeners();
  }

  void setRemarkSuffix(String value) {
    _remarkSuffix = value;
    notifyListeners();
  }

  void setFingerprint(String value) {
    _fingerprint = value;
    notifyListeners();
  }

  void setAlpnText(String value) {
    _alpnText = value;
    notifyListeners();
  }

  void setCipherSuites(String value) {
    _cipherSuites = value;
    notifyListeners();
  }

  void setEnableFinalmask(bool value) {
    _enableFinalmask = value;
    notifyListeners();
  }

  void setFrag1Packets(String value) {
    _frag1Packets = value;
    notifyListeners();
  }

  void setFrag1Lengths(String value) {
    _frag1Lengths = value;
    notifyListeners();
  }

  void setFrag1Delays(String value) {
    _frag1Delays = value;
    notifyListeners();
  }

  void setFrag1MaxSplit(String value) {
    _frag1MaxSplit = value;
    notifyListeners();
  }

  void setFrag2Packets(String value) {
    _frag2Packets = value;
    notifyListeners();
  }

  void setFrag2Lengths(String value) {
    _frag2Lengths = value;
    notifyListeners();
  }

  void setFrag2Delays(String value) {
    _frag2Delays = value;
    notifyListeners();
  }

  void setFrag2MaxSplit(String value) {
    _frag2MaxSplit = value;
    notifyListeners();
  }

  void resetCipherSuites() {
    _cipherSuites = CloudflareFixService.defaultCipherSuites;
    notifyListeners();
  }

  void resetToDefaults() {
    _socksPort = 10808;
    _httpPort = 10809;
    _dnsServer = CloudflareFixService.defaultDnsServer;
    _remarkSuffix = '-custom';
    _fingerprint = 'unsafe';
    _alpnText = 'http/1.1';
    _cipherSuites = CloudflareFixService.defaultCipherSuites;
    _enableFinalmask = true;
    _frag1Packets = 'tlshello';
    _frag1Lengths = '0,104,1';
    _frag1Delays = '0';
    _frag1MaxSplit = '0';
    _frag2Packets = '1-1';
    _frag2Lengths = '114,1';
    _frag2Delays = '1';
    _frag2MaxSplit = '11';
    notifyListeners();
  }

  List<String> _parseCsvList(String text) {
    return text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void transform() {
    final trimmed = _inputText.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Please enter or paste a VLESS link.';
      _results = [];
      notifyListeners();
      return;
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final lines = trimmed
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final newResults = <CloudflareFixResult>[];
      final alpnList = _parseCsvList(_alpnText);
      final f1Lengths = _parseCsvList(_frag1Lengths);
      final f1Delays = _parseCsvList(_frag1Delays);
      final f2Lengths = _parseCsvList(_frag2Lengths);
      final f2Delays = _parseCsvList(_frag2Delays);

      for (final link in lines) {
        final res = CloudflareFixService.transformVlessUrl(
          link,
          socksPort: _socksPort,
          httpPort: _httpPort,
          dnsServer: _dnsServer.isNotEmpty
              ? _dnsServer
              : CloudflareFixService.defaultDnsServer,
          remarkSuffix: _remarkSuffix,
          fingerprint: _fingerprint,
          alpn: alpnList.isNotEmpty ? alpnList : ['http/1.1'],
          cipherSuites: _cipherSuites.isNotEmpty
              ? _cipherSuites
              : CloudflareFixService.defaultCipherSuites,
          enableFinalmask: _enableFinalmask,
          frag1Packets: _frag1Packets,
          frag1Lengths: f1Lengths.isNotEmpty ? f1Lengths : ['0', '104', '1'],
          frag1Delays: f1Delays.isNotEmpty ? f1Delays : ['0'],
          frag1MaxSplit: _frag1MaxSplit,
          frag2Packets: _frag2Packets,
          frag2Lengths: f2Lengths.isNotEmpty ? f2Lengths : ['114', '1'],
          frag2Delays: f2Delays.isNotEmpty ? f2Delays : ['1'],
          frag2MaxSplit: _frag2MaxSplit,
        );
        newResults.add(res);
      }

      _results = newResults;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e is FormatException ? e.message : e.toString();
      _results = [];
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void clear() {
    _inputText = '';
    _results = [];
    _errorMessage = null;
    notifyListeners();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/masque_scout_scanner.dart';
import 'data/masque_ip_ranges.dart';

class MasqueScoutController extends ChangeNotifier {
  // Configuration
  MasqueScoutConfig _config = const MasqueScoutConfig();
  MasqueScoutConfig get config => _config;

  // Input text for endpoints/CIDRs
  String _inputText = '';
  String get inputText => _inputText;

  // Parsed endpoints
  List<String> _parsedEndpoints = [];
  List<String> get parsedEndpoints => _parsedEndpoints;
  int get parsedCount => _parsedEndpoints.length;

  // Scan state
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isPreparingScan = false;
  bool get isPreparingScan => _isPreparingScan;

  int _scannedCount = 0;
  int get scannedCount => _scannedCount;

  int _successCount = 0;
  int get successCount => _successCount;

  int get failureCount => _scannedCount - _successCount;

  double get progress =>
      _parsedEndpoints.isNotEmpty ? _scannedCount / _parsedEndpoints.length : 0;

  // Working endpoints (sorted by latency ascending)
  List<MasqueScoutResult> _workingEndpoints = [];
  List<MasqueScoutResult> get workingEndpoints => _workingEndpoints;

  // Stream subscription for scan cancellation
  StreamSubscription? _scanSubscription;

  MasqueScoutController() {
    loadPreset(MasqueIpRanges.seedsPresetText);
  }

  void _reparse() {
    _parsedEndpoints = MasqueScoutScanner.parseEndpointInput(
      _inputText,
      defaultPort: _config.defaultPort,
      multiPort: _config.multiPort,
      multiPorts: _config.ports,
    );
  }

  /// Update input text and parse endpoints
  void updateInput(String text) {
    _inputText = text;
    _reparse();
    notifyListeners();
  }

  /// Load a preset text
  void loadPreset(String presetText) {
    _inputText = presetText;
    _reparse();
    notifyListeners();
  }

  /// Shuffle input lines
  void shuffleInput() {
    final lines = _inputText
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('#'))
        .toList();
    if (lines.length <= 1) return;
    lines.shuffle();
    _inputText = lines.join('\n');
    _reparse();
    notifyListeners();
  }

  /// Switch protocol (H3 vs H2)
  void setProtocol(MasqueProtocol protocol) {
    _config = _config.copyWith(protocol: protocol);
    _reparse();
    notifyListeners();
  }

  /// Toggle multi-port scanning (443, 500, 1701, 4500, 4443, 8443, 8095)
  void setMultiPort(bool enabled) {
    _config = _config.copyWith(multiPort: enabled);
    _reparse();
    notifyListeners();
  }

  /// Update configuration
  void updateConfig({
    MasqueProtocol? protocol,
    int? customPort,
    bool? multiPort,
    List<int>? ports,
    Duration? timeout,
    int? maxWorkers,
    String? sni,
  }) {
    _config = _config.copyWith(
      protocol: protocol,
      customPort: customPort,
      multiPort: multiPort,
      ports: ports,
      timeout: timeout,
      maxWorkers: maxWorkers,
      sni: sni,
    );
    _reparse();
    notifyListeners();
  }

  /// Start scanning all parsed endpoints
  Future<void> startScan() async {
    if (_isScanning || _isPreparingScan || _parsedEndpoints.isEmpty) return;

    _isPreparingScan = true;
    _isScanning = true;
    _scannedCount = 0;
    _successCount = 0;
    _workingEndpoints = [];
    notifyListeners();

    final scanner = MasqueScoutScanner(config: _config);

    _scanSubscription = scanner.scanEndpoints(_parsedEndpoints).listen(
      (progress) {
        _isPreparingScan = false;
        _scannedCount = progress.completed;
        final hadNewSuccess = progress.successful > _successCount;
        _successCount = progress.successful;
        if (hadNewSuccess || _workingEndpoints.isEmpty) {
          _workingEndpoints = progress.workingEndpoints.toList()
            ..sort((a, b) =>
                (a.latencyMs ?? double.infinity).compareTo(b.latencyMs ?? double.infinity));
        }
        notifyListeners();
      },
      onDone: () {
        _isScanning = false;
        _isPreparingScan = false;
        _scanSubscription = null;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Masque Scout scan error: $error');
        _isScanning = false;
        _isPreparingScan = false;
        _scanSubscription = null;
        notifyListeners();
      },
    );
  }

  /// Stop current scan
  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    _isPreparingScan = false;
    notifyListeners();
  }

  /// Reset scan results
  void resetResults() {
    _scannedCount = 0;
    _successCount = 0;
    _workingEndpoints = [];
    notifyListeners();
  }

  /// Clear input and results
  void clearAll() {
    _inputText = '';
    _parsedEndpoints = [];
    _scannedCount = 0;
    _successCount = 0;
    _workingEndpoints = [];
    notifyListeners();
  }

  /// Copy working endpoints list (one per line)
  String getWorkingEndpointsText() {
    return _workingEndpoints.map((r) => r.endpoint).join('\n');
  }

  /// Copy working endpoints with latency details
  String getWorkingEndpointsDetailedText() {
    final buffer = StringBuffer();
    buffer.writeln('# Masque Scout Results');
    buffer.writeln('# Protocol: ${_config.protocol.displayName}');
    buffer.writeln('# Multi-Port: ${_config.multiPort ? "Enabled (${_config.ports.join(', ')})" : "Disabled"}');
    buffer.writeln('# SNI: ${_config.sni}');
    buffer.writeln('# Total scanned: $_scannedCount');
    buffer.writeln('# Working endpoints: ${_workingEndpoints.length}');
    buffer.writeln('# Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    for (final result in _workingEndpoints) {
      final latency = result.latencyMs?.toStringAsFixed(1) ?? 'N/A';
      final details = result.details ?? '';
      buffer.writeln('${result.endpoint} | Latency: ${latency}ms | $details');
    }

    return buffer.toString();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/sni_spoof_check_service.dart';

class SniSpoofCheckController extends ChangeNotifier {
  // ── Configuration ──────────────────────────────────────────────────────────

  SniSpoofCheckConfig _config = const SniSpoofCheckConfig();
  SniSpoofCheckConfig get config => _config;

  // ── Input state ────────────────────────────────────────────────────────────

  String _targetsText = '';
  String get targetsText => _targetsText;

  String _portsText = kDefaultSniPorts.join(',');
  String get portsText => _portsText;

  // ── Live status message ────────────────────────────────────────────────────

  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  List<String> _parsedTargets = [];
  List<String> get parsedTargets => _parsedTargets;
  int get parsedTargetCount => _parsedTargets.length;

  // ── Scan state ─────────────────────────────────────────────────────────────

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isPreparingScan = false;
  bool get isPreparingScan => _isPreparingScan;

  String? _userPublicIp;
  String? get userPublicIp => _userPublicIp;

  int _completedTargets = 0;
  int get completedTargets => _completedTargets;

  double get progress =>
      _parsedTargets.isNotEmpty ? _completedTargets / _parsedTargets.length : 0;

  // ── Results ────────────────────────────────────────────────────────────────

  List<SniIpResult> _results = [];
  List<SniIpResult> get results => _results;

  int get okCount =>
      _results.where((r) => r.status == SniResultStatus.ok).length;
  int get failCount =>
      _results.where((r) => r.status == SniResultStatus.fail).length;
  int get filteredCount =>
      _results.where((r) => r.status == SniResultStatus.filtered).length;
  int get errorCount =>
      _results.where((r) => r.status == SniResultStatus.error).length;

  // ── Internals ──────────────────────────────────────────────────────────────

  StreamSubscription? _scanSubscription;
  SniSpoofCheckService? _scanner;

  // ── Input management ───────────────────────────────────────────────────────

  void updateTargetsText(String text) {
    _targetsText = text;
    _parsedTargets = SniSpoofCheckService.parseTargets(text);
    notifyListeners();
  }

  void updatePortsText(String text) {
    _portsText = text;
    final ports = text
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .where((p) => p != null && p > 0 && p <= 65535)
        .cast<int>()
        .toList();
    if (ports.isNotEmpty) {
      _config = _config.copyWith(ports: ports);
    }
    notifyListeners();
  }

  void updateConfig({
    int? timeout,
    int? retries,
    int? concurrency,
    bool? enableIpCheck,
    String? manualIp,
  }) {
    _config = SniSpoofCheckConfig(
      ports: _config.ports,
      timeout: timeout ?? _config.timeout,
      retries: retries ?? _config.retries,
      concurrency: concurrency ?? _config.concurrency,
      enableIpCheck: enableIpCheck ?? _config.enableIpCheck,
      manualIp: manualIp ?? _config.manualIp,
    );
    notifyListeners();
  }

  // ── Scan control ───────────────────────────────────────────────────────────

  Future<void> startScan() async {
    if (_isScanning || _isPreparingScan || _parsedTargets.isEmpty) return;

    _isPreparingScan = true;
    _isScanning = true;
    _completedTargets = 0;
    _results = [];
    _userPublicIp = null;
    _statusMessage = 'Preparing scan...';
    notifyListeners();

    // Detect public IP if IP check is enabled
    if (_config.enableIpCheck) {
      _statusMessage = 'Detecting your public IP...';
      notifyListeners();
      if (_config.manualIp != null && _config.manualIp!.isNotEmpty) {
        _userPublicIp = _config.manualIp;
      } else {
        _userPublicIp = await SniSpoofCheckService.getUserPublicIp();
      }
      _statusMessage = 'Starting scan...';
      notifyListeners();
    }

    _scanner = SniSpoofCheckService(config: _config);

    _scanSubscription = _scanner!.scanTargets(_parsedTargets).listen(
      (progress) {
        _isPreparingScan = false;
        _completedTargets = progress.completedTargets;
        _results = progress.allResults.toList();
        _statusMessage = 'Scanning target ${progress.completedTargets}/${progress.totalTargets}...';
        notifyListeners();
      },
      onDone: () {
        _isScanning = false;
        _statusMessage = 'Scan complete';
        _scanSubscription = null;
        _scanner = null;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('SNI Spoof Check error: $error');
        _isScanning = false;
        _isPreparingScan = false;
        _scanSubscription = null;
        _scanner = null;
        notifyListeners();
      },
    );
  }

  void stopScan() {
    _scanner?.cancel();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanner = null;
    _isScanning = false;
    _isPreparingScan = false;
    notifyListeners();
  }

  void resetResults() {
    _completedTargets = 0;
    _results = [];
    _userPublicIp = null;
    notifyListeners();
  }

  void clearAll() {
    _targetsText = '';
    _portsText = kDefaultSniPorts.join(',');
    _parsedTargets = [];
    _completedTargets = 0;
    _results = [];
    _userPublicIp = null;
    _config = const SniSpoofCheckConfig();
    notifyListeners();
  }

  // ── Export ──────────────────────────────────────────────────────────────────

  String getResultsText() {
    return _results.map((r) => r.toDisplayString()).join('\n');
  }

  String getDetailedReport() {
    return SniSpoofCheckService.generateReport(_results, _config);
  }

  @override
  void dispose() {
    _scanner?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }
}

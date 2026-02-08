import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/services/cdn_config_scanner.dart';
import '../../core/services/xray_binary_service.dart' show XrayBinaryService;
import '../../core/services/xray_process_manager.dart' show XrayProcessManager, XrayStartupException;

/// Wizard step enum
enum CdnScanStep {
  binarySetup,
  configInput,
  ipInput,
  scanning,
}

/// State for binary download
enum BinaryDownloadState {
  checking,
  notInstalled,
  installed,
  downloading,
  extracting,
  error,
}

/// Controller for CDN Config Scan feature
class CdnConfigScanController extends ChangeNotifier {
  final XrayBinaryService _binaryService = XrayBinaryService();
  
  // Current wizard step
  CdnScanStep _currentStep = CdnScanStep.binarySetup;
  CdnScanStep get currentStep => _currentStep;

  // Binary setup state
  BinaryDownloadState _binaryState = BinaryDownloadState.checking;
  BinaryDownloadState get binaryState => _binaryState;
  
  String? _installedVersion;
  String? get installedVersion => _installedVersion;
  
  String? _latestVersion;
  String? get latestVersion => _latestVersion;
  
  String _customVersion = '';
  String get customVersion => _customVersion;
  
  bool _useCustomVersion = false;
  bool get useCustomVersion => _useCustomVersion;
  
  bool _isFetchingLatest = false;
  bool get isFetchingLatest => _isFetchingLatest;
  
  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;
  
  String? _downloadError;
  String? get downloadError => _downloadError;

  // Config input state
  String _configJson = '';
  String get configJson => _configJson;
  
  Map<String, dynamic>? _parsedConfig;
  Map<String, dynamic>? get parsedConfig => _parsedConfig;
  
  String? _configError;
  String? get configError => _configError;
  
  String? _originalAddress;
  String? get originalAddress => _originalAddress;
  
  int? _originalPort;
  int? get originalPort => _originalPort;

  // IP input state
  String _ipInput = '';
  String get ipInput => _ipInput;
  
  List<String> _parsedIps = [];
  List<String> get parsedIps => _parsedIps;
  int get parsedIpCount => _parsedIps.length;

  // Scan state
  CdnScanConfig _scanConfig = const CdnScanConfig();
  CdnScanConfig get scanConfig => _scanConfig;
  
  bool _isScanning = false;
  bool get isScanning => _isScanning;
  
  bool _isPreparingScan = false;
  bool get isPreparingScan => _isPreparingScan;
  
  int _scannedCount = 0;
  int get scannedCount => _scannedCount;
  
  int _successCount = 0;
  int get successCount => _successCount;
  
  int get failureCount => _scannedCount - _successCount;
  
  double get progress => _parsedIps.isNotEmpty ? _scannedCount / _parsedIps.length : 0;
  
  List<CdnScanResult> _results = [];
  List<CdnScanResult> get results => _results;
  
  String? _scanError;
  String? get scanError => _scanError;
  
  StreamSubscription? _scanSubscription;
  CdnConfigScanner? _scanner;

  /// Initialize the controller
  Future<void> initialize() async {
    _applyDefaultParallelism();
    await checkBinaryStatus();
  }

  void _applyDefaultParallelism() {
    final defaultParallel = _defaultParallelCount();
    if (_scanConfig.concurrentInstances <= 0 ||
        _scanConfig.concurrentInstances ==
            const CdnScanConfig().concurrentInstances) {
      _scanConfig =
          _scanConfig.copyWith(concurrentInstances: defaultParallel);
    }
  }

  int _defaultParallelCount() {
    final cpuCores = Platform.numberOfProcessors;
    final base = cpuCores > 0 ? cpuCores : 1;
    return base * 2;
  }

  /// Check if xray binary is installed
  Future<void> checkBinaryStatus() async {
    _binaryState = BinaryDownloadState.checking;
    notifyListeners();

    try {
      final isInstalled = await _binaryService.isXrayInstalled();
      final hasGeoData = await _binaryService.hasGeoData();
      
      if (isInstalled && hasGeoData) {
        _installedVersion = await _binaryService.getInstalledVersion();
        _binaryState = BinaryDownloadState.installed;
      } else {
        _binaryState = BinaryDownloadState.notInstalled;
      }
    } catch (e) {
      _binaryState = BinaryDownloadState.error;
      _downloadError = e.toString();
    }
    
    notifyListeners();
  }

  /// Fetch the latest version from GitHub
  Future<void> fetchLatestVersion() async {
    _isFetchingLatest = true;
    _downloadError = null;
    notifyListeners();
    
    try {
      _latestVersion = await _binaryService.fetchLatestVersion();
      notifyListeners();
    } catch (e) {
      _downloadError = 'Failed to fetch latest version: $e';
      notifyListeners();
    } finally {
      _isFetchingLatest = false;
      notifyListeners();
    }
  }

  /// Toggle between latest and custom version
  void setUseCustomVersion(bool useCustom) {
    _useCustomVersion = useCustom;
    notifyListeners();
  }

  /// Set custom version string
  void setCustomVersion(String version) {
    _customVersion = version;
    notifyListeners();
  }

  /// Get the version to download
  String? get versionToDownload {
    if (_useCustomVersion) {
      return _customVersion.isNotEmpty ? _customVersion : null;
    }
    return _latestVersion;
  }

  /// Download xray binary and geo data
  Future<void> downloadXray() async {
    final version = versionToDownload;
    if (version == null || version.isEmpty) return;

    _binaryState = BinaryDownloadState.downloading;
    _downloadProgress = 0;
    _downloadError = null;
    notifyListeners();

    try {
      // Download xray binary
      await _binaryService.downloadXray(
        version,
        onProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = received / total * 0.7; // 70% for binary
            notifyListeners();
          }
        },
      );

      _binaryState = BinaryDownloadState.extracting;
      notifyListeners();

      // Download geo data
      await _binaryService.downloadGeoData(
        onProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = 0.7 + (received / total * 0.3); // 30% for geo
            notifyListeners();
          }
        },
      );

      _installedVersion = version;
      _binaryState = BinaryDownloadState.installed;
      notifyListeners();
    } catch (e) {
      _binaryState = BinaryDownloadState.error;
      _downloadError = e.toString();
      notifyListeners();
    }
  }

  /// Delete installed xray and reset
  Future<void> deleteXray() async {
    await _binaryService.deleteXray();
    _installedVersion = null;
    _binaryState = BinaryDownloadState.notInstalled;
    notifyListeners();
  }

  /// Move to the next step
  void nextStep() {
    switch (_currentStep) {
      case CdnScanStep.binarySetup:
        _currentStep = CdnScanStep.configInput;
      case CdnScanStep.configInput:
        _currentStep = CdnScanStep.ipInput;
      case CdnScanStep.ipInput:
        _currentStep = CdnScanStep.scanning;
        startScan();
      case CdnScanStep.scanning:
        break; // Already at last step
    }
    notifyListeners();
  }

  /// Move to the previous step
  Future<void> previousStep() async {
    switch (_currentStep) {
      case CdnScanStep.binarySetup:
        break; // Already at first step
      case CdnScanStep.configInput:
        _currentStep = CdnScanStep.binarySetup;
      case CdnScanStep.ipInput:
        _currentStep = CdnScanStep.configInput;
      case CdnScanStep.scanning:
        await stopScan();
        _currentStep = CdnScanStep.ipInput;
    }
    notifyListeners();
  }

  /// Go to a specific step
  Future<void> goToStep(CdnScanStep step) async {
    if (_currentStep == CdnScanStep.scanning) {
      await stopScan();
    }
    _currentStep = step;
    notifyListeners();
  }

  /// Update config JSON input
  void updateConfigJson(String json) {
    _configJson = json;
    _configError = null;
    _parsedConfig = null;
    _originalAddress = null;
    _originalPort = null;
    
    if (json.trim().isEmpty) {
      notifyListeners();
      return;
    }

    try {
      final processManager = XrayProcessManager();
      _parsedConfig = processManager.parseConfig(json);
      _originalAddress = processManager.extractOutboundAddress(_parsedConfig!);
      _originalPort = processManager.extractInboundPort(_parsedConfig!);
      
      if (_originalAddress == null) {
        _configError = 'Could not find outbound address in config';
      }
      if (_originalPort == null) {
        _configError = 'Could not find inbound port in config';
      }
    } on FormatException catch (e) {
      _configError = e.message;
    } catch (e) {
      _configError = e.toString();
    }
    
    notifyListeners();
  }

  /// Load config from file
  Future<void> loadConfigFromFile(File file) async {
    try {
      final content = await file.readAsString();
      updateConfigJson(content);
    } catch (e) {
      _configError = 'Failed to read file: $e';
      notifyListeners();
    }
  }

  /// Check if config is valid
  bool get isConfigValid => 
      _parsedConfig != null && 
      _originalAddress != null && 
      _originalPort != null &&
      _configError == null;

  /// Update IP input
  void updateIpInput(String input) {
    _ipInput = input;
    _parsedIps = CdnConfigScanner.parseIpInput(input);
    notifyListeners();
  }

  /// Update scan configuration
  void updateScanConfig({
    int? concurrentInstances,
    Duration? timeout,
    String? testUrl,
    int? basePort,
  }) {
    _scanConfig = _scanConfig.copyWith(
      concurrentInstances: concurrentInstances,
      timeout: timeout,
      testUrl: testUrl,
      basePort: basePort,
    );
    notifyListeners();
  }

  /// Start scanning
  Future<void> startScan() async {
    if (_isScanning || _parsedConfig == null || _parsedIps.isEmpty) return;

    _isPreparingScan = true;
    _isScanning = true;
    _scannedCount = 0;
    _successCount = 0;
    _results = [];
    _scanError = null;
    notifyListeners();

    _scanner = CdnConfigScanner(
      binaryService: _binaryService,
      config: _scanConfig,
    );

    try {
      _scanSubscription = _scanner!.scanIps(_parsedIps, _parsedConfig!).listen(
        (progress) {
          _isPreparingScan = false;
          _scannedCount = progress.completed;
          _successCount = progress.successful;
          _results = progress.results.toList();
          notifyListeners();
        },
        onDone: () {
          _isScanning = false;
          _isPreparingScan = false;
          _scanSubscription = null;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Scan error: $error');
          _handleScanError(error);
        },
      );
    } on XrayStartupException catch (e) {
      _handleScanError(e);
    } catch (e) {
      _handleScanError(e);
    }
  }

  /// Handle scan errors and update state
  void _handleScanError(dynamic error) {
    _isScanning = false;
    _isPreparingScan = false;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    
    if (error is XrayStartupException) {
      _scanError = 'Xray failed to start: ${error.message}\n\n'
          'Please check that your config is valid and try again.';
    } else {
      _scanError = 'Scan failed: $error';
    }
    
    debugPrint('Scan error handled: $_scanError');
    notifyListeners();
  }

  /// Clear the current scan error
  void clearScanError() {
    _scanError = null;
    notifyListeners();
  }

  /// Stop the current scan
  Future<void> stopScan() async {
    await _scanner?.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    _isPreparingScan = false;
    notifyListeners();
  }

  /// Reset scan results
  void resetResults() {
    _scannedCount = 0;
    _successCount = 0;
    _results = [];
    notifyListeners();
  }

  /// Clear all state
  Future<void> clearAll() async {
    await stopScan();
    _configJson = '';
    _parsedConfig = null;
    _configError = null;
    _originalAddress = null;
    _originalPort = null;
    _ipInput = '';
    _parsedIps = [];
    _scannedCount = 0;
    _successCount = 0;
    _results = [];
    _scanError = null;
    _currentStep = CdnScanStep.binarySetup;
    notifyListeners();
  }

  /// Get working IPs as text
  String getWorkingIpsText() {
    return _results.map((r) => r.ip).join('\n');
  }

  /// Get working IPs with details
  String getWorkingIpsDetailedText() {
    final buffer = StringBuffer();
    buffer.writeln('# CDN Config Scan Results');
    buffer.writeln('# Original Address: $_originalAddress');
    buffer.writeln('# Total scanned: $_scannedCount');
    buffer.writeln('# Working IPs: ${_results.length}');
    buffer.writeln('# Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    for (final result in _results) {
      final latency = result.latencyMs?.toStringAsFixed(2) ?? 'N/A';
      buffer.writeln('${result.ip} | Latency: ${latency}ms');
    }

    return buffer.toString();
  }

  /// Get platform display name
  String get platformDisplayName => _binaryService.getPlatformDisplayName();

  @override
  void dispose() {
    // Use synchronous cleanup since dispose can't be async
    _scanSubscription?.cancel();
    _scanner?.dispose();
    _scanSubscription = null;
    _scanner = null;
    super.dispose();
  }
}


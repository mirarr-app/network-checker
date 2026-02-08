import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'xray_binary_service.dart';

/// Exception thrown when xray fails to start or encounters an error
class XrayStartupException implements Exception {
  final String message;
  final int? instanceId;
  final int? port;

  XrayStartupException(this.message, {this.instanceId, this.port});

  @override
  String toString() {
    if (instanceId != null && port != null) {
      return 'XrayStartupException (instance $instanceId, port $port): $message';
    }
    return 'XrayStartupException: $message';
  }
}

/// Exception thrown when a port is already in use
class PortInUseException implements Exception {
  final int port;
  final String message;

  PortInUseException(this.port, [String? message])
      : message = message ?? 'Port $port is already in use';

  @override
  String toString() => message;
}

/// Represents a running xray instance
class XrayInstance {
  final int id;
  final int port;
  Process process;
  final String configPath;
  bool isAvailable;
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  final List<String> _errorLog = [];
  bool _streamsAttached = false;

  XrayInstance({
    required this.id,
    required this.port,
    required this.process,
    required this.configPath,
    this.isAvailable = true,
  });

  List<String> get errorLog => List.unmodifiable(_errorLog);

  void addError(String error) {
    _errorLog.add(error);
    // Keep only last 50 error lines to prevent memory bloat
    if (_errorLog.length > 50) {
      _errorLog.removeAt(0);
    }
  }

  void clearErrors() {
    _errorLog.clear();
  }

  Future<void> cancelSubscriptions() async {
    _streamsAttached = false;
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
  }
}

/// Manages multiple xray process instances for parallel testing
class XrayProcessManager {
  final XrayBinaryService _binaryService;
  final List<XrayInstance> _instances = [];
  final int basePort;
  final bool enableProcessLogs;
  final Set<int> _reservedPorts = {};
  final Random _random = Random.secure();

  Directory? _tempConfigDir;

  XrayProcessManager({
    XrayBinaryService? binaryService,
    this.basePort = 10808,
    this.enableProcessLogs = kDebugMode,
  }) : _binaryService = binaryService ?? XrayBinaryService();

  /// Get all running instances
  List<XrayInstance> get instances => List.unmodifiable(_instances);

  /// Get number of running instances
  int get instanceCount => _instances.length;

  /// Parse and validate a config JSON, returning the parsed map
  Map<String, dynamic> parseConfig(String configJson) {
    try {
      final config = json.decode(configJson) as Map<String, dynamic>;

      // Validate required sections
      if (!config.containsKey('inbounds')) {
        throw FormatException('Config missing "inbounds" section');
      }
      if (!config.containsKey('outbounds')) {
        throw FormatException('Config missing "outbounds" section');
      }

      return config;
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Invalid JSON: $e');
    }
  }

  /// Extract the original outbound address from config
  String? extractOutboundAddress(Map<String, dynamic> config) {
    final outbounds = config['outbounds'] as List<dynamic>?;
    if (outbounds == null || outbounds.isEmpty) return null;

    // Find the proxy outbound (usually the first one or tagged as "proxy")
    for (final outbound in outbounds) {
      final map = outbound as Map<String, dynamic>;
      final protocol = map['protocol'] as String?;

      if (protocol == 'vless' || protocol == 'vmess' || protocol == 'trojan') {
        final settings = map['settings'] as Map<String, dynamic>?;
        final vnext = settings?['vnext'] as List<dynamic>?;
        if (vnext != null && vnext.isNotEmpty) {
          final server = vnext[0] as Map<String, dynamic>;
          return server['address'] as String?;
        }
      }
    }
    return null;
  }

  /// Extract the inbound port from config
  int? extractInboundPort(Map<String, dynamic> config) {
    final inbounds = config['inbounds'] as List<dynamic>?;
    if (inbounds == null || inbounds.isEmpty) return null;

    for (final inbound in inbounds) {
      final map = inbound as Map<String, dynamic>;
      final protocol = map['protocol'] as String?;

      if (protocol == 'socks' || protocol == 'http') {
        return map['port'] as int?;
      }
    }
    return null;
  }

  /// Create a modified config with new port and IP
  Map<String, dynamic> createModifiedConfig(
    Map<String, dynamic> baseConfig,
    int newPort,
    String newAddress,
  ) {
    // Deep copy the config
    final config =
        json.decode(json.encode(baseConfig)) as Map<String, dynamic>;

    // Modify inbound port
    final inbounds = config['inbounds'] as List<dynamic>;
    for (final inbound in inbounds) {
      final map = inbound as Map<String, dynamic>;
      final protocol = map['protocol'] as String?;
      if (protocol == 'socks' || protocol == 'http') {
        map['port'] = newPort;
        break;
      }
    }

    // Modify outbound address
    final outbounds = config['outbounds'] as List<dynamic>;
    for (final outbound in outbounds) {
      final map = outbound as Map<String, dynamic>;
      final protocol = map['protocol'] as String?;

      if (protocol == 'vless' || protocol == 'vmess' || protocol == 'trojan') {
        final settings = map['settings'] as Map<String, dynamic>;
        final vnext = settings['vnext'] as List<dynamic>;
        if (vnext.isNotEmpty) {
          final server = vnext[0] as Map<String, dynamic>;
          server['address'] = newAddress;
        }
        break;
      }
    }

    return config;
  }

  int _allocateRandomPort() {
    const minPort = 10000;
    const maxPort = 60000;
    const maxAttempts = 50;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final port = minPort + _random.nextInt(maxPort - minPort + 1);
      if (_reservedPorts.add(port)) {
        return port;
      }
    }

    throw StateError('Failed to allocate a random port after $maxAttempts attempts');
  }

  void _releasePort(int port) {
    _reservedPorts.remove(port);
  }

  /// Start a single xray instance for the given IP
  Future<XrayInstance> startInstanceForIp(
    Map<String, dynamic> baseConfig,
    String ip,
  ) async {
    // Ensure we have xray binary
    final xrayPath = await _binaryService.getXrayBinaryPath();
    if (!await File(xrayPath).exists()) {
      throw StateError('Xray binary not found. Please download it first.');
    }

    // Create temp directory for configs
    final xrayDir = await _binaryService.getXrayDirectory();
    _tempConfigDir = Directory('${xrayDir.path}/temp_configs');
    if (!await _tempConfigDir!.exists()) {
      await _tempConfigDir!.create();
    }

    final port = _allocateRandomPort();

    // Create config for this instance
    final instanceConfig = createModifiedConfig(baseConfig, port, ip);

    final configSuffix = '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(100000)}';
    final configPath = '${_tempConfigDir!.path}/config_$configSuffix.json';
    await File(configPath).writeAsString(json.encode(instanceConfig));

    try {
      final process = await Process.start(
        xrayPath,
        ['-c', configPath],
        workingDirectory: xrayDir.path,
      );

      final instance = XrayInstance(
        id: _instances.length,
        port: port,
        process: process,
        configPath: configPath,
        isAvailable: true,
      );

      // Set up stream listeners and track subscriptions
      _setupProcessListeners(instance);

      _instances.add(instance);
      return instance;
    } catch (e) {
      _releasePort(port);
      throw XrayStartupException(
        'Failed to start xray: $e',
        port: port,
      );
    }
  }

  /// Set up stdout/stderr listeners for an instance
  void _setupProcessListeners(XrayInstance instance) {
    // Close stdin immediately - we don't need to write to xray
    instance.process.stdin.close();

    if (!enableProcessLogs) {
      return;
    }

    // Only attach to streams if not already attached
    if (instance._streamsAttached) return;
    instance._streamsAttached = true;

    // Listen to raw bytes and decode manually to avoid creating extra stream transformers
    instance._stdoutSubscription = instance.process.stdout.listen(
      (data) {
        try {
          final text = utf8.decode(data, allowMalformed: true);
          debugPrint('Xray[${instance.id}]: $text');
        } catch (_) {}
      },
      onDone: () {
        instance._stdoutSubscription = null;
      },
      cancelOnError: false,
    );

    instance._stderrSubscription = instance.process.stderr.listen(
      (data) {
        try {
          final text = utf8.decode(data, allowMalformed: true);
          debugPrint('Xray[${instance.id}] ERR: $text');
          instance.addError(text);
        } catch (_) {}
      },
      onDone: () {
        instance._stderrSubscription = null;
      },
      cancelOnError: false,
    );
  }

  /// Kill a process and wait for it to fully terminate, ensuring streams are drained
  Future<void> _terminateProcess(Process process, {XrayInstance? instance}) async {
    // DON'T cancel subscriptions first - let them drain naturally when process exits
    
    // Try graceful termination first (SIGTERM)
    process.kill(ProcessSignal.sigterm);
    
    try {
      final exitCode = await process.exitCode.timeout(
        const Duration(milliseconds: 500),
      );
      debugPrint('Process terminated gracefully with code $exitCode');
    } on TimeoutException {
      // Force kill if graceful termination didn't work
      debugPrint('Force killing process...');
      process.kill(ProcessSignal.sigkill);
      try {
        await process.exitCode.timeout(const Duration(milliseconds: 500));
      } catch (_) {
        // Ignore - process should be dead now
      }
    }
    
    // Now that process is dead, cancel subscriptions - the streams should complete naturally
    // This is important to release the subscription resources
    if (instance != null) {
      await instance.cancelSubscriptions();
    }
    
    // Give a tiny bit of time for OS to clean up the pipe FDs
    await Future.delayed(const Duration(milliseconds: 10));
  }

  /// Kill a single instance and clean up its resources
  Future<void> _killInstance(XrayInstance instance) async {
    try {
      // Terminate the process - this will also cancel subscriptions after process exits
      await _terminateProcess(instance.process, instance: instance);
      _releasePort(instance.port);
      try {
        final configFile = File(instance.configPath);
        if (await configFile.exists()) {
          await configFile.delete();
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error killing xray instance ${instance.id}: $e');
    }
  }

  /// Stop a single instance and remove it from tracking
  Future<void> stopInstance(XrayInstance instance) async {
    await _killInstance(instance);
    _instances.remove(instance);
  }

  /// Get an available instance for testing
  XrayInstance? getAvailableInstance() {
    for (final instance in _instances) {
      if (instance.isAvailable) {
        return instance;
      }
    }
    return null;
  }

  /// Mark an instance as busy
  void markInstanceBusy(XrayInstance instance) {
    instance.isAvailable = false;
  }

  /// Mark an instance as available
  void markInstanceAvailable(XrayInstance instance) {
    instance.isAvailable = true;
  }

  /// Stop all xray instances
  Future<void> stopAll() async {
    // Kill all instances in parallel for faster cleanup
    await Future.wait(_instances.map(_killInstance));
    _instances.clear();

    // Clean up temp configs
    if (_tempConfigDir != null && await _tempConfigDir!.exists()) {
      try {
        await _tempConfigDir!.delete(recursive: true);
      } catch (e) {
        debugPrint('Error cleaning temp configs: $e');
      }
    }
    _tempConfigDir = null;
  }

  /// Dispose and clean up
  Future<void> dispose() async {
    await stopAll();
  }
}

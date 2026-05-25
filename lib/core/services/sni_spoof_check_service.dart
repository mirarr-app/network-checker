import 'dart:async';
import 'dart:io';

// ─── Configuration ───────────────────────────────────────────────────────────

/// Default targets for the SNI Spoof Check tool.
const String kDefaultSniTargets = '''hcaptcha.com
www.sciencedirect.com
auth.vercel.com''';

/// Default port to scan (quick mode).
const List<int> kDefaultSniPorts = [443];

/// All ports for comprehensive scanning.
const List<int> kAllSniPorts = [443, 2053, 2083, 2087, 2096, 8443];

/// API used to detect the user's public IP.
const String _kPublicIpApiUrl = 'http://chabokan.net/ip/';

class SniSpoofCheckConfig {
  final List<int> ports;
  final int timeout;
  final int retries;
  final int concurrency;
  final bool enableIpCheck;
  final String? manualIp;

  const SniSpoofCheckConfig({
    this.ports = kDefaultSniPorts,
    this.timeout = 5,
    this.retries = 3,
    this.concurrency = 20,
    this.enableIpCheck = true,
    this.manualIp,
  });

  SniSpoofCheckConfig copyWith({
    List<int>? ports,
    int? timeout,
    int? retries,
    int? concurrency,
    bool? enableIpCheck,
    String? manualIp,
  }) {
    return SniSpoofCheckConfig(
      ports: ports ?? this.ports,
      timeout: timeout ?? this.timeout,
      retries: retries ?? this.retries,
      concurrency: concurrency ?? this.concurrency,
      enableIpCheck: enableIpCheck ?? this.enableIpCheck,
      manualIp: manualIp ?? this.manualIp,
    );
  }
}

// ─── Result types ────────────────────────────────────────────────────────────

/// Status tag for a target+IP combination (mirrors the bash script output).
enum SniResultStatus { ok, fail, filtered, error }

/// Result of a single port check on one IP.
class SniPortResult {
  final int port;
  final bool isOpen;

  const SniPortResult({required this.port, required this.isOpen});
}

/// IP verification result (from /cdn-cgi/trace).
class SniIpCheckResult {
  final bool matched;
  final String? detectedIp;

  const SniIpCheckResult({required this.matched, this.detectedIp});
}

/// Full result for one resolved IP of a target.
class SniIpResult {
  final String target;
  final String ip;
  final SniResultStatus status;
  final List<SniPortResult> portResults;
  final SniIpCheckResult? ipCheckResult;
  final String? errorMessage;

  const SniIpResult({
    required this.target,
    required this.ip,
    required this.status,
    this.portResults = const [],
    this.ipCheckResult,
    this.errorMessage,
  });

  int get openPortCount => portResults.where((p) => p.isOpen).length;

  /// Format this result as a display string (mirroring the bash script output).
  String toDisplayString() {
    final tag = '[${status.name.toUpperCase()}]';

    if (status == SniResultStatus.error) {
      return '$tag $target (${errorMessage ?? 'Could not resolve'})';
    }
    if (status == SniResultStatus.filtered) {
      return '$tag $target -> $ip (Blocked/Internal IP)';
    }

    final portStr = portResults
        .map((p) => '${p.port}${p.isOpen ? '✔' : '✖'}')
        .join(' ');

    var line = '$tag $target -> $ip -> $portStr';

    if (ipCheckResult != null) {
      if (ipCheckResult!.matched) {
        line += ' IP✔';
      } else if (ipCheckResult!.detectedIp != null) {
        line += ' IP✖(${ipCheckResult!.detectedIp})';
      } else {
        line += ' IP✖';
      }
    }

    return line;
  }
}

/// Overall scan progress emitted via stream.
class SniSpoofScanProgress {
  final SniIpResult? latestResult;
  final int completedTargets;
  final int totalTargets;
  final List<SniIpResult> allResults;

  SniSpoofScanProgress({
    this.latestResult,
    required this.completedTargets,
    required this.totalTargets,
    required this.allResults,
  });

  double get progress =>
      totalTargets > 0 ? completedTargets / totalTargets : 0;

  int get okCount =>
      allResults.where((r) => r.status == SniResultStatus.ok).length;
  int get failCount =>
      allResults.where((r) => r.status == SniResultStatus.fail).length;
  int get filteredCount =>
      allResults.where((r) => r.status == SniResultStatus.filtered).length;
  int get errorCount =>
      allResults.where((r) => r.status == SniResultStatus.error).length;
}

// ─── Service ─────────────────────────────────────────────────────────────────

class SniSpoofCheckService {
  final SniSpoofCheckConfig config;
  bool _cancelled = false;

  SniSpoofCheckService({SniSpoofCheckConfig? config})
      : config = config ?? const SniSpoofCheckConfig();

  void cancel() {
    _cancelled = true;
  }

  // ── Target parsing ─────────────────────────────────────────────────────────

  /// Parse input text into a list of targets (domains or IPs), one per line.
  static List<String> parseTargets(String input) {
    return input
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
  }

  // ── DNS resolution ─────────────────────────────────────────────────────────

  static final _ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  /// Returns true if [target] is already an IPv4 address.
  static bool isIpAddress(String target) => _ipv4Regex.hasMatch(target);

  /// Resolve a domain to its A records; if already an IP, return it directly.
  static Future<List<String>> resolveTarget(String target) async {
    if (isIpAddress(target)) return [target];

    try {
      final addresses = await InternetAddress.lookup(target,
          type: InternetAddressType.IPv4);
      final ips = addresses
          .where((a) => a.type == InternetAddressType.IPv4)
          .map((a) => a.address)
          .toSet()
          .toList();
      return ips;
    } catch (_) {
      return [];
    }
  }

  // ── Port check ─────────────────────────────────────────────────────────────

  /// Test TCP connectivity to [ip]:[port] with retries.
  Future<bool> checkPort(String ip, int port) async {
    for (var attempt = 0; attempt < config.retries; attempt++) {
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: Duration(seconds: config.timeout),
        );
        socket.destroy();
        return true;
      } catch (_) {
        // retry
      }
    }
    return false;
  }

  // ── IP check via /cdn-cgi/trace ────────────────────────────────────────────

  /// Fetch the user's public IP via the configured API.
  static Future<String?> getUserPublicIp() async {
    for (var i = 0; i < 3; i++) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 10);
        final request = await client.getUrl(Uri.parse(_kPublicIpApiUrl));
        final response =
            await request.close().timeout(const Duration(seconds: 20));
        final body = await response.transform(SystemEncoding().decoder).join();
        client.close(force: true);

        // Parse {"ip": "x.x.x.x", ...}
        final match = RegExp(r'"ip"\s*:\s*"([^"]+)"').firstMatch(body);
        if (match != null) return match.group(1);
      } catch (_) {
        // retry
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  /// Verify IP by hitting https://{domain}/cdn-cgi/trace through a direct
  /// TCP+TLS connection to [ip]:443, injecting [domain] as the SNI hostname.
  /// Returns the `ip=` field from the Cloudflare trace response.
  Future<SniIpCheckResult> checkIp(
      String domain, String ip, String userPublicIp) async {
    Socket? rawSocket;
    SecureSocket? secureSocket;

    try {
      // Step 1: Direct TCP connect to ip:443
      rawSocket = await Socket.connect(
        ip,
        443,
        timeout: const Duration(seconds: 10),
      );

      // Step 2: TLS handshake with SNI = domain
      secureSocket = await SecureSocket.secure(
        rawSocket,
        host: domain,
        onBadCertificate: (_) => true, // Accept any cert for the trace check
      ).timeout(const Duration(seconds: 10));

      // Step 3: HTTP GET /cdn-cgi/trace with Host: domain
      final request = 'GET /cdn-cgi/trace HTTP/1.1\r\n'
          'Host: $domain\r\n'
          'Connection: close\r\n'
          '\r\n';
      secureSocket.write(request);
      await secureSocket.flush().timeout(const Duration(seconds: 5));

      // Step 4: Read response
      final responseBytes = <int>[];
      await for (final chunk
          in secureSocket.timeout(const Duration(seconds: 10))) {
        responseBytes.addAll(chunk);
        if (responseBytes.length > 8192) break; // Safety limit
      }

      final responseStr = String.fromCharCodes(responseBytes);

      // Parse ip= from the trace body
      final ipMatch = RegExp(r'^ip=(.+)$', multiLine: true)
          .firstMatch(responseStr);
      if (ipMatch == null) {
        return const SniIpCheckResult(matched: false);
      }

      final detectedIp = ipMatch.group(1)!.trim();
      return SniIpCheckResult(
        matched: detectedIp == userPublicIp,
        detectedIp: detectedIp,
      );
    } catch (_) {
      return const SniIpCheckResult(matched: false);
    } finally {
      try {
        await secureSocket
            ?.close()
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        try {
          secureSocket?.destroy();
        } catch (_) {}
      }
      if (secureSocket == null) {
        // TLS never wrapped, so raw socket is ours to close
        try {
          rawSocket?.destroy();
        } catch (_) {}
      }
    }
  }

  // ── Full scan orchestration ────────────────────────────────────────────────

  /// Run the full SNI spoof check scan.
  /// Returns a stream of progress updates.
  Stream<SniSpoofScanProgress> scanTargets(List<String> targets) {
    _cancelled = false;
    final controller = StreamController<SniSpoofScanProgress>();
    _runScan(targets, controller);
    return controller.stream;
  }

  Future<void> _runScan(
    List<String> targets,
    StreamController<SniSpoofScanProgress> controller,
  ) async {
    if (targets.isEmpty) {
      await controller.close();
      return;
    }

    // Get user public IP if IP check is enabled
    String? userPublicIp;
    if (config.enableIpCheck) {
      if (config.manualIp != null && config.manualIp!.isNotEmpty) {
        userPublicIp = config.manualIp;
      } else {
        userPublicIp = await getUserPublicIp();
      }
    }

    int completedTargets = 0;
    final allResults = <SniIpResult>[];

    // Create batches for concurrency control
    final batches = <List<String>>[];
    for (var i = 0; i < targets.length; i += config.concurrency) {
      batches.add(targets.sublist(
        i,
        i + config.concurrency > targets.length
            ? targets.length
            : i + config.concurrency,
      ));
    }

    try {
      for (final batch in batches) {
        if (_cancelled || controller.isClosed) break;

        final futures = batch.map((target) =>
            _processTarget(target, userPublicIp));
        final batchResults = await Future.wait(futures);

        for (final targetResults in batchResults) {
          if (_cancelled || controller.isClosed) break;

          completedTargets++;
          allResults.addAll(targetResults);

          controller.add(SniSpoofScanProgress(
            latestResult: targetResults.isNotEmpty ? targetResults.last : null,
            completedTargets: completedTargets,
            totalTargets: targets.length,
            allResults: List.unmodifiable(allResults),
          ));
        }
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    } finally {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  /// Process a single target: resolve, scan ports on each IP, optionally check IP.
  Future<List<SniIpResult>> _processTarget(
      String target, String? userPublicIp) async {
    // Resolve
    final ips = await resolveTarget(target);
    if (ips.isEmpty) {
      return [
        SniIpResult(
          target: target,
          ip: '',
          status: SniResultStatus.error,
          errorMessage: 'Could not resolve',
        ),
      ];
    }

    final results = <SniIpResult>[];
    for (final ip in ips) {
      if (_cancelled) break;

      // Filter internal/private IPs (10.x.x.x)
      if (ip.startsWith('10.')) {
        results.add(SniIpResult(
          target: target,
          ip: ip,
          status: SniResultStatus.filtered,
        ));
        continue;
      }

      // Scan all ports
      final portResults = <SniPortResult>[];
      int openCount = 0;

      for (final port in config.ports) {
        if (_cancelled) break;
        final isOpen = await checkPort(ip, port);
        portResults.add(SniPortResult(port: port, isOpen: isOpen));
        if (isOpen) openCount++;
      }

      if (openCount > 0) {
        // At least one port open — check IP if enabled
        SniIpCheckResult? ipCheckResult;
        if (config.enableIpCheck &&
            userPublicIp != null &&
            !isIpAddress(target)) {
          // IP check only makes sense for domain targets
          ipCheckResult = await checkIp(target, ip, userPublicIp);
        } else if (config.enableIpCheck &&
            userPublicIp != null &&
            isIpAddress(target)) {
          // For raw IP targets, we can't do domain-based trace, skip
          ipCheckResult = null;
        }

        results.add(SniIpResult(
          target: target,
          ip: ip,
          status: SniResultStatus.ok,
          portResults: portResults,
          ipCheckResult: ipCheckResult,
        ));
      } else {
        results.add(SniIpResult(
          target: target,
          ip: ip,
          status: SniResultStatus.fail,
          portResults: portResults,
        ));
      }
    }

    return results;
  }

  /// Generate a summary report text (mirrors the bash script final summary).
  static String generateReport(
      List<SniIpResult> results, SniSpoofCheckConfig config) {
    final buffer = StringBuffer();
    buffer.writeln('=== SNI Spoof Check Report ===');
    buffer.writeln('Ports: ${config.ports.join(',')}');
    buffer.writeln(
        'Timeout: ${config.timeout}s | Retries: ${config.retries}');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln('---------------------------------------------------');

    final ok = results.where((r) => r.status == SniResultStatus.ok).toList();
    final fail =
        results.where((r) => r.status == SniResultStatus.fail).toList();
    final error =
        results.where((r) => r.status == SniResultStatus.error).toList();
    final filtered =
        results.where((r) => r.status == SniResultStatus.filtered).toList();

    if (ok.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('=== OK (at least one open port) [${ok.length}] ===');
      for (final r in ok) {
        buffer.writeln(r.toDisplayString());
      }
    }

    if (fail.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('=== FAIL (all ports closed) [${fail.length}] ===');
      for (final r in fail) {
        buffer.writeln(r.toDisplayString());
      }
    }

    if (error.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('=== RESOLVE FAILED [${error.length}] ===');
      for (final r in error) {
        buffer.writeln(r.toDisplayString());
      }
    }

    if (filtered.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(
          '=== FILTERED (Blocked/IP 10.x) [${filtered.length}] ===');
      for (final r in filtered) {
        buffer.writeln(r.toDisplayString());
      }
    }

    buffer.writeln('---------------------------------------------------');
    buffer.writeln('Scan completed at ${DateTime.now().toIso8601String()}');
    return buffer.toString();
  }
}

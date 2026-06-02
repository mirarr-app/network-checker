import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Detailed result of a diagnostic test step
class DiagnosticTestResult {
  final String name;
  final bool success;
  final String message;
  final int? latencyMs;
  final String? details;

  DiagnosticTestResult({
    required this.name,
    required this.success,
    required this.message,
    this.latencyMs,
    this.details,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'success': success,
    'message': message,
    'latencyMs': latencyMs,
    'details': details,
  };
}

/// Service that executes core network connectivity tests on Android, Linux, and Windows.
class InternetDiagnosticsService {
  static const Duration timeoutLimit = Duration(seconds: 3);
  static const Duration dnsAnalysisTimeout = Duration(seconds: 2);
  static const List<String> _dnsAnalysisDomains = [
    'google.com',
    'cloudflare.com',
    'github.com',
    'wikipedia.org',
  ];
  static const Set<String> _knownHijackIps = {
    '127.0.0.1',
    '0.0.0.0',
    '10.10.34.34',
  };

  static final List<DnsAnalysisProvider> dnsAnalysisProviders = [
    const DnsAnalysisProvider(
      name: 'ISP DNS',
      address: 'System Resolver',
      usesSystemResolver: true,
    ),
    const DnsAnalysisProvider(name: 'Google DNS', address: '8.8.8.8'),
    const DnsAnalysisProvider(name: 'Cloudflare DNS', address: '1.1.1.1'),
    const DnsAnalysisProvider(name: 'Quad9 DNS', address: '9.9.9.9'),
    const DnsAnalysisProvider(name: 'OpenDNS', address: '208.67.222.222'),
  ];

  static final List<TlsAnalysisTarget> tlsAnalysisTargets = [
    const TlsAnalysisTarget(domain: 'chatgpt.com', expectedIp: '188.114.98.0'),
    const TlsAnalysisTarget(domain: 'vercel.com', expectedIp: '198.169.1.1'),
    const TlsAnalysisTarget(
      domain: 'static.cloudflareinsights.com',
      expectedIp: '104.16.80.73',
    ),
    const TlsAnalysisTarget(
      domain: 'sourceforge.net',
      expectedIp: '104.18.13.149',
    ),
    const TlsAnalysisTarget(
      domain: 'dash.cloudflare.com',
      expectedIp: '104.17.111.184',
    ),
    const TlsAnalysisTarget(domain: 'a.fsdn.com', expectedIp: '104.18.17.56'),
    const TlsAnalysisTarget(domain: 'npmjs.com', expectedIp: '104.17.134.117'),
    const TlsAnalysisTarget(
      domain: 'e7.c.lencr.org',
      expectedIp: '104.18.20.213',
    ),
    const TlsAnalysisTarget(domain: 'cdnjs.com', expectedIp: '104.24.196.20'),
    const TlsAnalysisTarget(
      domain: 'creativecommons.org',
      expectedIp: '104.20.6.134',
    ),
    const TlsAnalysisTarget(domain: 'nodejs.org', expectedIp: '104.16.213.131'),
    const TlsAnalysisTarget(domain: 'medium.com', expectedIp: '162.159.152.4'),
    const TlsAnalysisTarget(domain: 'jsdelivr.com', expectedIp: '188.114.98.0'),
    const TlsAnalysisTarget(domain: 'phpbb.com', expectedIp: '104.18.19.20'),
    const TlsAnalysisTarget(domain: 'codepen.io', expectedIp: '104.16.147.32'),
    const TlsAnalysisTarget(domain: 'google.com', expectedIp: '216.239.38.120'),
    const TlsAnalysisTarget(
      domain: 'translate.google.com',
      expectedIp: '172.217.168.78',
    ),
    const TlsAnalysisTarget(domain: 'gmail.com', expectedIp: '142.251.20.18'),
    const TlsAnalysisTarget(domain: 'github.com', expectedIp: '140.82.121.3'),
    const TlsAnalysisTarget(
      domain: 'www.speedtest.net',
      expectedIp: '104.17.147.22',
    ),
    const TlsAnalysisTarget(domain: 'coingecko.cfd', expectedIp: '8.6.112.0'),
    const TlsAnalysisTarget(
      domain: 'store.steampowered.com',
      expectedIp: '2.23.168.78',
    ),
    const TlsAnalysisTarget(domain: 'apple.com', expectedIp: '17.253.144.10'),
    const TlsAnalysisTarget(
      domain: 'chat.deepseek.com',
      expectedIp: '3.173.21.63',
    ),
    const TlsAnalysisTarget(
      domain: 'wikipedia.org',
      expectedIp: '185.15.59.224',
    ),
    const TlsAnalysisTarget(
      domain: 'play.google.com',
      expectedIp: '142.251.20.138',
    ),
    const TlsAnalysisTarget(
      domain: 'whatsapp.com',
      expectedIp: '57.144.245.32',
    ),
    const TlsAnalysisTarget(
      domain: 'playstation.com',
      expectedIp: '52.8.87.150',
    ),
    const TlsAnalysisTarget(domain: 'xbox.com', expectedIp: '20.76.201.171'),
    const TlsAnalysisTarget(
      domain: 'microsoft.com',
      expectedIp: '13.107.226.45',
    ),
    const TlsAnalysisTarget(domain: 'fastly.com', expectedIp: '151.101.193.57'),
    const TlsAnalysisTarget(
      domain: 'www.hcaptcha.com',
      expectedIp: '104.19.229.21',
    ),
    const TlsAnalysisTarget(
      domain: 'sciencedirect.com',
      expectedIp: '203.22.241.9',
    ),
    const TlsAnalysisTarget(
      domain: 'code.visualstudio.com',
      expectedIp: '13.107.253.45',
    ),
    const TlsAnalysisTarget(
      domain: 'crelease-assets.githubusercontent.com',
      expectedIp: '185.199.110.133',
    ),
  ];

  /// 1. Check DNS Resolution
  /// Resolves popular DNS resolver hostnames to see if the configured DNS servers are responsive and active.
  static Future<DiagnosticTestResult> checkDnsResolution() async {
    final targets = [
      'one.one.one.one',
      'dns.google',
    ];

    final stopwatch = Stopwatch()..start();
    final results = await Future.wait(
      targets.map((host) => _testDnsTarget(host)),
    );
    stopwatch.stop();

    final successful = results.where((r) => r.success).toList();
    final isSuccess = successful.isNotEmpty;

    final detailsBuilder = StringBuffer();
    detailsBuilder.writeln('Tested Endpoints:');
    for (final r in results) {
      if (r.success) {
        detailsBuilder.writeln('✓ ${r.host} - Resolved successfully (${r.latencyMs}ms)');
        detailsBuilder.writeln('  IP Address(es): ${r.ipAddresses.join(', ')}');
      } else {
        detailsBuilder.writeln('✗ ${r.host} - Failed (${r.error})');
      }
    }

    final message = isSuccess
        ? 'DNS resolution is available (${successful.length} of ${results.length} endpoints succeeded)'
        : 'DNS resolution failed (all endpoints failed)';

    return DiagnosticTestResult(
      name: 'DNS Resolution',
      success: isSuccess,
      message: message,
      latencyMs: successful.isNotEmpty
          ? successful.map((r) => r.latencyMs!).reduce((a, b) => a < b ? a : b)
          : stopwatch.elapsedMilliseconds,
      details: detailsBuilder.toString().trim(),
    );
  }

  static Future<_DnsTestResult> _testDnsTarget(String host) async {
    final stopwatch = Stopwatch()..start();
    try {
      final addresses = await InternetAddress.lookup(
        host,
      ).timeout(timeoutLimit);
      stopwatch.stop();

      if (addresses.isNotEmpty) {
        return _DnsTestResult(
          host: host,
          success: true,
          ipAddresses: addresses.map((a) => a.address).toList(),
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        return _DnsTestResult(
          host: host,
          success: false,
          ipAddresses: const [],
          error: 'Resolved empty address list',
        );
      }
    } on TimeoutException {
      stopwatch.stop();
      return _DnsTestResult(
        host: host,
        success: false,
        ipAddresses: const [],
        error: 'Timeout after ${timeoutLimit.inSeconds}s',
      );
    } catch (e) {
      stopwatch.stop();
      return _DnsTestResult(
        host: host,
        success: false,
        ipAddresses: const [],
        error: e.toString(),
      );
    }
  }

  /// 2. Check IPv4 Connectivity
  /// Bypasses DNS completely and attempts raw TCP socket connections to multiple public IPv4 DNS resolvers.
  static Future<DiagnosticTestResult> checkIpv4Connectivity() async {
    final targets = [
      {'name': 'Cloudflare DNS', 'address': '1.1.1.1', 'port': 53},
      {'name': 'Google DNS', 'address': '8.8.8.8', 'port': 53},
      {'name': 'Quad9 DNS', 'address': '9.9.9.9', 'port': 53},
    ];

    final stopwatch = Stopwatch()..start();
    final results = await Future.wait(
      targets.map((t) => _testSocketConnect(
        t['name'] as String,
        t['address'] as String,
        t['port'] as int,
      )),
    );
    stopwatch.stop();

    final successful = results.where((r) => r.success).toList();
    final isSuccess = successful.isNotEmpty;

    final detailsBuilder = StringBuffer();
    detailsBuilder.writeln('Tested Endpoints:');
    for (final r in results) {
      if (r.success) {
        detailsBuilder.writeln('✓ ${r.name} (${r.address}:${r.port}) - Succeeded (${r.latencyMs}ms)');
        detailsBuilder.writeln('  Local interface: ${r.localAddress}:${r.localPort}');
      } else {
        detailsBuilder.writeln('✗ ${r.name} (${r.address}:${r.port}) - Failed (${r.error})');
      }
    }

    final message = isSuccess
        ? 'IPv4 Internet access is available (${successful.length} of ${results.length} endpoints reached)'
        : 'IPv4 connectivity unavailable (all endpoints failed)';

    return DiagnosticTestResult(
      name: 'IPv4 Connectivity',
      success: isSuccess,
      message: message,
      latencyMs: successful.isNotEmpty
          ? successful.map((r) => r.latencyMs!).reduce((a, b) => a < b ? a : b)
          : stopwatch.elapsedMilliseconds,
      details: detailsBuilder.toString().trim(),
    );
  }

  /// 3. Check IPv6 Connectivity
  /// Bypasses DNS completely and attempts raw TCP socket connections to multiple public IPv6 DNS resolvers.
  static Future<DiagnosticTestResult> checkIpv6Connectivity() async {
    final targets = [
      {'name': 'Cloudflare IPv6 DNS', 'address': '2606:4700:4700::1111', 'port': 53},
      {'name': 'Google IPv6 DNS', 'address': '2001:4860:4860::8888', 'port': 53},
      {'name': 'Quad9 IPv6 DNS', 'address': '2620:fe::fe', 'port': 53},
    ];

    final stopwatch = Stopwatch()..start();
    final results = await Future.wait(
      targets.map((t) => _testSocketConnect(
        t['name'] as String,
        t['address'] as String,
        t['port'] as int,
      )),
    );
    stopwatch.stop();

    final successful = results.where((r) => r.success).toList();
    final isSuccess = successful.isNotEmpty;

    final detailsBuilder = StringBuffer();
    detailsBuilder.writeln('Tested Endpoints:');
    for (final r in results) {
      if (r.success) {
        detailsBuilder.writeln('✓ ${r.name} ([${r.address}]:${r.port}) - Succeeded (${r.latencyMs}ms)');
        detailsBuilder.writeln('  Local interface: [${r.localAddress}]:${r.localPort}');
      } else {
        detailsBuilder.writeln('✗ ${r.name} ([${r.address}]:${r.port}) - Failed (${r.error})');
      }
    }

    final message = isSuccess
        ? 'IPv6 Internet access is available (${successful.length} of ${results.length} endpoints reached)'
        : 'IPv6 connectivity unavailable (all endpoints failed)';

    return DiagnosticTestResult(
      name: 'IPv6 Connectivity',
      success: isSuccess,
      message: message,
      latencyMs: successful.isNotEmpty
          ? successful.map((r) => r.latencyMs!).reduce((a, b) => a < b ? a : b)
          : stopwatch.elapsedMilliseconds,
      details: detailsBuilder.toString().trim(),
    );
  }

  static Future<_SocketTestResult> _testSocketConnect(
    String name,
    String address,
    int port,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        address,
        port,
        timeout: timeoutLimit,
      );
      stopwatch.stop();
      final localAddress = socket.address.address;
      final localPort = socket.port;
      socket.destroy();

      return _SocketTestResult(
        name: name,
        address: address,
        port: port,
        success: true,
        latencyMs: stopwatch.elapsedMilliseconds,
        localAddress: localAddress,
        localPort: localPort,
      );
    } on TimeoutException {
      stopwatch.stop();
      return _SocketTestResult(
        name: name,
        address: address,
        port: port,
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: 'Timeout after ${timeoutLimit.inSeconds}s',
      );
    } catch (e) {
      stopwatch.stop();
      return _SocketTestResult(
        name: name,
        address: address,
        port: port,
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  /// 4. Check HTTPS Traffic
  /// Validates full HTTPS connection, including SSL/TLS handshake correctness, across multiple global hosts.
  static Future<DiagnosticTestResult> checkHttpsTraffic() async {
    final targets = [
      'https://www.cloudflare.com',
      'https://www.google.com',
    ];

    final stopwatch = Stopwatch()..start();
    final results = await Future.wait(
      targets.map((url) => _testHttpsTarget(url)),
    );
    stopwatch.stop();

    final successful = results.where((r) => r.success).toList();
    final isSuccess = successful.isNotEmpty;

    final detailsBuilder = StringBuffer();
    detailsBuilder.writeln('Tested Endpoints:');
    for (final r in results) {
      if (r.success) {
        detailsBuilder.writeln('✓ ${r.url} - Succeeded (Status: ${r.statusCode}, ${r.latencyMs}ms)');
      } else {
        final errDetails = r.statusCode != null ? 'Status: ${r.statusCode}' : r.error;
        detailsBuilder.writeln('✗ ${r.url} - Failed (${errDetails})');
      }
    }

    final message = isSuccess
        ? 'HTTPS traffic is available (${successful.length} of ${results.length} endpoints succeeded)'
        : 'HTTPS handshake or query failed (all endpoints failed)';

    return DiagnosticTestResult(
      name: 'HTTPS Traffic',
      success: isSuccess,
      message: message,
      latencyMs: successful.isNotEmpty
          ? successful.map((r) => r.latencyMs!).reduce((a, b) => a < b ? a : b)
          : stopwatch.elapsedMilliseconds,
      details: detailsBuilder.toString().trim(),
    );
  }

  static Future<_HttpsTestResult> _testHttpsTarget(String url) async {
    final stopwatch = Stopwatch()..start();
    try {
      final client = http.Client();
      try {
        final response = await client
            .head(Uri.parse(url))
            .timeout(timeoutLimit);
        stopwatch.stop();

        return _HttpsTestResult(
          url: url,
          success: response.statusCode < 400,
          statusCode: response.statusCode,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        client.close();
      }
    } on TimeoutException {
      stopwatch.stop();
      return _HttpsTestResult(
        url: url,
        success: false,
        error: 'Timeout after ${timeoutLimit.inSeconds}s',
      );
    } catch (e) {
      stopwatch.stop();
      return _HttpsTestResult(
        url: url,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 5. DNS Analysis
  /// Compares ISP/system DNS against major public resolvers and checks for tampering signals.
  static Future<DnsAnalysisSummary> analyzeDnsProviders() async {
    final nonexistentDomain =
        'nx-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(999999)}.invalid';

    final providerResults = await Future.wait(
      dnsAnalysisProviders.map(
        (provider) => _analyzeSingleDnsProvider(
          provider: provider,
          testDomains: _dnsAnalysisDomains,
          nonexistentDomain: nonexistentDomain,
        ),
      ),
    );

    return _buildDnsAnalysisSummary(
      providerResults: providerResults,
      testDomains: _dnsAnalysisDomains,
      nonexistentDomain: nonexistentDomain,
    );
  }

  /// 5 & 6. Fetch Public IP Address
  /// Queries domestic or international endpoints defensively.
  static Future<DiagnosticTestResult> fetchPublicIp({
    required bool domestic,
  }) async {
    final name = domestic ? 'Domestic IP Query' : 'International IP Query';
    final stopwatch = Stopwatch()..start();

    final urls = domestic
        ? ['https://chabokan.net/ip/']
        : [
            'https://api.ipify.org',
            'https://icanhazip.com',
            'https://ident.me',
            'https://ifconfig.me/ip',
          ];

    final completer = Completer<Map<String, String>>();
    var remaining = urls.length;
    final List<String> errors = [];
    const queryTimeout = Duration(seconds: 8);

    for (final url in urls) {
      http.get(Uri.parse(url)).timeout(queryTimeout).then((response) {
        if (completer.isCompleted) return;
        if (response.statusCode == 200) {
          String body = response.body.trim();
          String? retrievedIp;
          if (url.contains('chabokan.net')) {
            try {
              final data = jsonDecode(body) as Map<String, dynamic>;
              retrievedIp = (data['ipaddress'] ?? data['ip']) as String?;
            } catch (_) {}
          } else {
            retrievedIp = body;
          }

          if (retrievedIp != null && _isValidIpAddress(retrievedIp)) {
            completer.complete({
              'ip': retrievedIp,
              'url': url,
            });
            return;
          }
        }

        remaining--;
        errors.add('Failed to query $url: Status ${response.statusCode}');
        if (remaining == 0 && !completer.isCompleted) {
          completer.completeError(Exception(errors.join('\n')));
        }
      }).catchError((dynamic e) {
        if (completer.isCompleted) return;
        remaining--;
        errors.add('Failed to query $url: ${_formatGeneralError(e)}');
        if (remaining == 0 && !completer.isCompleted) {
          completer.completeError(Exception(errors.join('\n')));
        }
      });
    }

    String? retrievedIp;
    String? resolvedUrl;
    String errorLogs = '';

    try {
      final result = await completer.future;
      retrievedIp = result['ip'];
      resolvedUrl = result['url'];
    } catch (e) {
      errorLogs = e.toString().replaceFirst('Exception: ', '');
    }

    stopwatch.stop();

    if (retrievedIp != null) {
      IpGeoInfo? geoInfo;
      try {
        geoInfo = await fetchIpGeoDetails(retrievedIp);
      } catch (_) {}

      final geoDetails = geoInfo != null
          ? '\nGeo Location: ${geoInfo.countryName}, ${geoInfo.cityName}\nISP/Network: ${geoInfo.ispName}'
          : '\nGeo Location: Lookup failed or blocked';

      return DiagnosticTestResult(
        name: name,
        success: true,
        message: 'IP retrieved: $retrievedIp',
        latencyMs: stopwatch.elapsedMilliseconds,
        details:
            'API Source: $resolvedUrl\nResolved IP: $retrievedIp$geoDetails\nTime taken: ${stopwatch.elapsedMilliseconds}ms',
      );
    } else {
      return DiagnosticTestResult(
        name: name,
        success: false,
        message: 'Failed to retrieve public IP',
        latencyMs: stopwatch.elapsedMilliseconds,
        details: 'Attempted endpoints:\n$errorLogs',
      );
    }
  }

  /// Helper to fetch GeoIP information defensively
  static Future<IpGeoInfo?> fetchIpGeoDetails(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('https://freeipapi.com/api/json/$ip'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return IpGeoInfo.fromJson(data);
      }
    } catch (e) {
      debugPrint('GeoIP lookup failed for $ip: $e');
    }
    return null;
  }

  /// 7. Analyze Gateways
  /// Compares domestic and international IPs and produces a rich diagnostic report.
  static DiagnosticTestResult analyzePublicIps({
    required DiagnosticTestResult domesticResult,
    required DiagnosticTestResult internationalResult,
  }) {
    const name = 'IP Routing & Gateway Analysis';

    if (!domesticResult.success && !internationalResult.success) {
      return DiagnosticTestResult(
        name: name,
        success: false,
        message: 'Routing check failed - you are offline',
        details:
            'Error: Both domestic and international IP queries failed. Please check your physical connection, Wi-Fi, or system gateways.',
      );
    }

    if (!domesticResult.success) {
      return DiagnosticTestResult(
        name: name,
        success: false,
        message: 'Domestic gateway is unreachable',
        details:
            'Warning: International endpoints are reachable, but domestic CDNs (ArvanCloud/Chabokan) are completely blocked or unreachable.\nThis typically occurs if your VPN/Proxy is misconfigured or lacks split-tunneling routing for domestic hosts.',
      );
    }

    if (!internationalResult.success) {
      return DiagnosticTestResult(
        name: name,
        success: false,
        message: 'International gateway is blocked',
        details:
            'Warning: Domestic local gateways resolved successfully, but international IP servers (ipify/icanhazip) are blocked.\nThis indicates severe international internet censorship or that your international gateway is completely down.',
      );
    }

    // Both succeeded! Extract IP values
    final domesticIp = domesticResult.message
        .replaceFirst('IP retrieved: ', '')
        .trim();
    final internationalIp = internationalResult.message
        .replaceFirst('IP retrieved: ', '')
        .trim();

    if (domesticIp == internationalIp) {
      return DiagnosticTestResult(
        name: name,
        success: true,
        message: 'Direct Routing (Gateways Match)',
        details:
            'Domestic IP: $domesticIp\nInternational IP: $internationalIp\n\nRouting Status: MATCH\nDiagnosis: Both gateways egress from the exact same point. Your network is utilizing clean direct routing. No active transparent proxying, split-tunneling, or traffic manipulation detected.',
      );
    } else {
      return DiagnosticTestResult(
        name: name,
        success: true,
        message: 'Split Routing Detected (IP Mismatch)',
        details:
            'Domestic IP: $domesticIp\nInternational IP: $internationalIp\n\nRouting Status: MISMATCH / SPLIT TUNNEL\nDiagnosis: A routing discrepancy is detected! Your domestic traffic exits via a different network card or server than your international traffic. This is a characteristic signature of:\n1. An active VPN or proxy utilizing split-tunneling (local sites routed directly, foreign sites proxied).\n2. Governmental reverse proxies, carrier-grade NAT, or active deep packet injection (DPI) redirecting international gateways.',
      );
    }
  }

  static Future<TlsAnalysisSummary> analyzeTlsTargets({
    String? publicIp,
  }) async {
    final results = <TlsAnalysisResult>[];
    const batchSize = 4;

    for (var i = 0; i < tlsAnalysisTargets.length; i += batchSize) {
      final batch = tlsAnalysisTargets.sublist(
        i,
        min(i + batchSize, tlsAnalysisTargets.length),
      );
      results.addAll(
        await Future.wait(
          batch.map((target) => _analyzeSingleTlsTarget(target, publicIp)),
        ),
      );
    }

    return _buildTlsAnalysisSummary(results);
  }

  static Future<TlsAnalysisResult> _analyzeSingleTlsTarget(
    TlsAnalysisTarget target,
    String? publicIp,
  ) async {
    final resolvedIps = <String>[];
    final findings = <String>[];
    int? handshakeMs;
    String? selectedProtocol;
    String? certificateSubject;
    String? certificateIssuer;
    DateTime? certificateStart;
    DateTime? certificateEnd;
    bool handshakeSuccess = false;
    bool certificateValid = false;
    bool certificateMismatch = false;
    String? error;

    try {
      final addresses = await InternetAddress.lookup(
        target.domain,
      ).timeout(const Duration(seconds: 2));
      resolvedIps.addAll(addresses.map((address) => address.address).toSet());
      resolvedIps.sort();
      if (resolvedIps.isNotEmpty &&
          !resolvedIps.contains(target.expectedIp) &&
          !_sameIpv4C24(resolvedIps, target.expectedIp)) {
        findings.add('Resolved IP differs from expected baseline.');
      }
    } catch (e) {
      findings.add('DNS lookup failed before TLS handshake.');
    }

    final stopwatch = Stopwatch()..start();
    Socket? rawSocket;
    SecureSocket? socket;
    try {
      final ipToConnect = resolvedIps.isNotEmpty ? resolvedIps.first : target.domain;
      rawSocket = await Socket.connect(
        ipToConnect,
        443,
        timeout: const Duration(seconds: 4),
      ).timeout(const Duration(seconds: 4));
      socket = await SecureSocket.secure(
        rawSocket,
        host: target.domain,
        supportedProtocols: const ['h2', 'http/1.1'],
      ).timeout(const Duration(seconds: 4));

      stopwatch.stop();
      handshakeMs = stopwatch.elapsedMilliseconds;
      handshakeSuccess = true;
      selectedProtocol = socket.selectedProtocol;

      final certificate = socket.peerCertificate;
      certificateSubject = certificate?.subject;
      certificateIssuer = certificate?.issuer;
      certificateStart = certificate?.startValidity;
      certificateEnd = certificate?.endValidity;
      certificateValid =
          certificate != null && _certificateIsCurrentlyValid(certificate);
      certificateMismatch =
          certificate != null &&
          !_certificateLooksLikeDomain(certificate, target.domain);

      if (!certificateValid) {
        findings.add('Certificate is expired, not yet valid, or unavailable.');
      }
      if (certificateMismatch) {
        findings.add(
          'Certificate subject does not appear to match the domain.',
        );
      }
      socket.destroy();
    } on HandshakeException catch (e) {
      stopwatch.stop();
      handshakeMs = stopwatch.elapsedMilliseconds;
      error = e.toString();
      findings.add(
        'TLS handshake failed; possible interception or active blocking.',
      );
      rawSocket?.destroy();
    } on TimeoutException {
      stopwatch.stop();
      handshakeMs = stopwatch.elapsedMilliseconds;
      error = 'TLS handshake timed out.';
      findings.add('TLS handshake timeout.');
      rawSocket?.destroy();
    } catch (e) {
      stopwatch.stop();
      handshakeMs = stopwatch.elapsedMilliseconds;
      error = e.toString();
      findings.add('TLS connection failed.');
      rawSocket?.destroy();
    }

    CloudflareTraceResult? traceResult;
    if (target.shouldTraceCloudflare) {
      traceResult = await _fetchCloudflareTrace(target.domain, publicIp);
      if (traceResult.traceAvailable) {
        if (traceResult.traceIp == null) {
          findings.add('Cloudflare trace did not expose visitor IP.');
        } else if (publicIp != null && traceResult.traceIp != publicIp) {
          findings.add('Cloudflare trace IP differs from detected public IP.');
        }
      } else {
        findings.add('Cloudflare trace endpoint unavailable.');
      }
    }

    final tamperingScore = _scoreTlsTampering(
      handshakeSuccess: handshakeSuccess,
      certificateValid: certificateValid,
      certificateMismatch: certificateMismatch,
      hasResolutionMismatch: findings.any(
        (finding) => finding.contains('Resolved IP differs'),
      ),
      traceMismatch: findings.any(
        (finding) => finding.contains('trace IP differs'),
      ),
      traceUnavailable: findings.any(
        (finding) => finding.contains('trace endpoint unavailable'),
      ),
    );

    return TlsAnalysisResult(
      target: target,
      handshakeSuccess: handshakeSuccess,
      handshakeLatencyMs: handshakeMs,
      tlsVersion: selectedProtocol == null
          ? 'Platform negotiated TLS'
          : 'Platform negotiated TLS / ALPN $selectedProtocol',
      certificateValid: certificateValid,
      certificateMismatch: certificateMismatch,
      certificateSubject: certificateSubject,
      certificateIssuer: certificateIssuer,
      certificateStart: certificateStart,
      certificateEnd: certificateEnd,
      resolvedIps: resolvedIps,
      traceResult: traceResult,
      tamperingScore: tamperingScore,
      findings: findings,
      error: error,
    );
  }

  static Future<CloudflareTraceResult> _fetchCloudflareTrace(
    String domain,
    String? publicIp,
  ) async {
    final uri = Uri.parse('https://$domain/cdn-cgi/trace');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      stopwatch.stop();

      if (response.statusCode >= 400) {
        return CloudflareTraceResult(
          traceAvailable: false,
          expectedPublicIp: publicIp,
          latencyMs: stopwatch.elapsedMilliseconds,
          error: 'HTTP ${response.statusCode}',
        );
      }

      final traceFields = <String, String>{};
      for (final line in response.body.split('\n')) {
        final separator = line.indexOf('=');
        if (separator <= 0) continue;
        traceFields[line.substring(0, separator)] = line
            .substring(separator + 1)
            .trim();
      }

      final traceIp = traceFields['ip'];
      return CloudflareTraceResult(
        traceAvailable: true,
        traceIp: traceIp,
        expectedPublicIp: publicIp,
        traceMatchesPublicIp: publicIp != null && traceIp != null
            ? traceIp == publicIp
            : null,
        colo: traceFields['colo'],
        httpProtocol: traceFields['http'],
        tlsProtocol: traceFields['tls'],
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } on TimeoutException {
      stopwatch.stop();
      return CloudflareTraceResult(
        traceAvailable: false,
        expectedPublicIp: publicIp,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: 'Timeout',
      );
    } catch (e) {
      stopwatch.stop();
      return CloudflareTraceResult(
        traceAvailable: false,
        expectedPublicIp: publicIp,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  static TlsAnalysisSummary _buildTlsAnalysisSummary(
    List<TlsAnalysisResult> results,
  ) {
    final successful = results
        .where((result) => result.handshakeSuccess)
        .length;
    final certValid = results.where((result) => result.certificateValid).length;
    final mismatches = results
        .where((result) => result.certificateMismatch)
        .length;
    final traceMismatches = results
        .where((result) => result.traceResult?.traceMatchesPublicIp == false)
        .length;
    final latencies = results
        .where((result) => result.handshakeLatencyMs != null)
        .map((result) => result.handshakeLatencyMs!)
        .toList();
    final averageLatency = latencies.isEmpty
        ? null
        : (latencies.reduce((a, b) => a + b) / latencies.length).round();

    final averageTamperingScore = results.isEmpty
        ? 100
        : (results
                      .map((result) => result.tamperingScore)
                      .reduce((a, b) => a + b) /
                  results.length)
              .round();

    final findings = <String>[];
    if (mismatches > 0) {
      findings.add('$mismatches targets have possible certificate mismatch.');
    }
    if (traceMismatches > 0) {
      findings.add(
        '$traceMismatches Cloudflare trace IP checks differ from public IP.',
      );
    }
    final failed = results.length - successful;
    if (failed > 0) {
      findings.add('$failed targets failed TLS handshake.');
    }

    return TlsAnalysisSummary(
      results: results,
      successfulHandshakes: successful,
      validCertificates: certValid,
      certificateMismatches: mismatches,
      traceMismatches: traceMismatches,
      averageHandshakeLatencyMs: averageLatency,
      averageTamperingScore: averageTamperingScore,
      findings: findings,
      success: successful > 0 && averageTamperingScore < 70,
    );
  }

  static int _scoreTlsTampering({
    required bool handshakeSuccess,
    required bool certificateValid,
    required bool certificateMismatch,
    required bool hasResolutionMismatch,
    required bool traceMismatch,
    required bool traceUnavailable,
  }) {
    var score = 0;
    if (!handshakeSuccess) score += 45;
    if (!certificateValid) score += 25;
    if (certificateMismatch) score += 35;
    if (hasResolutionMismatch) score += 12;
    if (traceMismatch) score += 25;
    if (traceUnavailable) score += 8;
    return score.clamp(0, 100);
  }

  static bool _certificateIsCurrentlyValid(X509Certificate certificate) {
    final now = DateTime.now();
    return now.isAfter(certificate.startValidity) &&
        now.isBefore(certificate.endValidity);
  }

  static bool _certificateLooksLikeDomain(
    X509Certificate certificate,
    String domain,
  ) {
    final normalizedDomain = domain.toLowerCase();
    final subject = certificate.subject.toLowerCase();
    final commonNameMatch = RegExp(r'cn=([^,\n]+)').firstMatch(subject);
    final commonName = commonNameMatch?.group(1)?.trim();
    if (commonName == null) return true;
    return _domainMatchesCertificateName(normalizedDomain, commonName);
  }

  static bool _domainMatchesCertificateName(
    String domain,
    String certificateName,
  ) {
    final name = certificateName.toLowerCase();
    if (name == domain) return true;
    if (name.startsWith('*.')) {
      final suffix = name.substring(1);
      return domain.endsWith(suffix) &&
          domain.split('.').length == suffix.split('.').length;
    }
    return false;
  }

  static bool _sameIpv4C24(List<String> resolvedIps, String expectedIp) {
    final expectedParts = expectedIp.split('.');
    if (expectedParts.length != 4) return false;
    final expectedPrefix = expectedParts.take(3).join('.');
    return resolvedIps.any(
      (ip) => ip.split('.').take(3).join('.') == expectedPrefix,
    );
  }

  static Future<DnsProviderAnalysisResult> _analyzeSingleDnsProvider({
    required DnsAnalysisProvider provider,
    required List<String> testDomains,
    required String nonexistentDomain,
  }) async {
    final queryResults = <DnsQueryAnalysisResult>[];

    for (final domain in testDomains) {
      queryResults.add(
        await _queryDnsProvider(
          provider: provider,
          domain: domain,
          expectNxDomain: false,
        ),
      );
    }

    queryResults.add(
      await _queryDnsProvider(
        provider: provider,
        domain: nonexistentDomain,
        expectNxDomain: true,
      ),
    );

    final successfulQueries = queryResults
        .where((result) => result.success)
        .length;
    final latencies = queryResults
        .where((result) => result.latencyMs != null)
        .map((result) => result.latencyMs!)
        .toList();
    final averageLatency = latencies.isEmpty
        ? null
        : (latencies.reduce((a, b) => a + b) / latencies.length).round();

    return DnsProviderAnalysisResult(
      provider: provider,
      queryResults: queryResults,
      successRate: successfulQueries / queryResults.length,
      averageLatencyMs: averageLatency,
    );
  }

  static Future<DnsQueryAnalysisResult> _queryDnsProvider({
    required DnsAnalysisProvider provider,
    required String domain,
    required bool expectNxDomain,
  }) async {
    if (provider.usesSystemResolver) {
      return _querySystemDns(domain: domain, expectNxDomain: expectNxDomain);
    }

    return _queryUdpDns(
      provider: provider,
      domain: domain,
      expectNxDomain: expectNxDomain,
    );
  }

  static Future<DnsQueryAnalysisResult> _querySystemDns({
    required String domain,
    required bool expectNxDomain,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final addresses = await InternetAddress.lookup(
        domain,
      ).timeout(dnsAnalysisTimeout);
      stopwatch.stop();

      final ipAddresses =
          addresses.map((address) => address.address).toSet().toList()..sort();
      final suspiciousReasons = _detectSuspiciousDnsAnswers(
        domain: domain,
        ipAddresses: ipAddresses,
        expectNxDomain: expectNxDomain,
        isNxDomain: false,
      );

      return DnsQueryAnalysisResult(
        domain: domain,
        success:
            !expectNxDomain &&
            ipAddresses.isNotEmpty &&
            suspiciousReasons.isEmpty,
        isNxDomain: false,
        ipAddresses: ipAddresses,
        latencyMs: stopwatch.elapsedMilliseconds,
        suspiciousReasons: suspiciousReasons,
      );
    } on TimeoutException {
      stopwatch.stop();
      return DnsQueryAnalysisResult(
        domain: domain,
        success: false,
        isNxDomain: false,
        ipAddresses: const [],
        latencyMs: stopwatch.elapsedMilliseconds,
        error: 'System DNS lookup timed out.',
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      final isNxDomain = _looksLikeNxDomain(e);
      final suspiciousReasons = _detectSuspiciousDnsAnswers(
        domain: domain,
        ipAddresses: const [],
        expectNxDomain: expectNxDomain,
        isNxDomain: isNxDomain,
      );

      return DnsQueryAnalysisResult(
        domain: domain,
        success: expectNxDomain && isNxDomain,
        isNxDomain: isNxDomain,
        ipAddresses: const [],
        latencyMs: stopwatch.elapsedMilliseconds,
        error: isNxDomain ? null : _formatSocketException(e),
        suspiciousReasons: suspiciousReasons,
      );
    } catch (e) {
      stopwatch.stop();
      return DnsQueryAnalysisResult(
        domain: domain,
        success: false,
        isNxDomain: false,
        ipAddresses: const [],
        latencyMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  static Future<DnsQueryAnalysisResult> _queryUdpDns({
    required DnsAnalysisProvider provider,
    required String domain,
    required bool expectNxDomain,
  }) async {
    final serverIp = InternetAddress.tryParse(provider.address);
    if (serverIp == null) {
      return DnsQueryAnalysisResult(
        domain: domain,
        success: false,
        isNxDomain: false,
        ipAddresses: const [],
        error: 'Invalid DNS server address: ${provider.address}',
      );
    }

    final transactionId = Random().nextInt(0xffff);
    final query = _buildDnsQuery(domain, transactionId);
    final stopwatch = Stopwatch()..start();
    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final completer = Completer<List<int>?>();
      Timer? timer;

      timer = Timer(dnsAnalysisTimeout, () {
        if (!completer.isCompleted) completer.complete(null);
      });

      socket.listen((event) {
        if (event != RawSocketEvent.read || completer.isCompleted) return;
        final datagram = socket?.receive();
        if (datagram == null || datagram.data.length < 12) return;
        final responseId = (datagram.data[0] << 8) | datagram.data[1];
        if (responseId == transactionId) {
          completer.complete(datagram.data);
        }
      });

      socket.send(query, serverIp, 53);
      final responseBytes = await completer.future;
      stopwatch.stop();
      timer.cancel();

      if (responseBytes == null) {
        return DnsQueryAnalysisResult(
          domain: domain,
          success: false,
          isNxDomain: false,
          ipAddresses: const [],
          latencyMs: stopwatch.elapsedMilliseconds,
          error: 'Timeout after ${dnsAnalysisTimeout.inSeconds}s.',
        );
      }

      final response = _parseDnsResponse(responseBytes);
      final suspiciousReasons = _detectSuspiciousDnsAnswers(
        domain: domain,
        ipAddresses: response.ipAddresses,
        expectNxDomain: expectNxDomain,
        isNxDomain: response.isNxDomain,
        rcode: response.rcode,
      );

      return DnsQueryAnalysisResult(
        domain: domain,
        success: response.rcode == 0
            ? (!expectNxDomain &&
                  response.ipAddresses.isNotEmpty &&
                  suspiciousReasons.isEmpty)
            : (expectNxDomain && response.isNxDomain),
        isNxDomain: response.isNxDomain,
        ipAddresses: response.ipAddresses,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: response.rcode == 0 || response.isNxDomain
            ? null
            : 'DNS RCODE ${response.rcode}',
        suspiciousReasons: suspiciousReasons,
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return DnsQueryAnalysisResult(
        domain: domain,
        success: false,
        isNxDomain: false,
        ipAddresses: const [],
        latencyMs: stopwatch.elapsedMilliseconds,
        error: _formatSocketException(e),
      );
    } catch (e) {
      stopwatch.stop();
      return DnsQueryAnalysisResult(
        domain: domain,
        success: false,
        isNxDomain: false,
        ipAddresses: const [],
        latencyMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
    } finally {
      socket?.close();
    }
  }

  static List<int> _buildDnsQuery(String domain, int transactionId) {
    final bytes = <int>[
      (transactionId >> 8) & 0xff,
      transactionId & 0xff,
      0x01,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ];

    for (final label in domain.split('.')) {
      final encoded = ascii.encode(label);
      bytes.add(encoded.length);
      bytes.addAll(encoded);
    }

    bytes
      ..add(0x00)
      ..add(0x00)
      ..add(0x01)
      ..add(0x00)
      ..add(0x01);

    return bytes;
  }

  static _ParsedDnsResponse _parseDnsResponse(List<int> bytes) {
    if (bytes.length < 12) {
      throw const FormatException('DNS response is too short.');
    }

    final flags = (bytes[2] << 8) | bytes[3];
    final rcode = flags & 0x0f;
    final questionCount = (bytes[4] << 8) | bytes[5];
    final answerCount = (bytes[6] << 8) | bytes[7];
    var offset = 12;

    for (var i = 0; i < questionCount; i++) {
      offset = _skipDnsName(bytes, offset);
      offset += 4;
      if (offset > bytes.length) {
        throw const FormatException('DNS question section is truncated.');
      }
    }

    final ipAddresses = <String>{};
    for (var i = 0; i < answerCount; i++) {
      offset = _skipDnsName(bytes, offset);
      if (offset + 10 > bytes.length) {
        throw const FormatException('DNS answer section is truncated.');
      }

      final type = (bytes[offset] << 8) | bytes[offset + 1];
      final recordClass = (bytes[offset + 2] << 8) | bytes[offset + 3];
      final rdLength = (bytes[offset + 8] << 8) | bytes[offset + 9];
      offset += 10;

      if (offset + rdLength > bytes.length) {
        throw const FormatException('DNS record data is truncated.');
      }

      if (recordClass == 1 && type == 1 && rdLength == 4) {
        ipAddresses.add(bytes.sublist(offset, offset + 4).join('.'));
      }

      offset += rdLength;
    }

    final sortedIps = ipAddresses.toList()..sort();
    return _ParsedDnsResponse(
      rcode: rcode,
      isNxDomain: rcode == 3,
      ipAddresses: sortedIps,
    );
  }

  static int _skipDnsName(List<int> bytes, int offset) {
    var current = offset;
    var jumps = 0;

    while (current < bytes.length) {
      final length = bytes[current];
      if ((length & 0xc0) == 0xc0) {
        current += 2;
        if (current > bytes.length) {
          throw const FormatException('DNS compression pointer is truncated.');
        }
        return current;
      }

      if (length == 0) return current + 1;

      current += length + 1;
      jumps++;
      if (jumps > 128 || current > bytes.length) {
        throw const FormatException('DNS name is malformed.');
      }
    }

    throw const FormatException('DNS name is truncated.');
  }

  static List<String> _detectSuspiciousDnsAnswers({
    required String domain,
    required List<String> ipAddresses,
    required bool expectNxDomain,
    required bool isNxDomain,
    int? rcode,
  }) {
    final reasons = <String>[];

    if (expectNxDomain) {
      if (!isNxDomain && ipAddresses.isNotEmpty) {
        reasons.add('NXDOMAIN hijacking: nonexistent domain returned IPs.');
      } else if (!isNxDomain && rcode != null && rcode != 3) {
        reasons.add('Expected NXDOMAIN but received DNS RCODE $rcode.');
      }
      return reasons;
    }

    if (isNxDomain) {
      reasons.add('Incorrect response: valid domain returned NXDOMAIN.');
    }

    if (ipAddresses.isEmpty) {
      reasons.add('No A records returned.');
    }

    for (final ip in ipAddresses) {
      if (_knownHijackIps.contains(ip) || _isPrivateOrReservedIpv4(ip)) {
        reasons.add('Suspicious answer for $domain: $ip.');
      }
    }

    return reasons;
  }

  static DnsAnalysisSummary _buildDnsAnalysisSummary({
    required List<DnsProviderAnalysisResult> providerResults,
    required List<String> testDomains,
    required String nonexistentDomain,
  }) {
    final findings = <String>[];
    final consistencyByDomain = <String, double>{};

    for (final domain in testDomains) {
      final answerSets = <String, int>{};
      for (final providerResult in providerResults) {
        final query = providerResult.queryForDomain(domain);
        if (query == null || !query.success || query.ipAddresses.isEmpty) {
          continue;
        }
        final key = query.ipAddresses.join(',');
        answerSets[key] = (answerSets[key] ?? 0) + 1;
      }

      final successfulCount = answerSets.values.fold<int>(
        0,
        (sum, count) => sum + count,
      );
      if (successfulCount == 0) {
        consistencyByDomain[domain] = 0;
        findings.add('No provider returned a valid answer for $domain.');
        continue;
      }

      final largestGroup = answerSets.values.reduce(max);
      consistencyByDomain[domain] = largestGroup / successfulCount;

      if (answerSets.length > 1 && largestGroup == 1 && successfulCount > 1) {
        findings.add('All providers returned different A records for $domain.');
      } else if (answerSets.length > 1) {
        findings.add('Provider responses differ for $domain.');
      }
    }

    final nxHijackProviders = providerResults.where((providerResult) {
      final query = providerResult.queryForDomain(nonexistentDomain);
      return query?.suspiciousReasons.any(
            (reason) => reason.contains('NXDOMAIN hijacking'),
          ) ??
          false;
    }).toList();

    if (nxHijackProviders.isNotEmpty) {
      findings.add(
        'NXDOMAIN hijacking detected on ${nxHijackProviders.map((p) => p.provider.name).join(', ')}.',
      );
    }

    for (final providerResult in providerResults) {
      for (final query in providerResult.queryResults) {
        if (query.suspiciousReasons.isNotEmpty) {
          findings.add(
            '${providerResult.provider.name}: ${query.suspiciousReasons.join(' ')}',
          );
        }
      }
    }

    final latencies = providerResults
        .where((result) => result.averageLatencyMs != null)
        .map((result) => result.averageLatencyMs!)
        .toList();
    final averageLatency = latencies.isEmpty
        ? null
        : (latencies.reduce((a, b) => a + b) / latencies.length).round();

    final consistency = consistencyByDomain.isEmpty
        ? 0.0
        : consistencyByDomain.values.reduce((a, b) => a + b) /
              consistencyByDomain.length;

    var tamperingScore = 0;
    tamperingScore += nxHijackProviders.length * 25;
    tamperingScore +=
        providerResults
            .expand((providerResult) => providerResult.queryResults)
            .where((query) => query.suspiciousReasons.isNotEmpty)
            .length *
        8;
    tamperingScore += ((1 - consistency) * 25).round();
    tamperingScore +=
        providerResults.where((result) => result.successRate < 0.5).length * 10;
    tamperingScore = tamperingScore.clamp(0, 100);

    final successfulProviders = providerResults
        .where((result) => result.successRate > 0)
        .length;
    return DnsAnalysisSummary(
      providerResults: providerResults,
      testedDomains: [...testDomains, nonexistentDomain],
      averageLatencyMs: averageLatency,
      consistencyScore: consistency,
      tamperingScore: tamperingScore,
      findings: findings.toSet().toList(),
      success: successfulProviders > 0 && tamperingScore < 70,
    );
  }

  static bool _looksLikeNxDomain(SocketException e) {
    final message = e.toString().toLowerCase();
    return message.contains('failed host lookup') ||
        message.contains('nodename nor servname') ||
        message.contains('name or service not known') ||
        message.contains('no address associated');
  }

  static String _formatGeneralError(dynamic error) {
    if (error is TimeoutException) {
      return 'Request timed out (took longer than 8 seconds).';
    }
    final errorStr = error.toString();
    if (errorStr.contains('TimeoutException')) {
      return 'Request timed out (took longer than 8 seconds).';
    }
    if (error is SocketException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('failed host lookup') || msg.contains('dns')) {
        return 'DNS lookup failed (endpoint host could not be resolved).';
      }
      if (msg.contains('connection refused')) {
        return 'Connection refused by the host server.';
      }
      if (msg.contains('network is unreachable') || msg.contains('no route to host')) {
        return 'Network is unreachable or no route to host.';
      }
      return 'Network connection failed (${error.message}).';
    }
    if (errorStr.contains('HandshakeException') || errorStr.contains('cert')) {
      return 'SSL/TLS handshake failed (connection may be blocked or intercepted).';
    }
    if (errorStr.contains('SocketException')) {
      if (errorStr.contains('Connection timed out')) {
        return 'Connection timed out.';
      }
      return 'Network connection failed.';
    }
    return errorStr.length > 120 ? '${errorStr.substring(0, 117)}...' : errorStr;
  }

  static String _formatSocketException(SocketException e) {
    final message = e.message;
    return message.length > 80 ? '${message.substring(0, 77)}...' : message;
  }

  static bool _isPrivateOrReservedIpv4(String ip) {
    final parts = ip.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) return false;

    final a = parts[0]!;
    final b = parts[1]!;
    if (a == 10 || a == 127 || a == 0) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    if (a == 169 && b == 254) return true;
    if (a >= 224) return true;
    return false;
  }

  static bool _isValidIpAddress(String ip) {
    final ipRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$|^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$',
    );
    return ipRegex.hasMatch(ip.trim());
  }

  /// 8. Test reachability of a single website and diagnose failure profile.
  static Future<WebsiteReachabilityResult> testWebsiteReachability(
    String name,
    String domain,
  ) async {
    final stopwatch = Stopwatch()..start();

    // DNS check first
    List<InternetAddress>? resolvedAddresses;
    try {
      resolvedAddresses = await InternetAddress.lookup(
        domain,
      ).timeout(const Duration(seconds: 2));
      if (resolvedAddresses.isEmpty) {
        return WebsiteReachabilityResult(
          name: name,
          domain: domain,
          status: ReachabilityStatus.dnsFailure,
          errorDetails: 'DNS resolution completed but returned 0 IP addresses.',
        );
      }
    } on TimeoutException {
      return WebsiteReachabilityResult(
        name: name,
        domain: domain,
        status: ReachabilityStatus.dnsFailure,
        errorDetails: 'DNS resolution timed out.',
      );
    } catch (e) {
      return WebsiteReachabilityResult(
        name: name,
        domain: domain,
        status: ReachabilityStatus.dnsFailure,
        errorDetails: 'DNS resolution failed: $e',
      );
    }

    // Check if the resolved address is a hijacked domestic block IP
    final resolvedIp = resolvedAddresses.first.address;
    if (resolvedIp == '127.0.0.1' || resolvedIp == '10.10.34.34') {
      stopwatch.stop();
      return WebsiteReachabilityResult(
        name: name,
        domain: domain,
        status: ReachabilityStatus.blocked,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails:
            'DNS hijacking detected! Resolved to known block IP: $resolvedIp',
      );
    }

    // Attempt HTTP/HTTPS connection
    final uri = Uri.parse('https://$domain');
    try {
      final client = http.Client();
      try {
        final response = await client.head(uri).timeout(timeoutLimit);
        stopwatch.stop();

        // Any HTTP status code returned successfully means the network routing, DNS, TCP connection,
        // and SSL/TLS handshake succeeded and we reached the host. Even if the server returns 4xx or 5xx
        // (such as a 403 Forbidden because of headless client detection), the site is reachable.
        final note = response.statusCode >= 400
            ? '\n\nNote: Server returned HTTP status ${response.statusCode} (e.g., client/WAF rejection), but routing and SSL/TLS handshake succeeded. The site is REACHABLE.'
            : '';
        return WebsiteReachabilityResult(
          name: name,
          domain: domain,
          status: ReachabilityStatus.reachable,
          latencyMs: stopwatch.elapsedMilliseconds,
          statusCode: response.statusCode,
          errorDetails:
              'Resolved IP: $resolvedIp\nHTTP Status: ${response.statusCode}$note',
        );
      } finally {
        client.close();
      }
    } on TimeoutException {
      stopwatch.stop();
      return WebsiteReachabilityResult(
        name: name,
        domain: domain,
        status: ReachabilityStatus.timeout,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails:
            'TCP connection timed out after ${timeoutLimit.inSeconds} seconds.',
      );
    } on HandshakeException catch (e) {
      stopwatch.stop();
      return WebsiteReachabilityResult(
        name: name,
        domain: domain,
        status: ReachabilityStatus.tlsFailure,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails:
            'SSL/TLS Handshake failed: $e\nThis is a common symptom of SNI-based deep packet blocking.',
      );
    } on SocketException catch (e) {
      stopwatch.stop();

      final msg = e.toString().toLowerCase();
      ReachabilityStatus status = ReachabilityStatus.blocked;
      String diagMsg = 'Connection actively reset or rejected.';

      if (msg.contains('connection refused')) {
        diagMsg = 'Connection refused by gateway.';
      } else if (msg.contains('connection reset') ||
          msg.contains('connection aborted')) {
        diagMsg =
            'Connection reset by peer (TCP RST). This is typical of active firewall filtering/SNI interception.';
      } else if (msg.contains('network is unreachable')) {
        diagMsg = 'Network unreachable.';
      }

      return WebsiteReachabilityResult(
        name: name,
        domain: domain,
        status: status,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails: 'Socket Exception: $e\n$diagMsg',
      );
    } catch (e) {
      stopwatch.stop();
      return WebsiteReachabilityResult(
        name: name,
        domain: domain,
        status: ReachabilityStatus.blocked,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails: 'Unclassified network error: $e',
      );
    }
  }

  /// 9. Test reachability of a social media platform using primary and secondary endpoints.
  static Future<SocialMediaResult> testSocialMediaAccessibility({
    required String name,
    required String primaryDomain,
    required String secondaryDomain,
  }) async {
    // Run both queries concurrently to optimize scanning speed!
    final results = await Future.wait([
      testWebsiteReachability('$name Web Portal', primaryDomain),
      testWebsiteReachability('$name API/CDN Gateway', secondaryDomain),
    ]);

    final primary = results[0];
    final secondary = results[1];

    final primarySuccess = primary.status == ReachabilityStatus.reachable;
    final secondarySuccess = secondary.status == ReachabilityStatus.reachable;

    SocialMediaStatus status;
    if (primarySuccess && secondarySuccess) {
      status = SocialMediaStatus.accessible;
    } else if (primarySuccess || secondarySuccess) {
      status = SocialMediaStatus.partial;
    } else {
      status = SocialMediaStatus.blocked;
    }

    int? averageLatency;
    if (primary.latencyMs != null && secondary.latencyMs != null) {
      averageLatency = ((primary.latencyMs! + secondary.latencyMs!) / 2)
          .round();
    } else {
      averageLatency = primary.latencyMs ?? secondary.latencyMs;
    }

    return SocialMediaResult(
      name: name,
      status: status,
      latencyMs: averageLatency,
      primaryResult: primary,
      secondaryResult: secondary,
    );
  }

  /// Scans a list of CDN range IPs in parallel to verify reachability and latency.
  static Future<CdnIpScanResult> scanCdnIps(
    List<String> ips, {
    int port = 443,
    int maxConcurrency = 300,
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    if (ips.isEmpty) {
      return CdnIpScanResult(
        totalTested: 0,
        reachable: 0,
        averageLatencyMs: 0,
      );
    }

    int index = 0;
    int reachable = 0;
    int latencySum = 0;
    int latencyCount = 0;

    Future<void> runWorker() async {
      while (index < ips.length) {
        final ip = ips[index++];
        final stopwatch = Stopwatch()..start();
        Socket? socket;
        try {
          socket = await Socket.connect(ip, port, timeout: timeout);
          stopwatch.stop();
          reachable++;
          latencySum += stopwatch.elapsedMilliseconds;
          latencyCount++;
        } catch (_) {
          stopwatch.stop();
        } finally {
          socket?.destroy();
        }
      }
    }

    final List<Future<void>> workers = List.generate(
      ips.length < maxConcurrency ? ips.length : maxConcurrency,
      (_) => runWorker(),
    );

    await Future.wait(workers);

    return CdnIpScanResult(
      totalTested: ips.length,
      reachable: reachable,
      averageLatencyMs: latencyCount > 0 ? (latencySum / latencyCount).round() : 0,
    );
  }
}

/// Model holding GeoIP details retrieved via API
class IpGeoInfo {
  final String ipAddress;
  final String countryName;
  final String cityName;
  final String ispName;

  IpGeoInfo({
    required this.ipAddress,
    this.countryName = 'Unknown Country',
    this.cityName = 'Unknown City',
    this.ispName = 'Unknown ISP',
  });

  factory IpGeoInfo.fromJson(Map<String, dynamic> json) {
    return IpGeoInfo(
      ipAddress: json['ipAddress'] as String? ?? '',
      countryName: json['countryName'] as String? ?? 'Unknown Country',
      cityName: json['cityName'] as String? ?? 'Unknown City',
      ispName: json['asName'] as String? ?? 'Unknown ISP',
    );
  }

  @override
  String toString() => '$countryName, $cityName ($ispName)';
}

/// Enum holding possible reachability profiles
enum ReachabilityStatus { reachable, blocked, timeout, dnsFailure, tlsFailure }

/// Result model for a single website reachability test
class WebsiteReachabilityResult {
  final String name;
  final String domain;
  final ReachabilityStatus status;
  final int? latencyMs;
  final String? errorDetails;
  final int? statusCode;

  WebsiteReachabilityResult({
    required this.name,
    required this.domain,
    required this.status,
    this.latencyMs,
    this.errorDetails,
    this.statusCode,
  });
}

/// Enum holding possible social media accessibility profiles
enum SocialMediaStatus { accessible, partial, blocked }

/// Result model for a single social media platform reachability test
class SocialMediaResult {
  final String name;
  final SocialMediaStatus status;
  final int? latencyMs;
  final WebsiteReachabilityResult primaryResult;
  final WebsiteReachabilityResult secondaryResult;

  SocialMediaResult({
    required this.name,
    required this.status,
    this.latencyMs,
    required this.primaryResult,
    required this.secondaryResult,
  });
}

class DnsAnalysisProvider {
  final String name;
  final String address;
  final bool usesSystemResolver;

  const DnsAnalysisProvider({
    required this.name,
    required this.address,
    this.usesSystemResolver = false,
  });
}

class DnsQueryAnalysisResult {
  final String domain;
  final bool success;
  final bool isNxDomain;
  final List<String> ipAddresses;
  final int? latencyMs;
  final String? error;
  final List<String> suspiciousReasons;

  DnsQueryAnalysisResult({
    required this.domain,
    required this.success,
    required this.isNxDomain,
    required this.ipAddresses,
    this.latencyMs,
    this.error,
    this.suspiciousReasons = const [],
  });
}

class DnsProviderAnalysisResult {
  final DnsAnalysisProvider provider;
  final List<DnsQueryAnalysisResult> queryResults;
  final double successRate;
  final int? averageLatencyMs;

  DnsProviderAnalysisResult({
    required this.provider,
    required this.queryResults,
    required this.successRate,
    this.averageLatencyMs,
  });

  DnsQueryAnalysisResult? queryForDomain(String domain) {
    for (final result in queryResults) {
      if (result.domain == domain) return result;
    }
    return null;
  }
}

class DnsAnalysisSummary {
  final List<DnsProviderAnalysisResult> providerResults;
  final List<String> testedDomains;
  final int? averageLatencyMs;
  final double consistencyScore;
  final int tamperingScore;
  final List<String> findings;
  final bool success;

  DnsAnalysisSummary({
    required this.providerResults,
    required this.testedDomains,
    required this.averageLatencyMs,
    required this.consistencyScore,
    required this.tamperingScore,
    required this.findings,
    required this.success,
  });

  int get successfulProviders =>
      providerResults.where((result) => result.successRate > 0).length;

  String get consistencyLabel {
    if (consistencyScore >= 0.85) return 'High';
    if (consistencyScore >= 0.6) return 'Mixed';
    return 'Low';
  }
}

class TlsAnalysisTarget {
  final String domain;
  final String expectedIp;

  const TlsAnalysisTarget({required this.domain, required this.expectedIp});

  bool get shouldTraceCloudflare =>
      expectedIp.startsWith('104.') ||
      expectedIp.startsWith('162.159.') ||
      expectedIp.startsWith('172.64.') ||
      expectedIp.startsWith('188.114.');
}

class CloudflareTraceResult {
  final bool traceAvailable;
  final String? traceIp;
  final String? expectedPublicIp;
  final bool? traceMatchesPublicIp;
  final String? colo;
  final String? httpProtocol;
  final String? tlsProtocol;
  final int? latencyMs;
  final String? error;

  CloudflareTraceResult({
    required this.traceAvailable,
    this.traceIp,
    this.expectedPublicIp,
    this.traceMatchesPublicIp,
    this.colo,
    this.httpProtocol,
    this.tlsProtocol,
    this.latencyMs,
    this.error,
  });
}

class TlsAnalysisResult {
  final TlsAnalysisTarget target;
  final bool handshakeSuccess;
  final int? handshakeLatencyMs;
  final String tlsVersion;
  final bool certificateValid;
  final bool certificateMismatch;
  final String? certificateSubject;
  final String? certificateIssuer;
  final DateTime? certificateStart;
  final DateTime? certificateEnd;
  final List<String> resolvedIps;
  final CloudflareTraceResult? traceResult;
  final int tamperingScore;
  final List<String> findings;
  final String? error;

  TlsAnalysisResult({
    required this.target,
    required this.handshakeSuccess,
    required this.handshakeLatencyMs,
    required this.tlsVersion,
    required this.certificateValid,
    required this.certificateMismatch,
    required this.certificateSubject,
    required this.certificateIssuer,
    required this.certificateStart,
    required this.certificateEnd,
    required this.resolvedIps,
    required this.traceResult,
    required this.tamperingScore,
    required this.findings,
    this.error,
  });
}

class TlsAnalysisSummary {
  final List<TlsAnalysisResult> results;
  final int successfulHandshakes;
  final int validCertificates;
  final int certificateMismatches;
  final int traceMismatches;
  final int? averageHandshakeLatencyMs;
  final int averageTamperingScore;
  final List<String> findings;
  final bool success;

  TlsAnalysisSummary({
    required this.results,
    required this.successfulHandshakes,
    required this.validCertificates,
    required this.certificateMismatches,
    required this.traceMismatches,
    required this.averageHandshakeLatencyMs,
    required this.averageTamperingScore,
    required this.findings,
    required this.success,
  });
}

class _ParsedDnsResponse {
  final int rcode;
  final bool isNxDomain;
  final List<String> ipAddresses;

  _ParsedDnsResponse({
    required this.rcode,
    required this.isNxDomain,
    required this.ipAddresses,
  });
}

class _SocketTestResult {
  final String name;
  final String address;
  final int port;
  final bool success;
  final int? latencyMs;
  final String? localAddress;
  final int? localPort;
  final String? error;

  _SocketTestResult({
    required this.name,
    required this.address,
    required this.port,
    required this.success,
    this.latencyMs,
    this.localAddress,
    this.localPort,
    this.error,
  });
}

class _HttpsTestResult {
  final String url;
  final bool success;
  final int? statusCode;
  final int? latencyMs;
  final String? error;

  _HttpsTestResult({
    required this.url,
    required this.success,
    this.statusCode,
    this.latencyMs,
    this.error,
  });
}

class _DnsTestResult {
  final String host;
  final bool success;
  final List<String> ipAddresses;
  final int? latencyMs;
  final String? error;

  _DnsTestResult({
    required this.host,
    required this.success,
    required this.ipAddresses,
    this.latencyMs,
    this.error,
  });
}

class CdnIpScanResult {
  final int totalTested;
  final int reachable;
  final int averageLatencyMs;

  CdnIpScanResult({
    required this.totalTested,
    required this.reachable,
    required this.averageLatencyMs,
  });

  double get accessibilityRate => totalTested > 0 ? reachable / totalTested : 0;
}

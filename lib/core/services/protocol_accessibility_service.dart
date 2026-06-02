import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_curl/flutter_curl.dart' as curl;

/// Detailed result of a single domain check within a protocol test
class ProtocolTestResult {
  final String domain;
  final bool success;
  final int? latencyMs;
  final String? errorMessage;
  final String? details;

  const ProtocolTestResult({
    required this.domain,
    required this.success,
    this.latencyMs,
    this.errorMessage,
    this.details,
  });

  Map<String, dynamic> toMap() => {
        'domain': domain,
        'success': success,
        'latencyMs': latencyMs,
        'errorMessage': errorMessage,
        'details': details,
      };
}

/// Consolidated accessibility summary for a specific protocol
class ProtocolAccessibilitySummary {
  final String protocolName;
  final bool isSupported;
  final bool isBlocked; // All domains failed, but overall network is active
  final List<ProtocolTestResult> results;
  final String description;

  const ProtocolAccessibilitySummary({
    required this.protocolName,
    required this.isSupported,
    required this.isBlocked,
    required this.results,
    required this.description,
  });

  int get successfulCount => results.where((r) => r.success).length;
  int get failedCount => results.length - successfulCount;
  
  int get averageLatencyMs {
    final latencies = results
        .where((r) => r.success && r.latencyMs != null)
        .map((r) => r.latencyMs!)
        .toList();
    if (latencies.isEmpty) return 0;
    return (latencies.reduce((a, b) => a + b) / latencies.length).round();
  }
}

/// Service that executes protocol accessibility checks across multiple domains.
class ProtocolAccessibilityService {
  static const Duration defaultTimeout = Duration(seconds: 4);

  // ── 1. TCP HTTP Test ───────────────────────────────────────────────────────
  static Future<ProtocolTestResult> testHttpDomain(String domain, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    final client = http.Client();
    try {
      final uri = Uri.parse('http://$domain');
      // Set short connection timeout via head/get requests
      final response = await client
          .head(uri)
          .timeout(timeout);
      stopwatch.stop();

      return ProtocolTestResult(
        domain: domain,
        success: true,
        latencyMs: stopwatch.elapsedMilliseconds,
        details: 'HTTP Status: ${response.statusCode}\nHeaders: ${response.headers.keys.take(5).join(', ')}',
      );
    } catch (_) {
      try {
        // Fallback to GET if HEAD method is unsupported by server
        final uri = Uri.parse('http://$domain');
        final response = await client
            .get(uri)
            .timeout(timeout);
        stopwatch.stop();

        return ProtocolTestResult(
          domain: domain,
          success: true,
          latencyMs: stopwatch.elapsedMilliseconds,
          details: 'HTTP Status: ${response.statusCode}',
        );
      } catch (e) {
        stopwatch.stop();
        return ProtocolTestResult(
          domain: domain,
          success: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: _formatError(e),
        );
      }
    } finally {
      client.close();
    }
  }

  // ── 2. TCP HTTPS Test ──────────────────────────────────────────────────────
  static Future<ProtocolTestResult> testHttpsDomain(String domain, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    final client = http.Client();
    try {
      final uri = Uri.parse('https://$domain');
      final response = await client
          .head(uri)
          .timeout(timeout);
      stopwatch.stop();

      return ProtocolTestResult(
        domain: domain,
        success: true,
        latencyMs: stopwatch.elapsedMilliseconds,
        details: 'HTTPS Status: ${response.statusCode}\nHeaders: ${response.headers.keys.take(5).join(', ')}',
      );
    } catch (_) {
      try {
        final uri = Uri.parse('https://$domain');
        final response = await client
            .get(uri)
            .timeout(timeout);
        stopwatch.stop();

        return ProtocolTestResult(
          domain: domain,
          success: true,
          latencyMs: stopwatch.elapsedMilliseconds,
          details: 'HTTPS Status: ${response.statusCode}',
        );
      } catch (e) {
        stopwatch.stop();
        return ProtocolTestResult(
          domain: domain,
          success: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: _formatError(e),
        );
      }
    } finally {
      client.close();
    }
  }

  // ── 3. UDP Test (DNS / NTP) ────────────────────────────────────────────────
  static Future<ProtocolTestResult> testUdpDomain(String domain, Duration timeout) async {
    // If domain resembles an NTP server, we perform an NTP UDP request on port 123.
    // If it's a DNS server, we perform a DNS query on port 53.
    final isNtp = domain.contains('time') || domain.contains('pool.ntp');
    if (isNtp) {
      return _testNtpUdp(domain, timeout);
    } else {
      return _testDnsUdp(domain, timeout);
    }
  }

  static Future<ProtocolTestResult> _testNtpUdp(String host, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    RawDatagramSocket? socket;
    try {
      final addresses = await InternetAddress.lookup(host).timeout(timeout);
      if (addresses.isEmpty) {
        return ProtocolTestResult(
          domain: host,
          success: false,
          errorMessage: 'DNS resolution returned no IPs',
        );
      }
      final ip = addresses.first;
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final completer = Completer<bool>();
      Timer? timer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete(false);
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null && dg.data.length >= 48) {
            if (!completer.isCompleted) completer.complete(true);
          }
        }
      });

      // 48-byte NTP client request packet
      final buffer = List<int>.filled(48, 0);
      buffer[0] = 0x1B; // LI = 0, VN = 3, Mode = 3 (Client)
      socket.send(buffer, ip, 123);

      final ok = await completer.future;
      stopwatch.stop();
      timer.cancel();

      if (ok) {
        return ProtocolTestResult(
          domain: '$host (NTP UDP:123)',
          success: true,
          latencyMs: stopwatch.elapsedMilliseconds,
          details: 'Successfully received 48-byte NTP response from $ip',
        );
      } else {
        return ProtocolTestResult(
          domain: '$host (NTP UDP:123)',
          success: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'UDP query timed out',
        );
      }
    } catch (e) {
      stopwatch.stop();
      return ProtocolTestResult(
        domain: '$host (NTP UDP:123)',
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: _formatError(e),
      );
    } finally {
      socket?.close();
    }
  }

  static Future<ProtocolTestResult> _testDnsUdp(String host, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    RawDatagramSocket? socket;
    try {
      InternetAddress ip;
      final parsed = InternetAddress.tryParse(host);
      if (parsed != null) {
        ip = parsed;
      } else {
        final addresses = await InternetAddress.lookup(host).timeout(timeout);
        if (addresses.isEmpty) {
          return ProtocolTestResult(
            domain: host,
            success: false,
            errorMessage: 'DNS resolution returned no IPs',
          );
        }
        ip = addresses.first;
      }

      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final completer = Completer<List<int>?>();
      final txId = Random().nextInt(0xffff);
      Timer? timer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete(null);
      });

      socket.listen((event) {
        if (event != RawSocketEvent.read || completer.isCompleted) return;
        final datagram = socket?.receive();
        if (datagram == null || datagram.data.length < 12) return;
        final responseId = (datagram.data[0] << 8) | datagram.data[1];
        if (responseId == txId) {
          completer.complete(datagram.data);
        }
      });

      // Simple DNS query payload for google.com (Type A)
      final query = _buildDnsQuery('google.com', txId);
      socket.send(query, ip, 53);

      final responseBytes = await completer.future;
      stopwatch.stop();
      timer.cancel();

      if (responseBytes != null) {
        return ProtocolTestResult(
          domain: '$host (DNS UDP:53)',
          success: true,
          latencyMs: stopwatch.elapsedMilliseconds,
          details: 'Successfully resolved google.com via UDP DNS query (Length: ${responseBytes.length} bytes)',
        );
      } else {
        return ProtocolTestResult(
          domain: '$host (DNS UDP:53)',
          success: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'UDP query timed out',
        );
      }
    } catch (e) {
      stopwatch.stop();
      return ProtocolTestResult(
        domain: '$host (DNS UDP:53)',
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: _formatError(e),
      );
    } finally {
      socket?.close();
    }
  }

  // ── 4. QUIC / HTTP/3 Test ──────────────────────────────────────────────────
  static Future<ProtocolTestResult> testHttp3Domain(String domain, Duration timeout) async {
    final stopwatch = Stopwatch()..start();

    if (Platform.isAndroid) {
      // Use flutter_curl on Android (with forced HTTPVersion.http3)
      curl.Client? curlClient;
      try {
        curlClient = curl.Client(verifySSL: false, verbose: false);
        await curlClient.init();

        final request = curl.Request(
          url: 'https://$domain',
          method: 'GET',
          httpVersions: [curl.HTTPVersion.http3],
          verifySSL: false,
          connectTimeout: timeout,
          timeout: timeout + const Duration(seconds: 2),
        );

        final response = await curlClient.send(request).timeout(timeout + const Duration(seconds: 3));
        stopwatch.stop();

        final hasHttp3 = response.httpVersion == curl.HTTPVersion.http3;
        final details = 'Resolved HTTP Version: ${response.httpVersion}\nStatus: ${response.statusCode}\nIs HTTP/3: $hasHttp3';
        
        if (response.errorCode != null && response.errorCode != 0) {
          final errorMsg = response.errorMessage ?? 'curl error code ${response.errorCode}';
          return ProtocolTestResult(
            domain: domain,
            success: false,
            latencyMs: stopwatch.elapsedMilliseconds,
            errorMessage: 'libcurl error: $errorMsg',
            details: details,
          );
        }

        return ProtocolTestResult(
          domain: domain,
          success: true,
          latencyMs: stopwatch.elapsedMilliseconds,
          details: details,
        );
      } catch (e) {
        stopwatch.stop();
        return ProtocolTestResult(
          domain: domain,
          success: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'libcurl exception: ${_formatError(e)}',
        );
      } finally {
        if (curlClient != null) {
          try {
            curlClient.dispose();
          } catch (_) {}
        }
      }
    } else {
      // Desktop: use local system curl process with --http3-only
      try {
        final result = await Process.run(
          'curl',
          [
            '-I',
            '-s',
            '--http3-only',
            '--connect-timeout',
            timeout.inSeconds.toString(),
            '--max-time',
            (timeout.inSeconds + 2).toString(),
            '-k',
            'https://$domain',
          ],
        ).timeout(timeout + const Duration(seconds: 3));
        stopwatch.stop();

        final stdout = result.stdout.toString().trim();
        final stderr = result.stderr.toString().trim();
        final success = result.exitCode == 0 && (stdout.contains('HTTP/3') || stdout.contains('HTTP/2') || stdout.contains('200'));

        if (success) {
          final lines = stdout.split('\n');
          final protocolHeader = lines.isNotEmpty ? lines[0] : 'HTTP/3';
          return ProtocolTestResult(
            domain: domain,
            success: true,
            latencyMs: stopwatch.elapsedMilliseconds,
            details: 'curl output: $protocolHeader\nFull headers:\n${lines.take(3).join('\n')}',
          );
        } else {
          final errorMsg = stderr.isNotEmpty ? stderr : 'Exit code: ${result.exitCode}\nOutput: $stdout';
          return ProtocolTestResult(
            domain: domain,
            success: false,
            latencyMs: stopwatch.elapsedMilliseconds,
            errorMessage: 'HTTP/3 handshake failed',
            details: errorMsg,
          );
        }
      } catch (e) {
        stopwatch.stop();
        return ProtocolTestResult(
          domain: domain,
          success: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'curl command execution failed: ${_formatError(e)}',
        );
      }
    }
  }

  // ── 5. WebSocket Test ──────────────────────────────────────────────────────
  static Future<ProtocolTestResult> testWebSocketDomain(String url, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    WebSocket? socket;
    try {
      socket = await WebSocket.connect(url)
          .timeout(timeout);
      stopwatch.stop();
      
      final subProtocol = socket.protocol ?? 'None';
      await socket.close();

      return ProtocolTestResult(
        domain: url,
        success: true,
        latencyMs: stopwatch.elapsedMilliseconds,
        details: 'Handshake completed.\nSub-protocol: $subProtocol',
      );
    } catch (e) {
      stopwatch.stop();
      return ProtocolTestResult(
        domain: url,
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: _formatError(e),
      );
    }
  }

  // ── 6. DNS-over-HTTPS (DoH) Test ───────────────────────────────────────────
  static Future<ProtocolTestResult> testDoHDomain(String domain, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    final client = http.Client();
    try {
      // Perform GET query resolving google.com
      Uri uri;
      Map<String, String> headers = {};
      if (domain.contains('dns.google')) {
        uri = Uri.parse('https://$domain/resolve?name=google.com&type=A');
      } else {
        uri = Uri.parse('https://$domain/dns-query?name=google.com&type=A');
        headers = {'Accept': 'application/dns-json'};
      }

      final response = await client
          .get(uri, headers: headers)
          .timeout(timeout);
      stopwatch.stop();

      if (response.statusCode == 200) {
        final body = response.body;
        // Parse a sample field from JSON
        bool parsed = false;
        try {
          final data = jsonDecode(body) as Map<String, dynamic>;
          if (data.containsKey('Answer') || data.containsKey('Status')) {
            parsed = true;
          }
        } catch (_) {}

        if (parsed) {
          return ProtocolTestResult(
            domain: domain,
            success: true,
            latencyMs: stopwatch.elapsedMilliseconds,
            details: 'Resolved DoH successfully (Status 200).\nPayload: ${body.length > 100 ? "${body.substring(0, 100)}..." : body}',
          );
        } else {
          return ProtocolTestResult(
            domain: domain,
            success: false,
            latencyMs: stopwatch.elapsedMilliseconds,
            errorMessage: 'Invalid JSON/DNS format returned',
            details: 'Status: ${response.statusCode}\nBody: $body',
          );
        }
      } else {
        return ProtocolTestResult(
          domain: domain,
          success: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'HTTP status ${response.statusCode}',
        );
      }
    } catch (e) {
      stopwatch.stop();
      return ProtocolTestResult(
        domain: domain,
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: _formatError(e),
      );
    } finally {
      client.close();
    }
  }

  // ── 7. DNS-over-TLS (DoT) Test ─────────────────────────────────────────────
  static Future<ProtocolTestResult> testDoTDomain(String domain, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    SecureSocket? socket;
    try {
      socket = await SecureSocket.connect(
        domain,
        853,
        timeout: timeout,
        // Accept self-signed certificates defensively since we only test port accessibility, 
        // but verify standard handshakes if possible
        onBadCertificate: (_) => true,
      );
      stopwatch.stop();

      final selectedProtocol = socket.selectedProtocol ?? 'None';
      socket.destroy();

      return ProtocolTestResult(
        domain: domain,
        success: true,
        latencyMs: stopwatch.elapsedMilliseconds,
        details: 'TLS handshake succeeded on port 853\nProtocol: $selectedProtocol',
      );
    } catch (e) {
      stopwatch.stop();
      return ProtocolTestResult(
        domain: domain,
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: _formatError(e),
      );
    }
  }

  // ── 8. ICMP (Ping) Test ────────────────────────────────────────────────────
  static Future<ProtocolTestResult> testIcmpDomain(String domain, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    try {
      String pingCmd = 'ping';
      List<String> args;

      if (Platform.isWindows) {
        args = ['-n', '1', '-w', timeout.inMilliseconds.toString(), domain];
      } else {
        // Linux/Android
        args = ['-c', '1', '-W', max(1, timeout.inSeconds).toString(), domain];
      }

      final result = await Process.run(pingCmd, args).timeout(timeout + const Duration(seconds: 1));
      stopwatch.stop();

      if (result.exitCode == 0) {
        final stdout = result.stdout.toString();
        // Parse latency from stdout if possible
        int? latency;
        try {
          final regex = RegExp(r'(time|time=)(\d+(\.\d+)?)ms');
          final match = regex.firstMatch(stdout);
          if (match != null) {
            latency = double.tryParse(match.group(2)!)?.round();
          }
        } catch (_) {}

        return ProtocolTestResult(
          domain: domain,
          success: true,
          latencyMs: latency ?? stopwatch.elapsedMilliseconds,
          details: stdout.trim(),
        );
      } else {
        final err = result.stderr.toString().trim();
        return ProtocolTestResult(
          domain: domain,
          success: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'Ping failed (Exit code: ${result.exitCode})',
          details: err.isNotEmpty ? err : result.stdout.toString().trim(),
        );
      }
    } catch (e) {
      stopwatch.stop();
      return ProtocolTestResult(
        domain: domain,
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: _formatError(e),
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static List<int> _buildDnsQuery(String domain, int transactionId) {
    final bytes = <int>[
      (transactionId >> 8) & 0xff,
      transactionId & 0xff,
      0x01, 0x00, // Flags (standard query)
      0x00, 0x01, // Questions: 1
      0x00, 0x00, // Answers: 0
      0x00, 0x00, // Authority RRs: 0
      0x00, 0x00, // Additional RRs: 0
    ];

    for (final label in domain.split('.')) {
      final encoded = ascii.encode(label);
      bytes.add(encoded.length);
      bytes.addAll(encoded);
    }

    bytes
      ..add(0x00) // Root label
      ..add(0x00)..add(0x01) // Type A (1)
      ..add(0x00)..add(0x01); // Class IN (1)

    return bytes;
  }

  static String _formatError(dynamic e) {
    if (e is TimeoutException) {
      return 'Request timed out';
    } else if (e is SocketException) {
      return e.osError?.message ?? e.message;
    } else if (e is HandshakeException) {
      return 'TLS Handshake failed: ${e.message}';
    }
    return e.toString();
  }
}

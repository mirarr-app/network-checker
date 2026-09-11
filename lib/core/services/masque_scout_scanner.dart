import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http2/http2.dart';

import '../../features/masque_scout/data/masque_ip_ranges.dart';

/// Protocols supported by Masque Scout
enum MasqueProtocol {
  h3('MASQUE H3 (QUIC / HTTP-3)', 'QUIC on UDP (default port 443)', 443),
  h2('MASQUE H2 (TLS / HTTP-2)', 'TLS + HTTP/2 on TCP (default port 443)', 443);

  final String displayName;
  final String description;
  final int defaultPort;

  const MasqueProtocol(this.displayName, this.description, this.defaultPort);
}

/// Result of a Masque Scout endpoint scan
class MasqueScoutResult {
  final String ip;
  final int port;
  final MasqueProtocol protocol;
  final bool success;
  final double? latencyMs;
  final String? details;
  final String? errorMessage;
  final DateTime timestamp;

  MasqueScoutResult({
    required this.ip,
    required this.port,
    required this.protocol,
    required this.success,
    this.latencyMs,
    this.details,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get endpoint => '$ip:$port';

  Map<String, dynamic> toMap() => {
        'ip': ip,
        'port': port,
        'protocol': protocol.name,
        'success': success,
        'latencyMs': latencyMs,
        'details': details,
        'errorMessage': errorMessage,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Configuration for Masque Scout
class MasqueScoutConfig {
  final MasqueProtocol protocol;
  final int? customPort;
  final bool multiPort;
  final List<int> ports;
  final Duration timeout;
  final int maxWorkers;
  final String sni;

  const MasqueScoutConfig({
    this.protocol = MasqueProtocol.h3,
    this.customPort,
    this.multiPort = false,
    this.ports = MasqueIpRanges.masquePorts,
    this.timeout = const Duration(seconds: 4),
    this.maxWorkers = 15,
    this.sni = 'cloudflareaccess.com',
  });

  int get defaultPort => customPort ?? protocol.defaultPort;

  MasqueScoutConfig copyWith({
    MasqueProtocol? protocol,
    int? customPort,
    bool? multiPort,
    List<int>? ports,
    Duration? timeout,
    int? maxWorkers,
    String? sni,
  }) {
    return MasqueScoutConfig(
      protocol: protocol ?? this.protocol,
      customPort: customPort ?? this.customPort,
      multiPort: multiPort ?? this.multiPort,
      ports: ports ?? this.ports,
      timeout: timeout ?? this.timeout,
      maxWorkers: maxWorkers ?? this.maxWorkers,
      sni: sni ?? this.sni,
    );
  }
}

/// Progress information for Masque Scout
class MasqueScoutProgress {
  final MasqueScoutResult? result;
  final int completed;
  final int total;
  final int successful;
  final List<MasqueScoutResult> workingEndpoints;

  MasqueScoutProgress({
    this.result,
    required this.completed,
    required this.total,
    required this.successful,
    required this.workingEndpoints,
  });

  double get progress => total > 0 ? completed / total : 0;
  int get remaining => total - completed;
  bool get isComplete => completed >= total;
  int get failed => completed - successful;
}

/// Scanner engine for Cloudflare MASQUE endpoints
class MasqueScoutScanner {
  final MasqueScoutConfig config;

  MasqueScoutScanner({MasqueScoutConfig? config})
      : config = config ?? const MasqueScoutConfig();

  /// Parse input text supporting single IPs, IPs with ports, and CIDR subnets.
  /// If [multiPort] is true, addresses without explicit ports will be expanded
  /// into endpoints for each port in [multiPorts] (defaults to Aether MASQUE_PORTS).
  static List<String> parseEndpointInput(
    String input, {
    int defaultPort = 443,
    bool multiPort = false,
    List<int>? multiPorts,
  }) {
    final activePorts = multiPort ? (multiPorts ?? MasqueIpRanges.masquePorts) : [defaultPort];
    final endpoints = <String>[];
    final lines = input.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.contains('/')) {
        // CIDR subnet notation
        try {
          final ips = _generateIpsFromSubnet(line);
          for (final ip in ips) {
            for (final port in activePorts) {
              endpoints.add('$ip:$port');
            }
          }
        } catch (_) {}
      } else {
        // Single address or address with port
        String host = line;
        int? explicitPort;

        if (line.startsWith('[')) {
          final closeBracket = line.indexOf(']');
          if (closeBracket != -1) {
            host = line.substring(1, closeBracket);
            final colonAfter = line.indexOf(':', closeBracket);
            if (colonAfter != -1) {
              explicitPort = int.tryParse(line.substring(colonAfter + 1));
              if (explicitPort == null || explicitPort <= 0 || explicitPort > 65535) {
                continue; // invalid port
              }
            }
          } else {
            continue; // malformed bracket
          }
        } else {
          final colonIdx = line.lastIndexOf(':');
          if (colonIdx != -1) {
            final possiblePort = int.tryParse(line.substring(colonIdx + 1));
            if (possiblePort != null && possiblePort > 0 && possiblePort <= 65535) {
              final ipPart = line.substring(0, colonIdx);
              if (InternetAddress.tryParse(ipPart) != null) {
                host = ipPart;
                explicitPort = possiblePort;
              }
            }
          }
        }

        // Validate host is a valid IP
        if (InternetAddress.tryParse(host) == null) {
          continue;
        }

        final isV6 = host.contains(':');
        final formattedHost = isV6 ? '[$host]' : host;

        if (explicitPort != null) {
          endpoints.add('$formattedHost:$explicitPort');
        } else {
          for (final port in activePorts) {
            endpoints.add('$formattedHost:$port');
          }
        }
      }
    }

    return endpoints;
  }

  /// Generate list of IPs from a subnet in CIDR notation
  static List<String> _generateIpsFromSubnet(String subnet) {
    final parts = subnet.split('/');
    if (parts.length != 2) return [];

    final ipStr = parts[0];
    final prefixLength = int.tryParse(parts[1]);
    if (prefixLength == null || prefixLength < 0 || prefixLength > 32) return [];

    final ipParts = ipStr.split('.');
    if (ipParts.length != 4) return [];

    final octets = ipParts.map((p) => int.tryParse(p)).toList();
    if (octets.any((o) => o == null || o < 0 || o > 255)) return [];

    int ipInt = 0;
    for (var i = 0; i < 4; i++) {
      ipInt = (ipInt << 8) | octets[i]!;
    }

    final hostBits = 32 - prefixLength;
    final numHosts = 1 << hostBits;
    final netmask = ~((1 << hostBits) - 1) & 0xFFFFFFFF;
    final networkAddr = ipInt & netmask;

    final ips = <String>[];
    final start = prefixLength >= 31 ? 0 : 1;
    final end = prefixLength >= 31 ? numHosts : numHosts - 1;

    for (var i = start; i < end; i++) {
      final addr = networkAddr + i;
      final ip =
          '${(addr >> 24) & 0xFF}.${(addr >> 16) & 0xFF}.${(addr >> 8) & 0xFF}.${addr & 0xFF}';
      ips.add(ip);
    }

    return ips;
  }

  /// Safely extracts target IP and Port without mangling IPv6 addresses
  (String, int) _getTargetIpAndPort(String endpoint) {
    final trimmed = endpoint.trim();
    // 1. If it parses directly as IP (v4 or v6), no port was attached
    if (InternetAddress.tryParse(trimmed) != null) {
      return (trimmed, config.defaultPort);
    }
    // 2. Bracketed IPv6 format: [2606:4700::1]:443 or [2606:4700::1]
    if (trimmed.startsWith('[')) {
      final closeBracket = trimmed.indexOf(']');
      if (closeBracket != -1) {
        final ip = trimmed.substring(1, closeBracket);
        final colonAfter = trimmed.indexOf(':', closeBracket);
        final port = colonAfter != -1
            ? int.tryParse(trimmed.substring(colonAfter + 1)) ?? config.defaultPort
            : config.defaultPort;
        return (ip, port);
      }
    }
    // 3. IPv4 format with port: 162.159.196.1:443
    final colonIdx = trimmed.lastIndexOf(':');
    if (colonIdx != -1) {
      final ipPart = trimmed.substring(0, colonIdx);
      final portPart = trimmed.substring(colonIdx + 1);
      final port = int.tryParse(portPart);
      if (port != null && InternetAddress.tryParse(ipPart) != null) {
        return (ipPart, port);
      }
    }
    return (trimmed, config.defaultPort);
  }

  // ── 1. MASQUE H2 (TLS + HTTP/2) Handshake ──────────────────────────────────

  /// Performs full TCP connect + TLS handshake with ALPN h2 + HTTP/2 frame exchange
  Future<MasqueScoutResult> testMasqueH2(String endpoint) async {
    final (targetIp, targetPort) = _getTargetIpAndPort(endpoint);
    final stopwatch = Stopwatch()..start();

    Socket? rawSocket;
    SecureSocket? secureSocket;
    ClientTransportConnection? transport;

    try {
      rawSocket = await Socket.connect(
        targetIp,
        targetPort,
        timeout: config.timeout,
      );
      rawSocket.setOption(SocketOption.tcpNoDelay, true);

      // Perform TLS handshake with ALPN [h2]
      secureSocket = await SecureSocket.secure(
        rawSocket,
        host: config.sni,
        supportedProtocols: ['h2'],
        onBadCertificate: (_) => true,
      ).timeout(config.timeout);

      final negotiatedProto = secureSocket.selectedProtocol;
      if (negotiatedProto != 'h2') {
        stopwatch.stop();
        return MasqueScoutResult(
          ip: targetIp,
          port: targetPort,
          protocol: MasqueProtocol.h2,
          success: false,
          latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
          errorMessage: 'TLS completed but negotiated $negotiatedProto instead of h2',
        );
      }

      // Establish HTTP/2 transport connection
      transport = ClientTransportConnection.viaSocket(secureSocket);

      final stream = transport.makeRequest([
        Header.ascii(':method', 'GET'),
        Header.ascii(':path', '/'),
        Header.ascii(':scheme', 'https'),
        Header.ascii(':authority', config.sni),
        Header.ascii('user-agent', 'MasqueScout'),
      ], endStream: true);

      final completer = Completer<int>();
      stream.incomingMessages.listen(
        (message) {
          if (message is HeadersStreamMessage) {
            for (final header in message.headers) {
              final name = String.fromCharCodes(header.name);
              final value = String.fromCharCodes(header.value);
              if (name == ':status') {
                final status = int.tryParse(value) ?? 0;
                if (!completer.isCompleted) completer.complete(status);
              }
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
      );

      final statusCode = await completer.future.timeout(config.timeout);
      stopwatch.stop();

      return MasqueScoutResult(
        ip: targetIp,
        port: targetPort,
        protocol: MasqueProtocol.h2,
        success: true,
        latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
        details: 'HTTP/2 negotiated & stream responded (Status: $statusCode)',
      );
    } catch (e) {
      stopwatch.stop();
      return MasqueScoutResult(
        ip: targetIp,
        port: targetPort,
        protocol: MasqueProtocol.h2,
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
        errorMessage: _formatError(e),
      );
    } finally {
      try {
        await transport?.finish();
      } catch (_) {}
      try {
        secureSocket?.destroy();
      } catch (_) {}
      try {
        rawSocket?.destroy();
      } catch (_) {}
    }
  }

  // ── 2. MASQUE H3 (QUIC / HTTP-3) Handshake ─────────────────────────────────

  /// Performs full QUIC v1 Initial handshake round-trip with TLS 1.3 ClientHello (ALPN h3)
  Future<MasqueScoutResult> testMasqueH3(
    String endpoint, {
    Uint8List? prebuiltPacket,
  }) async {
    final (targetIp, targetPort) = _getTargetIpAndPort(endpoint);
    final targetAddr = InternetAddress.tryParse(targetIp);
    if (targetAddr == null) {
      return MasqueScoutResult(
        ip: targetIp,
        port: targetPort,
        protocol: MasqueProtocol.h3,
        success: false,
        errorMessage: 'Invalid IP address: $targetIp',
      );
    }

    final stopwatch = Stopwatch()..start();
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;

    try {
      final isV6 = targetAddr.type == InternetAddressType.IPv6;
      socket = await RawDatagramSocket.bind(
        isV6 ? InternetAddress.anyIPv6 : InternetAddress.anyIPv4,
        0,
      ).timeout(config.timeout);

      final quicPacket = prebuiltPacket ?? await _buildQuicInitialPacket(sni: config.sni);

      final completer = Completer<Uint8List?>();
      subscription = socket.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            try {
              final dg = socket?.receive();
              if (dg != null && dg.data.isNotEmpty) {
                if (!completer.isCompleted) completer.complete(dg.data);
              }
            } catch (_) {}
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.complete(null);
        },
        cancelOnError: true,
      );

      socket.send(quicPacket, targetAddr, targetPort);

      final resp = await completer.future.timeout(config.timeout, onTimeout: () => null);
      stopwatch.stop();

      if (resp != null && resp.isNotEmpty) {
        final firstByte = resp[0];
        final isLongHeader = (firstByte & 0x80) != 0;
        final type = (firstByte & 0x30) >> 4;
        final typeDesc = switch (type) {
          0 => 'Initial (ServerHello)',
          1 => '0-RTT',
          2 => 'Handshake',
          3 => 'Retry',
          _ => 'Packet type $type',
        };

        if (isLongHeader) {
          return MasqueScoutResult(
            ip: targetIp,
            port: targetPort,
            protocol: MasqueProtocol.h3,
            success: true,
            latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
            details: 'QUIC v1 Long Header Handshake confirmed ($typeDesc, ${resp.length} bytes)',
          );
        } else {
          return MasqueScoutResult(
            ip: targetIp,
            port: targetPort,
            protocol: MasqueProtocol.h3,
            success: true,
            latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
            details: 'QUIC Short Header response received (${resp.length} bytes)',
          );
        }
      }

      return MasqueScoutResult(
        ip: targetIp,
        port: targetPort,
        protocol: MasqueProtocol.h3,
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
        errorMessage: 'QUIC handshake timed out (no UDP reply from server)',
      );
    } catch (e) {
      stopwatch.stop();
      return MasqueScoutResult(
        ip: targetIp,
        port: targetPort,
        protocol: MasqueProtocol.h3,
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
        errorMessage: _formatError(e),
      );
    } finally {
      try {
        await subscription?.cancel();
      } catch (_) {}
      try {
        socket?.close();
      } catch (_) {}
    }
  }

  /// Dispatch test based on protocol
  Future<MasqueScoutResult> testEndpoint(
    String endpoint, {
    Uint8List? prebuiltPacket,
  }) {
    switch (config.protocol) {
      case MasqueProtocol.h3:
        return testMasqueH3(endpoint, prebuiltPacket: prebuiltPacket);
      case MasqueProtocol.h2:
        return testMasqueH2(endpoint);
    }
  }

  /// Scan multiple endpoints concurrently emitting progress stream
  Stream<MasqueScoutProgress> scanEndpoints(List<String> endpoints) {
    final controller = StreamController<MasqueScoutProgress>();
    _runScan(endpoints, controller);
    return controller.stream;
  }

  Future<void> _runScan(
    List<String> endpoints,
    StreamController<MasqueScoutProgress> controller,
  ) async {
    if (endpoints.isEmpty) {
      await controller.close();
      return;
    }

    int completed = 0;
    int successful = 0;
    final total = endpoints.length;
    final results = <MasqueScoutResult>[];

    // Precompute QUIC packet once for H3 to eliminate repeating cryptography per endpoint
    Uint8List? precomputedH3Packet;
    try {
      if (config.protocol == MasqueProtocol.h3) {
        precomputedH3Packet = await _buildQuicInitialPacket(sni: config.sni);
      }
    } catch (_) {}

    // Batching based on maxWorkers
    final batches = <List<String>>[];
    for (var i = 0; i < endpoints.length; i += config.maxWorkers) {
      batches.add(
        endpoints.sublist(
          i,
          i + config.maxWorkers > endpoints.length ? endpoints.length : i + config.maxWorkers,
        ),
      );
    }

    try {
      for (final batch in batches) {
        if (controller.isClosed) break;

        final futures = batch.map((ep) {
          final packet = config.protocol == MasqueProtocol.h3 ? precomputedH3Packet : null;
          return testEndpoint(ep, prebuiltPacket: packet);
        });
        final batchResults = await Future.wait(futures);

        for (final result in batchResults) {
          if (controller.isClosed) break;

          completed++;
          if (result.success) {
            successful++;
            results.add(result);
          }

          controller.add(MasqueScoutProgress(
            result: result,
            completed: completed,
            total: total,
            successful: successful,
            workingEndpoints: List.unmodifiable(results),
          ));
        }

        // Yield to the event loop so Flutter UI and Android Choreographer can render smoothly
        await Future.delayed(const Duration(milliseconds: 16));
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

  // ── QUIC Packet Builder Helpers ─────────────────────────────────────────────

  static Future<Uint8List> _buildQuicInitialPacket({required String sni}) async {
    final rng = Random.secure();
    final dcid = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      dcid[i] = rng.nextInt(256);
    }
    final scid = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      scid[i] = rng.nextInt(256);
    }

    // RFC 9001 section 5.2 Initial Salt
    final initialSalt = Uint8List.fromList([
      0x38, 0x76, 0x2c, 0xf7, 0xf5, 0x59, 0x34, 0xb3,
      0x4d, 0x17, 0x9a, 0xe6, 0xa4, 0xc8, 0x0c, 0xad,
      0xcc, 0xbb, 0x7f, 0x0a,
    ]);

    final hmacSha256 = Hmac(Sha256());
    final initialSecret = (await hmacSha256.calculateMac(
      dcid,
      secretKey: SecretKey(initialSalt),
    )).bytes;

    final clientInitialSecret = await _hkdfExpandLabel(initialSecret, 'client in', Uint8List(0), 32);
    final key = await _hkdfExpandLabel(clientInitialSecret, 'quic key', Uint8List(0), 16);
    final iv = await _hkdfExpandLabel(clientInitialSecret, 'quic iv', Uint8List(0), 12);
    final hp = await _hkdfExpandLabel(clientInitialSecret, 'quic hp', Uint8List(0), 16);

    final clientHello = _buildTlsClientHello(sni: sni, rng: rng);

    final cryptoFrame = BytesBuilder();
    cryptoFrame.addByte(0x06); // Frame Type: CRYPTO
    cryptoFrame.addByte(0x00); // Offset: 0
    cryptoFrame.add(_encodeVarInt(clientHello.length));
    cryptoFrame.add(clientHello);

    final payloadBuilder = BytesBuilder();
    payloadBuilder.add(cryptoFrame.toBytes());

    const packetNumber = 0;
    const pnLength = 1;
    final headerLengthWithoutPn = 1 + 4 + 1 + dcid.length + 1 + scid.length + 1 + 2;
    const tagLength = 16;
    final neededPayloadLength = 1200 - headerLengthWithoutPn - pnLength - tagLength;
    if (neededPayloadLength > payloadBuilder.length) {
      payloadBuilder.add(Uint8List(neededPayloadLength - payloadBuilder.length));
    }

    final plaintext = payloadBuilder.toBytes();
    final totalLengthField = pnLength + plaintext.length + tagLength;

    final header = BytesBuilder();
    header.addByte(0xC0 | (pnLength - 1));
    header.add([0x00, 0x00, 0x00, 0x01]); // Version: QUIC v1
    header.addByte(dcid.length);
    header.add(dcid);
    header.addByte(scid.length);
    header.add(scid);
    header.addByte(0x00); // Token length: 0
    header.add([0x40 | ((totalLengthField >> 8) & 0x3F), totalLengthField & 0xFF]);

    final headerBytes = header.toBytes();

    final nonce = Uint8List.fromList(iv);
    nonce[11] ^= packetNumber;

    final aad = Uint8List.fromList([...headerBytes, packetNumber]);

    final aesGcm = AesGcm.with128bits();
    final secretBox = await aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: aad,
    );
    final ciphertext = Uint8List.fromList([...secretBox.cipherText, ...secretBox.mac.bytes]);

    final sample = ciphertext.sublist(4 - pnLength, 20 - pnLength);
    final mask = _aes128EncryptBlock(hp, sample);

    final protectedFirstByte = headerBytes[0] ^ (mask[0] & 0x0F);
    final protectedPn = packetNumber ^ mask[1];

    final result = BytesBuilder();
    result.addByte(protectedFirstByte);
    result.add(headerBytes.sublist(1));
    result.addByte(protectedPn);
    result.add(ciphertext);

    return result.toBytes();
  }

  static Future<Uint8List> _hkdfExpandLabel(
    List<int> secret,
    String label,
    List<int> context,
    int length,
  ) async {
    final hmac = Hmac(Sha256());
    final prefix = utf8.encode('tls13 ');
    final labelBytes = utf8.encode(label);

    final info = BytesBuilder();
    info.add([length >> 8, length & 0xFF]);
    info.addByte(prefix.length + labelBytes.length);
    info.add(prefix);
    info.add(labelBytes);
    info.addByte(context.length);
    info.add(context);

    final t1 = (await hmac.calculateMac(
      [...info.toBytes(), 0x01],
      secretKey: SecretKey(secret),
    )).bytes;
    return Uint8List.fromList(t1.sublist(0, length));
  }

  static Uint8List _buildTlsClientHello({required String sni, required Random rng}) {
    final ch = BytesBuilder();
    final random = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      random[i] = rng.nextInt(256);
    }
    final sessionId = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      sessionId[i] = rng.nextInt(256);
    }

    final extensions = BytesBuilder();

    // 1. SNI
    final sniBytes = utf8.encode(sni);
    extensions.add([0x00, 0x00]);
    final sniExtLen = 2 + 1 + 2 + sniBytes.length;
    extensions.add([sniExtLen >> 8, sniExtLen & 0xFF]);
    extensions.add([(sniExtLen - 2) >> 8, (sniExtLen - 2) & 0xFF]);
    extensions.addByte(0x00);
    extensions.add([sniBytes.length >> 8, sniBytes.length & 0xFF]);
    extensions.add(sniBytes);

    // 2. Supported Groups (X25519)
    extensions.add([0x00, 0x0a, 0x00, 0x04, 0x00, 0x02, 0x00, 0x1d]);

    // 3. Supported Versions (TLS 1.3)
    extensions.add([0x00, 0x2b, 0x00, 0x03, 0x02, 0x03, 0x04]);

    // 4. ALPN ("h3")
    extensions.add([0x00, 0x10, 0x00, 0x05, 0x00, 0x03, 0x02, 0x68, 0x33]);

    // 5. Key Share (X25519)
    final keySharePub = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      keySharePub[i] = rng.nextInt(256);
    }
    extensions.add([0x00, 0x33, 0x00, 36, 0x00, 34, 0x00, 0x1d, 0x00, 32]);
    extensions.add(keySharePub);

    // 6. QUIC Transport Parameters
    final tp = [
      0x04, 0x04, 0x80, 0x0f, 0x42, 0x40, // initial_max_data: 1000000
      0x08, 0x02, 0x40, 0x64,             // initial_max_streams_bidi: 100
    ];
    extensions.add([0x00, 0x39, 0x00, tp.length]);
    extensions.add(tp);

    final extBytes = extensions.toBytes();

    final body = BytesBuilder();
    body.add([0x03, 0x03]); // client_version TLS 1.2
    body.add(random);
    body.addByte(sessionId.length);
    body.add(sessionId);
    body.add([0x00, 0x06, 0x13, 0x01, 0x13, 0x02, 0x13, 0x03]);
    body.add([0x01, 0x00]);
    body.add([extBytes.length >> 8, extBytes.length & 0xFF]);
    body.add(extBytes);

    final bodyBytes = body.toBytes();

    ch.addByte(0x01); // Handshake Type: ClientHello
    ch.add([0x00, (bodyBytes.length >> 8) & 0xFF, bodyBytes.length & 0xFF]);
    ch.add(bodyBytes);

    return ch.toBytes();
  }

  static List<int> _encodeVarInt(int value) {
    if (value < 64) {
      return [value];
    } else if (value < 16384) {
      return [0x40 | (value >> 8), value & 0xFF];
    } else if (value < 1073741824) {
      return [
        0x80 | (value >> 24),
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ];
    } else {
      return [
        0xC0 | (value >> 56),
        (value >> 48) & 0xFF,
        (value >> 40) & 0xFF,
        (value >> 32) & 0xFF,
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ];
    }
  }

  static Uint8List _aes128EncryptBlock(Uint8List key, Uint8List input) {
    final w = _keyExpansion(key);
    final state = Uint8List.fromList(input);

    _addRoundKey(state, w, 0);
    for (var round = 1; round < 10; round++) {
      _subBytes(state);
      _shiftRows(state);
      _mixColumns(state);
      _addRoundKey(state, w, round);
    }
    _subBytes(state);
    _shiftRows(state);
    _addRoundKey(state, w, 10);

    return state;
  }

  static const List<int> _sBox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
  ];

  static const List<int> _rCon = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
  ];

  static Uint32List _keyExpansion(Uint8List key) {
    final w = Uint32List(44);
    final bytes = ByteData.sublistView(key);
    for (var i = 0; i < 4; i++) {
      w[i] = bytes.getUint32(i * 4, Endian.big);
    }
    for (var i = 4; i < 44; i++) {
      var temp = w[i - 1];
      if (i % 4 == 0) {
        temp = ((temp << 8) | (temp >>> 24)) & 0xFFFFFFFF;
        temp = (_sBox[(temp >> 24) & 0xFF] << 24) |
               (_sBox[(temp >> 16) & 0xFF] << 16) |
               (_sBox[(temp >> 8) & 0xFF] << 8) |
               _sBox[temp & 0xFF];
        temp ^= (_rCon[i ~/ 4] << 24);
      }
      w[i] = (w[i - 4] ^ temp) & 0xFFFFFFFF;
    }
    return w;
  }

  static void _addRoundKey(Uint8List state, Uint32List w, int round) {
    for (var c = 0; c < 4; c++) {
      final word = w[round * 4 + c];
      state[c * 4 + 0] ^= (word >> 24) & 0xFF;
      state[c * 4 + 1] ^= (word >> 16) & 0xFF;
      state[c * 4 + 2] ^= (word >> 8) & 0xFF;
      state[c * 4 + 3] ^= word & 0xFF;
    }
  }

  static void _subBytes(Uint8List state) {
    for (var i = 0; i < 16; i++) {
      state[i] = _sBox[state[i]];
    }
  }

  static void _shiftRows(Uint8List s) {
    var t = s[1]; s[1] = s[5]; s[5] = s[9]; s[9] = s[13]; s[13] = t;
    t = s[2]; s[2] = s[10]; s[10] = t; t = s[6]; s[6] = s[14]; s[14] = t;
    t = s[15]; s[15] = s[11]; s[11] = s[7]; s[7] = s[3]; s[3] = t;
  }

  static int _xtimes(int b) => ((b << 1) ^ (((b >> 7) & 1) * 0x1b)) & 0xFF;

  static void _mixColumns(Uint8List s) {
    for (var c = 0; c < 4; c++) {
      final idx = c * 4;
      final a0 = s[idx], a1 = s[idx + 1], a2 = s[idx + 2], a3 = s[idx + 3];
      s[idx] = _xtimes(a0 ^ a1) ^ a1 ^ a2 ^ a3;
      s[idx + 1] = _xtimes(a1 ^ a2) ^ a2 ^ a3 ^ a0;
      s[idx + 2] = _xtimes(a2 ^ a3) ^ a3 ^ a0 ^ a1;
      s[idx + 3] = _xtimes(a3 ^ a0) ^ a0 ^ a1 ^ a2;
    }
  }

  static String _formatError(dynamic e) {
    if (e is TimeoutException) {
      return 'Connection timed out';
    } else if (e is SocketException) {
      return e.osError?.message ?? e.message;
    } else if (e is HandshakeException) {
      return 'TLS Handshake failed: ${e.message}';
    }
    return e.toString();
  }
}

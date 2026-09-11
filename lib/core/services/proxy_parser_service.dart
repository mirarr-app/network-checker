import 'dart:convert';

/// Data model representing parsed proxy details
class ParsedProxyNode {
  final String protocol; // 'vless', 'vmess', 'trojan', 'shadowsocks', 'socks', 'http'
  final String address;
  final int port;
  final String? idOrPassword;
  final String? alterId;
  final String? cipher;
  final String network; // 'tcp', 'ws', 'grpc', 'h2', 'kcp', 'quic', 'xhttp', 'splithttp'
  final String security; // 'none', 'tls', 'reality'
  final String? sni;
  final String? path;
  final String? host;
  final String? serviceName;
  final String? mode;
  final String? publicKey;
  final String? shortId;
  final String? spiderX;
  final String? fingerprint;
  final String? flow;
  final String? encryption;
  final List<String>? alpn;
  final String? headerType;
  final String remarks;
  final Map<String, dynamic>? finalmask;
  final Map<String, dynamic>? sockopt;
  final Map<String, dynamic>? xhttpSettings;
  final Map<String, dynamic>? extraStreamSettings;
  final Map<String, dynamic>? rawOutbound;

  ParsedProxyNode({
    required this.protocol,
    required this.address,
    required this.port,
    this.idOrPassword,
    this.alterId,
    this.cipher,
    this.network = 'tcp',
    this.security = 'none',
    this.sni,
    this.path,
    this.host,
    this.serviceName,
    this.mode,
    this.publicKey,
    this.shortId,
    this.spiderX,
    this.fingerprint,
    this.flow,
    this.encryption,
    this.alpn,
    this.headerType,
    required this.remarks,
    this.finalmask,
    this.sockopt,
    this.xhttpSettings,
    this.extraStreamSettings,
    this.rawOutbound,
  });

  /// Converts parsed proxy node to Xray outbound map
  Map<String, dynamic> toXrayOutbound({
    required String tag,
    String? dialerProxyTag,
  }) {
    if (rawOutbound != null) {
      // Retain raw outbound configuration with 100% fidelity
      final Map<String, dynamic> outbound =
          json.decode(json.encode(rawOutbound)) as Map<String, dynamic>;
      outbound['tag'] = tag;

      final streamSettings = Map<String, dynamic>.from(
        outbound['streamSettings'] as Map? ?? {},
      );

      final sockoptMap = Map<String, dynamic>.from(
        streamSettings['sockopt'] as Map? ?? {},
      );

      if (dialerProxyTag != null && dialerProxyTag.isNotEmpty) {
        // Chained hops (hop1..N): safely merge dialerProxy without wiping existing options
        sockoptMap['dialerProxy'] = dialerProxyTag;
        streamSettings['sockopt'] = sockoptMap;
      } else {
        // Entry node (hop0): ensure no residual dialerProxy exists
        sockoptMap.remove('dialerProxy');
        if (sockoptMap.isNotEmpty) {
          streamSettings['sockopt'] = sockoptMap;
        } else {
          streamSettings.remove('sockopt');
        }
      }

      outbound['streamSettings'] = streamSettings;
      return outbound;
    }

    final Map<String, dynamic> outbound = {
      'tag': tag,
      'protocol': protocol,
    };

    // Protocol settings
    if (protocol == 'vless') {
      final userMap = <String, dynamic>{
        'id': idOrPassword ?? '',
        'encryption': (encryption != null && encryption!.isNotEmpty) ? encryption : 'none',
      };
      if (flow != null && flow!.isNotEmpty) {
        userMap['flow'] = flow;
      }

      outbound['settings'] = {
        'vnext': [
          {
            'address': address,
            'port': port,
            'users': [userMap],
          }
        ],
      };
    } else if (protocol == 'vmess') {
      int parsedAlterId = 0;
      if (alterId != null) {
        parsedAlterId = int.tryParse(alterId!) ?? 0;
      }
      outbound['settings'] = {
        'vnext': [
          {
            'address': address,
            'port': port,
            'users': [
              {
                'id': idOrPassword ?? '',
                'alterId': parsedAlterId,
                'security': (cipher != null && cipher!.isNotEmpty) ? cipher : 'auto',
              }
            ],
          }
        ],
      };
    } else if (protocol == 'trojan') {
      outbound['settings'] = {
        'servers': [
          {
            'address': address,
            'port': port,
            'password': idOrPassword ?? '',
          }
        ],
      };
    } else if (protocol == 'shadowsocks') {
      outbound['settings'] = {
        'servers': [
          {
            'address': address,
            'port': port,
            'method': (cipher != null && cipher!.isNotEmpty) ? cipher : 'aes-256-gcm',
            'password': idOrPassword ?? '',
          }
        ],
      };
    } else if (protocol == 'socks') {
      final userList = <Map<String, dynamic>>[];
      if (idOrPassword != null && idOrPassword!.isNotEmpty) {
        userList.add({
          'user': idOrPassword,
          'pass': encryption ?? '',
        });
      }
      outbound['settings'] = {
        'servers': [
          {
            'address': address,
            'port': port,
            'users': userList,
          }
        ],
      };
    } else if (protocol == 'http') {
      final userList = <Map<String, dynamic>>[];
      if (idOrPassword != null && idOrPassword!.isNotEmpty) {
        userList.add({
          'user': idOrPassword,
          'pass': encryption ?? '',
        });
      }
      outbound['settings'] = {
        'servers': [
          {
            'address': address,
            'port': port,
            'users': userList,
          }
        ],
      };
    } else {
      throw FormatException('Unsupported protocol: $protocol');
    }

    // Stream settings
    final normalizedNet = (network == 'splithttp') ? 'xhttp' : network;
    final Map<String, dynamic> streamSettings = {
      'network': normalizedNet,
      'security': security,
    };

    if (security == 'tls') {
      final Map<String, dynamic> tlsSettings = {};
      if (sni != null && sni!.isNotEmpty) {
        tlsSettings['serverName'] = sni;
      }
      if (alpn != null && alpn!.isNotEmpty) {
        tlsSettings['alpn'] = alpn;
      }
      if (fingerprint != null && fingerprint!.isNotEmpty) {
        tlsSettings['fingerprint'] = fingerprint;
      }
      streamSettings['tlsSettings'] = tlsSettings;
    } else if (security == 'reality') {
      final Map<String, dynamic> realitySettings = {};
      if (sni != null && sni!.isNotEmpty) {
        realitySettings['serverName'] = sni;
      }
      if (publicKey != null && publicKey!.isNotEmpty) {
        realitySettings['publicKey'] = publicKey;
      }
      if (shortId != null && shortId!.isNotEmpty) {
        realitySettings['shortId'] = shortId;
      }
      if (spiderX != null && spiderX!.isNotEmpty) {
        realitySettings['spiderX'] = spiderX;
      }
      if (fingerprint != null && fingerprint!.isNotEmpty) {
        realitySettings['fingerprint'] = fingerprint;
      }
      streamSettings['realitySettings'] = realitySettings;
    }

    // Transport settings
    if (network == 'ws') {
      final Map<String, dynamic> wsSettings = {};
      if (path != null && path!.isNotEmpty) {
        wsSettings['path'] = path;
      }
      if (host != null && host!.isNotEmpty) {
        wsSettings['headers'] = {'Host': host};
      }
      streamSettings['wsSettings'] = wsSettings;
    } else if (network == 'grpc') {
      final Map<String, dynamic> grpcSettings = {};
      if (serviceName != null && serviceName!.isNotEmpty) {
        grpcSettings['serviceName'] = serviceName;
      }
      if (mode == 'multi') {
        grpcSettings['multiMode'] = true;
      }
      streamSettings['grpcSettings'] = grpcSettings;
    } else if (network == 'h2' || network == 'http') {
      final Map<String, dynamic> httpSettings = {};
      if (path != null && path!.isNotEmpty) {
        httpSettings['path'] = path;
      }
      if (host != null && host!.isNotEmpty) {
        httpSettings['host'] = [host];
      }
      streamSettings['httpSettings'] = httpSettings;
    } else if (network == 'kcp') {
      final Map<String, dynamic> kcpSettings = {};
      if (headerType != null && headerType!.isNotEmpty) {
        kcpSettings['header'] = {'type': headerType};
      }
      streamSettings['kcpSettings'] = kcpSettings;
    } else if (network == 'quic') {
      final Map<String, dynamic> quicSettings = {};
      if (headerType != null && headerType!.isNotEmpty) {
        quicSettings['header'] = {'type': headerType};
      }
      streamSettings['quicSettings'] = quicSettings;
    } else if (network == 'xhttp' || network == 'splithttp') {
      final Map<String, dynamic> xhttp = Map<String, dynamic>.from(xhttpSettings ?? {});
      if (path != null && path!.isNotEmpty && !xhttp.containsKey('path')) {
        xhttp['path'] = path;
      }
      if (host != null && host!.isNotEmpty && !xhttp.containsKey('host')) {
        xhttp['host'] = host;
      }
      if (mode != null && mode!.isNotEmpty && !xhttp.containsKey('mode')) {
        xhttp['mode'] = mode;
      }
      streamSettings['xhttpSettings'] = xhttp;
    }

    // Finalmask settings
    if (finalmask != null && finalmask!.isNotEmpty) {
      streamSettings['finalmask'] = json.decode(json.encode(finalmask));
    }

    // Sockopt (including dialerProxy)
    final Map<String, dynamic> sockoptMap = Map<String, dynamic>.from(sockopt ?? {});
    if (dialerProxyTag != null && dialerProxyTag.isNotEmpty) {
      sockoptMap['dialerProxy'] = dialerProxyTag;
      streamSettings['sockopt'] = sockoptMap;
    } else {
      sockoptMap.remove('dialerProxy');
      if (sockoptMap.isNotEmpty) {
        streamSettings['sockopt'] = sockoptMap;
      }
    }

    // Extra stream settings
    if (extraStreamSettings != null && extraStreamSettings!.isNotEmpty) {
      for (final entry in extraStreamSettings!.entries) {
        if (!streamSettings.containsKey(entry.key)) {
          streamSettings[entry.key] = entry.value;
        }
      }
    }

    outbound['streamSettings'] = streamSettings;
    return outbound;
  }
}

/// Service to parse proxy share links and assemble multi-hop Xray JSON configs
class ProxyParserService {
  /// Non-proxy protocols to ignore when extracting outbounds from full configs
  static const Set<String> nonProxyProtocols = {
    'freedom',
    'blackhole',
    'dns',
  };

  /// Sanitizes relaxed JSON/JSON5 by removing line & block comments and trailing commas.
  static String sanitizeJson(String input) {
    // Pass 1: Strip comments while respecting string literals
    final withoutComments = StringBuffer();
    int i = 0;
    final len = input.length;
    bool inString = false;

    while (i < len) {
      final c = input[i];

      if (inString) {
        withoutComments.write(c);
        if (c == '\\' && i + 1 < len) {
          i++;
          withoutComments.write(input[i]);
        } else if (c == '"') {
          inString = false;
        }
        i++;
        continue;
      }

      if (c == '"') {
        inString = true;
        withoutComments.write(c);
        i++;
        continue;
      }

      // Check for line comment //
      if (c == '/' && i + 1 < len && input[i + 1] == '/') {
        i += 2;
        while (i < len && input[i] != '\n' && input[i] != '\r') {
          i++;
        }
        continue;
      }

      // Check for block comment /* ... */
      if (c == '/' && i + 1 < len && input[i + 1] == '*') {
        i += 2;
        while (i + 1 < len && !(input[i] == '*' && input[i + 1] == '/')) {
          i++;
        }
        i += 2; // skip */
        continue;
      }

      withoutComments.write(c);
      i++;
    }

    final commentStripped = withoutComments.toString();

    // Pass 2: Strip trailing commas before } or ] while respecting string literals
    final result = StringBuffer();
    i = 0;
    final len2 = commentStripped.length;
    inString = false;

    while (i < len2) {
      final c = commentStripped[i];

      if (inString) {
        result.write(c);
        if (c == '\\' && i + 1 < len2) {
          i++;
          result.write(commentStripped[i]);
        } else if (c == '"') {
          inString = false;
        }
        i++;
        continue;
      }

      if (c == '"') {
        inString = true;
        result.write(c);
        i++;
        continue;
      }

      if (c == ',') {
        // Look ahead for the next non-whitespace character
        int j = i + 1;
        while (j < len2 &&
            (commentStripped[j] == ' ' ||
                commentStripped[j] == '\t' ||
                commentStripped[j] == '\n' ||
                commentStripped[j] == '\r')) {
          j++;
        }
        if (j < len2 && (commentStripped[j] == '}' || commentStripped[j] == ']')) {
          // Trailing comma: skip writing ','
          i++;
          continue;
        }
      }

      result.write(c);
      i++;
    }

    return result.toString();
  }

  /// Extracts the proxy outbound map from a full Xray config or standalone outbound
  static Map<String, dynamic> extractOutboundFromJson(Map<String, dynamic> jsonMap) {
    // Case 1: Full config with 'outbounds' list
    if (jsonMap.containsKey('outbounds') && jsonMap['outbounds'] is List) {
      final outbounds = jsonMap['outbounds'] as List;
      for (final item in outbounds) {
        if (item is Map) {
          final proto = item['protocol']?.toString().toLowerCase();
          if (proto != null && proto.isNotEmpty && !nonProxyProtocols.contains(proto)) {
            return Map<String, dynamic>.from(item);
          }
        }
      }
      throw const FormatException(
        'No proxy outbound found in Xray configuration outbounds (ignoring freedom, blackhole, dns)',
      );
    }

    // Case 2: Standalone outbound map
    if (jsonMap.containsKey('protocol')) {
      final proto = jsonMap['protocol'].toString().toLowerCase();
      if (nonProxyProtocols.contains(proto)) {
        throw FormatException('Protocol "$proto" is not a proxy outbound protocol');
      }
      return jsonMap;
    }

    throw const FormatException(
      'JSON does not contain a valid Xray outbound (missing "protocol" or "outbounds")',
    );
  }

  /// Parses an Xray JSON config or standalone outbound JSON into a [ParsedProxyNode]
  static ParsedProxyNode parseJsonConfig(String jsonStr) {
    final sanitized = sanitizeJson(jsonStr);
    final dynamic decoded;
    try {
      decoded = json.decode(sanitized);
    } catch (e) {
      throw FormatException('Invalid JSON format: $e');
    }

    final Map<String, dynamic> outboundMap;
    if (decoded is Map<String, dynamic>) {
      outboundMap = extractOutboundFromJson(decoded);
    } else if (decoded is Map) {
      outboundMap = extractOutboundFromJson(Map<String, dynamic>.from(decoded));
    } else if (decoded is List && decoded.isNotEmpty) {
      final proxyOutbound = decoded.firstWhere(
        (element) =>
            element is Map &&
            element['protocol'] != null &&
            !nonProxyProtocols.contains(element['protocol'].toString().toLowerCase()),
        orElse: () => null,
      );
      if (proxyOutbound == null) {
        throw const FormatException('No proxy outbound found in JSON list');
      }
      outboundMap = Map<String, dynamic>.from(proxyOutbound as Map);
    } else {
      throw const FormatException('JSON root must be an object or array');
    }

    return parseOutboundMap(outboundMap);
  }

  /// Converts an Xray outbound Map into a [ParsedProxyNode] retaining raw outbound for 100% fidelity
  static ParsedProxyNode parseOutboundMap(
    Map<String, dynamic> outboundMap, [
    String? fallbackRemarks,
  ]) {
    final protocol = outboundMap['protocol']?.toString().toLowerCase() ?? '';
    if (protocol.isEmpty) {
      throw const FormatException('Outbound missing protocol');
    }

    final tag = outboundMap['tag']?.toString();
    final remarks = fallbackRemarks ?? tag ?? '${protocol.toUpperCase()} Node';

    final settings = outboundMap['settings'] as Map?;
    String address = '';
    int port = 443;
    String? idOrPassword;
    String? alterId;
    String? cipher;
    String? flow;
    String? encryption;

    if (protocol == 'vless' || protocol == 'vmess') {
      final vnext = settings?['vnext'] as List?;
      if (vnext != null && vnext.isNotEmpty && vnext.first is Map) {
        final server = vnext.first as Map;
        address = server['address']?.toString() ?? '';
        port = int.tryParse(server['port']?.toString() ?? '') ?? 443;
        final users = server['users'] as List?;
        if (users != null && users.isNotEmpty && users.first is Map) {
          final user = users.first as Map;
          idOrPassword = user['id']?.toString();
          alterId = user['alterId']?.toString();
          cipher = user['security']?.toString();
          flow = user['flow']?.toString();
          encryption = user['encryption']?.toString();
        }
      }
    } else if (protocol == 'trojan' ||
        protocol == 'shadowsocks' ||
        protocol == 'socks' ||
        protocol == 'http') {
      final servers = settings?['servers'] as List?;
      if (servers != null && servers.isNotEmpty && servers.first is Map) {
        final server = servers.first as Map;
        address = server['address']?.toString() ?? '';
        port = int.tryParse(server['port']?.toString() ?? '') ?? 443;
        idOrPassword = server['password']?.toString();
        cipher = server['method']?.toString();
        final users = server['users'] as List?;
        if (users != null && users.isNotEmpty && users.first is Map) {
          final user = users.first as Map;
          idOrPassword ??= user['user']?.toString();
          encryption ??= user['pass']?.toString();
        }
      }
    }

    final streamSettings = outboundMap['streamSettings'] as Map?;
    final network = streamSettings?['network']?.toString() ?? 'tcp';
    final security = streamSettings?['security']?.toString() ?? 'none';

    final tlsSettings = streamSettings?['tlsSettings'] as Map?;
    final realitySettings = streamSettings?['realitySettings'] as Map?;
    final sni = tlsSettings?['serverName']?.toString() ??
        realitySettings?['serverName']?.toString();
    final fingerprint = tlsSettings?['fingerprint']?.toString() ??
        realitySettings?['fingerprint']?.toString();
    final alpnList = tlsSettings?['alpn'] as List?;
    final alpn = alpnList?.map((e) => e.toString()).toList();
    final publicKey = realitySettings?['publicKey']?.toString();
    final shortId = realitySettings?['shortId']?.toString();
    final spiderX = realitySettings?['spiderX']?.toString();

    final wsSettings = streamSettings?['wsSettings'] as Map?;
    final grpcSettings = streamSettings?['grpcSettings'] as Map?;
    final httpSettings = streamSettings?['httpSettings'] as Map?;
    final xhttpSettings = streamSettings?['xhttpSettings'] as Map?;

    final path = wsSettings?['path']?.toString() ??
        httpSettings?['path']?.toString() ??
        xhttpSettings?['path']?.toString();
    final host = wsSettings?['headers']?['Host']?.toString() ??
        (httpSettings?['host'] is List
            ? (httpSettings!['host'] as List).firstOrNull?.toString()
            : httpSettings?['host']?.toString()) ??
        xhttpSettings?['host']?.toString();
    final serviceName = grpcSettings?['serviceName']?.toString();
    final mode = (grpcSettings?['multiMode'] == true)
        ? 'multi'
        : xhttpSettings?['mode']?.toString();

    final finalmask = streamSettings?['finalmask'] is Map
        ? Map<String, dynamic>.from(streamSettings!['finalmask'] as Map)
        : null;

    final sockopt = streamSettings?['sockopt'] is Map
        ? Map<String, dynamic>.from(streamSettings!['sockopt'] as Map)
        : null;

    final xhttp = xhttpSettings is Map
        ? Map<String, dynamic>.from(xhttpSettings)
        : null;

    return ParsedProxyNode(
      protocol: protocol,
      address: address,
      port: port,
      idOrPassword: idOrPassword,
      alterId: alterId,
      cipher: cipher,
      network: network,
      security: security,
      sni: sni,
      path: path,
      host: host,
      serviceName: serviceName,
      mode: mode,
      publicKey: publicKey,
      shortId: shortId,
      spiderX: spiderX,
      fingerprint: fingerprint,
      flow: flow,
      encryption: encryption,
      alpn: alpn,
      remarks: remarks,
      finalmask: finalmask,
      sockopt: sockopt,
      xhttpSettings: xhttp,
      rawOutbound: outboundMap,
    );
  }

  /// Parses a proxy link (VLESS, VMess, etc.) OR raw Xray JSON config into a [ParsedProxyNode]
  static ParsedProxyNode parseLink(String shareLink) {
    final trimmed = shareLink.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Share link cannot be empty');
    }

    if (_isJsonInput(trimmed)) {
      return parseJsonConfig(trimmed);
    }

    if (trimmed.startsWith('vless://')) {
      return _parseVless(trimmed);
    } else if (trimmed.startsWith('vmess://')) {
      return _parseVmess(trimmed);
    } else if (trimmed.startsWith('trojan://')) {
      return _parseTrojan(trimmed);
    } else if (trimmed.startsWith('ss://')) {
      return _parseShadowsocks(trimmed);
    } else if (trimmed.startsWith('socks://') || trimmed.startsWith('socks5://')) {
      return _parseSocks(trimmed);
    } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _parseHttp(trimmed);
    } else {
      throw const FormatException(
        'Unsupported proxy link protocol. Supported protocols: vless://, vmess://, trojan://, ss://, socks://, socks5://, http://, https://, or raw Xray JSON config',
      );
    }
  }

  /// Parse vless:// link
  static ParsedProxyNode _parseVless(String link) {
    // Format: vless://uuid@host:port?query#remarks
    final uriStr = link.substring(8);
    final fragmentParts = uriStr.split('#');
    final remarks = fragmentParts.length > 1 ? Uri.decodeComponent(fragmentParts[1]) : 'VLESS Node';
    final beforeFragment = fragmentParts[0];

    final queryParts = beforeFragment.split('?');
    final queryString = queryParts.length > 1 ? queryParts[1] : '';
    final mainPart = queryParts[0];

    final atParts = mainPart.split('@');
    if (atParts.length != 2) {
      throw const FormatException('Invalid VLESS format: missing "@" separating UUID and host');
    }

    final uuid = atParts[0];
    final hostPortStr = atParts[1];

    final hostPort = _parseHostPort(hostPortStr);
    final queryParams = _parseQueryString(queryString);

    final net = queryParams['type'] ?? queryParams['network'] ?? 'tcp';
    final sec = queryParams['security'] ?? 'none';
    final sni = queryParams['sni'] ?? queryParams['peer'];
    final path = queryParams['path'] != null ? Uri.decodeComponent(queryParams['path']!) : null;
    final host = queryParams['host'] ?? queryParams['headerType'];
    final serviceName = queryParams['serviceName'];
    final mode = queryParams['mode'];
    final pbk = queryParams['pbk'] ?? queryParams['publicKey'];
    final sid = queryParams['sid'] ?? queryParams['shortId'];
    final spx = queryParams['spx'] ?? queryParams['spiderX'];
    final fp = queryParams['fp'] ?? queryParams['fingerprint'];
    final flow = queryParams['flow'];
    final encryption = queryParams['encryption'];
    final alpn = queryParams['alpn']?.split(',');
    final headerType = queryParams['headerType'];

    Map<String, dynamic>? finalmask;
    if (queryParams.containsKey('finalmask')) {
      finalmask = _parseFinalmask(queryParams['finalmask']!);
    }

    final sockopt = _parseSockopt(queryParams);

    if (queryParams.containsKey('fragment')) {
      _applyFragmentParam(
        raw: queryParams['fragment']!,
        existingFinalmask: finalmask,
        sockopt: sockopt,
        setFinalmask: (fm) => finalmask = fm,
      );
    }

    Map<String, dynamic>? xhttp;
    if (net == 'xhttp' || net == 'splithttp') {
      xhttp = _parseXhttpSettings(queryParams, path, host, mode);
    }

    return ParsedProxyNode(
      protocol: 'vless',
      address: hostPort.host,
      port: hostPort.port,
      idOrPassword: uuid,
      network: net,
      security: sec,
      sni: sni,
      path: path,
      host: host,
      serviceName: serviceName,
      mode: mode,
      publicKey: pbk,
      shortId: sid,
      spiderX: spx,
      fingerprint: fp,
      flow: flow,
      encryption: encryption,
      alpn: alpn,
      headerType: headerType,
      remarks: remarks.isNotEmpty ? remarks : 'VLESS Node',
      finalmask: finalmask,
      sockopt: sockopt.isNotEmpty ? sockopt : null,
      xhttpSettings: xhttp,
    );
  }

  /// Parse trojan:// link
  static ParsedProxyNode _parseTrojan(String link) {
    // Format: trojan://password@host:port?query#remarks
    final uriStr = link.substring(9);
    final fragmentParts = uriStr.split('#');
    final remarks = fragmentParts.length > 1 ? Uri.decodeComponent(fragmentParts[1]) : 'Trojan Node';
    final beforeFragment = fragmentParts[0];

    final queryParts = beforeFragment.split('?');
    final queryString = queryParts.length > 1 ? queryParts[1] : '';
    final mainPart = queryParts[0];

    final atParts = mainPart.split('@');
    if (atParts.length != 2) {
      throw const FormatException('Invalid Trojan format: missing "@" separating password and host');
    }

    final password = Uri.decodeComponent(atParts[0]);
    final hostPortStr = atParts[1];

    final hostPort = _parseHostPort(hostPortStr);
    final queryParams = _parseQueryString(queryString);

    final net = queryParams['type'] ?? queryParams['network'] ?? 'tcp';
    final sec = queryParams['security'] ?? 'tls';
    final sni = queryParams['sni'] ?? queryParams['peer'] ?? queryParams['host'];
    final path = queryParams['path'] != null ? Uri.decodeComponent(queryParams['path']!) : null;
    final host = queryParams['host'];
    final serviceName = queryParams['serviceName'];
    final mode = queryParams['mode'];
    final pbk = queryParams['pbk'] ?? queryParams['publicKey'];
    final sid = queryParams['sid'] ?? queryParams['shortId'];
    final spx = queryParams['spx'] ?? queryParams['spiderX'];
    final fp = queryParams['fp'] ?? queryParams['fingerprint'];
    final alpn = queryParams['alpn']?.split(',');
    final headerType = queryParams['headerType'];

    Map<String, dynamic>? finalmask;
    if (queryParams.containsKey('finalmask')) {
      finalmask = _parseFinalmask(queryParams['finalmask']!);
    }

    final sockopt = _parseSockopt(queryParams);

    if (queryParams.containsKey('fragment')) {
      _applyFragmentParam(
        raw: queryParams['fragment']!,
        existingFinalmask: finalmask,
        sockopt: sockopt,
        setFinalmask: (fm) => finalmask = fm,
      );
    }

    Map<String, dynamic>? xhttp;
    if (net == 'xhttp' || net == 'splithttp') {
      xhttp = _parseXhttpSettings(queryParams, path, host, mode);
    }

    return ParsedProxyNode(
      protocol: 'trojan',
      address: hostPort.host,
      port: hostPort.port,
      idOrPassword: password,
      network: net,
      security: sec,
      sni: sni,
      path: path,
      host: host,
      serviceName: serviceName,
      mode: mode,
      publicKey: pbk,
      shortId: sid,
      spiderX: spx,
      fingerprint: fp,
      alpn: alpn,
      headerType: headerType,
      remarks: remarks.isNotEmpty ? remarks : 'Trojan Node',
      finalmask: finalmask,
      sockopt: sockopt.isNotEmpty ? sockopt : null,
      xhttpSettings: xhttp,
    );
  }

  /// Parse vmess:// link (base64 JSON or URI fallback)
  static ParsedProxyNode _parseVmess(String link) {
    final raw = link.substring(8).trim();

    // Check if it's base64 encoded JSON
    if (!raw.contains('@')) {
      try {
        final decodedStr = utf8.decode(base64.decode(_normalizeBase64(raw)));
        final Map<String, dynamic> jsonMap = json.decode(sanitizeJson(decodedStr));

        final add = jsonMap['add']?.toString() ?? '';
        final port = int.tryParse(jsonMap['port']?.toString() ?? '') ?? 443;
        final id = jsonMap['id']?.toString() ?? '';
        final aid = jsonMap['aid']?.toString() ?? '0';
        final scy = jsonMap['scy']?.toString() ?? jsonMap['cipher']?.toString() ?? 'auto';
        final net = jsonMap['net']?.toString() ?? 'tcp';
        final sec = (jsonMap['tls']?.toString() == 'tls' || jsonMap['tls']?.toString() == '1')
            ? 'tls'
            : (jsonMap['tls']?.toString() == 'reality' ? 'reality' : 'none');
        final path = jsonMap['path']?.toString();
        final host = jsonMap['host']?.toString();
        final sni = jsonMap['sni']?.toString() ?? host;
        final ps = jsonMap['ps']?.toString() ?? 'VMess Node';
        final alpnStr = jsonMap['alpn']?.toString();
        final alpn = alpnStr != null && alpnStr.isNotEmpty ? alpnStr.split(',') : null;
        final fp = jsonMap['fp']?.toString();
        final headerType = jsonMap['type']?.toString();

        if (add.isEmpty || id.isEmpty) {
          throw const FormatException('VMess JSON missing address or id');
        }

        Map<String, dynamic>? finalmask;
        if (jsonMap['finalmask'] is Map) {
          finalmask = Map<String, dynamic>.from(jsonMap['finalmask'] as Map);
        } else if (jsonMap['finalmask'] is String) {
          finalmask = _parseFinalmask(jsonMap['finalmask'] as String);
        }

        final Map<String, dynamic> sockopt = {};
        if (jsonMap['sockopt'] is Map) {
          sockopt.addAll(Map<String, dynamic>.from(jsonMap['sockopt'] as Map));
        }

        if (jsonMap['fragment'] != null) {
          _applyFragmentParam(
            raw: jsonMap['fragment'].toString(),
            existingFinalmask: finalmask,
            sockopt: sockopt,
            setFinalmask: (fm) => finalmask = fm,
          );
        }

        Map<String, dynamic>? xhttp;
        if (net == 'xhttp' || net == 'splithttp') {
          xhttp = {};
          if (path != null && path.isNotEmpty) xhttp['path'] = path;
          if (host != null && host.isNotEmpty) xhttp['host'] = host;
          if (jsonMap['mode'] != null) xhttp['mode'] = jsonMap['mode'].toString();
          if (jsonMap['xhttpSettings'] is Map) {
            xhttp.addAll(Map<String, dynamic>.from(jsonMap['xhttpSettings'] as Map));
          }
        }

        return ParsedProxyNode(
          protocol: 'vmess',
          address: add,
          port: port,
          idOrPassword: id,
          alterId: aid,
          cipher: scy,
          network: net,
          security: sec,
          sni: sni,
          path: path,
          host: host,
          fingerprint: fp,
          alpn: alpn,
          headerType: headerType,
          remarks: ps.isNotEmpty ? ps : 'VMess Node',
          finalmask: finalmask,
          sockopt: sockopt.isNotEmpty ? sockopt : null,
          xhttpSettings: xhttp,
        );
      } catch (e) {
        if (e is FormatException && e.message.startsWith('Unsupported')) rethrow;
        // Fallthrough to URI style parse if base64 fails
      }
    }

    // URI format fallback: vmess://uuid@host:port?query#remarks
    final fragmentParts = raw.split('#');
    final remarks = fragmentParts.length > 1 ? Uri.decodeComponent(fragmentParts[1]) : 'VMess Node';
    final beforeFragment = fragmentParts[0];

    final queryParts = beforeFragment.split('?');
    final queryString = queryParts.length > 1 ? queryParts[1] : '';
    final mainPart = queryParts[0];

    final atParts = mainPart.split('@');
    if (atParts.length != 2) {
      throw const FormatException('Invalid VMess URI format: missing "@" separating UUID and host');
    }

    final uuid = atParts[0];
    final hostPortStr = atParts[1];

    final hostPort = _parseHostPort(hostPortStr);
    final queryParams = _parseQueryString(queryString);

    final net = queryParams['net'] ?? queryParams['type'] ?? queryParams['network'] ?? 'tcp';
    final sec = queryParams['security'] ?? queryParams['tls'] ?? 'none';
    final sni = queryParams['sni'] ?? queryParams['peer'] ?? queryParams['host'];
    final path = queryParams['path'] != null ? Uri.decodeComponent(queryParams['path']!) : null;
    final host = queryParams['host'];
    final fp = queryParams['fp'] ?? queryParams['fingerprint'];
    final aid = queryParams['aid'] ?? queryParams['alterId'] ?? '0';
    final cipher = queryParams['scy'] ?? queryParams['cipher'] ?? 'auto';

    Map<String, dynamic>? finalmask;
    if (queryParams.containsKey('finalmask')) {
      finalmask = _parseFinalmask(queryParams['finalmask']!);
    }

    final sockopt = _parseSockopt(queryParams);

    if (queryParams.containsKey('fragment')) {
      _applyFragmentParam(
        raw: queryParams['fragment']!,
        existingFinalmask: finalmask,
        sockopt: sockopt,
        setFinalmask: (fm) => finalmask = fm,
      );
    }

    Map<String, dynamic>? xhttp;
    if (net == 'xhttp' || net == 'splithttp') {
      xhttp = _parseXhttpSettings(queryParams, path, host, queryParams['mode']);
    }

    return ParsedProxyNode(
      protocol: 'vmess',
      address: hostPort.host,
      port: hostPort.port,
      idOrPassword: uuid,
      alterId: aid,
      cipher: cipher,
      network: net,
      security: sec,
      sni: sni,
      path: path,
      host: host,
      fingerprint: fp,
      remarks: remarks.isNotEmpty ? remarks : 'VMess Node',
      finalmask: finalmask,
      sockopt: sockopt.isNotEmpty ? sockopt : null,
      xhttpSettings: xhttp,
    );
  }

  /// Parse ss:// (Shadowsocks) link
  static ParsedProxyNode _parseShadowsocks(String link) {
    final uriStr = link.substring(5);
    final fragmentParts = uriStr.split('#');
    final remarks = fragmentParts.length > 1 ? Uri.decodeComponent(fragmentParts[1]) : 'Shadowsocks Node';
    final beforeFragment = fragmentParts[0];

    final queryParts = beforeFragment.split('?');
    final queryString = queryParts.length > 1 ? queryParts[1] : '';
    final mainPart = queryParts[0];

    String method = '';
    String password = '';
    String host = '';
    int port = 8388;

    if (mainPart.contains('@')) {
      final atParts = mainPart.split('@');
      final userinfo = atParts[0];
      final hostPortStr = atParts[1];

      final hostPort = _parseHostPort(hostPortStr);
      host = hostPort.host;
      port = hostPort.port;

      String decodedUserinfo = userinfo;
      if (!userinfo.contains(':')) {
        try {
          decodedUserinfo = utf8.decode(base64.decode(_normalizeBase64(userinfo)));
        } catch (_) {}
      }

      final colonIdx = decodedUserinfo.indexOf(':');
      if (colonIdx != -1) {
        method = Uri.decodeComponent(decodedUserinfo.substring(0, colonIdx));
        password = Uri.decodeComponent(decodedUserinfo.substring(colonIdx + 1));
      } else {
        password = Uri.decodeComponent(decodedUserinfo);
      }
    } else {
      // Legacy base64 format: ss://BASE64(method:password@host:port)
      try {
        final decodedStr = utf8.decode(base64.decode(_normalizeBase64(mainPart)));
        final atParts = decodedStr.split('@');
        if (atParts.length == 2) {
          final userinfo = atParts[0];
          final hostPortStr = atParts[1];
          final hostPort = _parseHostPort(hostPortStr);
          host = hostPort.host;
          port = hostPort.port;

          final colonIdx = userinfo.indexOf(':');
          if (colonIdx != -1) {
            method = Uri.decodeComponent(userinfo.substring(0, colonIdx));
            password = Uri.decodeComponent(userinfo.substring(colonIdx + 1));
          } else {
            password = Uri.decodeComponent(userinfo);
          }
        } else {
          throw const FormatException('Invalid Shadowsocks format');
        }
      } catch (e) {
        throw FormatException('Invalid Shadowsocks format: $e');
      }
    }

    final queryParams = _parseQueryString(queryString);

    Map<String, dynamic>? finalmask;
    if (queryParams.containsKey('finalmask')) {
      finalmask = _parseFinalmask(queryParams['finalmask']!);
    }

    final sockopt = _parseSockopt(queryParams);

    if (queryParams.containsKey('fragment')) {
      _applyFragmentParam(
        raw: queryParams['fragment']!,
        existingFinalmask: finalmask,
        sockopt: sockopt,
        setFinalmask: (fm) => finalmask = fm,
      );
    }

    return ParsedProxyNode(
      protocol: 'shadowsocks',
      address: host,
      port: port,
      idOrPassword: password,
      cipher: method.isNotEmpty ? method : 'aes-256-gcm',
      remarks: remarks.isNotEmpty ? remarks : 'Shadowsocks Node',
      finalmask: finalmask,
      sockopt: sockopt.isNotEmpty ? sockopt : null,
    );
  }

  /// Parse socks:// or socks5:// link
  static ParsedProxyNode _parseSocks(String link) {
    final prefixLen = link.startsWith('socks5://') ? 9 : 8;
    final uriStr = link.substring(prefixLen);
    final fragmentParts = uriStr.split('#');
    final remarks = fragmentParts.length > 1 ? Uri.decodeComponent(fragmentParts[1]) : 'SOCKS Node';
    final beforeFragment = fragmentParts[0];

    final queryParts = beforeFragment.split('?');
    final queryString = queryParts.length > 1 ? queryParts[1] : '';
    final mainPart = queryParts[0];

    String username = '';
    String password = '';
    String host = '';
    int port = 1080;

    if (mainPart.contains('@')) {
      final atParts = mainPart.split('@');
      final userinfo = atParts[0];
      final hostPortStr = atParts[1];

      final hostPort = _parseHostPort(hostPortStr);
      host = hostPort.host;
      port = hostPort.port;

      String decodedUserinfo = userinfo;
      if (!userinfo.contains(':')) {
        try {
          decodedUserinfo = utf8.decode(base64.decode(_normalizeBase64(userinfo)));
        } catch (_) {}
      }

      final colonIdx = decodedUserinfo.indexOf(':');
      if (colonIdx != -1) {
        username = Uri.decodeComponent(decodedUserinfo.substring(0, colonIdx));
        password = Uri.decodeComponent(decodedUserinfo.substring(colonIdx + 1));
      } else {
        username = Uri.decodeComponent(decodedUserinfo);
      }
    } else {
      final hostPort = _parseHostPort(mainPart);
      host = hostPort.host;
      port = hostPort.port;
    }

    final queryParams = _parseQueryString(queryString);

    Map<String, dynamic>? finalmask;
    if (queryParams.containsKey('finalmask')) {
      finalmask = _parseFinalmask(queryParams['finalmask']!);
    }

    final sockopt = _parseSockopt(queryParams);

    if (queryParams.containsKey('fragment')) {
      _applyFragmentParam(
        raw: queryParams['fragment']!,
        existingFinalmask: finalmask,
        sockopt: sockopt,
        setFinalmask: (fm) => finalmask = fm,
      );
    }

    return ParsedProxyNode(
      protocol: 'socks',
      address: host,
      port: port,
      idOrPassword: username,
      encryption: password,
      remarks: remarks.isNotEmpty ? remarks : 'SOCKS Node',
      finalmask: finalmask,
      sockopt: sockopt.isNotEmpty ? sockopt : null,
    );
  }

  /// Parse http:// or https:// link
  static ParsedProxyNode _parseHttp(String link) {
    final isHttps = link.startsWith('https://');
    final prefixLen = isHttps ? 8 : 7;
    final uriStr = link.substring(prefixLen);
    final fragmentParts = uriStr.split('#');
    final remarks = fragmentParts.length > 1 ? Uri.decodeComponent(fragmentParts[1]) : (isHttps ? 'HTTPS Node' : 'HTTP Node');
    final beforeFragment = fragmentParts[0];

    final queryParts = beforeFragment.split('?');
    final queryString = queryParts.length > 1 ? queryParts[1] : '';
    final mainPart = queryParts[0];

    String username = '';
    String password = '';
    String host = '';
    int port = isHttps ? 443 : 80;

    if (mainPart.contains('@')) {
      final atParts = mainPart.split('@');
      final userinfo = atParts[0];
      final hostPortStr = atParts[1];

      final hostPort = _parseHostPort(hostPortStr);
      host = hostPort.host;
      port = hostPort.port;

      String decodedUserinfo = userinfo;
      if (!userinfo.contains(':')) {
        try {
          decodedUserinfo = utf8.decode(base64.decode(_normalizeBase64(userinfo)));
        } catch (_) {}
      }

      final colonIdx = decodedUserinfo.indexOf(':');
      if (colonIdx != -1) {
        username = Uri.decodeComponent(decodedUserinfo.substring(0, colonIdx));
        password = Uri.decodeComponent(decodedUserinfo.substring(colonIdx + 1));
      } else {
        username = Uri.decodeComponent(decodedUserinfo);
      }
    } else {
      final hostPort = _parseHostPort(mainPart);
      host = hostPort.host;
      port = hostPort.port;
    }

    final queryParams = _parseQueryString(queryString);
    final sni = queryParams['sni'] ?? queryParams['peer'] ?? host;

    Map<String, dynamic>? finalmask;
    if (queryParams.containsKey('finalmask')) {
      finalmask = _parseFinalmask(queryParams['finalmask']!);
    }

    final sockopt = _parseSockopt(queryParams);

    if (queryParams.containsKey('fragment')) {
      _applyFragmentParam(
        raw: queryParams['fragment']!,
        existingFinalmask: finalmask,
        sockopt: sockopt,
        setFinalmask: (fm) => finalmask = fm,
      );
    }

    return ParsedProxyNode(
      protocol: 'http',
      address: host,
      port: port,
      idOrPassword: username,
      encryption: password,
      security: isHttps ? 'tls' : 'none',
      sni: isHttps ? sni : null,
      remarks: remarks.isNotEmpty ? remarks : (isHttps ? 'HTTPS Node' : 'HTTP Node'),
      finalmask: finalmask,
      sockopt: sockopt.isNotEmpty ? sockopt : null,
    );
  }

  /// Generate full multi-hop Xray profile JSON structure
  static Map<String, dynamic> generateChainProfile({
    required List<String> nodeShareLinks,
    int socksPort = 10808,
    int httpPort = 10809,
  }) {
    if (nodeShareLinks.length < 2) {
      throw const FormatException('At least 2 nodes (Entry and Exit) are required for chaining.');
    }

    final parsedNodes = <ParsedProxyNode>[];
    for (int i = 0; i < nodeShareLinks.length; i++) {
      try {
        parsedNodes.add(parseLink(nodeShareLinks[i]));
      } catch (e) {
        throw FormatException('Failed to parse Hop $i: $e');
      }
    }

    final outbounds = <Map<String, dynamic>>[];

    for (int i = 0; i < parsedNodes.length; i++) {
      final tag = 'hop$i';
      final dialerProxyTag = i > 0 ? 'hop${i - 1}' : null;
      outbounds.add(parsedNodes[i].toXrayOutbound(
        tag: tag,
        dialerProxyTag: dialerProxyTag,
      ));
    }

    // Direct & Block outbounds
    outbounds.add({'tag': 'direct', 'protocol': 'freedom', 'settings': {}});
    outbounds.add({'tag': 'block', 'protocol': 'blackhole', 'settings': {}});

    final finalHopTag = 'hop${parsedNodes.length - 1}';

    // Summary remarks
    final entryProtocol = parsedNodes.first.protocol.toUpperCase();
    final exitProtocol = parsedNodes.last.protocol.toUpperCase();
    final remarks = 'Chained: $entryProtocol (Entry) → $exitProtocol (Exit)';

    final profile = <String, dynamic>{
      'remarks': remarks,
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'tag': 'socks-in',
          'port': socksPort,
          'listen': '127.0.0.1',
          'protocol': 'socks',
          'settings': {
            'udp': true,
            'auth': 'noauth',
          },
        },
        {
          'tag': 'http-in',
          'port': httpPort,
          'listen': '127.0.0.1',
          'protocol': 'http',
          'settings': {},
        },
      ],
      'outbounds': outbounds,
      'routing': {
        'rules': [
          {
            'type': 'field',
            'outboundTag': finalHopTag,
            'port': '0-65535',
          },
        ],
      },
    };

    return profile;
  }

  // --- Internal Utilities ---

  static String _normalizeBase64(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return normalized;
  }

  static _HostPort _parseHostPort(String input) {
    final colonIndex = input.lastIndexOf(':');
    if (colonIndex == -1) {
      throw FormatException('Invalid host:port string: $input');
    }
    final host = input.substring(0, colonIndex);
    final portStr = input.substring(colonIndex + 1);
    final port = int.tryParse(portStr);
    if (port == null || port <= 0 || port > 65535) {
      throw FormatException('Invalid port in host:port string: $portStr');
    }
    return _HostPort(host, port);
  }

  static Map<String, String> _parseQueryString(String query) {
    final params = <String, String>{};
    if (query.isEmpty) return params;
    final pairs = query.split('&');
    for (final pair in pairs) {
      if (pair.isEmpty) continue;
      final kv = pair.split('=');
      final key = Uri.decodeQueryComponent(kv[0]);
      final val = kv.length > 1 ? Uri.decodeQueryComponent(kv[1]) : '';
      params[key] = val;
    }
    return params;
  }

  static bool _isJsonInput(String input) {
    final t = input.trim();
    if (t.startsWith('{') || t.startsWith('[')) return true;
    if (t.startsWith('//') || t.startsWith('/*')) {
      try {
        final sanitized = sanitizeJson(t).trim();
        return sanitized.startsWith('{') || sanitized.startsWith('[');
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static Map<String, dynamic>? _parseFinalmask(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Try 1: URL decoded, then JSON decode
    try {
      final urlDecoded = Uri.decodeComponent(trimmed);
      final sanitized = sanitizeJson(urlDecoded);
      final decoded = json.decode(sanitized);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    // Try 2: Base64 decode
    for (final candidate in [trimmed, Uri.decodeComponent(trimmed)]) {
      try {
        final b64Decoded = utf8.decode(base64.decode(_normalizeBase64(candidate)));
        final sanitized = sanitizeJson(b64Decoded);
        final decoded = json.decode(sanitized);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
    }

    return null;
  }

  static Map<String, dynamic> _parseSockopt(Map<String, String> queryParams) {
    final sockopt = <String, dynamic>{};

    if (queryParams.containsKey('sockopt')) {
      final raw = queryParams['sockopt']!.trim();
      try {
        final decoded = Uri.decodeComponent(raw);
        final sanitized = sanitizeJson(decoded);
        final obj = json.decode(sanitized);
        if (obj is Map<String, dynamic>) {
          sockopt.addAll(obj);
        }
      } catch (_) {
        try {
          final b64 = utf8.decode(base64.decode(_normalizeBase64(raw)));
          final sanitized = sanitizeJson(b64);
          final obj = json.decode(sanitized);
          if (obj is Map<String, dynamic>) {
            sockopt.addAll(obj);
          }
        } catch (_) {}
      }
    }

    if (queryParams.containsKey('domainStrategy')) {
      sockopt['domainStrategy'] = queryParams['domainStrategy'];
    } else if (queryParams.containsKey('domain_strategy')) {
      sockopt['domainStrategy'] = queryParams['domain_strategy'];
    }

    if (queryParams.containsKey('tfo') || queryParams.containsKey('tcpFastOpen')) {
      final tfoVal = queryParams['tfo'] ?? queryParams['tcpFastOpen'];
      sockopt['tcpFastOpen'] = (tfoVal == '1' || tfoVal?.toLowerCase() == 'true');
    }

    if (queryParams.containsKey('dialerProxy')) {
      sockopt['dialerProxy'] = queryParams['dialerProxy'];
    }

    if (queryParams.containsKey('mark')) {
      final markVal = int.tryParse(queryParams['mark']!);
      if (markVal != null) sockopt['mark'] = markVal;
    }

    if (queryParams.containsKey('tproxy')) {
      sockopt['tproxy'] = queryParams['tproxy'];
    }

    if (queryParams.containsKey('happyEyeballs')) {
      try {
        final sanitized = sanitizeJson(Uri.decodeComponent(queryParams['happyEyeballs']!));
        final obj = json.decode(sanitized);
        if (obj is Map<String, dynamic>) {
          sockopt['happyEyeballs'] = obj;
        }
      } catch (_) {}
    }

    return sockopt;
  }

  static void _applyFragmentParam({
    required String raw,
    Map<String, dynamic>? existingFinalmask,
    required Map<String, dynamic> sockopt,
    void Function(Map<String, dynamic>)? setFinalmask,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;

    // Check if raw is JSON or base64 JSON
    Map<String, dynamic>? jsonMap;
    try {
      final decoded = Uri.decodeComponent(trimmed);
      final sanitized = sanitizeJson(decoded);
      final obj = json.decode(sanitized);
      if (obj is Map<String, dynamic>) jsonMap = obj;
    } catch (_) {}

    if (jsonMap == null) {
      try {
        final b64 = utf8.decode(base64.decode(_normalizeBase64(trimmed)));
        final sanitized = sanitizeJson(b64);
        final obj = json.decode(sanitized);
        if (obj is Map<String, dynamic>) jsonMap = obj;
      } catch (_) {}
    }

    if (jsonMap != null) {
      if (jsonMap.containsKey('tcp')) {
        if (setFinalmask != null) setFinalmask(jsonMap);
        return;
      }
      if (jsonMap.containsKey('packets') ||
          jsonMap.containsKey('length') ||
          jsonMap.containsKey('lengths') ||
          jsonMap.containsKey('interval') ||
          jsonMap.containsKey('delays')) {
        sockopt['fragment'] = jsonMap;
        return;
      }
    }

    // Comma-separated: packets,length,interval
    final decodedStr = Uri.decodeComponent(trimmed);
    final parts = decodedStr.split(',');
    if (parts.isNotEmpty) {
      final packets = parts[0].trim();
      final length = parts.length > 1 ? parts[1].trim() : '';
      final interval = parts.length > 2 ? parts[2].trim() : '';
      final fragMap = <String, dynamic>{
        'packets': packets,
        if (length.isNotEmpty) 'length': length,
        if (interval.isNotEmpty) 'interval': interval,
      };
      sockopt['fragment'] = fragMap;
    }
  }

  static Map<String, dynamic> _parseXhttpSettings(
    Map<String, String> queryParams,
    String? path,
    String? host,
    String? mode,
  ) {
    final xhttp = <String, dynamic>{};
    if (path != null && path.isNotEmpty) xhttp['path'] = path;
    if (host != null && host.isNotEmpty) xhttp['host'] = host;
    if (mode != null && mode.isNotEmpty) xhttp['mode'] = mode;

    if (queryParams.containsKey('extra')) {
      try {
        final decodedExtra = Uri.decodeComponent(queryParams['extra']!);
        final sanitized = sanitizeJson(decodedExtra);
        final obj = json.decode(sanitized);
        if (obj is Map<String, dynamic>) {
          xhttp.addAll(obj);
        }
      } catch (_) {}
    }

    if (queryParams.containsKey('xhttpSettings')) {
      try {
        final decoded = Uri.decodeComponent(queryParams['xhttpSettings']!);
        final sanitized = sanitizeJson(decoded);
        final obj = json.decode(sanitized);
        if (obj is Map<String, dynamic>) {
          xhttp.addAll(obj);
        }
      } catch (_) {}
    }

    return xhttp;
  }
}

class _HostPort {
  final String host;
  final int port;
  _HostPort(this.host, this.port);
}

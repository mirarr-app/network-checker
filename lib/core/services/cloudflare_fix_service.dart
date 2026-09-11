import 'dart:convert';

/// Result of a Cloudflare Fix transformation operation
class CloudflareFixResult {
  final Map<String, dynamic> jsonConfig;
  final String formattedJson;
  final String remarks;
  final String address;
  final int port;
  final String network;
  final String sni;
  final String fingerprint;
  final List<String> alpn;

  CloudflareFixResult({
    required this.jsonConfig,
    required this.formattedJson,
    required this.remarks,
    required this.address,
    required this.port,
    required this.network,
    required this.sni,
    required this.fingerprint,
    required this.alpn,
  });
}

/// Available fingerprint options for TLS settings
const List<String> kAvailableFingerprints = [
  'unsafe',
  'chrome',
  'firefox',
  'android',
  'randomized',
  'random',
  'edge',
  'safari',
  '360',
  'qq',
  'ios',
];

/// Service to transform VLESS+TLS+WS and VLESS+TLS+xHTTP links into Cloudflare-optimized Xray JSON configs.
class CloudflareFixService {
  static const String defaultCipherSuites =
      'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256:TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384:TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384:TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256:TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256:TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256:TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256:TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA:TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA:TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256:TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256';

  static const String defaultDnsServer = 'https://cloudflare-dns.com/dns-query';

  /// Standard hosts mapping required for Cloudflare DNS functionality
  static const Map<String, dynamic> defaultDnsHosts = {
    'domain:googleapis.cn': 'googleapis.com',
    'dns.alidns.com': [
      '223.5.5.5',
      '223.6.6.6',
      '2400:3200::1',
      '2400:3200:baba::1',
    ],
    'dns.sse.cisco.com': [
      '208.67.220.220',
      '208.67.222.222',
      '2620:119:35::35',
      '2620:119:53::53',
    ],
    'dns.umbrella.com': [
      '208.67.220.220',
      '208.67.222.222',
      '2620:119:35::35',
      '2620:119:53::53',
    ],
    'one.one.one.one': [
      '1.1.1.1',
      '1.0.0.1',
      '2606:4700:4700::1111',
      '2606:4700:4700::1001',
    ],
    '1dot1dot1dot1.cloudflare-dns.com': [
      '1.1.1.1',
      '1.0.0.1',
      '2606:4700:4700::1111',
      '2606:4700:4700::1001',
    ],
    'dns.cloudflare.com': [
      '162.159.61.8',
      '172.64.41.8',
      '2a06:98c1:52::8',
      '2803:f800:53::8',
    ],
    'cloudflare-dns.com': [
      '104.16.248.249',
      '104.16.249.249',
      '2606:4700::6810:f8f9',
      '2606:4700::6810:f9f9',
    ],
    'engage.cloudflareclient.com': [
      '162.159.192.1',
      '2606:4700:d0::a29f:c001',
    ],
    'doh.pub': [
      '1.12.12.12',
      '120.53.53.53',
    ],
    'dot.pub': [
      '1.12.12.12',
      '120.53.53.53',
    ],
    'dns.google': [
      '8.8.8.8',
      '8.8.4.4',
      '2001:4860:4860::8888',
      '2001:4860:4860::8844',
    ],
    'dns.quad9.net': [
      '9.9.9.9',
      '149.112.112.112',
      '2620:fe::fe',
      '2620:fe::9',
    ],
    'dns.sb': [
      '45.11.45.11',
      '185.222.222.222',
      '2a09::',
      '2a11::',
    ],
    'common.dot.dns.yandex.net': [
      '77.88.8.8',
      '77.88.8.1',
      '2a02:6b8::feed:0ff',
      '2a02:6b8:0:1::feed:0ff',
    ],
  };

  /// Transforms a VLESS share link into a Cloudflare Fix Xray JSON config.
  /// Strictly requires security=tls and network type=ws or type=xhttp.
  static CloudflareFixResult transformVlessUrl(
    String shareLink, {
    int socksPort = 10808,
    int httpPort = 10809,
    String dnsServer = defaultDnsServer,
    String remarkSuffix = '-custom',
    String fingerprint = 'unsafe',
    List<String> alpn = const ['http/1.1'],
    String cipherSuites = defaultCipherSuites,
    bool enableFinalmask = true,
    String frag1Packets = 'tlshello',
    List<String> frag1Lengths = const ['0', '104', '1'],
    List<String> frag1Delays = const ['0'],
    String frag1MaxSplit = '0',
    String frag2Packets = '1-1',
    List<String> frag2Lengths = const ['114', '1'],
    List<String> frag2Delays = const ['1'],
    String frag2MaxSplit = '11',
  }) {
    final trimmed = shareLink.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('VLESS configuration link cannot be empty.');
    }

    if (!trimmed.startsWith('vless://')) {
      throw const FormatException(
        'Invalid protocol. Only VLESS links starting with "vless://" are supported.',
      );
    }

    // Parse vless://uuid@host:port?queryParams#remarks
    final uriStr = trimmed.substring(8);
    final fragmentParts = uriStr.split('#');
    final rawRemarks = fragmentParts.length > 1
        ? Uri.decodeComponent(fragmentParts[1])
        : 'VLESS Node';
    final beforeFragment = fragmentParts[0];

    final queryParts = beforeFragment.split('?');
    final queryString = queryParts.length > 1 ? queryParts[1] : '';
    final mainPart = queryParts[0];

    final atParts = mainPart.split('@');
    if (atParts.length != 2) {
      throw const FormatException(
        'Invalid VLESS link format: missing "@" separating UUID and server address.',
      );
    }

    final uuid = atParts[0];
    final hostPortStr = atParts[1];

    final colonIndex = hostPortStr.lastIndexOf(':');
    if (colonIndex == -1) {
      throw FormatException('Invalid address/port in VLESS link: $hostPortStr');
    }
    final address = hostPortStr.substring(0, colonIndex);
    final portStr = hostPortStr.substring(colonIndex + 1);
    final port = int.tryParse(portStr);
    if (port == null || port <= 0 || port > 65535) {
      throw FormatException('Invalid port number: $portStr');
    }

    final queryParams = _parseQueryString(queryString);

    final security = (queryParams['security'] ?? queryParams['tls'] ?? 'none').toLowerCase();
    final network = (queryParams['type'] ?? queryParams['network'] ?? 'tcp').toLowerCase();

    // STRICT COMPATIBILITY CHECK:
    // Only VLESS+TLS+WS and VLESS+TLS+xHTTP are supported!
    final isSupportedSecurity = security == 'tls';
    final isSupportedNetwork = network == 'ws' || network == 'xhttp' || network == 'splithttp';

    if (!isSupportedSecurity || !isSupportedNetwork) {
      throw const FormatException(
        'Only VLESS+TLS+WS and VLESS+TLS+xHTTP configurations are supported.',
      );
    }

    final normalizedNetwork = (network == 'xhttp' || network == 'splithttp') ? 'xhttp' : 'ws';
    final sni = queryParams['sni'] ?? queryParams['peer'] ?? queryParams['host'] ?? address;
    final path = queryParams['path'] != null ? Uri.decodeComponent(queryParams['path']!) : '';
    final host = queryParams['host'] ?? '';
    final flow = queryParams['flow'] ?? '';
    final encryption = (queryParams['encryption'] != null && queryParams['encryption']!.isNotEmpty)
        ? queryParams['encryption']!
        : 'none';
    final mode = queryParams['mode'] ?? 'auto';

    final finalRemarks = rawRemarks.endsWith(remarkSuffix)
        ? rawRemarks
        : '$rawRemarks$remarkSuffix';

    // Construct streamSettings according to Cloudflare Fix spec
    final Map<String, dynamic> streamSettings = {
      if (enableFinalmask)
        'finalmask': {
          'tcp': [
            {
              'type': 'fragment',
              'settings': {
                'packets': frag1Packets,
                'lengths': frag1Lengths,
                'delays': frag1Delays,
                'maxSplit': frag1MaxSplit,
              },
            },
            {
              'type': 'fragment',
              'settings': {
                'packets': frag2Packets,
                'lengths': frag2Lengths,
                'delays': frag2Delays,
                'maxSplit': frag2MaxSplit,
              },
            },
          ],
        },
      'network': normalizedNetwork,
      'security': 'tls',
      'sockopt': {
        'domainStrategy': 'UseIP',
        'happyEyeballs': {
          'interleave': 2,
          'maxConcurrentTry': 4,
          'prioritizeIPv6': false,
          'tryDelayMs': 250,
        },
      },
      'tlsSettings': {
        'allowInsecure': false,
        'alpn': alpn.isNotEmpty ? alpn : ['http/1.1'],
        'cipherSuites': cipherSuites.isNotEmpty ? cipherSuites : defaultCipherSuites,
        'fingerprint': fingerprint,
        'serverName': sni,
      },
    };

    if (normalizedNetwork == 'ws') {
      streamSettings['wsSettings'] = {
        'host': host.isNotEmpty ? host : sni,
        'path': path,
      };
    } else if (normalizedNetwork == 'xhttp') {
      streamSettings['xhttpSettings'] = {
        'host': host.isNotEmpty ? host : sni,
        'path': path,
        'mode': mode,
      };
    }

    final jsonMap = <String, dynamic>{
      'dns': {
        'hosts': Map<String, dynamic>.from(defaultDnsHosts),
        'servers': [dnsServer],
        'tag': 'dns-module',
      },
      'inbounds': [
        {
          'listen': '127.0.0.1',
          'port': socksPort,
          'protocol': 'socks',
          'settings': {
            'auth': 'noauth',
            'udp': true,
            'userLevel': 8,
          },
          'sniffing': {
            'destOverride': ['http', 'tls', 'quic'],
            'enabled': true,
            'routeOnly': false,
          },
          'tag': 'socks',
        },
        {
          'listen': '127.0.0.1',
          'port': httpPort,
          'protocol': 'http',
          'settings': {
            'userLevel': 8,
          },
          'sniffing': {
            'destOverride': ['http', 'tls', 'quic'],
            'enabled': true,
            'routeOnly': false,
          },
          'tag': 'http',
        },
      ],
      'log': {
        'loglevel': 'warning',
      },
      'outbounds': [
        {
          'mux': {
            'concurrency': -1,
            'enabled': false,
          },
          'protocol': 'vless',
          'settings': {
            'address': address,
            'encryption': encryption,
            'flow': flow,
            'id': uuid,
            'level': 8,
            'port': port,
          },
          'streamSettings': streamSettings,
          'tag': 'proxy',
        },
        {
          'protocol': 'freedom',
          'streamSettings': {
            'network': 'tcp',
            'sockopt': {
              'domainStrategy': 'UseIP',
            },
          },
          'tag': 'direct',
        },
        {
          'protocol': 'blackhole',
          'settings': {},
          'tag': 'block',
        },
      ],
      'remarks': finalRemarks,
      'routing': {
        'domainStrategy': 'AsIs',
        'rules': [
          {
            'inboundTag': ['dns-module'],
            'outboundTag': 'proxy',
            'type': 'field',
          },
        ],
      },
    };

    const encoder = JsonEncoder.withIndent('  ');
    final formatted = encoder.convert(jsonMap);

    return CloudflareFixResult(
      jsonConfig: jsonMap,
      formattedJson: formatted,
      remarks: finalRemarks,
      address: address,
      port: port,
      network: normalizedNetwork.toUpperCase(),
      sni: sni,
      fingerprint: fingerprint,
      alpn: alpn,
    );
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
}

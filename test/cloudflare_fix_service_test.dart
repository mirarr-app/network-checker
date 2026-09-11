import 'package:flutter_test/flutter_test.dart';
import 'package:rdnbenet/core/services/cloudflare_fix_service.dart';

void main() {
  group('CloudflareFixService', () {
    const wsUrl =
        'vless://00000000-0000-0000-0000-000000000000@example.com:443?path=%2Fwspath&security=tls&alpn=h3%2Ch2%2Chttp%2F1.1&encryption=none&host=example.com&fp=chrome&type=ws&sni=example.com#TestWS';

    const xhttpUrl =
        'vless://11111111-1111-1111-1111-111111111111@xhttp.example.com:443?path=%2Fxhpath&security=tls&encryption=none&host=xhttp.example.com&type=xhttp&sni=xhttp.example.com#TestXHTTP';

    test('transforms VLESS+TLS+WS correctly with default settings', () {
      final result = CloudflareFixService.transformVlessUrl(wsUrl);

      expect(result.remarks, 'TestWS-custom');
      expect(result.address, 'example.com');
      expect(result.port, 443);
      expect(result.network, 'WS');
      expect(result.sni, 'example.com');
      expect(result.fingerprint, 'unsafe');
      expect(result.alpn, ['http/1.1']);

      final jsonMap = result.jsonConfig;
      expect(jsonMap['log']['loglevel'], 'warning');
      expect(jsonMap['inbounds'].length, 2);
      expect(jsonMap['inbounds'][0]['port'], 10808);
      expect(jsonMap['inbounds'][1]['port'], 10809);

      final outbounds = jsonMap['outbounds'] as List;
      final proxyOutbound = outbounds.firstWhere((o) => o['tag'] == 'proxy');
      expect(proxyOutbound['protocol'], 'vless');

      final streamSettings = proxyOutbound['streamSettings'];
      expect(streamSettings['network'], 'ws');
      expect(streamSettings['security'], 'tls');

      final tlsSettings = streamSettings['tlsSettings'];
      expect(tlsSettings['fingerprint'], 'unsafe');
      expect(tlsSettings['alpn'], ['http/1.1']);
      expect(tlsSettings['serverName'], 'example.com');
      expect(tlsSettings['cipherSuites'], contains('TLS_AES_256_GCM_SHA384'));

      final finalmask = streamSettings['finalmask'];
      expect(finalmask['tcp'].length, 2);
      expect(finalmask['tcp'][0]['settings']['packets'], 'tlshello');
      expect(finalmask['tcp'][0]['settings']['lengths'], ['0', '104', '1']);
      expect(finalmask['tcp'][0]['settings']['delays'], ['0']);
      expect(finalmask['tcp'][0]['settings']['maxSplit'], '0');
      expect(finalmask['tcp'][1]['settings']['packets'], '1-1');
      expect(finalmask['tcp'][1]['settings']['lengths'], ['114', '1']);
      expect(finalmask['tcp'][1]['settings']['delays'], ['1']);
      expect(finalmask['tcp'][1]['settings']['maxSplit'], '11');

      final wsSettings = streamSettings['wsSettings'];
      expect(wsSettings['host'], 'example.com');
      expect(wsSettings['path'], '/wspath');
    });

    test('transforms VLESS+TLS+WS with custom fingerprint and ALPN settings', () {
      final result = CloudflareFixService.transformVlessUrl(
        wsUrl,
        fingerprint: 'chrome',
        alpn: ['h2', 'http/1.1'],
        cipherSuites: 'TLS_AES_128_GCM_SHA256',
        enableFinalmask: true,
      );

      expect(result.fingerprint, 'chrome');
      expect(result.alpn, ['h2', 'http/1.1']);

      final proxyOutbound =
          (result.jsonConfig['outbounds'] as List).firstWhere((o) => o['tag'] == 'proxy');
      final tlsSettings = proxyOutbound['streamSettings']['tlsSettings'];
      expect(tlsSettings['fingerprint'], 'chrome');
      expect(tlsSettings['alpn'], ['h2', 'http/1.1']);
      expect(tlsSettings['cipherSuites'], 'TLS_AES_128_GCM_SHA256');
    });

    test('transforms VLESS+TLS+xHTTP correctly', () {
      final result = CloudflareFixService.transformVlessUrl(xhttpUrl);

      expect(result.remarks, 'TestXHTTP-custom');
      expect(result.network, 'XHTTP');

      final proxyOutbound =
          (result.jsonConfig['outbounds'] as List).firstWhere((o) => o['tag'] == 'proxy');
      final streamSettings = proxyOutbound['streamSettings'];
      expect(streamSettings['network'], 'xhttp');

      final xhttpSettings = streamSettings['xhttpSettings'];
      expect(xhttpSettings['host'], 'xhttp.example.com');
      expect(xhttpSettings['path'], '/xhpath');
    });

    test('rejects unsupported protocols (e.g. security=none, network=tcp)', () {
      const tcpUrl =
          'vless://00000000-0000-0000-0000-000000000000@example.com:443?security=none&type=tcp#TCPNode';

      expect(
        () => CloudflareFixService.transformVlessUrl(tcpUrl),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Only VLESS+TLS+WS and VLESS+TLS+xHTTP configurations are supported'),
          ),
        ),
      );
    });
  });
}

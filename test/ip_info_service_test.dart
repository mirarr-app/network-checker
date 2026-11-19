import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rdnbenet/core/services/ip_info_service.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  group('IpInfoService - medianLatency', () {
    test('returns null for an empty list', () {
      expect(IpInfoService.medianLatency([]), isNull);
    });

    test('returns the middle value for an odd count', () {
      expect(IpInfoService.medianLatency([120, 80, 100]), 100);
    });

    test('returns the rounded mean of the middle two for an even count', () {
      expect(IpInfoService.medianLatency([100, 80, 120, 90]), 95);
    });

    test('ignores ordering', () {
      expect(IpInfoService.medianLatency([300, 10, 50]), 50);
    });
  });

  group('IpInfoService - isBogonOrPrivate', () {
    test('identifies IPv4 private 10.0.0.0/8', () {
      expect(IpInfoService.isBogonOrPrivate('10.0.0.0'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('10.0.0.1'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('10.255.255.255'), isTrue);
    });

    test('identifies IPv4 private 172.16.0.0/12', () {
      expect(IpInfoService.isBogonOrPrivate('172.16.0.0'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('172.16.0.1'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('172.31.255.255'), isTrue);
      // Boundaries
      expect(IpInfoService.isBogonOrPrivate('172.15.255.255'), isFalse);
      expect(IpInfoService.isBogonOrPrivate('172.32.0.0'), isFalse);
    });

    test('identifies IPv4 private 192.168.0.0/16', () {
      expect(IpInfoService.isBogonOrPrivate('192.168.0.0'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('192.168.1.1'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('192.168.255.255'), isTrue);
    });

    test('identifies IPv4 loopback 127.0.0.0/8', () {
      expect(IpInfoService.isBogonOrPrivate('127.0.0.1'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('127.255.255.254'), isTrue);
    });

    test('identifies IPv4 CGNAT 100.64.0.0/10', () {
      expect(IpInfoService.isBogonOrPrivate('100.64.0.0'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('100.64.0.1'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('100.127.255.255'), isTrue);
      // Boundaries
      expect(IpInfoService.isBogonOrPrivate('100.63.255.255'), isFalse);
      expect(IpInfoService.isBogonOrPrivate('100.128.0.0'), isFalse);
    });

    test('identifies IPv4 0.0.0.0/8', () {
      expect(IpInfoService.isBogonOrPrivate('0.0.0.0'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('0.255.255.255'), isTrue);
    });

    test('identifies IPv4 link-local 169.254.0.0/16', () {
      expect(IpInfoService.isBogonOrPrivate('169.254.0.1'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('169.254.255.254'), isTrue);
    });

    test('does not flag public IPv4 addresses', () {
      expect(IpInfoService.isBogonOrPrivate('8.8.8.8'), isFalse);
      expect(IpInfoService.isBogonOrPrivate('1.1.1.1'), isFalse);
      expect(IpInfoService.isBogonOrPrivate('142.250.190.46'), isFalse);
    });

    test('identifies IPv6 loopback, link-local, and unique-local', () {
      expect(IpInfoService.isBogonOrPrivate('::1'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('::'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('fe80::1'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('fe80::1ff:fe23:4567'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('fc00::1'), isTrue);
      expect(IpInfoService.isBogonOrPrivate('fd12:3456:789a::1'), isTrue);
    });

    test('does not flag public IPv6 addresses', () {
      expect(IpInfoService.isBogonOrPrivate('2606:4700:4700::1111'), isFalse);
      expect(IpInfoService.isBogonOrPrivate('2001:4860:4860::8888'), isFalse);
    });

    test('handles whitespace and invalid inputs safely', () {
      expect(IpInfoService.isBogonOrPrivate(' 192.168.1.1 '), isTrue);
      expect(IpInfoService.isBogonOrPrivate(''), isFalse);
      expect(IpInfoService.isBogonOrPrivate('not-an-ip'), isFalse);
      expect(IpInfoService.isBogonOrPrivate('999.999.999.999'), isFalse);
    });
  });

  group('IpInfoService - bogon purity check', () {
    test('skips external HTTP lookups and returns score 100 for private IPs',
        () async {
      for (final ip in [
        '192.168.1.1',
        '10.0.0.1',
        '127.0.0.1',
        '100.64.0.1',
        '::1',
        'fe80::1',
        'fc00::1',
      ]) {
        final result = await IpInfoService.checkIpPurity(ip: ip);
        expect(result.score, 100);
        expect(result.verdict, IpInfoService.verdictPrivateOrBogon);
        expect(result.factors.length, 1);
        expect(result.factors.first.name, 'Private / Bogon IP');
        expect(result.factors.first.passed, isTrue);
        expect(result.factors.first.detail, contains('unroutable'));
      }
    });
  });

  group('IpInfoService - purity scoring', () {
    const cleanFactor = PurityFactor(
      name: 'Clean check',
      passed: true,
      detail: 'ok',
      penalty: 60,
    );

    test('all passing factors score 100 with >= 2 verified factors', () {
      expect(
        IpInfoService.computePurityScore([cleanFactor, cleanFactor]),
        100,
      );
    });

    test('a failing factor subtracts its penalty when quorum is met', () {
      const torFactor = PurityFactor(
        name: 'Tor exit node',
        passed: false,
        detail: 'exit node',
        penalty: 60,
      );
      expect(IpInfoService.computePurityScore([cleanFactor, torFactor]), 40);
    });

    test('an unchecked factor (passed == null) subtracts nothing when quorum is met', () {
      const uncheckedFactor = PurityFactor(
        name: 'Reverse DNS',
        passed: null,
        detail: 'not checked',
        penalty: 15,
      );
      expect(
        IpInfoService.computePurityScore([
          cleanFactor,
          cleanFactor,
          uncheckedFactor,
        ]),
        100,
      );
    });

    test('fewer than 2 verified factors returns 0 and unverified', () {
      const uncheckedFactor = PurityFactor(
        name: 'Reverse DNS',
        passed: null,
        detail: 'not checked',
        penalty: 15,
      );
      expect(IpInfoService.computePurityScore([]), 0);
      expect(IpInfoService.computePurityScore([uncheckedFactor]), 0);
      expect(IpInfoService.computePurityScore([cleanFactor]), 0);
      expect(
        IpInfoService.computePurityScore([cleanFactor, uncheckedFactor]),
        0,
      );
      expect(
        IpInfoService.purityVerdict(100, verifiedFactors: 1),
        IpInfoService.verdictUnverified,
      );
      expect(
        IpInfoService.purityVerdict(100, verifiedFactors: [cleanFactor]),
        IpInfoService.verdictUnverified,
      );
      expect(
        IpInfoService.purityVerdict(0, hasVerifiedFactors: false),
        IpInfoService.verdictUnverified,
      );
    });

    test('score clamps at 0', () {
      const bigPenalty = PurityFactor(
        name: 'Tor exit node',
        passed: false,
        detail: 'exit node',
        penalty: 60,
      );
      const proxyPenalty = PurityFactor(
        name: 'Known proxy',
        passed: false,
        detail: 'proxy',
        penalty: 35,
      );
      const hostingPenalty = PurityFactor(
        name: 'Datacenter / hosting ASN',
        passed: false,
        detail: 'hosting',
        penalty: 25,
      );
      expect(
        IpInfoService.computePurityScore([
          bigPenalty,
          proxyPenalty,
          hostingPenalty,
        ]),
        0,
      );
    });

    test('verdict bands when quorum is met', () {
      expect(IpInfoService.purityVerdict(100), 'Clean');
      expect(IpInfoService.purityVerdict(80), 'Clean');
      expect(IpInfoService.purityVerdict(79), 'Suspicious');
      expect(IpInfoService.purityVerdict(50), 'Suspicious');
      expect(IpInfoService.purityVerdict(49), 'Flagged');
      expect(IpInfoService.purityVerdict(0), 'Flagged');
    });
  });

  group('IpInfoService - threat intelligence handling', () {
    test('marks threat passed true only when intel explicitly reports clean', () async {
      final client = MockHttpClient((request) async {
        if (request.url.host == 'ip.net.coffee') {
          return http.Response(
            jsonEncode({
              'ip': '8.8.8.8',
              'is_abuser': false,
              'threats': [],
              'is_datacenter': false,
              'is_vpn': false,
              'is_proxy': false,
              'is_tor': false,
            }),
            200,
          );
        }
        if (request.url.host == 'check.torproject.org') {
          return http.Response('', 200);
        }
        return http.Response('not found', 404);
      });

      final result = await IpInfoService.checkIpPurity(
        ip: '8.8.8.8',
        client: client,
      );

      final threatFactor = result.factors.firstWhere(
        (f) => f.name == 'Threat / abuse history',
      );
      expect(threatFactor.passed, isTrue);
      expect(threatFactor.detail, contains('Clean threat history'));
    });

    test('marks threat passed false when intel reports abuse', () async {
      final client = MockHttpClient((request) async {
        if (request.url.host == 'ip.net.coffee') {
          return http.Response(
            jsonEncode({
              'ip': '8.8.8.8',
              'is_abuser': true,
              'abuser_score': '95%',
              'is_datacenter': false,
              'is_vpn': false,
              'is_proxy': false,
              'is_tor': false,
            }),
            200,
          );
        }
        if (request.url.host == 'check.torproject.org') {
          return http.Response('', 200);
        }
        return http.Response('not found', 404);
      });

      final result = await IpInfoService.checkIpPurity(
        ip: '8.8.8.8',
        client: client,
      );

      final threatFactor = result.factors.firstWhere(
        (f) => f.name == 'Threat / abuse history',
      );
      expect(threatFactor.passed, isFalse);
    });

    test('marks threat unverified (null) when fallback source lacks threat keys', () async {
      final client = MockHttpClient((request) async {
        if (request.url.host == 'ip.net.coffee') {
          return http.Response('service unavailable', 503);
        }
        if (request.url.host == 'ipwho.is') {
          // ipwho.is returns geo & asn, but no threat keys
          return http.Response(
            jsonEncode({
              'ip': '8.8.8.8',
              'success': true,
              'connection': {
                'asn': 15169,
                'org': 'Google LLC',
                'isp': 'Google LLC',
              },
              'country': 'United States',
              'city': 'Mountain View',
            }),
            200,
          );
        }
        if (request.url.host == 'check.torproject.org') {
          return http.Response('', 200);
        }
        return http.Response('not found', 404);
      });

      final result = await IpInfoService.checkIpPurity(
        ip: '8.8.8.8',
        client: client,
      );

      final threatFactor = result.factors.firstWhere(
        (f) => f.name == 'Threat / abuse history',
      );
      expect(threatFactor.passed, isNull);
      expect(threatFactor.detail, contains('not provided'));
    });
  });

  group('IpInfoService - checkIpLeak dual-stack & offline robustness', () {
    test('does not report leak for dual-stack IPv4 + IPv6 responses', () async {
      final client = MockHttpClient((request) async {
        if (request.url.host == 'api.ipify.org') {
          return http.Response('1.1.1.1', 200);
        }
        if (request.url.host == 'icanhazip.com') {
          return http.Response('2606:4700::1', 200);
        }
        if (request.url.host == 'ident.me') {
          return http.Response('1.1.1.1', 200);
        }
        if (request.url.host == 'www.cloudflare.com') {
          return http.Response('ip=1.1.1.1\nloc=US\n', 200);
        }
        return http.Response('not found', 404);
      });

      final result = await IpInfoService.checkIpLeak(client: client);
      expect(result.consistent, isTrue);
      expect(result.seenIpv4, {'1.1.1.1'});
      expect(result.seenIpv6, {'2606:4700::1'});
    });

    test('flags leak when multiple distinct IPv4 addresses appear', () async {
      final client = MockHttpClient((request) async {
        if (request.url.host == 'api.ipify.org') {
          return http.Response('1.1.1.1', 200);
        }
        if (request.url.host == 'icanhazip.com') {
          return http.Response('2.2.2.2', 200);
        }
        return http.Response('not found', 404);
      });

      final result = await IpInfoService.checkIpLeak(client: client);
      expect(result.consistent, isFalse);
    });

    test('flags leak when multiple distinct IPv6 addresses appear', () async {
      final client = MockHttpClient((request) async {
        if (request.url.host == 'icanhazip.com') {
          return http.Response('2606:4700::1', 200);
        }
        if (request.url.host == 'ident.me') {
          return http.Response('2001:db8::1', 200);
        }
        return http.Response('not found', 404);
      });

      final result = await IpInfoService.checkIpLeak(client: client);
      expect(result.consistent, isFalse);
    });

    test('does not report leak when all queries fail (offline)', () async {
      final client = MockHttpClient((request) async {
        throw const SocketException('Network unreachable');
      });

      final result = await IpInfoService.checkIpLeak(client: client);
      expect(result.consistent, isTrue);
      expect(result.seenIpv4, isEmpty);
      expect(result.seenIpv6, isEmpty);
    });

    test('ignores HTML error pages and invalid IP strings', () async {
      final client = MockHttpClient((request) async {
        if (request.url.host == 'api.ipify.org') {
          return http.Response('<html>502 Bad Gateway</html>', 200);
        }
        if (request.url.host == 'icanhazip.com') {
          return http.Response('1.1.1.1', 200);
        }
        return http.Response('not found', 404);
      });

      final result = await IpInfoService.checkIpLeak(client: client);
      expect(result.consistent, isTrue);
      expect(result.seenIpv4, {'1.1.1.1'});
      expect(result.seenBy['ipify'], isNull);
    });
  });

  group('IpInfoService - parseDohAnswers', () {
    test('extracts IPv4 (type 1) and IPv6 (type 28) records', () {
      final json = {
        'Status': 0,
        'Answer': [
          {'name': 'example.com.', 'type': 1, 'data': '93.184.216.34'},
          {
            'name': 'example.com.',
            'type': 28,
            'data': '2606:2800:220:1:248:1893:25c8:1946',
          },
        ],
      };

      final answers = IpInfoService.parseDohAnswers(json);
      expect(answers, [
        '93.184.216.34',
        '2606:2800:220:1:248:1893:25c8:1946',
      ]);
    });

    test('filters out CNAME (type 5) and metadata records', () {
      final json = {
        'Status': 0,
        'Answer': [
          {
            'name': 'cdn.example.com.',
            'type': 5,
            'data': 'edge.example.net.',
          },
          {
            'name': 'edge.example.net.',
            'type': 1,
            'data': '93.184.216.34',
          },
          {
            'name': 'example.com.',
            'type': 16,
            'data': 'v=spf1 ~all',
          },
        ],
      };

      final answers = IpInfoService.parseDohAnswers(json);
      expect(answers, ['93.184.216.34']);
    });

    test('returns empty list for missing or invalid Answer field', () {
      expect(IpInfoService.parseDohAnswers({}), isEmpty);
      expect(IpInfoService.parseDohAnswers({'Answer': null}), isEmpty);
      expect(IpInfoService.parseDohAnswers({'Answer': []}), isEmpty);
      expect(
        IpInfoService.parseDohAnswers({
          'Answer': [
            {'type': 1, 'data': 'not-an-ip'},
          ],
        }),
        isEmpty,
      );
    });
  });

  group('IpInfoService - hosting ASN detection', () {
    test('flags known hosting/cloud organizations', () {
      expect(IpInfoService.isHostingAsn('Amazon.com, Inc.'), isTrue);
      expect(IpInfoService.isHostingAsn('DigitalOcean, LLC'), isTrue);
      expect(IpInfoService.isHostingAsn('Hetzner Online GmbH'), isTrue);
      expect(
        IpInfoService.isHostingAsn('Google Cloud Platform'),
        isTrue,
      );
      expect(IpInfoService.isHostingAsn('Datacamp Limited'), isTrue);
      expect(IpInfoService.isHostingAsn('M247 Ltd'), isTrue);
      expect(IpInfoService.isHostingAsn('Leaseweb Deutschland GmbH'), isTrue);
      expect(IpInfoService.isHostingAsn('The Constant Company, LLC'), isTrue);
      expect(IpInfoService.isHostingAsn('Contabo GmbH'), isTrue);
    });

    test('does not flag residential ISPs', () {
      expect(IpInfoService.isHostingAsn('Google LLC'), isFalse);
      expect(
        IpInfoService.isHostingAsn('Mobile Telecommunication Company of Iran'),
        isFalse,
      );
      expect(IpInfoService.isHostingAsn(''), isFalse);
    });
  });

  group('IpInfoService - PTR datacenter detection', () {
    test('flags server-style PTR hostnames', () {
      expect(
        IpInfoService.ptrLooksLikeDatacenter(
          'ec2-1-2-3-4.compute-1.amazonaws.com',
        ),
        isTrue,
      );
      expect(
        IpInfoService.ptrLooksLikeDatacenter('vps-123.vultr.com'),
        isTrue,
      );
    });

    test('does not flag residential PTR hostnames', () {
      expect(
        IpInfoService.ptrLooksLikeDatacenter('1-2-3-4.dynamic.isp.com'),
        isFalse,
      );
      expect(
        IpInfoService.ptrLooksLikeDatacenter('cable-1-2-3-4.isp.net'),
        isFalse,
      );
    });
  });

  group('IpInfoService - Cloudflare trace parsing', () {
    test('parses key=value lines into fields', () {
      const body = 'fl=123f\n'
          'h=www.cloudflare.com\n'
          'ip=1.2.3.4\n'
          'ts=1234567890.123\n'
          'visit_scheme=https\n'
          'uag=Mozilla/5.0\n'
          'colo=FRA\n'
          'sliver=none\n'
          'http=http/2\n'
          'loc=DE\n'
          'tls=TLSv1.3\n'
          'sni=plaintext\n'
          'warp=off\n'
          'gateway=off\n'
          'rbi=off\n'
          'kex=X25519\n';
      final fields = IpInfoService.parseCloudflareTrace(body);
      expect(fields['ip'], '1.2.3.4');
      expect(fields['colo'], 'FRA');
      expect(fields['loc'], 'DE');
      expect(fields['warp'], 'off');
      expect(fields['tls'], 'TLSv1.3');
      expect(fields['http'], 'http/2');
    });

    test('ignores malformed lines', () {
      const body = 'ip=1.2.3.4\nno-separator-here\n=empty-key\ncolo=\n';
      final fields = IpInfoService.parseCloudflareTrace(body);
      expect(fields['ip'], '1.2.3.4');
      expect(fields.containsKey('no-separator-here'), isFalse);
      expect(fields['colo'], '');
    });
  });

  group('IpInfoService - RDAP parsing', () {
    test('extracts network, organization, country, dates and abuse contact',
        () {
      final json = <String, dynamic>{
        'objectClassName': 'ip network',
        'handle': '8.8.8.0 - 8.8.8.255',
        'name': 'GOOGLE',
        'entities': [
          {
            'objectClassName': 'entity',
            'handle': 'GOGL',
            'roles': ['registrant'],
            'vCardArray': [
              'vcard',
              [
                ['version', {}, 'text', '4.0'],
                ['fn', {}, 'text', 'Google LLC'],
                [
                  'adr',
                  {'label': '1600 Amphitheatre Parkway\nMountain View\nCA\n94043\nUnited States'},
                  'text',
                  [
                    '',
                    '',
                    '1600 Amphitheatre Parkway',
                    'Mountain View',
                    'CA',
                    '94043',
                    'United States',
                  ],
                ],
              ],
            ],
          },
          {
            'objectClassName': 'entity',
            'handle': 'ABUSE',
            'roles': ['abuse'],
            'vCardArray': [
              'vcard',
              [
                ['version', {}, 'text', '4.0'],
                ['fn', {}, 'text', 'Google Abuse'],
                ['email', {}, 'text', 'abuse@google.com'],
              ],
            ],
          },
        ],
        'events': [
          {
            'eventAction': 'registration',
            'eventDate': '2014-03-14T00:00:00Z',
          },
          {
            'eventAction': 'last changed',
            'eventDate': '2020-03-31T00:00:00Z',
          },
        ],
      };

      final info = IpInfoService.parseRdap(json, '8.8.8.8');
      expect(info.ip, '8.8.8.8');
      expect(info.networkName, 'GOOGLE');
      expect(info.organization, 'Google LLC');
      expect(info.country, 'United States');
      expect(info.registeredOn, '2014-03-14T00:00:00Z');
      expect(info.lastChanged, '2020-03-31T00:00:00Z');
      expect(info.abuseEmail, 'abuse@google.com');
      expect(info.error, isNull);
    });

    test('handles a minimal RDAP response without entities or events', () {
      final info = IpInfoService.parseRdap(
        <String, dynamic>{'objectClassName': 'ip network'},
        '1.2.3.4',
      );
      expect(info.ip, '1.2.3.4');
      expect(info.networkName, isNull);
      expect(info.organization, isNull);
      expect(info.country, isNull);
      expect(info.abuseEmail, isNull);
    });
  });
}

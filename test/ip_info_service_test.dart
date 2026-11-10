import 'package:flutter_test/flutter_test.dart';
import 'package:rdnbenet/core/services/ip_info_service.dart';

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

  group('IpInfoService - purity scoring', () {
    const cleanFactor = PurityFactor(
      name: 'Clean check',
      passed: true,
      detail: 'ok',
      penalty: 60,
    );

    test('all passing factors score 100', () {
      expect(
        IpInfoService.computePurityScore([cleanFactor, cleanFactor]),
        100,
      );
    });

    test('a failing factor subtracts its penalty', () {
      const torFactor = PurityFactor(
        name: 'Tor exit node',
        passed: false,
        detail: 'exit node',
        penalty: 60,
      );
      expect(IpInfoService.computePurityScore([cleanFactor, torFactor]), 40);
    });

    test('an unchecked factor (passed == null) subtracts nothing', () {
      const uncheckedFactor = PurityFactor(
        name: 'Reverse DNS',
        passed: null,
        detail: 'not checked',
        penalty: 15,
      );
      expect(
        IpInfoService.computePurityScore([cleanFactor, uncheckedFactor]),
        100,
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

    test('all unchecked factors return 0 and unverified', () {
      const uncheckedFactor = PurityFactor(
        name: 'Reverse DNS',
        passed: null,
        detail: 'not checked',
        penalty: 15,
      );
      expect(
        IpInfoService.computePurityScore([uncheckedFactor]),
        0,
      );
      expect(
        IpInfoService.purityVerdict(0, hasVerifiedFactors: false),
        'Unverified',
      );
    });

    test('verdict bands', () {
      expect(IpInfoService.purityVerdict(100), 'Clean');
      expect(IpInfoService.purityVerdict(80), 'Clean');
      expect(IpInfoService.purityVerdict(79), 'Suspicious');
      expect(IpInfoService.purityVerdict(50), 'Suspicious');
      expect(IpInfoService.purityVerdict(49), 'Flagged');
      expect(IpInfoService.purityVerdict(0), 'Flagged');
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
      expect(IpInfoService.isHostingAsn('Mobile Telecommunication Company of Iran'), isFalse);
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

  group('IpInfoService - live lookups', () {
    test('fetchIpLookup returns a public IP', () async {
      final lookup = await IpInfoService.fetchIpLookup();
      expect(
        lookup.primaryIp,
        isNotNull,
        reason: 'No public IP could be fetched',
      );
      print('Public IP: ${lookup.primaryIp}');
      if (lookup.geo != null) {
        print(
          'Geo: ${lookup.geo!.countryName}, ${lookup.geo!.cityName} '
          '(${lookup.geo!.ispName})',
        );
      }
    });

    test('checkCloudflare returns trace fields', () async {
      final status = await IpInfoService.checkCloudflare();
      expect(
        status.reachable,
        isTrue,
        reason: 'Cloudflare trace unreachable: ${status.error}',
      );
      expect(status.ip, isNotNull);
      print('Cloudflare edge: ${status.colo} (${status.location}), '
          'WARP: ${status.warp}');
    });

    test('checkIpPurity returns factors and verdict', () async {
      final purity = await IpInfoService.checkIpPurity(ip: '8.8.8.8');
      expect(purity.factors, isNotEmpty);
      expect(purity.score, inInclusiveRange(0, 100));
      expect(['Clean', 'Suspicious', 'Flagged', 'Unverified'], contains(purity.verdict));
    });
  });
}

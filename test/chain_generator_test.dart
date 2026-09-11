import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rdnbenet/core/services/proxy_parser_service.dart';

void main() {
  group('Chain Generator & Xray Config Support Tests', () {
    test('sanitizes relaxed JSON5 with line comments, block comments, and trailing commas', () {
      const relaxedJson = '''
      // Leading comment
      {
        /* Multi-line
           block comment */
        "protocol": "vless", // inline line comment
        "address": "1.2.3.4", /* inline block comment */
        "port": 443,
        "path": "//api/v1/*test*/,hello,", // comments and commas inside string literal
        "settings": {
          "vnext": [
            {
              "address": "1.2.3.4",
              "port": 443,
            }, // trailing comma in object and array
          ],
        },
      }
      ''';

      final sanitized = ProxyParserService.sanitizeJson(relaxedJson);
      final decoded = json.decode(sanitized) as Map<String, dynamic>;

      expect(decoded['protocol'], equals('vless'));
      expect(decoded['address'], equals('1.2.3.4'));
      expect(decoded['port'], equals(443));
      expect(decoded['path'], equals('//api/v1/*test*/,hello,'));
      final vnext = (decoded['settings'] as Map)['vnext'] as List;
      expect(vnext.length, equals(1));
      expect(vnext[0]['address'], equals('1.2.3.4'));
    });

    test('parses standalone Xray outbound JSON containing finalmask and sockopt', () {
      const standaloneOutboundJson = '''
      {
        "tag": "my-custom-outbound",
        "protocol": "vless",
        "settings": {
          "vnext": [
            {
              "address": "entry.domain.com",
              "port": 443,
              "users": [
                {
                  "id": "11111111-2222-3333-4444-555555555555",
                  "encryption": "none",
                  "flow": "xtls-rprx-vision"
                }
              ]
            }
          ]
        },
        "streamSettings": {
          "network": "tcp",
          "security": "reality",
          "realitySettings": {
            "serverName": "entry.domain.com",
            "publicKey": "base64publickeyhere1234567890=",
            "shortId": "16"
          },
          "finalmask": {
            "tcp": [
              {
                "type": "fragment",
                "settings": {
                  "packets": "1-3",
                  "lengths": "100-200",
                  "delays": "10-20"
                }
              }
            ]
          },
          "sockopt": {
            "domainStrategy": "UseIP",
            "happyEyeballs": {
              "interleave": 2,
              "maxConcurrentTry": 4
            }
          }
        }
      }
      ''';

      final node = ProxyParserService.parseLink(standaloneOutboundJson);

      expect(node.protocol, equals('vless'));
      expect(node.address, equals('entry.domain.com'));
      expect(node.port, equals(443));
      expect(node.idOrPassword, equals('11111111-2222-3333-4444-555555555555'));
      expect(node.security, equals('reality'));
      expect(node.finalmask, isNotNull);
      expect(node.finalmask!['tcp'], isList);
      expect(node.sockopt, isNotNull);
      expect(node.sockopt!['domainStrategy'], equals('UseIP'));
      expect(node.sockopt!['happyEyeballs']['interleave'], equals(2));

      // Test generating outbound for hop0 (entry)
      final outboundHop0 = node.toXrayOutbound(tag: 'hop0');
      expect(outboundHop0['tag'], equals('hop0'));
      expect(outboundHop0['protocol'], equals('vless'));
      expect(outboundHop0['streamSettings']['finalmask'], isNotNull);
      expect(outboundHop0['streamSettings']['sockopt']['domainStrategy'], equals('UseIP'));
      expect(outboundHop0['streamSettings']['sockopt']['dialerProxy'], isNull);
    });

    test('parses full Xray config JSON with comments and trailing commas, ignoring non-proxy protocols', () {
      const fullXrayConfig = '''
      // Full Xray Configuration with relaxed JSON formatting
      {
        /* Inbounds section */
        "inbounds": [
          {
            "port": 10808,
            "protocol": "socks",
            "settings": { "auth": "noauth", },
          },
        ],
        /* Outbounds section with non-proxy protocols first */
        "outbounds": [
          // Freedom outbound (should be skipped)
          {
            "protocol": "freedom",
            "tag": "direct",
            "settings": {},
          },
          // Blackhole outbound (should be skipped)
          {
            "protocol": "blackhole",
            "tag": "block",
            "settings": {},
          },
          // DNS outbound (should be skipped)
          {
            "protocol": "dns",
            "tag": "dns-out",
          },
          // Actual proxy outbound
          {
            "protocol": "trojan",
            "tag": "trojan-proxy",
            "settings": {
              "servers": [
                {
                  "address": "exit.trojan.com",
                  "port": 8443,
                  "password": "trojan-super-secret-password",
                },
              ],
            },
            "streamSettings": {
              "network": "ws",
              "security": "tls",
              "tlsSettings": {
                "serverName": "exit.trojan.com",
                "alpn": ["h2", "http/1.1",],
              },
              "wsSettings": {
                "path": "/trojan-ws",
                "headers": {
                  "Host": "exit.trojan.com",
                },
              },
            },
          },
        ],
      }
      ''';

      final node = ProxyParserService.parseLink(fullXrayConfig);

      expect(node.protocol, equals('trojan'));
      expect(node.address, equals('exit.trojan.com'));
      expect(node.port, equals(8443));
      expect(node.idOrPassword, equals('trojan-super-secret-password'));
      expect(node.network, equals('ws'));
      expect(node.security, equals('tls'));
      expect(node.sni, equals('exit.trojan.com'));
      expect(node.path, equals('/trojan-ws'));
      expect(node.host, equals('exit.trojan.com'));
    });

    test('parses vless:// link containing URL-encoded finalmask query param', () {
      final finalmaskObj = {
        'tcp': [
          {
            'type': 'fragment',
            'settings': {
              'packets': '1-3',
              'lengths': '100-200',
              'delays': '10-20',
            },
          },
        ],
      };
      final encodedFinalmask = Uri.encodeComponent(json.encode(finalmaskObj));
      final link =
          'vless://00000000-0000-0000-0000-000000000001@entry.vless.com:443?type=ws&security=tls&finalmask=$encodedFinalmask#EntryVlessFinalmask';

      final node = ProxyParserService.parseLink(link);

      expect(node.protocol, equals('vless'));
      expect(node.address, equals('entry.vless.com'));
      expect(node.finalmask, isNotNull);
      expect(node.finalmask!['tcp'], isList);

      final outbound = node.toXrayOutbound(tag: 'hop0');
      expect(outbound['streamSettings']['finalmask'], equals(finalmaskObj));
    });

    test('parses vless:// link containing base64 encoded finalmask query param', () {
      final finalmaskObj = {
        'tcp': [
          {
            'type': 'fragment',
            'settings': {'packets': 'tlshello'},
          },
        ],
      };
      final b64Finalmask = base64.encode(utf8.encode(json.encode(finalmaskObj)));
      final link =
          'vless://00000000-0000-0000-0000-000000000001@entry.vless.com:443?type=ws&security=tls&finalmask=$b64Finalmask#EntryVlessB64';

      final node = ProxyParserService.parseLink(link);

      expect(node.finalmask, isNotNull);
      expect(node.finalmask!['tcp'][0]['settings']['packets'], equals('tlshello'));
    });

    test('parses vless:// link containing xhttp transport and generates xhttpSettings', () {
      const link =
          'vless://00000000-0000-0000-0000-000000000002@xhttp.example.com:443?type=xhttp&security=tls&path=%2Fxhttp-endpoint&host=xhttp.example.com&mode=packet-up#XhttpNode';

      final node = ProxyParserService.parseLink(link);

      expect(node.protocol, equals('vless'));
      expect(node.address, equals('xhttp.example.com'));
      expect(node.network, equals('xhttp'));
      expect(node.path, equals('/xhttp-endpoint'));
      expect(node.host, equals('xhttp.example.com'));
      expect(node.mode, equals('packet-up'));

      final outbound = node.toXrayOutbound(tag: 'hop0');
      expect(outbound['streamSettings']['network'], equals('xhttp'));
      expect(outbound['streamSettings']['xhttpSettings'], isNotNull);
      expect(outbound['streamSettings']['xhttpSettings']['path'], equals('/xhttp-endpoint'));
      expect(outbound['streamSettings']['xhttpSettings']['host'], equals('xhttp.example.com'));
      expect(outbound['streamSettings']['xhttpSettings']['mode'], equals('packet-up'));
    });

    test('parses vless:// link with splithttp transport and normalizes to xhttp', () {
      const link =
          'vless://00000000-0000-0000-0000-000000000002@split.example.com:443?type=splithttp&security=tls&path=%2Fsplit-path#SplitNode';

      final node = ProxyParserService.parseLink(link);

      expect(node.network, equals('splithttp'));
      final outbound = node.toXrayOutbound(tag: 'hop0');
      expect(outbound['streamSettings']['network'], equals('xhttp'));
      expect(outbound['streamSettings']['xhttpSettings']['path'], equals('/split-path'));
    });

    test('parses fragment query param into sockopt', () {
      const link =
          'vless://00000000-0000-0000-0000-000000000001@frag.example.com:443?security=tls&fragment=1-3,100-200,10-20#FragNode';

      final node = ProxyParserService.parseLink(link);

      expect(node.sockopt, isNotNull);
      expect(node.sockopt!['fragment'], isNotNull);
      expect(node.sockopt!['fragment']['packets'], equals('1-3'));
      expect(node.sockopt!['fragment']['length'], equals('100-200'));
      expect(node.sockopt!['fragment']['interval'], equals('10-20'));
    });

    test('multi-hop chain generation preserves finalmask on hop0 and safely merges dialerProxy on hop1..N', () {
      // Hop 0: Standalone Xray JSON with finalmask and a residual dialerProxy (which should be removed)
      const hop0Json = '''
      {
        "protocol": "vless",
        "tag": "existing-hop0",
        "settings": {
          "vnext": [
            {
              "address": "hop0.entry.com",
              "port": 443,
              "users": [
                { "id": "00000000-0000-0000-0000-000000000000", "encryption": "none" }
              ]
            }
          ]
        },
        "streamSettings": {
          "network": "ws",
          "security": "tls",
          "tlsSettings": { "serverName": "hop0.entry.com" },
          "finalmask": {
            "tcp": [
              {
                "type": "fragment",
                "settings": { "packets": "1-3", "lengths": "100-200" }
              }
            ]
          },
          "sockopt": {
            "dialerProxy": "residual-old-hop",
            "domainStrategy": "UseIP"
          }
        }
      }
      ''';

      // Hop 1: VLESS link with sockopt domainStrategy and xhttp
      const hop1Link =
          'vless://11111111-1111-1111-1111-111111111111@hop1.middle.com:443?type=xhttp&path=%2Fxhttp&security=tls&domainStrategy=AsIs&tfo=1#MiddleHop';

      // Hop 2: Full Xray Config JSON with sockopt happyEyeballs
      const hop2Json = '''
      {
        "outbounds": [
          {
            "protocol": "trojan",
            "tag": "hop2-trojan",
            "settings": {
              "servers": [
                { "address": "hop2.exit.com", "port": 8443, "password": "pass" }
              ]
            },
            "streamSettings": {
              "network": "grpc",
              "security": "tls",
              "sockopt": {
                "happyEyeballs": { "interleave": 2 }
              }
            }
          }
        ]
      }
      ''';

      final chainProfile = ProxyParserService.generateChainProfile(
        nodeShareLinks: [hop0Json, hop1Link, hop2Json],
        socksPort: 10808,
        httpPort: 10809,
      );

      final outbounds = chainProfile['outbounds'] as List;
      expect(outbounds.length, equals(5)); // hop0, hop1, hop2, direct, block

      // Hop 0 verification:
      final hop0 = outbounds[0] as Map<String, dynamic>;
      expect(hop0['tag'], equals('hop0'));
      expect(hop0['protocol'], equals('vless'));
      // finalmask preserved on hop0
      expect(hop0['streamSettings']['finalmask'], isNotNull);
      expect(hop0['streamSettings']['finalmask']['tcp'], isList);
      // residual dialerProxy removed from hop0
      expect(hop0['streamSettings']['sockopt']['dialerProxy'], isNull);
      // existing sockopt options preserved on hop0
      expect(hop0['streamSettings']['sockopt']['domainStrategy'], equals('UseIP'));

      // Hop 1 verification:
      final hop1 = outbounds[1] as Map<String, dynamic>;
      expect(hop1['tag'], equals('hop1'));
      expect(hop1['protocol'], equals('vless'));
      expect(hop1['streamSettings']['network'], equals('xhttp'));
      // dialerProxy safely merged as 'hop0'
      expect(hop1['streamSettings']['sockopt']['dialerProxy'], equals('hop0'));
      // existing sockopt options preserved
      expect(hop1['streamSettings']['sockopt']['domainStrategy'], equals('AsIs'));
      expect(hop1['streamSettings']['sockopt']['tcpFastOpen'], isTrue);

      // Hop 2 verification:
      final hop2 = outbounds[2] as Map<String, dynamic>;
      expect(hop2['tag'], equals('hop2'));
      expect(hop2['protocol'], equals('trojan'));
      // dialerProxy safely merged as 'hop1'
      expect(hop2['streamSettings']['sockopt']['dialerProxy'], equals('hop1'));
      // existing sockopt options preserved
      expect(hop2['streamSettings']['sockopt']['happyEyeballs']['interleave'], equals(2));

      // Routing rule points to final hop
      final routingRules = chainProfile['routing']['rules'] as List;
      expect(routingRules.first['outboundTag'], equals('hop2'));
    });
  });
}

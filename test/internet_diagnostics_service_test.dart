import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rdnbenet/core/services/internet_diagnostics_service.dart';

void main() {
  group('InternetDiagnosticsService - Chabokan IP Parsing', () {
    test('fetchPublicIp with domestic: true queries chabokan and successfully parses the IP from JSON', () async {
      final result = await InternetDiagnosticsService.fetchPublicIp(domestic: true);
      
      expect(result.success, isTrue, reason: 'Failed to fetch public IP: ${result.details}');
      expect(result.message, startsWith('IP retrieved: '));
      
      final ip = result.message.replaceFirst('IP retrieved: ', '').trim();
      
      // Verify it's a valid IP address (not a JSON string!)
      final ipRegex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$|^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$',
      );
      expect(ipRegex.hasMatch(ip), isTrue, reason: 'Extracted IP is not a valid IP: $ip');
      
      print('Successfully fetched and parsed domestic IP from Chabokan: $ip');
    });

    test('fetchPublicIp with domestic: false queries international endpoints in parallel and succeeds', () async {
      final result = await InternetDiagnosticsService.fetchPublicIp(domestic: false);
      
      expect(result.success, isTrue, reason: 'Failed to fetch public IP: ${result.details}');
      expect(result.message, startsWith('IP retrieved: '));
      
      final ip = result.message.replaceFirst('IP retrieved: ', '').trim();
      final ipRegex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$|^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$',
      );
      expect(ipRegex.hasMatch(ip), isTrue, reason: 'Extracted IP is not a valid IP: $ip');
      
      print('Successfully fetched and parsed international IP in parallel: $ip');
    });
  });

  group('InternetDiagnosticsService - Connectivity Checks', () {
    test('checkDnsResolution completes and verifies multiple hostnames', () async {
      final result = await InternetDiagnosticsService.checkDnsResolution();
      print('DNS Resolution Details:\n${result.details}');
      expect(result.name, equals('DNS Resolution'));
      expect(result.details, contains('Tested Endpoints:'));
      expect(result.details, contains('one.one.one.one'));
      expect(result.details, contains('dns.google'));
    });

    test('checkIpv4Connectivity completes and verifies multiple resolvers', () async {
      final result = await InternetDiagnosticsService.checkIpv4Connectivity();
      print('IPv4 Connection Details:\n${result.details}');
      expect(result.name, equals('IPv4 Connectivity'));
      expect(result.details, contains('Tested Endpoints:'));
      expect(result.details, contains('Cloudflare DNS'));
      expect(result.details, contains('Google DNS'));
      expect(result.details, contains('Quad9 DNS'));
    });

    test('checkIpv6Connectivity completes and verifies multiple resolvers', () async {
      final result = await InternetDiagnosticsService.checkIpv6Connectivity();
      print('IPv6 Connection Details:\n${result.details}');
      expect(result.name, equals('IPv6 Connectivity'));
      expect(result.details, contains('Tested Endpoints:'));
      expect(result.details, contains('Cloudflare IPv6 DNS'));
      expect(result.details, contains('Google IPv6 DNS'));
      expect(result.details, contains('Quad9 IPv6 DNS'));
    });

    test('checkHttpsTraffic completes and verifies multiple HTTP endpoints', () async {
      final result = await InternetDiagnosticsService.checkHttpsTraffic();
      print('HTTPS Connection Details:\n${result.details}');
      expect(result.name, equals('HTTPS Traffic'));
      expect(result.details, contains('Tested Endpoints:'));
      expect(result.details, contains('https://www.cloudflare.com'));
      expect(result.details, contains('https://www.google.com'));
    });
  });

  group('InternetDiagnosticsService - CDN Parallel IP Scanner', () {
    test('scanCdnIps parses and returns scan result structure', () async {
      final result = await InternetDiagnosticsService.scanCdnIps(
        ['8.8.8.8', '1.1.1.1'],
        timeout: const Duration(milliseconds: 100),
      );
      
      expect(result.totalTested, equals(2));
      expect(result.reachable, isNotNull);
      expect(result.averageLatencyMs, isNotNull);
      expect(result.accessibilityRate, isNotNull);
    });
  });

  group('InternetDiagnosticsService - TLS Certificate Domain Verification', () {
    test('domainMatchesCertificateName handles exact, wildcard, apex, and www', () {
      expect(
        InternetDiagnosticsService.domainMatchesCertificateName('google.com', 'google.com'),
        isTrue,
      );
      expect(
        InternetDiagnosticsService.domainMatchesCertificateName('mail.google.com', '*.google.com'),
        isTrue,
      );
      expect(
        InternetDiagnosticsService.domainMatchesCertificateName('google.com', '*.google.com'),
        isTrue,
      );
      expect(
        InternetDiagnosticsService.domainMatchesCertificateName('playstation.com', 'www.playstation.com'),
        isTrue,
      );
      expect(
        InternetDiagnosticsService.domainMatchesCertificateName('www.playstation.com', 'playstation.com'),
        isTrue,
      );
      expect(
        InternetDiagnosticsService.domainMatchesCertificateName('xbox.com', 'surface.com'),
        isFalse,
      );
      expect(
        InternetDiagnosticsService.domainMatchesCertificateName('evil.google.com.attacker.com', '*.google.com'),
        isFalse,
      );
    });

    test('extractSubjectAlternativeNames extracts DNS names from certificate DER', () {
      final der = _buildMinimalCertWithSans(['xbox.com', 'surface.com', '*.domain.com']);
      final sans = InternetDiagnosticsService.extractSubjectAlternativeNames(der);
      expect(sans, containsAll(['xbox.com', 'surface.com', '*.domain.com']));
    });

    test('certificateLooksLikeDomain verifies multi-domain / shared CDN SANs (Issue #77)', () {
      // Scenario 1: Multi-domain / Shared CDN cert where CN is surface.com, but SAN contains xbox.com
      final xboxCert = _FakeX509Certificate(
        subject: 'C=US, ST=WA, L=Redmond, O=Microsoft Corporation, CN=surface.com',
        der: _buildMinimalCertWithSans(['myservice.surface.com', 'xbox.com', 'surface.com']),
      );
      expect(
        InternetDiagnosticsService.certificateLooksLikeDomain(xboxCert, 'xbox.com'),
        isTrue,
      );

      // Scenario 2: Wildcard CN (*.google.com) with apex in SAN or matched by wildcard
      final googleCert = _FakeX509Certificate(
        subject: 'CN=*.google.com',
        der: _buildMinimalCertWithSans(['*.google.com', 'google.com']),
      );
      expect(
        InternetDiagnosticsService.certificateLooksLikeDomain(googleCert, 'google.com'),
        isTrue,
      );

      // Scenario 3: Subdomain vs Apex CN (*.cloudflareinsights.com in SAN, CN is cloudflareinsights.com)
      final cfCert = _FakeX509Certificate(
        subject: 'CN=cloudflareinsights.com',
        der: _buildMinimalCertWithSans(['cloudflareinsights.com', '*.cloudflareinsights.com']),
      );
      expect(
        InternetDiagnosticsService.certificateLooksLikeDomain(cfCert, 'static.cloudflareinsights.com'),
        isTrue,
      );

      // Scenario 4: Genuine mismatch (neither CN nor SAN match)
      final mismatchCert = _FakeX509Certificate(
        subject: 'CN=attacker.com',
        der: _buildMinimalCertWithSans(['attacker.com', 'fake.com']),
      );
      expect(
        InternetDiagnosticsService.certificateLooksLikeDomain(mismatchCert, 'google.com'),
        isFalse,
      );
    });
  });
}

class _FakeX509Certificate implements X509Certificate {
  @override
  final String subject;
  @override
  String get issuer => 'CN=Test CA';
  @override
  final Uint8List der;
  @override
  DateTime get startValidity => DateTime.now().subtract(const Duration(days: 1));
  @override
  DateTime get endValidity => DateTime.now().add(const Duration(days: 30));
  @override
  Uint8List get sha1 => Uint8List(20);
  @override
  String get pem => '';

  _FakeX509Certificate({
    required this.subject,
    Uint8List? der,
  }) : der = der ?? Uint8List(0);
}

Uint8List _buildMinimalCertWithSans(List<String> dnsNames) {
  final gnBytes = <int>[];
  for (final name in dnsNames) {
    final nameBytes = name.codeUnits;
    gnBytes.add(0x82); // [2] dNSName tag
    gnBytes.add(nameBytes.length);
    gnBytes.addAll(nameBytes);
  }
  final gnSeq = [0x30, gnBytes.length, ...gnBytes];
  final ext = [
    0x30,
    5 + 2 + gnSeq.length,
    0x06, 0x03, 0x55, 0x1d, 0x11, // OID 2.5.29.17
    0x04, gnSeq.length, ...gnSeq, // OCTET STRING
  ];
  final extsSeq = [0x30, ext.length, ...ext];
  final extTag = [0xa3, extsSeq.length, ...extsSeq]; // [3] EXPLICIT
  final tbs = [0x30, extTag.length, ...extTag]; // TBSCertificate
  final cert = [0x30, tbs.length, ...tbs]; // Certificate
  return Uint8List.fromList(cert);
}

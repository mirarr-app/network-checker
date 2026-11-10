import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'internet_diagnostics_service.dart';
import 'protocol_accessibility_service.dart';

/// IP info service: the native equivalent of an IP lookup / IP purity /
/// split-routing / browser-environment website (e.g. ipfinal.com).
///
/// All data comes from free, keyless sources:
/// - Public IP: api.ipify.org / icanhazip.com / ident.me (via
///   [InternetDiagnosticsService.fetchPublicIp]) and api64.ipify.org for IPv6.
/// - Geolocation / ASN / proxy flag: freeipapi.com (already used by the app).
/// - IP purity: the Tor bulk exit list, the freeipapi `isProxy` flag, ASN
///   ownership and reverse-DNS heuristics. No paid reputation API is used,
///   so the score is a transparent heuristic, not a commercial verdict.
/// - Split routing: Cloudflare's `/cdn-cgi/trace` endpoint (any
///   Cloudflare-fronted domain echoes the exit IP it saw) plus system DNS
///   resolution and HTTPS latency for the rest.
/// - DNS leak: system DNS answers compared against Cloudflare and Google
///   DNS-over-HTTPS.
/// - Cloudflare: `https://www.cloudflare.com/cdn-cgi/trace`.
/// - Whois: public RDAP (`https://rdap.org/ip/<ip>`).
/// - Global ping: ICMP via the `ping` binary, with an HTTPS-latency fallback
///   on devices where `ping` is unavailable.
class IpInfoService {
  static const _torExitListUrl =
      'https://check.torproject.org/torbulkexitlist';
  static const _rdapBaseUrl = 'https://rdap.org/ip';

  static Set<String>? _torExitIps;
  static DateTime? _torExitListFetchedAt;

  /// Fetches the device's public IPv4 and IPv6 addresses plus GeoIP details
  /// for the primary address. Either address may be null when unavailable.
  static Future<IpLookupInfo> fetchIpLookup() async {
    String? ipv4;
    String? ipv6;

    try {
      final result = await InternetDiagnosticsService.fetchPublicIp(
        domestic: false,
      );
      if (result.success) {
        final ip = result.message.replaceFirst('IP retrieved: ', '').trim();
        if (ip.contains(':')) {
          ipv6 = ip;
        } else {
          ipv4 = ip;
        }
      }
    } catch (e) {
      debugPrint('IP info: public IP lookup failed: $e');
    }

    // api64 returns the IPv6 address when the device has IPv6, else IPv4.
    try {
      final response = await http
          .get(Uri.parse('https://api64.ipify.org'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final ip = response.body.trim();
        if (ip.contains(':')) {
          ipv6 = ip;
        } else {
          ipv4 ??= ip;
        }
      }
    } catch (e) {
      debugPrint('IP info: api64.ipify.org lookup failed: $e');
    }

    IpGeoInfo? geo;
    final primaryIp = ipv4 ?? ipv6;
    if (primaryIp != null) {
      try {
        geo = await InternetDiagnosticsService.fetchIpGeoDetails(primaryIp);
      } catch (_) {}
    }

    return IpLookupInfo(ipv4: ipv4, ipv6: ipv6, geo: geo);
  }

  // ── IP purity ──────────────────────────────────────────────────────────

  /// Scores an IP from 0 (flagged) to 100 (clean) using only free signals.
  /// Each factor that fails subtracts its penalty; factors that could not
  /// be checked ([PurityFactor.passed] == null) subtract nothing.
  static int computePurityScore(List<PurityFactor> factors) {
    var score = 100;
    for (final factor in factors) {
      if (factor.passed == false) score -= factor.penalty;
    }
    return score.clamp(0, 100);
  }

  static String purityVerdict(int score) {
    if (score >= 80) return 'Clean';
    if (score >= 50) return 'Suspicious';
    return 'Flagged';
  }

  /// Runs the purity checks for [ip]. [geo] is reused when the caller
  /// already fetched it (from [fetchIpLookup]) to avoid a second lookup.
  static Future<IpPurityResult> checkIpPurity({
    required String ip,
    IpGeoInfo? geo,
  }) async {
    final factors = <PurityFactor>[];

    // 1. Tor exit node membership.
    final torExitIps = await _fetchTorExitList();
    if (torExitIps == null) {
      factors.add(
        const PurityFactor(
          name: 'Tor exit node',
          passed: null,
          detail: 'Tor exit list unreachable — not checked',
          penalty: 60,
        ),
      );
    } else {
      final isExit = torExitIps.contains(ip);
      factors.add(
        PurityFactor(
          name: 'Tor exit node',
          passed: !isExit,
          detail: isExit
              ? 'This IP is a known Tor exit node'
              : 'Not a known Tor exit node',
          penalty: 60,
        ),
      );
    }

    // 2. Proxy flag and ASN ownership from the GeoIP database.
    if (geo != null) {
      factors.add(
        PurityFactor(
          name: 'Known proxy',
          passed: !geo.isProxy,
          detail: geo.isProxy
              ? 'GeoIP database flags this IP as a proxy'
              : 'Not flagged as a proxy',
          penalty: 35,
        ),
      );

      final hosting = isHostingAsn(geo.asnOrganization);
      factors.add(
        PurityFactor(
          name: 'Datacenter / hosting ASN',
          passed: !hosting,
          detail: hosting
              ? 'ASN belongs to a hosting/cloud provider'
                    ' (${geo.asnOrganization})'
              : 'ASN looks like a residential/ISP network'
                    ' (${geo.asnOrganization})',
          penalty: 25,
        ),
      );
    }

    // 3. Reverse DNS: server/datacenter-style PTR hostnames.
    final ptr = await _reverseDns(ip);
    if (ptr == null) {
      factors.add(
        const PurityFactor(
          name: 'Reverse DNS',
          passed: null,
          detail: 'No PTR record — not checked',
          penalty: 15,
        ),
      );
    } else {
      final datacenter = ptrLooksLikeDatacenter(ptr);
      factors.add(
        PurityFactor(
          name: 'Reverse DNS',
          passed: !datacenter,
          detail: datacenter
              ? 'PTR hostname looks like a server/datacenter ($ptr)'
              : 'PTR hostname: $ptr',
          penalty: 15,
        ),
      );
    }

    final score = computePurityScore(factors);
    return IpPurityResult(
      score: score,
      verdict: purityVerdict(score),
      factors: factors,
    );
  }

  static Future<Set<String>?> _fetchTorExitList() async {
    if (_torExitIps != null &&
        _torExitListFetchedAt != null &&
        DateTime.now().difference(_torExitListFetchedAt!).inMinutes < 60) {
      return _torExitIps;
    }
    try {
      final response = await http
          .get(Uri.parse(_torExitListUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        _torExitIps = response.body
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && !line.startsWith('#'))
            .toSet();
        _torExitListFetchedAt = DateTime.now();
        return _torExitIps;
      }
    } catch (e) {
      debugPrint('IP info: Tor exit list fetch failed: $e');
    }
    return null;
  }

  /// Whether an ASN organization name belongs to a hosting/cloud provider.
  static bool isHostingAsn(String organization) {
    final lower = organization.toLowerCase();
    if (lower.isEmpty) return false;
    return _hostingOrgKeywords.any((keyword) => lower.contains(keyword));
  }

  static const List<String> _hostingOrgKeywords = [
    'amazon',
    'microsoft',
    'azure',
    'google cloud',
    'compute engine',
    'digitalocean',
    'linode',
    'vultr',
    'hetzner',
    'ovh',
    'alibaba',
    'tencent cloud',
    'oracle cloud',
    'akamai',
    'cloudflare',
    'fastly',
    'choopa',
    'kamatera',
    'contabo',
    'scaleway',
    'ionos',
    'hosting',
    'datacenter',
    'data center',
    'vps',
  ];

  /// Whether a PTR hostname looks like a server/datacenter host.
  static bool ptrLooksLikeDatacenter(String hostname) {
    final lower = hostname.toLowerCase();
    return _datacenterPtrKeywords.any((keyword) => lower.contains(keyword));
  }

  static const List<String> _datacenterPtrKeywords = [
    'vps',
    'vultr',
    'digitalocean',
    'linode',
    'amazonaws',
    'googleusercontent',
    'azure',
    'datacenter',
    'dedicated',
    'compute',
    'hosting',
    'cloud-',
    '.vps',
  ];

  static Future<String?> _reverseDns(String ip) async {
    try {
      final reversed = await InternetAddress(
        ip,
      ).reverse().timeout(const Duration(seconds: 5));
      // No PTR record: the resolver echoes the IP itself.
      if (reversed.host == ip) return null;
      return reversed.host;
    } catch (_) {
      return null;
    }
  }

  // ── Split routing ──────────────────────────────────────────────────────

  /// Tests each target domain and reports the exit IP it was reached with.
  /// Cloudflare-fronted domains echo the exit IP via `/cdn-cgi/trace`;
  /// other domains fall back to system DNS resolution + HTTPS, in which case
  /// the exit IP is the device's current public IP ([publicIp]).
  /// Results arrive incrementally through [onResult].
  static Future<void> testSplitRouting({
    required List<SplitRouteTarget> targets,
    required String? publicIp,
    required void Function(SplitRouteResult result) onResult,
    int concurrency = 8,
  }) async {
    final geoCache = <String, String?>{};

    Future<String?> geoFor(String ip) async {
      if (geoCache.containsKey(ip)) return geoCache[ip];
      String? label;
      try {
        final geo = await InternetDiagnosticsService.fetchIpGeoDetails(ip);
        if (geo != null) label = '${geo.countryName}, ${geo.cityName}';
      } catch (_) {}
      geoCache[ip] = label;
      return label;
    }

    final queue = Queue<SplitRouteTarget>.of(targets);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final target = queue.removeFirst();
        final result = await _testSingleSplitRoute(
          target,
          publicIp: publicIp,
          geoFor: geoFor,
        );
        onResult(result);
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
  }

  static Future<SplitRouteResult> _testSingleSplitRoute(
    SplitRouteTarget target, {
    required String? publicIp,
    required Future<String?> Function(String ip) geoFor,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Cloudflare trace: the site itself reports the IP it saw.
    try {
      final traceUri = Uri.parse('https://${target.domain}/cdn-cgi/trace');
      final traceResponse = await http
          .get(traceUri)
          .timeout(const Duration(seconds: 4));
      if (traceResponse.statusCode == 200) {
        final fields = parseCloudflareTrace(traceResponse.body);
        final traceIp = fields['ip'];
        if (traceIp != null && traceIp.isNotEmpty) {
          stopwatch.stop();
          return SplitRouteResult(
            name: target.name,
            domain: target.domain,
            status: ReachabilityStatus.reachable,
            exitIp: traceIp,
            exitIpLocation: await geoFor(traceIp),
            latencyMs: stopwatch.elapsedMilliseconds,
            exitIpFromTrace: true,
          );
        }
      }
    } catch (_) {
      // Fall through to DNS + HTTPS.
    }

    // 2. DNS resolution via the system resolver (respects VPN split rules).
    List<InternetAddress>? resolved;
    try {
      resolved = await InternetAddress.lookup(
        target.domain,
      ).timeout(const Duration(seconds: 5));
    } on TimeoutException {
      stopwatch.stop();
      return SplitRouteResult(
        name: target.name,
        domain: target.domain,
        status: ReachabilityStatus.dnsFailure,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails: 'DNS resolution timed out.',
      );
    } catch (e) {
      stopwatch.stop();
      return SplitRouteResult(
        name: target.name,
        domain: target.domain,
        status: ReachabilityStatus.dnsFailure,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails: 'DNS resolution failed: $e',
      );
    }

    if (resolved.isEmpty) {
      stopwatch.stop();
      return SplitRouteResult(
        name: target.name,
        domain: target.domain,
        status: ReachabilityStatus.dnsFailure,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails: 'DNS resolution returned no addresses.',
      );
    }

    final resolvedIp = resolved.first.address;
    if (resolvedIp == '127.0.0.1' || resolvedIp == '10.10.34.34') {
      stopwatch.stop();
      return SplitRouteResult(
        name: target.name,
        domain: target.domain,
        status: ReachabilityStatus.blocked,
        resolvedIp: resolvedIp,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails:
            'DNS hijacking detected! Resolved to known block IP: $resolvedIp',
      );
    }

    // 3. HTTPS request: any HTTP status means routing, DNS and TLS worked.
    try {
      final response = await http
          .head(Uri.parse('https://${target.domain}'))
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      return SplitRouteResult(
        name: target.name,
        domain: target.domain,
        status: ReachabilityStatus.reachable,
        exitIp: publicIp,
        exitIpLocation: publicIp != null ? await geoFor(publicIp) : null,
        resolvedIp: resolvedIp,
        latencyMs: stopwatch.elapsedMilliseconds,
        exitIpFromTrace: false,
        errorDetails:
            'Resolved IP: $resolvedIp\nHTTP Status: ${response.statusCode}',
      );
    } on TimeoutException {
      stopwatch.stop();
      return SplitRouteResult(
        name: target.name,
        domain: target.domain,
        status: ReachabilityStatus.timeout,
        resolvedIp: resolvedIp,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails: 'TCP connection timed out after 5 seconds.',
      );
    } on HandshakeException catch (e) {
      stopwatch.stop();
      return SplitRouteResult(
        name: target.name,
        domain: target.domain,
        status: ReachabilityStatus.tlsFailure,
        resolvedIp: resolvedIp,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails:
            'SSL/TLS Handshake failed: $e\nThis is a common symptom of SNI-based deep packet blocking.',
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return SplitRouteResult(
        name: target.name,
        domain: target.domain,
        status: ReachabilityStatus.blocked,
        resolvedIp: resolvedIp,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails: 'Socket Exception: $e',
      );
    } catch (e) {
      stopwatch.stop();
      return SplitRouteResult(
        name: target.name,
        domain: target.domain,
        status: ReachabilityStatus.blocked,
        resolvedIp: resolvedIp,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorDetails: 'Unclassified network error: $e',
      );
    }
  }

  // ── Connectivity latency ───────────────────────────────────────────────

  /// Median of the successful attempts, or null when every attempt failed.
  static int? medianLatency(List<int> values) {
    if (values.isEmpty) return null;
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  /// Measures HTTPS latency to [target] with 3 attempts and reports the
  /// median. Any HTTP status counts as reachable.
  static Future<LatencyResult> measureLatencyForTarget(
    SplitRouteTarget target,
  ) async {
    final attempts = <int?>[];
    String? error;
    for (var i = 0; i < 3; i++) {
      final stopwatch = Stopwatch()..start();
      try {
        await http
            .head(Uri.parse('https://${target.domain}'))
            .timeout(const Duration(seconds: 5));
        stopwatch.stop();
        attempts.add(stopwatch.elapsedMilliseconds);
      } catch (e) {
        stopwatch.stop();
        attempts.add(null);
        error ??= e.toString();
      }
    }
    final successes = attempts.whereType<int>().toList();
    return LatencyResult(
      name: target.name,
      domain: target.domain,
      attempts: attempts,
      medianLatencyMs: medianLatency(successes),
      reachable: successes.isNotEmpty,
      errorDetails: successes.isEmpty ? error : null,
    );
  }

  // ── Environment checks ─────────────────────────────────────────────────

  /// Parses a `cdn-cgi/trace` response body into `key=value` fields.
  static Map<String, String> parseCloudflareTrace(String body) {
    final fields = <String, String>{};
    for (final line in body.split('\n')) {
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      fields[line.substring(0, separator).trim()] =
          line.substring(separator + 1).trim();
    }
    return fields;
  }

  /// Compares the system DNS answer for a test domain against Cloudflare
  /// and Google DNS-over-HTTPS. A mismatch (or a block IP from the system
  /// resolver) means DNS traffic is leaking to, or being tampered with by,
  /// the local resolver.
  static Future<DnsLeakResult> checkDnsLeak() async {
    const testDomain = 'example.com';

    List<String> systemIps = [];
    String? systemError;
    try {
      final addresses = await InternetAddress.lookup(
        testDomain,
      ).timeout(const Duration(seconds: 5));
      systemIps = addresses.map((address) => address.address).toList();
    } catch (e) {
      systemError = e.toString();
    }

    final cloudflareIps = await _dohLookup(
      'https://cloudflare-dns.com/dns-query?name=$testDomain&type=A',
    );
    final googleIps = await _dohLookup(
      'https://dns.google/resolve?name=$testDomain&type=1',
    );

    var verdict = 'No DNS leak detected';
    var tampered = false;
    var leakDetected = false;

    if (systemIps.any(
      (ip) => ip == '127.0.0.1' || ip == '10.10.34.34',
    )) {
      tampered = true;
      verdict =
          'DNS tampering detected — system DNS returned a block IP ($testDomain → ${systemIps.join(', ')})';
    } else if (systemIps.isEmpty) {
      verdict =
          'System DNS failed to resolve $testDomain (${systemError ?? 'unknown error'})';
    } else if (cloudflareIps.isNotEmpty && googleIps.isNotEmpty) {
      final systemSet = systemIps.toSet();
      final agreesWithCf =
          systemSet.intersection(cloudflareIps.toSet()).isNotEmpty;
      final agreesWithGoogle =
          systemSet.intersection(googleIps.toSet()).isNotEmpty;
      if (!agreesWithCf && !agreesWithGoogle) {
        leakDetected = true;
        verdict =
            'System DNS disagrees with encrypted DNS — answers may be leaking to, or altered by, the local resolver';
      }
    }

    return DnsLeakResult(
      testDomain: testDomain,
      systemDnsIps: systemIps,
      cloudflareDohIps: cloudflareIps,
      googleDohIps: googleIps,
      systemError: systemError,
      verdict: verdict,
      tampered: tampered,
      leakDetected: leakDetected,
    );
  }

  static Future<List<String>> _dohLookup(String url) async {
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {'Accept': 'application/dns-json'},
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final answers = data['Answer'];
      if (answers is! List) return [];
      return answers
          .whereType<Map<String, dynamic>>()
          .map((answer) => answer['data']?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Native equivalent of a WebRTC leak test: WebRTC itself is a browser
  /// technology, so instead this compares the public IP as seen by several
  /// independent services (a mismatch means traffic exits through different
  /// paths) and lists the device's local network interfaces — the addresses
  /// a browser WebRTC check would expose.
  static Future<IpLeakResult> checkIpLeak() async {
    final seenBy = <String, String?>{};
    const echoEndpoints = {
      'ipify': 'https://api.ipify.org',
      'icanhazip': 'https://icanhazip.com',
      'ident.me': 'https://ident.me',
    };
    for (final entry in echoEndpoints.entries) {
      try {
        final response = await http
            .get(Uri.parse(entry.value))
            .timeout(const Duration(seconds: 5));
        seenBy[entry.key] =
            response.statusCode == 200 ? response.body.trim() : null;
      } catch (_) {
        seenBy[entry.key] = null;
      }
    }
    try {
      final response = await http
          .get(Uri.parse('https://www.cloudflare.com/cdn-cgi/trace'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        seenBy['Cloudflare trace'] =
            parseCloudflareTrace(response.body)['ip'];
      }
    } catch (_) {
      seenBy['Cloudflare trace'] = null;
    }

    final interfaces = <LocalInterfaceInfo>[];
    try {
      final list = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final interface in list) {
        for (final address in interface.addresses) {
          interfaces.add(
            LocalInterfaceInfo(
              name: interface.name,
              address: address.address,
              type: address.type.name,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('IP info: listing network interfaces failed: $e');
    }

    final distinctIps = seenBy.values.whereType<String>().toSet();
    return IpLeakResult(
      seenBy: seenBy,
      consistent: distinctIps.length <= 1,
      localInterfaces: interfaces,
    );
  }

  /// Reads Cloudflare's trace endpoint: the edge location, WARP status and
  /// negotiated TLS/HTTP versions for this connection.
  static Future<CloudflareStatus> checkCloudflare() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse('https://www.cloudflare.com/cdn-cgi/trace'))
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      if (response.statusCode != 200) {
        return CloudflareStatus(
          reachable: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          error: 'HTTP ${response.statusCode}',
        );
      }
      final fields = parseCloudflareTrace(response.body);
      return CloudflareStatus(
        reachable: true,
        ip: fields['ip'],
        colo: fields['colo'],
        location: fields['loc'],
        warp: fields['warp'],
        tlsVersion: fields['tls'],
        httpVersion: fields['http'],
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return CloudflareStatus(
        reachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  /// Public RDAP (whois) lookup for [ip]. Parses the network name,
  /// registrant organization, country, registration dates and abuse contact.
  static Future<WhoisInfo> lookupWhois(String ip) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .get(
            Uri.parse('$_rdapBaseUrl/$ip'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return parseRdap(
          data,
          ip,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
      return WhoisInfo(
        ip: ip,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: 'RDAP returned HTTP ${response.statusCode}',
      );
    } catch (e) {
      stopwatch.stop();
      return WhoisInfo(
        ip: ip,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  /// Parses an RDAP JSON response. Pure function, unit-testable.
  static WhoisInfo parseRdap(
    Map<String, dynamic> json,
    String ip, {
    int? latencyMs,
  }) {
    String? networkName = json['name'] as String?;
    String? country;
    String? organization;
    String? abuseEmail;
    String? registeredOn;
    String? lastChanged;

    final entities = json['entities'];
    if (entities is List) {
      for (final entity in entities) {
        if (entity is! Map<String, dynamic>) continue;
        final roles = (entity['roles'] as List?)
                ?.map((role) => role.toString())
                .toList() ??
            <String>[];
        final vcard = entity['vCardArray'];
        if (vcard is List && vcard.length > 1 && vcard[1] is List) {
          String? fn;
          String? email;
          String? adrCountry;
          for (final property in vcard[1] as List) {
            if (property is! List || property.isEmpty) continue;
            final key = property[0].toString();
            if (key == 'fn' && property.length > 3) {
              fn = property[3]?.toString();
            } else if (key == 'email' && property.length > 3) {
              email = property[3]?.toString();
            } else if (key == 'adr' &&
                property.length > 3 &&
                property[3] is List) {
              final addressParts = property[3] as List;
              if (addressParts.isNotEmpty) {
                adrCountry = addressParts.last?.toString();
              }
            }
          }
          if (fn != null) {
            if (roles.contains('registrant')) {
              organization = fn;
            } else {
              organization ??= fn;
            }
          }
          if (roles.contains('abuse') && email != null) {
            abuseEmail = email;
          }
          if (country == null && adrCountry != null) {
            country = adrCountry;
          }
        }
      }
    }

    final events = json['events'];
    if (events is List) {
      for (final event in events) {
        if (event is! Map<String, dynamic>) continue;
        if (event['eventAction'] == 'registration') {
          registeredOn = event['eventDate']?.toString();
        } else if (event['eventAction'] == 'last changed') {
          lastChanged = event['eventDate']?.toString();
        }
      }
    }

    return WhoisInfo(
      ip: ip,
      networkName: networkName,
      organization: organization,
      country: country,
      registeredOn: registeredOn,
      lastChanged: lastChanged,
      abuseEmail: abuseEmail,
      latencyMs: latencyMs,
    );
  }

  // ── Global ping ────────────────────────────────────────────────────────

  /// ICMP ping to [target]; falls back to HTTPS latency when ICMP fails
  /// (e.g. the `ping` binary is missing on some Android devices).
  static Future<GlobalPingResult> measureGlobalPing(
    GlobalPingTarget target,
  ) async {
    try {
      final result = await ProtocolAccessibilityService.testIcmpDomain(
        target.target,
        const Duration(seconds: 3),
      );
      if (result.success) {
        return GlobalPingResult(
          name: target.name,
          target: target.target,
          region: target.region,
          latencyMs: result.latencyMs,
          success: true,
        );
      }
      // ICMP failed: fall back to HTTPS latency so the user still gets a
      // number, clearly labeled as a fallback.
      return await _measureGlobalPingViaHttp(
        target,
        icmpError: result.errorMessage,
      );
    } catch (e) {
      return await _measureGlobalPingViaHttp(target, icmpError: e.toString());
    }
  }

  static Future<GlobalPingResult> _measureGlobalPingViaHttp(
    GlobalPingTarget target, {
    String? icmpError,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      await http
          .head(Uri.parse('https://${target.target}'))
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      return GlobalPingResult(
        name: target.name,
        target: target.target,
        region: target.region,
        latencyMs: stopwatch.elapsedMilliseconds,
        success: true,
        viaHttpFallback: true,
        errorDetails: icmpError != null
            ? 'ICMP unavailable ($icmpError); measured over HTTPS instead.'
            : null,
      );
    } catch (e) {
      stopwatch.stop();
      return GlobalPingResult(
        name: target.name,
        target: target.target,
        region: target.region,
        latencyMs: stopwatch.elapsedMilliseconds,
        success: false,
        errorDetails: 'ICMP failed ($icmpError); HTTPS also failed: $e',
      );
    }
  }
}

/// Result of the public IP lookup.
class IpLookupInfo {
  final String? ipv4;
  final String? ipv6;
  final IpGeoInfo? geo;

  const IpLookupInfo({this.ipv4, this.ipv6, this.geo});

  String? get primaryIp => ipv4 ?? ipv6;
}

/// One signal feeding the IP purity score.
class PurityFactor {
  /// Human-readable name of the check.
  final String name;

  /// True when the check is clean, false when it failed, null when the
  /// check could not run (no penalty in that case).
  final bool? passed;
  final String detail;

  /// Points subtracted from 100 when [passed] is false.
  final int penalty;

  const PurityFactor({
    required this.name,
    required this.passed,
    required this.detail,
    required this.penalty,
  });
}

/// IP purity score: 0–100 plus the per-factor breakdown.
class IpPurityResult {
  final int score;
  final String verdict;
  final List<PurityFactor> factors;

  const IpPurityResult({
    required this.score,
    required this.verdict,
    required this.factors,
  });
}

/// One website in the split-routing / latency target lists.
class SplitRouteTarget {
  final String name;
  final String domain;

  const SplitRouteTarget({required this.name, required this.domain});
}

/// Result for one domain in the split-routing test.
class SplitRouteResult {
  final String name;
  final String domain;
  final ReachabilityStatus status;

  /// The exit IP the domain saw (from `/cdn-cgi/trace`) or, for
  /// non-Cloudflare domains, the device's current public IP.
  final String? exitIp;
  final String? exitIpLocation;
  final String? resolvedIp;
  final int? latencyMs;

  /// True when [exitIp] came from the domain's own trace endpoint.
  final bool exitIpFromTrace;
  final String? errorDetails;

  const SplitRouteResult({
    required this.name,
    required this.domain,
    required this.status,
    this.exitIp,
    this.exitIpLocation,
    this.resolvedIp,
    this.latencyMs,
    this.exitIpFromTrace = false,
    this.errorDetails,
  });
}

/// Median HTTPS latency to one service (3 attempts).
class LatencyResult {
  final String name;
  final String domain;

  /// Per-attempt latencies in ms; null means that attempt failed.
  final List<int?> attempts;
  final int? medianLatencyMs;
  final bool reachable;
  final String? errorDetails;

  const LatencyResult({
    required this.name,
    required this.domain,
    required this.attempts,
    this.medianLatencyMs,
    required this.reachable,
    this.errorDetails,
  });
}

/// Outcome of the DNS leak check.
class DnsLeakResult {
  final String testDomain;
  final List<String> systemDnsIps;
  final List<String> cloudflareDohIps;
  final List<String> googleDohIps;
  final String? systemError;
  final String verdict;
  final bool tampered;
  final bool leakDetected;

  const DnsLeakResult({
    required this.testDomain,
    required this.systemDnsIps,
    required this.cloudflareDohIps,
    required this.googleDohIps,
    this.systemError,
    required this.verdict,
    required this.tampered,
    required this.leakDetected,
  });
}

/// One local network interface address (native WebRTC-leak equivalent).
class LocalInterfaceInfo {
  final String name;
  final String address;
  final String type;

  const LocalInterfaceInfo({
    required this.name,
    required this.address,
    required this.type,
  });
}

/// Outcome of the IP leak check.
class IpLeakResult {
  /// Public IP as seen by each echo service.
  final Map<String, String?> seenBy;

  /// True when every service that answered saw the same IP.
  final bool consistent;
  final List<LocalInterfaceInfo> localInterfaces;

  const IpLeakResult({
    required this.seenBy,
    required this.consistent,
    required this.localInterfaces,
  });
}

/// Cloudflare edge details for this connection.
class CloudflareStatus {
  final bool reachable;
  final String? ip;
  final String? colo;
  final String? location;
  final String? warp;
  final String? tlsVersion;
  final String? httpVersion;
  final int? latencyMs;
  final String? error;

  const CloudflareStatus({
    required this.reachable,
    this.ip,
    this.colo,
    this.location,
    this.warp,
    this.tlsVersion,
    this.httpVersion,
    this.latencyMs,
    this.error,
  });
}

/// Parsed RDAP (whois) record for an IP.
class WhoisInfo {
  final String ip;
  final String? networkName;
  final String? organization;
  final String? country;
  final String? registeredOn;
  final String? lastChanged;
  final String? abuseEmail;
  final int? latencyMs;
  final String? error;

  const WhoisInfo({
    required this.ip,
    this.networkName,
    this.organization,
    this.country,
    this.registeredOn,
    this.lastChanged,
    this.abuseEmail,
    this.latencyMs,
    this.error,
  });
}

/// One endpoint in the global ping test.
class GlobalPingTarget {
  final String name;
  final String target;
  final String region;

  const GlobalPingTarget({
    required this.name,
    required this.target,
    required this.region,
  });
}

/// ICMP (or HTTPS-fallback) latency to one global endpoint.
class GlobalPingResult {
  final String name;
  final String target;
  final String region;
  final int? latencyMs;
  final bool success;

  /// True when ICMP was unavailable and HTTPS latency was measured instead.
  final bool viaHttpFallback;
  final String? errorDetails;

  const GlobalPingResult({
    required this.name,
    required this.target,
    required this.region,
    this.latencyMs,
    required this.success,
    this.viaHttpFallback = false,
    this.errorDetails,
  });
}

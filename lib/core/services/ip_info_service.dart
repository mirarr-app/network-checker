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

  /// Standard verdicts for IP purity evaluation.
  static const String verdictClean = 'Clean';
  static const String verdictSuspicious = 'Suspicious';
  static const String verdictFlagged = 'Flagged';
  static const String verdictUnverified = 'Unverified';
  static const String verdictPrivateOrBogon = 'Private / Bogon';

  /// Returns whether [ip] is a bogon, loopback, link-local, or private address.
  /// Checks IPv4 private ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16,
  /// 127.0.0.0/8, 100.64.0.0/10 CGNAT, 0.0.0.0/8, 169.254.0.0/16) and IPv6
  /// loopback/link-local/unique-local (fc00::/7, fe80::/10, ::1, ::).
  static bool isBogonOrPrivate(String ip) {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return false;

    final parsed = InternetAddress.tryParse(trimmed);
    if (parsed == null) return false;

    if (parsed.type == InternetAddressType.IPv4) {
      final bytes = parsed.rawAddress;
      final b0 = bytes[0];
      final b1 = bytes[1];

      // 0.0.0.0/8 (Current network / "this host")
      if (b0 == 0) return true;

      // 10.0.0.0/8 (Private)
      if (b0 == 10) return true;

      // 100.64.0.0/10 (Shared Address Space / CGNAT: 100.64.0.0 – 100.127.255.255)
      if (b0 == 100 && b1 >= 64 && b1 <= 127) return true;

      // 127.0.0.0/8 (Loopback)
      if (b0 == 127) return true;

      // 169.254.0.0/16 (Link-local)
      if (b0 == 169 && b1 == 254) return true;

      // 172.16.0.0/12 (Private: 172.16.0.0 – 172.31.255.255)
      if (b0 == 172 && b1 >= 16 && b1 <= 31) return true;

      // 192.168.0.0/16 (Private)
      if (b0 == 192 && b1 == 168) return true;

      return false;
    }

    if (parsed.type == InternetAddressType.IPv6) {
      final bytes = parsed.rawAddress;

      // :: (Unspecified)
      if (bytes.every((b) => b == 0)) return true;

      // ::1 (Loopback)
      if (parsed.isLoopback ||
          (bytes.sublist(0, 15).every((b) => b == 0) && bytes[15] == 1)) {
        return true;
      }

      // fe80::/10 (Link-local)
      if (parsed.isLinkLocal ||
          (bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80)) {
        return true;
      }

      // fc00::/7 (Unique-local: fc00:: – fdff::)
      if ((bytes[0] & 0xFE) == 0xFC) return true;

      // IPv4-mapped IPv6 address (::ffff:x.x.x.x)
      if (bytes.sublist(0, 10).every((b) => b == 0) &&
          bytes[10] == 0xFF &&
          bytes[11] == 0xFF) {
        return isBogonOrPrivate(
          '${bytes[12]}.${bytes[13]}.${bytes[14]}.${bytes[15]}',
        );
      }

      return false;
    }

    return false;
  }

  /// Fetches rich IP intelligence from keyless public APIs.
  /// Tries ip.net.coffee first, then falls back to ipwho.is and freeipapi.com.
  static Future<Map<String, dynamic>?> _fetchIpIntelligence(
    String ip, {
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      // 1. ip.net.coffee (specialized in IP purity, VPN, proxy, datacenter, threats)
      try {
        final response = await httpClient
            .get(
              Uri.parse('https://ip.net.coffee/api/ip/lookup/$ip'),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
              },
            )
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic> && data['ip'] != null) {
            return data;
          }
        }
      } catch (_) {}

      // 2. ipwho.is fallback (reliable, keyless HTTPS: returns ASN, org, isp, country, city)
      try {
        final response = await httpClient
            .get(Uri.parse('https://ipwho.is/$ip'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic> && data['success'] == true) {
            final connection = data['connection'] is Map<String, dynamic>
                ? data['connection'] as Map<String, dynamic>
                : const <String, dynamic>{};
            final asnNum = connection['asn']?.toString() ?? '';
            final asnStr = asnNum.isNotEmpty
                ? (asnNum.startsWith('AS') ? asnNum : 'AS$asnNum')
                : '';
            final org = connection['org']?.toString() ?? '';
            final isp = connection['isp']?.toString() ?? org;
            return {
              'ip': data['ip']?.toString() ?? ip,
              'is_datacenter': false,
              'is_vpn': false,
              'is_proxy': false,
              'is_mobile': false,
              'company_name': org.isNotEmpty ? org : isp,
              'company_type': 'isp',
              'asOrganization': org,
              'asn': asnStr,
              'isp': isp,
              'country': data['country'],
              'city': data['city'],
              'region': data['region'],
            };
          }
        }
      } catch (_) {}

      // 3. freeipapi.com fallback
      try {
        final response = await httpClient
            .get(Uri.parse('https://freeipapi.com/api/json/$ip'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic> &&
              (data['ipAddress'] != null || data['ip'] != null)) {
            final asnOrg = data['asnOrganization']?.toString() ?? '';
            return {
              'ip': data['ipAddress']?.toString() ??
                  data['ip']?.toString() ??
                  ip,
              'is_datacenter': false,
              'is_vpn': false,
              'is_proxy': data['isProxy'] == true,
              'is_mobile': false,
              'company_name': asnOrg,
              'company_type': 'isp',
              'asOrganization': asnOrg,
              'asn': data['asn']?.toString() ?? '',
              'isp': asnOrg,
              'country': data['countryName'] ?? data['country'],
              'city': data['cityName'] ?? data['city'],
              'region': data['regionName'] ?? data['region'],
            };
          }
        }
      } catch (_) {}

      return null;
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Scores an IP from 0 (flagged) to 100 (clean) using verified signals.
  /// Requires at least 2 verified factors ([PurityFactor.passed] != null) to compute a score.
  /// If fewer than 2 factors are verified, returns 0 (unverified score).
  /// Each factor that fails subtracts its penalty; factors that could not
  /// be checked ([PurityFactor.passed] == null) subtract nothing.
  static int computePurityScore(List<PurityFactor> factors) {
    if (factors.isEmpty) return 0;
    final verified = factors.where((factor) => factor.passed != null);
    if (verified.length < 2) return 0;

    var score = 100;
    for (final factor in factors) {
      if (factor.passed == false) score -= factor.penalty;
    }
    return score.clamp(0, 100);
  }

  /// Maps a purity score to a human-readable verdict.
  /// If verified factors < 2 (or [hasVerifiedFactors] is false), returns 'Unverified'.
  static String purityVerdict(
    int score, {
    bool hasVerifiedFactors = true,
    dynamic verifiedFactors,
    int? verifiedCount,
  }) {
    int? count = verifiedCount;
    if (verifiedFactors is int) {
      count = verifiedFactors;
    } else if (verifiedFactors is Iterable<PurityFactor>) {
      count = verifiedFactors.where((f) => f.passed != null).length;
    } else if (verifiedFactors is bool) {
      hasVerifiedFactors = verifiedFactors;
    }

    if (!hasVerifiedFactors || (count != null && count < 2)) {
      return verdictUnverified;
    }
    if (score >= 80) return verdictClean;
    if (score >= 50) return verdictSuspicious;
    return verdictFlagged;
  }

  /// Runs the purity checks for [ip]. Combines keyless intelligence APIs,
  /// the Tor bulk exit list, GeoIP ASN data, and reverse DNS heuristics.
  static Future<IpPurityResult> checkIpPurity({
    required String ip,
    IpGeoInfo? geo,
    http.Client? client,
  }) async {
    // 0. Bogon / private IP check: skip public external HTTP lookups completely.
    if (isBogonOrPrivate(ip)) {
      return const IpPurityResult(
        score: 100,
        verdict: verdictPrivateOrBogon,
        factors: [
          PurityFactor(
            name: 'Private / Bogon IP',
            passed: true,
            detail:
                'This IP is a local, private, or unroutable address. External reputation and threat lookups are skipped.',
            penalty: 0,
          ),
        ],
      );
    }

    final factors = <PurityFactor>[];

    // Fetch multi-source IP intelligence (VPN, proxy, datacenter, threats)
    final intel = await _fetchIpIntelligence(ip, client: client);

    // 1. Tor exit node membership.
    final torExitIps = await _fetchTorExitList(client: client);
    final bool isTorIntel = intel?['is_tor'] == true;
    if (torExitIps != null) {
      final isExit = torExitIps.contains(ip) || isTorIntel;
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
    } else if (intel != null) {
      factors.add(
        PurityFactor(
          name: 'Tor exit node',
          passed: !isTorIntel,
          detail: isTorIntel
              ? 'Intelligence flags this IP as a Tor exit node'
              : 'Not a known Tor exit node',
          penalty: 60,
        ),
      );
    } else {
      factors.add(
        const PurityFactor(
          name: 'Tor exit node',
          passed: null,
          detail: 'Tor exit list unreachable — not checked',
          penalty: 60,
        ),
      );
    }

    // 2. Known proxy / VPN detection.
    final bool? isProxyFlag;
    final String proxyDetail;
    if (intel != null) {
      final vpn = intel['is_vpn'] == true;
      final proxy = intel['is_proxy'] == true || intel['proxy'] == true;
      if (vpn && proxy) {
        isProxyFlag = true;
        proxyDetail = 'Intelligence flags this IP as both a VPN and a Proxy';
      } else if (vpn) {
        isProxyFlag = true;
        proxyDetail = 'Intelligence flags this IP as a VPN exit';
      } else if (proxy) {
        isProxyFlag = true;
        proxyDetail = 'Intelligence flags this IP as a proxy server';
      } else {
        isProxyFlag = false;
        proxyDetail = 'Not flagged as a VPN or proxy';
      }
    } else if (geo != null) {
      isProxyFlag = geo.isProxy;
      proxyDetail = geo.isProxy
          ? 'GeoIP database flags this IP as a proxy'
          : 'Not flagged as a proxy';
    } else {
      isProxyFlag = null;
      proxyDetail = 'Proxy / VPN status unverified';
    }

    factors.add(
      PurityFactor(
        name: 'Known proxy / VPN',
        passed: isProxyFlag == null ? null : !isProxyFlag,
        detail: proxyDetail,
        penalty: 35,
      ),
    );

    // 3. Datacenter / hosting ASN detection.
    final asnOrg = geo?.asnOrganization.isNotEmpty == true
        ? geo!.asnOrganization
        : (intel?['datacenter_name'] as String? ??
            intel?['asOrganization'] as String? ??
            intel?['org'] as String? ??
            '');

    final bool hasIntelDc = intel?['is_datacenter'] == true ||
        intel?['company_type'] == 'hosting' ||
        intel?['hosting'] == true;

    final bool isDcFlag;
    final String dcDetail;
    if (hasIntelDc || isHostingAsn(asnOrg)) {
      isDcFlag = true;
      final dcName = asnOrg.isNotEmpty
          ? asnOrg
          : (intel?['datacenter_name'] ?? 'Cloud hosting');
      dcDetail = 'IP belongs to a hosting/datacenter provider ($dcName)';
    } else if (intel != null || geo != null || asnOrg.isNotEmpty) {
      isDcFlag = false;
      final ispName = asnOrg.isNotEmpty
          ? asnOrg
          : (intel?['isp'] ?? geo?.ispName ?? 'ISP network');
      dcDetail = 'ASN looks like a residential/ISP network ($ispName)';
    } else {
      isDcFlag = false;
      dcDetail = 'Datacenter / hosting status unverified';
    }

    final hasAsnInfo = asnOrg.isNotEmpty || intel != null || geo != null;
    factors.add(
      PurityFactor(
        name: 'Datacenter / hosting ASN',
        passed: !hasAsnInfo ? null : !isDcFlag,
        detail: !hasAsnInfo
            ? 'Datacenter / hosting status unverified'
            : dcDetail,
        penalty: 25,
      ),
    );

    // 4. Threat / abuse history.
    if (intel != null) {
      final isAbuser = intel['is_abuser'] == true;
      final threats = (intel['intelligence'] is Map &&
              intel['intelligence']['threats'] is List)
          ? (intel['intelligence']['threats'] as List)
          : (intel['threats'] is List ? (intel['threats'] as List) : null);
      final abuserScore = intel['abuser_score']?.toString();

      final hasExplicitThreatIntel = intel.containsKey('is_abuser') ||
          intel.containsKey('threats') ||
          (intel['intelligence'] is Map &&
              (intel['intelligence'] as Map).containsKey('threats')) ||
          intel.containsKey('abuser_score');

      if (isAbuser || (threats != null && threats.isNotEmpty)) {
        final threatLabels = threats != null
            ? threats
                .map((t) => t is Map ? t['label']?.toString() : null)
                .whereType<String>()
                .join(', ')
            : '';
        factors.add(
          PurityFactor(
            name: 'Threat / abuse history',
            passed: false,
            detail: threatLabels.isNotEmpty
                ? 'Threats reported: $threatLabels'
                : 'Flagged for abuse or malicious activity (${abuserScore ?? 'High risk'})',
            penalty: 20,
          ),
        );
      } else if (hasExplicitThreatIntel) {
        factors.add(
          const PurityFactor(
            name: 'Threat / abuse history',
            passed: true,
            detail: 'Clean threat history — no abuse reports found',
            penalty: 20,
          ),
        );
      } else {
        factors.add(
          const PurityFactor(
            name: 'Threat / abuse history',
            passed: null,
            detail:
                'Threat intelligence not provided by lookup source — not checked',
            penalty: 20,
          ),
        );
      }
    } else {
      factors.add(
        const PurityFactor(
          name: 'Threat / abuse history',
          passed: null,
          detail: 'Threat intelligence unreachable — not checked',
          penalty: 20,
        ),
      );
    }

    // 5. Reverse DNS: server/datacenter-style PTR hostnames.
    final ptr = (intel?['rdns'] as String?)?.isNotEmpty == true
        ? intel!['rdns'] as String
        : await _reverseDns(ip);

    if (ptr == null || ptr.isEmpty) {
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

    final verifiedCount =
        factors.where((factor) => factor.passed != null).length;
    final score = computePurityScore(factors);
    return IpPurityResult(
      score: score,
      verdict: purityVerdict(score, verifiedFactors: verifiedCount),
      factors: factors,
    );
  }

  static Future<Set<String>?> _fetchTorExitList({http.Client? client}) async {
    if (_torExitIps != null &&
        _torExitListFetchedAt != null &&
        DateTime.now().difference(_torExitListFetchedAt!).inMinutes < 60) {
      return _torExitIps;
    }
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;
    try {
      final response = await httpClient
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
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
    return null;
  }

  @visibleForTesting
  static void resetTorExitListCache() {
    _torExitIps = null;
    _torExitListFetchedAt = null;
  }

  /// Whether an ASN organization name belongs to a hosting/cloud provider.
  static bool isHostingAsn(String organization) {
    final lower = organization.toLowerCase();
    if (lower.isEmpty) return false;
    return _hostingOrgKeywords.any((keyword) => lower.contains(keyword));
  }

  static const List<String> _hostingOrgKeywords = [
    'amazon',
    'aws',
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
    'aliyun',
    'tencent cloud',
    'oracle cloud',
    'oracle corporation',
    'akamai',
    'cloudflare',
    'fastly',
    'choopa',
    'constant company',
    'kamatera',
    'contabo',
    'scaleway',
    'online s.a.s',
    'ionos',
    'datacamp',
    'cdn77',
    'm247',
    'leaseweb',
    'hostinger',
    'netcup',
    'clouvider',
    'serverius',
    'hostroyale',
    'stark industries',
    'fly.io',
    'zenlayer',
    'rackspace',
    'cogent',
    'hurricane electric',
    'gtt communications',
    'lumen',
    'centurylink',
    'hosting',
    'datacenter',
    'data center',
    'vps',
    'server',
    'colocation',
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
    'your-server.de',
    'hetzner',
    'ovh.net',
    'contabo',
    'leaseweb',
    'scaleway',
    'server',
    'cdn77',
    'datacamp',
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

    // 1. Cloudflare trace: only attempted if the domain supports trace.
    if (target.supportsTrace) {
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
        exitIp: null,
        exitIpLocation: null,
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

    final dohResults = await Future.wait([
      _dohLookup(
        'https://cloudflare-dns.com/dns-query?name=$testDomain&type=A',
      ),
      _dohLookup(
        'https://dns.google/resolve?name=$testDomain&type=1',
      ),
    ]);
    final cloudflareIps = dohResults[0];
    final googleIps = dohResults[1];

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
    } else if (cloudflareIps.isEmpty && googleIps.isEmpty) {
      verdict =
          'Encrypted DNS (DoH) unreachable — cannot compare with system resolver (DoH may be blocked)';
    } else if (cloudflareIps.isNotEmpty || googleIps.isNotEmpty) {
      final systemSet = systemIps.toSet();
      final agreesWithCf = cloudflareIps.isNotEmpty &&
          systemSet.intersection(cloudflareIps.toSet()).isNotEmpty;
      final agreesWithGoogle = googleIps.isNotEmpty &&
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

  /// Parses DNS-over-HTTPS JSON response answers, filtering for A (type 1)
  /// and AAAA (type 28) records, ignoring CNAME (type 5) and metadata.
  static List<String> parseDohAnswers(Map<String, dynamic> json) {
    final answers = json['Answer'];
    if (answers is! List) return [];
    return answers
        .whereType<Map<String, dynamic>>()
        .where((answer) {
          final type = answer['type'];
          return type == 1 || type == 28;
        })
        .map((answer) => answer['data']?.toString().trim() ?? '')
        .where((data) => data.isNotEmpty && InternetAddress.tryParse(data) != null)
        .toList();
  }

  static Future<List<String>> _dohLookup(
    String url, {
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;
    try {
      final response = await httpClient
          .get(
            Uri.parse(url),
            headers: {'Accept': 'application/dns-json'},
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return [];
      return parseDohAnswers(data);
    } catch (_) {
      return [];
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Native equivalent of a WebRTC leak test: compares the public IP as seen
  /// by several independent services and lists local network interfaces.
  /// Dual-stack aware: tracks IPv4 and IPv6 separately to avoid false alarms.
  static Future<IpLeakResult> checkIpLeak({
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    final seenBy = <String, String?>{};
    final seenIpv4 = <String>{};
    final seenIpv6 = <String>{};

    Future<void> fetchEcho(String name, Uri uri, {bool isTrace = false}) async {
      try {
        final response = await httpClient
            .get(uri)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final rawIp = isTrace
              ? parseCloudflareTrace(response.body)['ip']
              : response.body.trim();
          if (rawIp != null && rawIp.isNotEmpty) {
            final parsed = InternetAddress.tryParse(rawIp);
            if (parsed != null) {
              seenBy[name] = parsed.address;
              if (parsed.type == InternetAddressType.IPv4) {
                seenIpv4.add(parsed.address);
              } else if (parsed.type == InternetAddressType.IPv6) {
                seenIpv6.add(parsed.address);
              }
              return;
            }
          }
        }
        seenBy[name] = null;
      } catch (_) {
        seenBy[name] = null;
      }
    }

    try {
      await Future.wait([
        fetchEcho('ipify', Uri.parse('https://api.ipify.org')),
        fetchEcho('icanhazip', Uri.parse('https://icanhazip.com')),
        fetchEcho('ident.me', Uri.parse('https://ident.me')),
        fetchEcho(
          'Cloudflare trace',
          Uri.parse('https://www.cloudflare.com/cdn-cgi/trace'),
          isTrace: true,
        ),
      ]);
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
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

    // A leak is only flagged if distinctIpv4.length > 1 OR distinctIpv6.length > 1.
    // If all queries fail (distinctIpv4.isEmpty && distinctIpv6.isEmpty), do NOT report a leak! Report consistent: true.
    final bool hasLeak = seenIpv4.length > 1 || seenIpv6.length > 1;
    final bool consistent = !hasLeak;

    return IpLeakResult(
      seenBy: seenBy,
      consistent: consistent,
      localInterfaces: interfaces,
      seenIpv4: seenIpv4,
      seenIpv6: seenIpv6,
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
  final bool supportsTrace;

  const SplitRouteTarget({
    required this.name,
    required this.domain,
    this.supportsTrace = false,
  });
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

/// Top-level convenience alias for [IpInfoService.isBogonOrPrivate].
bool isBogonOrPrivate(String ip) => IpInfoService.isBogonOrPrivate(ip);

/// Outcome of the IP leak check.
class IpLeakResult {
  /// Public IP as seen by each echo service.
  final Map<String, String?> seenBy;

  /// True when every service that answered saw the same IP.
  final bool consistent;
  final List<LocalInterfaceInfo> localInterfaces;

  /// Distinct IPv4 addresses seen across echo endpoints.
  final Set<String>? seenIpv4;

  /// Distinct IPv6 addresses seen across echo endpoints.
  final Set<String>? seenIpv6;

  const IpLeakResult({
    required this.seenBy,
    required this.consistent,
    required this.localInterfaces,
    this.seenIpv4,
    this.seenIpv6,
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

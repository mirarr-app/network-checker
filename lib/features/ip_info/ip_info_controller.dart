import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/services/internet_diagnostics_service.dart';
import '../../core/services/ip_info_service.dart';
import 'data/ip_info_targets.dart';

/// Current state of the IP info engine.
enum IpInfoStatus { idle, running, completed }

/// Purity verdict classification bands.
enum PurityVerdict {
  clean,
  suspicious,
  flagged,
  unverified,
  bogon;

  static PurityVerdict fromString(String verdict) {
    final v = verdict.toLowerCase();
    if (v.contains('bogon') || v.contains('private') || v.contains('reserved')) {
      return PurityVerdict.bogon;
    }
    if (v.contains('unverified')) {
      return PurityVerdict.unverified;
    }
    if (v.contains('clean')) {
      return PurityVerdict.clean;
    }
    if (v.contains('suspicious')) {
      return PurityVerdict.suspicious;
    }
    return PurityVerdict.flagged;
  }
}

/// Coordinates the IP info checks and exposes their state to the UI.
/// Follows the same pattern as [InternetDiagnosticsController]: sections run
/// sequentially, results stream in incrementally, and starting a new run
/// cancels the previous one via [_currentRunId].
class IpInfoController extends ChangeNotifier {
  IpInfoStatus _status = IpInfoStatus.idle;
  int _currentRunId = 0;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  IpLookupInfo? _lookup;
  IpPurityResult? _purity;

  List<SplitRouteResult> _splitResults = [];
  bool _isTestingSplit = false;

  List<LatencyResult> _latencyResults = [];
  bool _isMeasuringLatency = false;

  DnsLeakResult? _dnsLeak;
  IpLeakResult? _ipLeak;
  CloudflareStatus? _cloudflare;
  WhoisInfo? _whois;
  List<GlobalPingResult> _globalPingResults = [];
  bool _isCheckingEnvironment = false;

  int _completedSections = 0;
  static const int totalSections = 5;

  String? _targetIp;
  String? _inspectedIp;
  String? _errorMessage;

  IpInfoStatus get status => _status;
  bool get isIdle => _status == IpInfoStatus.idle;
  bool get isRunning => _status == IpInfoStatus.running;
  bool get isCompleted => _status == IpInfoStatus.completed;

  String? get targetIp => _targetIp;
  String? get inspectedIp => _inspectedIp;
  bool get isManual => _targetIp != null;
  String? get errorMessage => _errorMessage;

  String? get activeIp => _targetIp ?? _inspectedIp ?? _lookup?.primaryIp;

  IpGeoInfo? get activeGeo {
    final current = activeIp;
    if (_lookup == null || current == null) return null;
    if (current == _lookup!.ipv4 && _lookup!.ipv4Geo != null) {
      return _lookup!.ipv4Geo;
    }
    if (current == _lookup!.ipv6 && _lookup!.ipv6Geo != null) {
      return _lookup!.ipv6Geo;
    }
    return _lookup!.geo;
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Strips optional scheme, brackets, CIDR, zone index, and trailing port from an IP input string.
  static String cleanIpInput(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;

    // 1. Strip URL scheme if present (e.g. http:// or https://)
    if (s.contains('://')) {
      s = s.substring(s.indexOf('://') + 3);
    }

    // 2. Strip trailing paths or CIDR (e.g. 1.2.3.4/24 or 1.2.3.4/test -> 1.2.3.4)
    if (s.contains('/')) {
      s = s.split('/').first.trim();
    }

    // 3. Strip bracketed IPv6 (e.g. [2001:db8::1]:8080 -> 2001:db8::1)
    if (s.startsWith('[') && s.contains(']')) {
      final closeIdx = s.indexOf(']');
      s = s.substring(1, closeIdx);
      return s.trim();
    }

    // 4. Strip IPv6 scope / zone index (e.g. fe80::1%eth0 -> fe80::1)
    if (s.contains('%')) {
      s = s.split('%').first.trim();
    }

    // 5. Strip port from IPv4 (e.g. 1.2.3.4:8080 -> 1.2.3.4)
    if (s.contains(':') && s.indexOf(':') == s.lastIndexOf(':')) {
      final parts = s.split(':');
      final possibleIp = parts[0].trim();
      final parsed = InternetAddress.tryParse(possibleIp);
      if (parsed != null && parsed.type == InternetAddressType.IPv4) {
        s = possibleIp;
      }
    }

    return s.trim();
  }

  IpLookupInfo? get lookup => _lookup;
  IpPurityResult? get purity => _purity;
  HumanVsMachineResult? get humanVsMachine => _purity?.humanVsMachine;
  PurityVerdict? get purityVerdict =>
      _purity == null ? null : PurityVerdict.fromString(_purity!.verdict);

  List<SplitRouteResult> get splitResults => _splitResults;
  bool get isTestingSplit => _isTestingSplit;

  List<LatencyResult> get latencyResults => _latencyResults;
  bool get isMeasuringLatency => _isMeasuringLatency;

  DnsLeakResult? get dnsLeak => _dnsLeak;
  IpLeakResult? get ipLeak => _ipLeak;
  CloudflareStatus? get cloudflare => _cloudflare;
  WhoisInfo? get whois => _whois;
  List<GlobalPingResult> get globalPingResults => _globalPingResults;
  bool get isCheckingEnvironment => _isCheckingEnvironment;

  int get completedSections => _completedSections;
  double get progressFraction => _completedSections / totalSections;

  int get splitTestedCount => _splitResults.length;
  int get splitReachableCount => _splitResults
      .where((r) => r.status == ReachabilityStatus.reachable)
      .length;

  int get latencyTestedCount => _latencyResults.length;
  int? get averageLatencyMs {
    final latencies = _latencyResults
        .where((r) => r.medianLatencyMs != null)
        .map((r) => r.medianLatencyMs!)
        .toList();
    if (latencies.isEmpty) return null;
    return (latencies.reduce((a, b) => a + b) / latencies.length).round();
  }

  int get globalPingTestedCount => _globalPingResults.length;
  int? get averageGlobalPingMs {
    final latencies = _globalPingResults
        .where((r) => r.latencyMs != null && r.success)
        .map((r) => r.latencyMs!)
        .toList();
    if (latencies.isEmpty) return null;
    return (latencies.reduce((a, b) => a + b) / latencies.length).round();
  }

  void _addSplitResult(SplitRouteResult result) {
    final list = [..._splitResults, result]
      ..sort((a, b) => a.name.compareTo(b.name));
    _splitResults = list;
  }

  void _addLatencyResult(LatencyResult result) {
    final list = [..._latencyResults, result]
      ..sort((a, b) => a.name.compareTo(b.name));
    _latencyResults = list;
  }

  @visibleForTesting
  void setResultsForTesting({
    IpLookupInfo? lookup,
    IpPurityResult? purity,
    String? targetIp,
    String? inspectedIp,
    IpInfoStatus status = IpInfoStatus.completed,
    String? errorMessage,
  }) {
    _lookup = lookup;
    _purity = purity;
    _targetIp = targetIp;
    _inspectedIp = inspectedIp;
    _status = status;
    _errorMessage = errorMessage;
    notifyListeners();
  }

  /// Inspects a specific address ([ip]) discovered during an automatic scan
  /// without re-running network-wide tests (split routing, ping, latency) or
  /// losing the dual-stack context.
  Future<void> inspectAddress(String ip, {http.Client? client}) async {
    if (_status == IpInfoStatus.running) return;
    if (activeIp == ip) return;

    _inspectedIp = ip;
    notifyListeners();

    var geo = activeGeo;
    if (geo == null && !IpInfoService.isBogonOrPrivate(ip)) {
      try {
        geo = await InternetDiagnosticsService.fetchIpGeoDetails(ip);
        if (geo != null && _lookup != null) {
          if (ip == _lookup!.ipv4) {
            _lookup = _lookup!.copyWith(ipv4Geo: geo);
          } else if (ip == _lookup!.ipv6) {
            _lookup = _lookup!.copyWith(ipv6Geo: geo);
          }
        }
      } catch (_) {}
    }

    try {
      _purity = await IpInfoService.checkIpPurity(
        ip: ip,
        geo: geo,
        client: client,
      );
    } catch (_) {}

    try {
      if (!IpInfoService.isBogonOrPrivate(ip)) {
        _whois = await IpInfoService.lookupWhois(ip);
      } else {
        _whois = null;
      }
    } catch (_) {}

    notifyListeners();
  }

  /// Runs the whole IP info suite: lookup, purity, split routing, latency,
  /// then the environment checks.
  /// If [manualIp] is provided and non-empty, inspects that specific IPv4/IPv6
  /// address instead of auto-detecting the device's public IP.
  Future<void> runIpInfoSuite([String? manualIp]) =>
      runIpInfoSuiteInternal(manualIp: manualIp);

  /// Internal implementation of [runIpInfoSuite] allowing injection of
  /// targets and HTTP client for testing.
  Future<void> runIpInfoSuiteInternal({
    String? manualIp,
    http.Client? client,
    List<SplitRouteTarget>? splitTargets,
    List<SplitRouteTarget>? latencyTargets,
    bool skipEnvironment = false,
  }) async {
    if (_status == IpInfoStatus.running) return;

    final trimmed = manualIp != null ? cleanIpInput(manualIp) : null;
    if (trimmed != null && trimmed.isNotEmpty) {
      final parsed = InternetAddress.tryParse(trimmed);
      if (parsed == null) {
        _errorMessage =
            'Invalid IP address format. Please enter a valid IPv4 or IPv6 address.';
        notifyListeners();
        return;
      }
      _targetIp = trimmed;
    } else {
      _targetIp = null;
    }
    _inspectedIp = null;
    _errorMessage = null;

    _currentRunId++;
    final runId = _currentRunId;

    _status = IpInfoStatus.running;
    _completedSections = 0;
    _lookup = null;
    _purity = null;
    _splitResults = [];
    _isTestingSplit = false;
    _latencyResults = [];
    _isMeasuringLatency = false;
    _dnsLeak = null;
    _ipLeak = null;
    _cloudflare = null;
    _whois = null;
    _globalPingResults = [];
    _isCheckingEnvironment = false;
    notifyListeners();

    try {
      // 1. IP lookup (public IPv4/IPv6 + geolocation).
      if (_targetIp != null) {
        final parsed = InternetAddress.tryParse(_targetIp!)!;
        final isV6 = parsed.type == InternetAddressType.IPv6;
        final ipv4 = isV6 ? null : _targetIp;
        final ipv6 = isV6 ? _targetIp : null;
        IpGeoInfo? geo;
        if (!IpInfoService.isBogonOrPrivate(_targetIp!)) {
          try {
            geo = await InternetDiagnosticsService.fetchIpGeoDetails(_targetIp!);
          } catch (_) {}
        }
        _lookup = IpLookupInfo(
          ipv4: ipv4,
          ipv6: ipv6,
          geo: geo,
          ipv4Geo: isV6 ? null : geo,
          ipv6Geo: isV6 ? geo : null,
        );
      } else {
        _lookup = await IpInfoService.fetchIpLookup(client: client);
      }
      if (_disposed || runId != _currentRunId) return;
      _completedSections++;
      notifyListeners();

      // 2. IP purity check for the primary/active IP.
      final primaryIp = activeIp;
      if (primaryIp != null) {
        _purity = await IpInfoService.checkIpPurity(
          ip: primaryIp,
          geo: activeGeo,
          client: client,
        );
      }
      if (_disposed || runId != _currentRunId) return;
      _completedSections++;
      notifyListeners();

      // 3. Split-routing test (results stream in as each domain finishes).
      final activeSplitTargets = splitTargets ?? IpInfoTargets.splitRouteTargets;
      if (activeSplitTargets.isNotEmpty) {
        _isTestingSplit = true;
        notifyListeners();
        await IpInfoService.testSplitRouting(
          targets: activeSplitTargets,
          publicIp: _targetIp == null ? primaryIp : null,
          onResult: (result) {
            if (_disposed || runId != _currentRunId) return;
            _addSplitResult(result);
            notifyListeners();
          },
        );
        if (_disposed || runId != _currentRunId) return;
        _isTestingSplit = false;
      }
      _completedSections++;
      notifyListeners();

      // 4. Connectivity latency (median of 3 attempts per service).
      final activeLatencyTargets = latencyTargets ?? IpInfoTargets.latencyTargets;
      if (activeLatencyTargets.isNotEmpty) {
        _isMeasuringLatency = true;
        notifyListeners();
        final latencyFutures = activeLatencyTargets.map((target) async {
          final result = await IpInfoService.measureLatencyForTarget(target);
          if (_disposed || runId != _currentRunId) return;
          _addLatencyResult(result);
          notifyListeners();
        });
        await Future.wait(latencyFutures);
        if (_disposed || runId != _currentRunId) return;
        _isMeasuringLatency = false;
      }
      _completedSections++;
      notifyListeners();

      // 5. Environment checks (run concurrently, applied as they finish).
      if (!skipEnvironment) {
        _isCheckingEnvironment = true;
        notifyListeners();

        final environmentFutures = <Future<void>>[
          IpInfoService.checkDnsLeak().then((result) {
            if (_disposed || runId != _currentRunId) return;
            _dnsLeak = result;
            notifyListeners();
          }),
          IpInfoService.checkIpLeak(client: client).then((result) {
            if (_disposed || runId != _currentRunId) return;
            _ipLeak = result;
            notifyListeners();
          }),
          IpInfoService.checkCloudflare().then((result) {
            if (_disposed || runId != _currentRunId) return;
            _cloudflare = result;
            notifyListeners();
          }),
          Future.wait(
            IpInfoTargets.globalPingTargets.map(
              IpInfoService.measureGlobalPing,
            ),
          ).then((results) {
            if (_disposed || runId != _currentRunId) return;
            _globalPingResults = results;
            notifyListeners();
          }),
        ];
        if (primaryIp != null && !IpInfoService.isBogonOrPrivate(primaryIp)) {
          environmentFutures.add(
            IpInfoService.lookupWhois(primaryIp).then((result) {
              if (_disposed || runId != _currentRunId) return;
              _whois = result;
              notifyListeners();
            }),
          );
        }
        await Future.wait(environmentFutures);
        if (_disposed || runId != _currentRunId) return;
      }
      _completedSections++;
    } catch (e, st) {
      debugPrint('Error running IP info suite: $e\n$st');
    } finally {
      if (!_disposed && runId == _currentRunId) {
        _status = IpInfoStatus.completed;
        _isTestingSplit = false;
        _isMeasuringLatency = false;
        _isCheckingEnvironment = false;
        notifyListeners();
      }
    }
  }

  /// Resets the engine to its idle state, cancelling any active run.
  void resetSuite() {
    _currentRunId++;
    _status = IpInfoStatus.idle;
    _completedSections = 0;
    _targetIp = null;
    _inspectedIp = null;
    _errorMessage = null;
    _lookup = null;
    _purity = null;
    _splitResults = [];
    _isTestingSplit = false;
    _latencyResults = [];
    _isMeasuringLatency = false;
    _dnsLeak = null;
    _ipLeak = null;
    _cloudflare = null;
    _whois = null;
    _globalPingResults = [];
    _isCheckingEnvironment = false;
    notifyListeners();
  }

  /// Plain-text report of the whole suite, ready to paste into an AI tool.
  String generateIpInfoReport() {
    final buffer = StringBuffer();
    buffer.writeln('==================================================');
    buffer.writeln('NETWORK CHECKER IP INFO REPORT');
    buffer.writeln('Generated at: ${DateTime.now().toLocal()}');
    buffer.writeln('==================================================\n');

    if (_lookup != null) {
      buffer.writeln('### IP LOOKUP');
      if (isManual) {
        buffer.writeln('Mode: Manual query ($_targetIp)');
      } else {
        final isDualStack = _lookup!.ipv4 != null && _lookup!.ipv6 != null;
        buffer.writeln(
          'Mode: Automatic scan${isDualStack ? ' (Dual-stack IPv4 & IPv6 detected)' : ''}',
        );
      }
      buffer.writeln('IPv4: ${_lookup!.ipv4 ?? 'Unavailable'}');
      buffer.writeln('IPv6: ${_lookup!.ipv6 ?? 'Unavailable'}');
      final current = activeIp;
      if (current != null) {
        buffer.writeln('Active target: $current');
      }
      final geo = activeGeo ?? _lookup!.geo;
      if (geo != null) {
        buffer.writeln('Location: ${geo.countryName}, ${geo.regionName}, '
            '${geo.cityName}');
        buffer.writeln('ISP: ${geo.ispName}');
        buffer.writeln('ASN: ${geo.asn} (${geo.asnOrganization})');
        if (geo.timeZone.isNotEmpty) {
          buffer.writeln('Timezone: ${geo.timeZone}');
        }
      }
      if (_lookup!.ipv4 != null &&
          _lookup!.ipv6 != null &&
          _lookup!.ipv4Geo != null &&
          _lookup!.ipv6Geo != null &&
          _lookup!.ipv4Geo != _lookup!.ipv6Geo) {
        final otherGeo = current == _lookup!.ipv4 ? _lookup!.ipv6Geo! : _lookup!.ipv4Geo!;
        final otherLabel = current == _lookup!.ipv4 ? 'IPv6' : 'IPv4';
        buffer.writeln();
        buffer.writeln('[$otherLabel Network Details]');
        buffer.writeln('Location: ${otherGeo.countryName}, ${otherGeo.regionName}, ${otherGeo.cityName}');
        buffer.writeln('ISP: ${otherGeo.ispName}');
        buffer.writeln('ASN: ${otherGeo.asn} (${otherGeo.asnOrganization})');
      }
      buffer.writeln();
    }

    if (_purity != null) {
      buffer.writeln('### IP PURITY');
      buffer.writeln(
        'Score: ${_purity!.score}/100 (${_purity!.verdict})',
      );
      for (final factor in _purity!.factors) {
        final state = factor.passed == null
            ? 'NOT CHECKED'
            : (factor.passed! ? 'PASS' : 'FAIL');
        buffer.writeln('- ${factor.name}: $state — ${factor.detail}');
      }
      final hvm = _purity!.humanVsMachine;
      if (hvm != null && !hvm.isBogon) {
        buffer.writeln();
        buffer.writeln('### HUMANS VS MACHINES');
        buffer.writeln('Classification: ${hvm.classification.label}');
        buffer.writeln('Human: ${hvm.humanPercentString}');
        buffer.writeln('Machine: ${hvm.machinePercentString}');
        buffer.writeln('Source: ${hvm.note}');
      }
      buffer.writeln();
    }

    if (_splitResults.isNotEmpty) {
      buffer.writeln('### SPLIT ROUTING');
      buffer.writeln(
        'Reachable: $splitReachableCount / ${_splitResults.length}',
      );
      for (final result in _splitResults) {
        final exitInfo = result.exitIpFromTrace && result.exitIp != null
            ? 'trace exit: ${result.exitIp}${result.exitIpLocation != null ? ' (${result.exitIpLocation})' : ''}'
            : (result.resolvedIp != null
                ? 'resolved: ${result.resolvedIp}'
                : 'direct/no trace');
        buffer.writeln(
          '- ${result.name} (${result.domain}): ${result.status.name}, '
          '$exitInfo, '
          'latency: ${result.latencyMs ?? '--'} ms',
        );
      }
      buffer.writeln();
    }

    if (_latencyResults.isNotEmpty) {
      buffer.writeln('### CONNECTIVITY LATENCY (median of 3)');
      buffer.writeln(
        'Average median latency: ${averageLatencyMs ?? '--'} ms',
      );
      for (final result in _latencyResults) {
        buffer.writeln(
          '- ${result.name} (${result.domain}): '
          '${result.medianLatencyMs != null ? '${result.medianLatencyMs} ms' : 'unreachable'}',
        );
      }
      buffer.writeln();
    }

    if (_dnsLeak != null ||
        _ipLeak != null ||
        _cloudflare != null ||
        _whois != null ||
        _globalPingResults.isNotEmpty) {
      buffer.writeln('### ENVIRONMENT');
      if (_dnsLeak != null) {
        buffer.writeln('DNS leak: ${_dnsLeak!.verdict}');
        buffer.writeln(
          '  System DNS: ${_dnsLeak!.systemDnsIps.join(', ')}',
        );
        buffer.writeln(
          '  Cloudflare DoH: ${_dnsLeak!.cloudflareDohIps.join(', ')}',
        );
        buffer.writeln(
          '  Google DoH: ${_dnsLeak!.googleDohIps.join(', ')}',
        );
      }
      if (_ipLeak != null) {
        buffer.writeln(
          'IP leak: ${_ipLeak!.consistent ? 'consistent — no leak detected' : 'INCONSISTENT — traffic exits through different IPs'}',
        );
        for (final entry in _ipLeak!.seenBy.entries) {
          buffer.writeln('  ${entry.key}: ${entry.value ?? '--'}');
        }
        if (_ipLeak!.localInterfaces.isNotEmpty) {
          buffer.writeln('  Local interfaces:');
          for (final interface in _ipLeak!.localInterfaces) {
            buffer.writeln(
              '    ${interface.name}: ${interface.address} (${interface.type})',
            );
          }
        }
      }
      if (_cloudflare != null) {
        if (_cloudflare!.reachable) {
          buffer.writeln(
            'Cloudflare: reachable, edge ${_cloudflare!.colo ?? '--'} '
            '(${_cloudflare!.location ?? '--'}), '
            'WARP: ${_cloudflare!.warp ?? '--'}, '
            'TLS: ${_cloudflare!.tlsVersion ?? '--'}, '
            'HTTP: ${_cloudflare!.httpVersion ?? '--'}',
          );
        } else {
          buffer.writeln(
            'Cloudflare: unreachable (${_cloudflare!.error ?? 'unknown error'})',
          );
        }
      }
      if (_globalPingResults.isNotEmpty) {
        buffer.writeln('Global ping:');
        for (final result in _globalPingResults) {
          buffer.writeln(
            '  ${result.name} (${result.region}): '
            '${result.success ? '${result.latencyMs} ms' : 'failed'}'
            '${result.viaHttpFallback ? ' (HTTPS fallback)' : ''}',
          );
        }
      }
      if (_whois != null) {
        if (_whois!.error == null) {
          buffer.writeln('Whois (${_whois!.ip}):');
          buffer.writeln('  Network: ${_whois!.networkName ?? '--'}');
          buffer.writeln('  Organization: ${_whois!.organization ?? '--'}');
          buffer.writeln('  Country: ${_whois!.country ?? '--'}');
          buffer.writeln('  Registered: ${_whois!.registeredOn ?? '--'}');
          buffer.writeln('  Last changed: ${_whois!.lastChanged ?? '--'}');
          buffer.writeln('  Abuse contact: ${_whois!.abuseEmail ?? '--'}');
        } else {
          buffer.writeln('Whois: failed (${_whois!.error})');
        }
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }
}

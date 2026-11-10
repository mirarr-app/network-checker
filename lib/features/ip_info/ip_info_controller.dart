import 'package:flutter/foundation.dart';

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

  IpInfoStatus get status => _status;
  bool get isIdle => _status == IpInfoStatus.idle;
  bool get isRunning => _status == IpInfoStatus.running;
  bool get isCompleted => _status == IpInfoStatus.completed;

  IpLookupInfo? get lookup => _lookup;
  IpPurityResult? get purity => _purity;
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

  /// Runs the whole IP info suite: lookup, purity, split routing, latency,
  /// then the environment checks.
  Future<void> runIpInfoSuite() async {
    if (_status == IpInfoStatus.running) return;

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
      _lookup = await IpInfoService.fetchIpLookup();
      if (_disposed || runId != _currentRunId) return;
      _completedSections++;
      notifyListeners();

      // 2. IP purity check for the primary IP.
      final primaryIp = _lookup?.primaryIp;
      if (primaryIp != null) {
        _purity = await IpInfoService.checkIpPurity(
          ip: primaryIp,
          geo: _lookup?.geo,
        );
      }
      if (_disposed || runId != _currentRunId) return;
      _completedSections++;
      notifyListeners();

      // 3. Split-routing test (results stream in as each domain finishes).
      _isTestingSplit = true;
      notifyListeners();
      await IpInfoService.testSplitRouting(
        targets: IpInfoTargets.splitRouteTargets,
        publicIp: primaryIp,
        onResult: (result) {
          if (_disposed || runId != _currentRunId) return;
          _addSplitResult(result);
          notifyListeners();
        },
      );
      if (_disposed || runId != _currentRunId) return;
      _isTestingSplit = false;
      _completedSections++;
      notifyListeners();

      // 4. Connectivity latency (median of 3 attempts per service).
      _isMeasuringLatency = true;
      notifyListeners();
      final latencyFutures = IpInfoTargets.latencyTargets.map((target) async {
        final result = await IpInfoService.measureLatencyForTarget(target);
        if (_disposed || runId != _currentRunId) return;
        _addLatencyResult(result);
        notifyListeners();
      });
      await Future.wait(latencyFutures);
      if (_disposed || runId != _currentRunId) return;
      _isMeasuringLatency = false;
      _completedSections++;
      notifyListeners();

      // 5. Environment checks (run concurrently, applied as they finish).
      _isCheckingEnvironment = true;
      notifyListeners();

      final environmentFutures = <Future<void>>[
        IpInfoService.checkDnsLeak().then((result) {
          if (_disposed || runId != _currentRunId) return;
          _dnsLeak = result;
          notifyListeners();
        }),
        IpInfoService.checkIpLeak().then((result) {
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
      if (primaryIp != null) {
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
      buffer.writeln('IPv4: ${_lookup!.ipv4 ?? 'Unavailable'}');
      buffer.writeln('IPv6: ${_lookup!.ipv6 ?? 'Unavailable'}');
      final geo = _lookup!.geo;
      if (geo != null) {
        buffer.writeln('Location: ${geo.countryName}, ${geo.regionName}, '
            '${geo.cityName}');
        buffer.writeln('ISP: ${geo.ispName}');
        buffer.writeln('ASN: ${geo.asn} (${geo.asnOrganization})');
        if (geo.timeZone.isNotEmpty) {
          buffer.writeln('Timezone: ${geo.timeZone}');
        }
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

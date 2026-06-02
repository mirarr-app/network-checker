import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/services/internet_diagnostics_service.dart';
import '../../core/services/cdn_ips.dart';
import '../../core/services/protocol_accessibility_service.dart';

/// Current state status of the diagnostic engine
enum DiagnosticEngineStatus { idle, running, completed }

/// Controller that coordinates executing tests and updating diagnostic UI states.
class InternetDiagnosticsController extends ChangeNotifier {
  DiagnosticEngineStatus _engineStatus = DiagnosticEngineStatus.idle;
  int _currentRunId = 0;

  // Track status of individual checks
  bool _dnsSuccess = false;
  bool _ipv4Success = false;
  bool _ipv6Success = false;
  bool _httpsSuccess = false;
  bool _dnsAnalysisSuccess = false;
  bool _tlsAnalysisSuccess = false;
  bool _domesticIpSuccess = false;
  bool _internationalIpSuccess = false;
  bool _overallInternetAccess = false;

  // Hold detailed results
  DiagnosticTestResult? _dnsResult;
  DiagnosticTestResult? _ipv4Result;
  DiagnosticTestResult? _ipv6Result;
  DiagnosticTestResult? _httpsResult;
  DnsAnalysisSummary? _dnsAnalysisSummary;
  TlsAnalysisSummary? _tlsAnalysisSummary;
  DiagnosticTestResult? _domesticIpResult;
  DiagnosticTestResult? _internationalIpResult;
  DiagnosticTestResult? _routingAnalysisResult;

  // Website Reachability State
  List<WebsiteReachabilityResult> _websiteResults = [];
  bool _isScanningWebsites = false;

  // CDN Reachability State
  List<WebsiteReachabilityResult> _cdnResults = [];
  bool _isScanningCdns = false;

  // TLS / HTTPS Analysis State
  bool _isScanningTlsTargets = false;

  // Social Media Reachability State
  List<SocialMediaResult> _socialMediaResults = [];
  bool _isScanningSocialMedia = false;

  // Protocol Accessibility State
  bool _protocolAccessibilitySuccess = false;
  List<ProtocolAccessibilitySummary> _protocolAccessibilitySummaries = [];
  bool _isScanningProtocols = false;
  String _protocolStepName = '';

  // List of major targets to verify
  static const List<Map<String, String>> targetWebsites = [
    {'name': 'Google', 'domain': 'www.google.com'},
    {'name': 'YouTube', 'domain': 'www.youtube.com'},
    {'name': 'GitHub', 'domain': 'github.com'},
    {'name': 'Wikipedia', 'domain': 'wikipedia.org'},
    {'name': 'Reddit', 'domain': 'www.reddit.com'},
    {'name': 'Stack Overflow', 'domain': 'stackoverflow.com'},
    {'name': 'ChatGPT', 'domain': 'chatgpt.com'},
    {'name': 'Claude', 'domain': 'claude.ai'},
    {'name': 'Gemini', 'domain': 'gemini.google.com'},
  ];

  // List of CDN targets to verify
  static const List<Map<String, dynamic>> targetCdns = [
    {
      'name': 'Cloudflare',
      'domain': 'cloudflare.com',
      'ips': cloudflareIps,
    },
    {
      'name': 'Akamai',
      'domain': 'akamai.com',
      'ips': akamaiIps,
    },
    {
      'name': 'Fastly',
      'domain': 'fastly.com',
      'ips': fastlyIps,
    },
    {
      'name': 'AWS CloudFront',
      'domain': 'aws.amazon.com',
      'ips': cloudfrontIps,
    },
    {
      'name': 'Azure CDN',
      'domain': 'azure.microsoft.com',
      'ips': azureIps,
    },
    {
      'name': 'Google CDN',
      'domain': 'cloud.google.com',
      'ips': googleIps,
    },
  ];

  // List of social media targets to verify
  static const List<Map<String, String>> targetSocialMedia = [
    {
      'name': 'Telegram',
      'primary': 'telegram.org',
      'secondary': 'api.telegram.org',
    },
    {
      'name': 'WhatsApp',
      'primary': 'web.whatsapp.com',
      'secondary': 'graph.whatsapp.com',
    },
    {
      'name': 'Discord',
      'primary': 'discord.com',
      'secondary': 'gateway.discord.gg',
    },
    {
      'name': 'Instagram',
      'primary': 'instagram.com',
      'secondary': 'scontent.cdninstagram.com',
    },
    {'name': 'X (Twitter)', 'primary': 'x.com', 'secondary': 'api.x.com'},
    {
      'name': 'Facebook',
      'primary': 'facebook.com',
      'secondary': 'graph.facebook.com',
    },
    {'name': 'TikTok', 'primary': 'tiktok.com', 'secondary': 'api.tiktokv.com'},
    {
      'name': 'Snapchat',
      'primary': 'snapchat.com',
      'secondary': 'aws.api.snapchat.com',
    },
    {'name': 'Signal', 'primary': 'signal.org', 'secondary': 'chat.signal.org'},
  ];

  // Track progress
  int _completedTestsCount = 0;
  static const int totalTestsCount = 12; // 12 progressive sequence tasks

  // Targets for Protocol Accessibility Checks
  static const List<String> protocolHttpDomains = [
    'google.com',
    'cloudflare.com',
    'wikipedia.org',
    'github.com',
  ];

  static const List<String> protocolHttpsDomains = [
    'google.com',
    'cloudflare.com',
    'wikipedia.org',
    'github.com',
  ];

  static const List<String> protocolUdpDomains = [
    'dns.google',
    'one.one.one.one',
    'time.google.com',
    'time.windows.com',
  ];

  static const List<String> protocolHttp3Domains = [
    'google.com',
    'cloudflare.com',
    'speedtest.net',
    'dash.cloudflare.com',
  ];

  static const List<String> protocolWebsocketUrls = [
    'wss://ws.postman-echo.com/raw',
    'wss://javascript.info/article/websocket/demo/hello',
    'wss://echo.websocket.events',
  ];

  static const List<String> protocolDohDomains = [
    'dns.google',
    'cloudflare-dns.com',
    'dns.quad9.net',
  ];

  static const List<String> protocolDotDomains = [
    'dns.google',
    'one.one.one.one',
    'dns.quad9.net',
  ];

  static const List<String> protocolPingDomains = [
    'google.com',
    'cloudflare.com',
    'github.com',
    'wikipedia.org',
  ];

  // Getters
  bool get protocolAccessibilitySuccess => _protocolAccessibilitySuccess;
  List<ProtocolAccessibilitySummary> get protocolAccessibilitySummaries => _protocolAccessibilitySummaries;
  bool get isScanningProtocols => _isScanningProtocols;
  String get protocolStepName => _protocolStepName;
  int get supportedProtocolsCount => _protocolAccessibilitySummaries.where((s) => s.isSupported).length;
  int get blockedProtocolsCount => _protocolAccessibilitySummaries.where((s) => s.isBlocked).length;

  // Getters
  DiagnosticEngineStatus get engineStatus => _engineStatus;
  bool get dnsSuccess => _dnsSuccess;
  bool get ipv4Success => _ipv4Success;
  bool get ipv6Success => _ipv6Success;
  bool get httpsSuccess => _httpsSuccess;
  bool get dnsAnalysisSuccess => _dnsAnalysisSuccess;
  bool get tlsAnalysisSuccess => _tlsAnalysisSuccess;
  bool get domesticIpSuccess => _domesticIpSuccess;
  bool get internationalIpSuccess => _internationalIpSuccess;
  bool get overallInternetAccess => _overallInternetAccess;

  DiagnosticTestResult? get dnsResult => _dnsResult;
  DiagnosticTestResult? get ipv4Result => _ipv4Result;
  DiagnosticTestResult? get ipv6Result => _ipv6Result;
  DiagnosticTestResult? get httpsResult => _httpsResult;
  DnsAnalysisSummary? get dnsAnalysisSummary => _dnsAnalysisSummary;
  TlsAnalysisSummary? get tlsAnalysisSummary => _tlsAnalysisSummary;
  DiagnosticTestResult? get domesticIpResult => _domesticIpResult;
  DiagnosticTestResult? get internationalIpResult => _internationalIpResult;
  DiagnosticTestResult? get routingAnalysisResult => _routingAnalysisResult;

  List<WebsiteReachabilityResult> get websiteResults => _websiteResults;
  bool get isScanningWebsites => _isScanningWebsites;
  bool get isScanningTlsTargets => _isScanningTlsTargets;

  List<WebsiteReachabilityResult> get cdnResults => _cdnResults;
  bool get isScanningCdns => _isScanningCdns;

  List<SocialMediaResult> get socialMediaResults => _socialMediaResults;
  bool get isScanningSocialMedia => _isScanningSocialMedia;

  int get completedTestsCount => _completedTestsCount;
  double get progressFraction => _completedTestsCount / totalTestsCount;

  bool get isIdle => _engineStatus == DiagnosticEngineStatus.idle;
  bool get isRunning => _engineStatus == DiagnosticEngineStatus.running;
  bool get isCompleted => _engineStatus == DiagnosticEngineStatus.completed;

  // Website reachability summary statistics
  int get reachableWebsitesCount => _websiteResults
      .where((w) => w.status == ReachabilityStatus.reachable)
      .length;

  int get blockedWebsitesCount => _websiteResults
      .where((w) => w.status == ReachabilityStatus.blocked)
      .length;

  int get failedWebsitesCount => _websiteResults
      .where(
        (w) =>
            w.status == ReachabilityStatus.dnsFailure ||
            w.status == ReachabilityStatus.tlsFailure ||
            w.status == ReachabilityStatus.timeout,
      )
      .length;

  int get averageWebsiteLatencyMs {
    final latencies = _websiteResults
        .where(
          (w) =>
              w.latencyMs != null && w.status == ReachabilityStatus.reachable,
        )
        .map((w) => w.latencyMs!)
        .toList();
    if (latencies.isEmpty) return 0;
    final total = latencies.reduce((a, b) => a + b);
    return (total / latencies.length).round();
  }

  // CDN reachability summary statistics
  int get reachableCdnsCount => _cdnResults
      .where((w) => w.status == ReachabilityStatus.reachable)
      .length;

  int get blockedCdnsCount => _cdnResults
      .where((w) => w.status == ReachabilityStatus.blocked)
      .length;

  int get failedCdnsCount => _cdnResults
      .where(
        (w) =>
            w.status == ReachabilityStatus.dnsFailure ||
            w.status == ReachabilityStatus.tlsFailure ||
            w.status == ReachabilityStatus.timeout,
      )
      .length;

  int get averageCdnLatencyMs {
    final latencies = _cdnResults
        .where(
          (w) =>
              w.latencyMs != null && w.status == ReachabilityStatus.reachable,
        )
        .map((w) => w.latencyMs!)
        .toList();
    if (latencies.isEmpty) return 0;
    final total = latencies.reduce((a, b) => a + b);
    return (total / latencies.length).round();
  }

  int get tlsHandshakeSuccessCount =>
      _tlsAnalysisSummary?.successfulHandshakes ?? 0;

  int get tlsCertificateMismatchCount =>
      _tlsAnalysisSummary?.certificateMismatches ?? 0;

  int get tlsTraceMismatchCount => _tlsAnalysisSummary?.traceMismatches ?? 0;

  int get averageTlsHandshakeLatencyMs =>
      _tlsAnalysisSummary?.averageHandshakeLatencyMs ?? 0;

  // Social Media accessibility summary statistics
  int get accessibleSocialCount => _socialMediaResults
      .where((w) => w.status == SocialMediaStatus.accessible)
      .length;

  int get partialSocialCount => _socialMediaResults
      .where((w) => w.status == SocialMediaStatus.partial)
      .length;

  int get blockedSocialCount => _socialMediaResults
      .where((w) => w.status == SocialMediaStatus.blocked)
      .length;

  int get averageSocialLatencyMs {
    final latencies = _socialMediaResults
        .where(
          (w) => w.latencyMs != null && w.status != SocialMediaStatus.blocked,
        )
        .map((w) => w.latencyMs!)
        .toList();
    if (latencies.isEmpty) return 0;
    final total = latencies.reduce((a, b) => a + b);
    return (total / latencies.length).round();
  }

  /// Run all tests sequentially to create a gorgeous scanning effect in the UI
  Future<void> runDiagnosticsSuite() async {
    if (_engineStatus == DiagnosticEngineStatus.running) return;

    _currentRunId++;
    final runId = _currentRunId;

    _engineStatus = DiagnosticEngineStatus.running;
    _completedTestsCount = 0;

    _dnsSuccess = false;
    _ipv4Success = false;
    _ipv6Success = false;
    _httpsSuccess = false;
    _dnsAnalysisSuccess = false;
    _tlsAnalysisSuccess = false;
    _domesticIpSuccess = false;
    _internationalIpSuccess = false;
    _overallInternetAccess = false;

    _dnsResult = null;
    _ipv4Result = null;
    _ipv6Result = null;
    _httpsResult = null;
    _dnsAnalysisSummary = null;
    _tlsAnalysisSummary = null;
    _domesticIpResult = null;
    _internationalIpResult = null;
    _routingAnalysisResult = null;
    _websiteResults = [];
    _isScanningWebsites = false;
    _isScanningTlsTargets = false;
    _cdnResults = [];
    _isScanningCdns = false;
    _socialMediaResults = [];
    _isScanningSocialMedia = false;

    notifyListeners();

    // 1. DNS Resolution Test
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (runId != _currentRunId) return;
    _dnsResult = await InternetDiagnosticsService.checkDnsResolution();
    if (runId != _currentRunId) return;
    _dnsSuccess = _dnsResult!.success;
    _completedTestsCount++;
    notifyListeners();

    // 2. IPv4 Connectivity Test
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (runId != _currentRunId) return;
    _ipv4Result = await InternetDiagnosticsService.checkIpv4Connectivity();
    if (runId != _currentRunId) return;
    _ipv4Success = _ipv4Result!.success;
    _completedTestsCount++;
    notifyListeners();

    // 3. IPv6 Connectivity Test
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (runId != _currentRunId) return;
    _ipv6Result = await InternetDiagnosticsService.checkIpv6Connectivity();
    if (runId != _currentRunId) return;
    _ipv6Success = _ipv6Result!.success;
    _completedTestsCount++;
    notifyListeners();

    // 4. HTTPS Traffic Test
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (runId != _currentRunId) return;
    _httpsResult = await InternetDiagnosticsService.checkHttpsTraffic();
    if (runId != _currentRunId) return;
    _httpsSuccess = _httpsResult!.success;
    _completedTestsCount++;
    notifyListeners();

    // 5. DNS Provider Analysis
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (runId != _currentRunId) return;
    _dnsAnalysisSummary =
        await InternetDiagnosticsService.analyzeDnsProviders();
    if (runId != _currentRunId) return;
    _dnsAnalysisSuccess = _dnsAnalysisSummary!.success;
    _completedTestsCount++;
    notifyListeners();

    // 6. Domestic IP Discovery Test
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (runId != _currentRunId) return;
    _domesticIpResult = await InternetDiagnosticsService.fetchPublicIp(
      domestic: true,
    );
    if (runId != _currentRunId) return;
    _domesticIpSuccess = _domesticIpResult!.success;
    _completedTestsCount++;
    notifyListeners();

    // 7. International IP Discovery Test
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (runId != _currentRunId) return;
    _internationalIpResult = await InternetDiagnosticsService.fetchPublicIp(
      domestic: false,
    );
    if (runId != _currentRunId) return;
    _internationalIpSuccess = _internationalIpResult!.success;
    _completedTestsCount++;
    notifyListeners();

    // 8. Perform IP Routing and Discrepancy Analysis
    _routingAnalysisResult = InternetDiagnosticsService.analyzePublicIps(
      domesticResult: _domesticIpResult!,
      internationalResult: _internationalIpResult!,
    );
    notifyListeners();

    // 9. TLS / HTTPS Analysis Step
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (runId != _currentRunId) return;
    _isScanningTlsTargets = true;
    _completedTestsCount++;
    notifyListeners();

    final tlsSummary = await InternetDiagnosticsService.analyzeTlsTargets(
      publicIp:
          _extractRetrievedIp(_internationalIpResult) ??
          _extractRetrievedIp(_domesticIpResult),
    );
    if (runId != _currentRunId) return;
    _tlsAnalysisSummary = tlsSummary;
    _tlsAnalysisSuccess = _tlsAnalysisSummary!.success;
    _isScanningTlsTargets = false;
    notifyListeners();

    // 10. Website Reachability Scan Step
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (runId != _currentRunId) return;
    _isScanningWebsites = true;
    _completedTestsCount++;
    notifyListeners();

    for (final target in targetWebsites) {
      if (runId != _currentRunId) return;
      final name = target['name']!;
      final domain = target['domain']!;

      final result = await InternetDiagnosticsService.testWebsiteReachability(
        name,
        domain,
      );
      if (runId != _currentRunId) return;
      _websiteResults.add(result);
      notifyListeners();

      // Subtle stagger delay between sequential checks to render scanning effect
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (runId != _currentRunId) return;
    }

    _isScanningWebsites = false;
    notifyListeners();

    // 10. CDN Reachability Scan Step
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (runId != _currentRunId) return;
    _isScanningCdns = true;
    _completedTestsCount++;
    notifyListeners();

    for (final target in targetCdns) {
      if (runId != _currentRunId) return;
      final name = target['name']!;
      final domain = target['domain']!;
      final List<String> ips = target['ips'] as List<String>;

      // Pick a random list of 50 IPs from each CDN
      final random = Random();
      final List<String> shuffledIps = List<String>.from(ips)..shuffle(random);
      final List<String> selectedIps = shuffledIps.take(50).toList();

      final scanResult = await InternetDiagnosticsService.scanCdnIps(
        selectedIps,
        maxConcurrency: 50,
        timeout: const Duration(milliseconds: 500),
      );
      if (runId != _currentRunId) return;

      final isReachable = scanResult.reachable > 0;
      final accessibilityPercent = (scanResult.accessibilityRate * 100).toStringAsFixed(1);
      
      final detailsText = 'Edge IP Range Scan Results (Tested 50 Random IPs):\n'
          'Total tested random IPs: ${scanResult.totalTested}\n'
          'Reachable edge IPs: ${scanResult.reachable}\n'
          'Failed IPs: ${scanResult.totalTested - scanResult.reachable}\n'
          'CDN Accessibility: $accessibilityPercent%\n'
          'Average Handshake Latency: ${scanResult.averageLatencyMs}ms\n\n'
          'Note: This test scanned 50 randomly selected IPs from the CDN\'s public ranges to determine edge network accessibility and performance.';

      final result = WebsiteReachabilityResult(
        name: name,
        domain: domain,
        status: isReachable ? ReachabilityStatus.reachable : ReachabilityStatus.blocked,
        latencyMs: scanResult.averageLatencyMs,
        errorDetails: detailsText,
        statusCode: isReachable ? 200 : null,
      );

      _cdnResults.add(result);
      notifyListeners();

      // Subtle stagger delay between sequential checks to render scanning effect
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (runId != _currentRunId) return;
    }

    _isScanningCdns = false;
    notifyListeners();

    // 11. Social Media Accessibility Scan Step
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (runId != _currentRunId) return;
    _isScanningSocialMedia = true;
    _completedTestsCount++;
    notifyListeners();

    for (final target in targetSocialMedia) {
      if (runId != _currentRunId) return;
      final name = target['name']!;
      final primary = target['primary']!;
      final secondary = target['secondary']!;

      final result =
          await InternetDiagnosticsService.testSocialMediaAccessibility(
            name: name,
            primaryDomain: primary,
            secondaryDomain: secondary,
          );
      if (runId != _currentRunId) return;
      _socialMediaResults.add(result);
      notifyListeners();

      // Subtle stagger delay between sequential checks to render scanning effect
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (runId != _currentRunId) return;
    }

    _isScanningSocialMedia = false;
    notifyListeners();

    // 12. Protocol Accessibility Scan Step
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (runId != _currentRunId) return;
    _isScanningProtocols = true;
    _completedTestsCount++;
    notifyListeners();

    final testTimeout = const Duration(seconds: 4);
    final List<ProtocolAccessibilitySummary> summaries = [];

    Future<ProtocolAccessibilitySummary> runProtocolStep(
      String name,
      String description,
      List<String> targets,
      Future<ProtocolTestResult> Function(String, Duration) tester,
    ) async {
      _protocolStepName = 'Testing $name...';
      notifyListeners();
      final futures = targets.map((domain) => tester(domain, testTimeout)).toList();
      final results = await Future.wait(futures);
      return ProtocolAccessibilitySummary(
        protocolName: name,
        isSupported: results.any((r) => r.success),
        isBlocked: false, // updated below
        results: results,
        description: description,
      );
    }

    try {
      summaries.add(await runProtocolStep(
        'TCP HTTP',
        'Plain HTTP connectivity on TCP port 80',
        protocolHttpDomains,
        ProtocolAccessibilityService.testHttpDomain,
      ));
      if (runId != _currentRunId) return;

      summaries.add(await runProtocolStep(
        'TCP HTTPS',
        'Secure HTTPS connectivity on TCP port 443',
        protocolHttpsDomains,
        ProtocolAccessibilityService.testHttpsDomain,
      ));
      if (runId != _currentRunId) return;

      summaries.add(await runProtocolStep(
        'UDP Connectivity',
        'Generic UDP traffic via NTP and DNS',
        protocolUdpDomains,
        ProtocolAccessibilityService.testUdpDomain,
      ));
      if (runId != _currentRunId) return;

      summaries.add(await runProtocolStep(
        'HTTP/3 (QUIC)',
        'Forced HTTP/3 over QUIC on UDP port 443',
        protocolHttp3Domains,
        ProtocolAccessibilityService.testHttp3Domain,
      ));
      if (runId != _currentRunId) return;

      summaries.add(await runProtocolStep(
        'WebSockets',
        'WebSocket handshake and duplex connection',
        protocolWebsocketUrls,
        ProtocolAccessibilityService.testWebSocketDomain,
      ));
      if (runId != _currentRunId) return;

      summaries.add(await runProtocolStep(
        'DNS-over-HTTPS',
        'DNS queries routed securely inside HTTPS request',
        protocolDohDomains,
        ProtocolAccessibilityService.testDoHDomain,
      ));
      if (runId != _currentRunId) return;

      summaries.add(await runProtocolStep(
        'DNS-over-TLS',
        'DNS queries secure wrapping in TLS port 853',
        protocolDotDomains,
        ProtocolAccessibilityService.testDoTDomain,
      ));
      if (runId != _currentRunId) return;

      summaries.add(await runProtocolStep(
        'ICMP Ping',
        'Standard ICMP Echo ping reachability',
        protocolPingDomains,
        ProtocolAccessibilityService.testIcmpDomain,
      ));
    } catch (e) {
      debugPrint('Protocol Accessibility scan error: $e');
    }

    if (runId != _currentRunId) return;

    // Compute Overall Internet Access
    final hasProtocolSupport = summaries.any((s) => s.isSupported);
    _overallInternetAccess =
        _dnsSuccess ||
        _ipv4Success ||
        _ipv6Success ||
        _httpsSuccess ||
        _dnsAnalysisSuccess ||
        _tlsAnalysisSuccess ||
        _domesticIpSuccess ||
        _internationalIpSuccess ||
        _websiteResults.any((w) => w.status == ReachabilityStatus.reachable) ||
        _cdnResults.any((c) => c.status == ReachabilityStatus.reachable) ||
        _socialMediaResults.any(
          (s) =>
              s.status == SocialMediaStatus.accessible ||
              s.status == SocialMediaStatus.partial,
        ) ||
        hasProtocolSupport;

    // Calculate blocked status for protocols based on network online status
    final online = _overallInternetAccess || _httpsSuccess || _dnsSuccess;
    _protocolAccessibilitySummaries = summaries.map((s) {
      final isBlocked = !s.isSupported && online;
      return ProtocolAccessibilitySummary(
        protocolName: s.protocolName,
        isSupported: s.isSupported,
        isBlocked: isBlocked,
        results: s.results,
        description: s.description,
      );
    }).toList();

    _protocolAccessibilitySuccess = hasProtocolSupport;
    _isScanningProtocols = false;

    _engineStatus = DiagnosticEngineStatus.completed;
    notifyListeners();
  }

  /// Reset the engine state
  void resetSuite() {
    _currentRunId++; // Increment to cancel any active runs
    _engineStatus = DiagnosticEngineStatus.idle;
    _completedTestsCount = 0;

    _dnsSuccess = false;
    _ipv4Success = false;
    _ipv6Success = false;
    _httpsSuccess = false;
    _dnsAnalysisSuccess = false;
    _tlsAnalysisSuccess = false;
    _domesticIpSuccess = false;
    _internationalIpSuccess = false;
    _overallInternetAccess = false;

    _dnsResult = null;
    _ipv4Result = null;
    _ipv6Result = null;
    _httpsResult = null;
    _dnsAnalysisSummary = null;
    _tlsAnalysisSummary = null;
    _domesticIpResult = null;
    _internationalIpResult = null;
    _routingAnalysisResult = null;
    _websiteResults = [];
    _isScanningWebsites = false;
    _isScanningTlsTargets = false;
    _cdnResults = [];
    _isScanningCdns = false;
    _socialMediaResults = [];
    _isScanningSocialMedia = false;

    _protocolAccessibilitySuccess = false;
    _protocolAccessibilitySummaries = [];
    _isScanningProtocols = false;
    _protocolStepName = '';

    notifyListeners();
  }

  String? _extractRetrievedIp(DiagnosticTestResult? result) {
    if (result == null || !result.success) return null;
    return result.message.replaceFirst('IP retrieved: ', '').trim();
  }
}

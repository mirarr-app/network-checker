import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/internet_diagnostics_service.dart';
import '../../core/services/protocol_accessibility_service.dart';
import 'internet_diagnostics_controller.dart';

class InternetDiagnosticsScreen extends StatelessWidget {
  const InternetDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Internet Diagnostics'),
        actions: [
          Consumer<InternetDiagnosticsController>(
            builder: (context, controller, _) {
              if (controller.isCompleted) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset suite',
                  onPressed: controller.resetSuite,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<InternetDiagnosticsController>(
        builder: (context, controller, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // 1. Central Radar / Diagnostic Gauge
                _buildDiagnosticGauge(context, controller),

                const SizedBox(height: 24),

                // 2. IP Protocol Overview Badges
                _buildOverviewBadges(context, controller),

                const SizedBox(height: 16),

                // 3. Dynamic IP Routing Analysis Card
                _buildDnsAnalysisDashboard(context, controller),

                const SizedBox(height: 16),

                // 4. Dynamic IP Routing Analysis Card
                _buildIpRoutingAnalysis(context, controller),

                const SizedBox(height: 16),

                // 5. TLS / HTTPS Analysis Dashboard
                _buildTlsAnalysisDashboard(context, controller),

                const SizedBox(height: 16),

                // 6. Website Reachability Scan Dashboard
                _buildWebsiteReachabilityDashboard(context, controller),

                const SizedBox(height: 16),

                // 7. CDN Reachability Scan Dashboard
                _buildCdnReachabilityDashboard(context, controller),

                const SizedBox(height: 16),

                // 8. Social Media Accessibility Dashboard
                _buildSocialMediaAccessibilityDashboard(context, controller),

                const SizedBox(height: 16),

                // 9. Protocol Accessibility Dashboard
                _buildProtocolAccessibilityDashboard(context, controller),

                const SizedBox(height: 24),

                // 5. Staggered Check Details List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 12),
                        child: Text(
                          'DIAGNOSTIC CHECKLIST',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),

                      // DNS resolution card
                      _DiagnosticCheckCard(
                            title: 'DNS Resolution',
                            description: 'Resolves hostnames to IP addresses',
                            iconData: Icons.dns_rounded,
                            isPending: controller.isIdle,
                            isRunning:
                                controller.isRunning &&
                                controller.completedTestsCount == 0,
                            isSuccess: controller.isCompleted
                                ? controller.dnsSuccess
                                : (controller.completedTestsCount > 0
                                      ? controller.dnsSuccess
                                      : false),
                            result: controller.dnsResult,
                          )
                          .animate()
                          .fadeIn(delay: 100.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 12),

                      // IPv4 Connectivity card
                      _DiagnosticCheckCard(
                            title: 'IPv4 Socket Connectivity',
                            description:
                                'Tests direct TCP routing to IPv4 public address',
                            iconData: Icons.four_g_mobiledata_rounded,
                            isPending:
                                controller.isIdle ||
                                (controller.isRunning &&
                                    controller.completedTestsCount < 1),
                            isRunning:
                                controller.isRunning &&
                                controller.completedTestsCount == 1,
                            isSuccess: controller.isCompleted
                                ? controller.ipv4Success
                                : (controller.completedTestsCount > 1
                                      ? controller.ipv4Success
                                      : false),
                            result: controller.ipv4Result,
                          )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 12),

                      // IPv6 Connectivity card
                      _DiagnosticCheckCard(
                            title: 'IPv6 Socket Connectivity',
                            description:
                                'Tests direct TCP routing to IPv6 public address',
                            iconData: Icons.six_ft_apart_rounded,
                            customIcon: const Text(
                              '6',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            isPending:
                                controller.isIdle ||
                                (controller.isRunning &&
                                    controller.completedTestsCount < 2),
                            isRunning:
                                controller.isRunning &&
                                controller.completedTestsCount == 2,
                            isSuccess: controller.isCompleted
                                ? controller.ipv6Success
                                : (controller.completedTestsCount > 2
                                      ? controller.ipv6Success
                                      : false),
                            result: controller.ipv6Result,
                          )
                          .animate()
                          .fadeIn(delay: 300.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 12),

                      // HTTPS Traffic card
                      _DiagnosticCheckCard(
                            title: 'HTTPS Connection & TLS Handshake',
                            description:
                                'Performs HTTPS fetch and handshake checks',
                            iconData: Icons.security_rounded,
                            isPending:
                                controller.isIdle ||
                                (controller.isRunning &&
                                    controller.completedTestsCount < 3),
                            isRunning:
                                controller.isRunning &&
                                controller.completedTestsCount == 3,
                            isSuccess: controller.isCompleted
                                ? controller.httpsSuccess
                                : (controller.completedTestsCount > 3
                                      ? controller.httpsSuccess
                                      : false),
                            result: controller.httpsResult,
                          )
                          .animate()
                          .fadeIn(delay: 400.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 12),

                      _DiagnosticCheckCard(
                        title: 'DNS Provider Analysis',
                        description:
                            'Compares ISP, Google, Cloudflare, Quad9, and OpenDNS responses',
                        iconData: Icons.manage_search_rounded,
                        isPending:
                            controller.isIdle ||
                            (controller.isRunning &&
                                controller.completedTestsCount < 4),
                        isRunning:
                            controller.isRunning &&
                            controller.completedTestsCount == 4,
                        isSuccess: controller.isCompleted
                            ? controller.dnsAnalysisSuccess
                            : (controller.completedTestsCount > 4
                                  ? controller.dnsAnalysisSuccess
                                  : false),
                        result: controller.dnsAnalysisSummary != null
                            ? DiagnosticTestResult(
                                name: 'DNS Provider Analysis',
                                success: controller.dnsAnalysisSummary!.success,
                                message:
                                    '${controller.dnsAnalysisSummary!.successfulProviders} of ${controller.dnsAnalysisSummary!.providerResults.length} providers responded',
                                latencyMs: controller
                                    .dnsAnalysisSummary!
                                    .averageLatencyMs,
                                details:
                                    'DNS consistency: ${(controller.dnsAnalysisSummary!.consistencyScore * 100).round()}%\nTampering score: ${controller.dnsAnalysisSummary!.tamperingScore}/100\nFindings:\n${controller.dnsAnalysisSummary!.findings.isEmpty ? 'No strong DNS tampering indicators detected.' : controller.dnsAnalysisSummary!.findings.join('\n')}',
                              )
                            : null,
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 12),

                      // Domestic IP Discovery card
                      _DiagnosticCheckCard(
                            title: 'Domestic IP Discovery',
                            description:
                                'Queries domestic CDN edge (Chabokan)',
                            iconData: Icons.location_on_rounded,
                            isPending:
                                controller.isIdle ||
                                (controller.isRunning &&
                                    controller.completedTestsCount < 5),
                            isRunning:
                                controller.isRunning &&
                                controller.completedTestsCount == 5,
                            isSuccess: controller.isCompleted
                                ? controller.domesticIpSuccess
                                : (controller.completedTestsCount > 5
                                      ? controller.domesticIpSuccess
                                      : false),
                            result: controller.domesticIpResult,
                          )
                          .animate()
                          .fadeIn(delay: 600.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 12),

                      // International IP Discovery card
                      _DiagnosticCheckCard(
                            title: 'International IP Discovery',
                            description:
                                'Queries global IP reflection endpoint (ipify)',
                            iconData: Icons.public_rounded,
                            isPending:
                                controller.isIdle ||
                                (controller.isRunning &&
                                    controller.completedTestsCount < 6),
                            isRunning:
                                controller.isRunning &&
                                controller.completedTestsCount == 6,
                            isSuccess: controller.isCompleted
                                ? controller.internationalIpSuccess
                                : (controller.completedTestsCount > 6
                                      ? controller.internationalIpSuccess
                                      : false),
                            result: controller.internationalIpResult,
                          )
                          .animate()
                          .fadeIn(delay: 700.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 12),

                      _DiagnosticCheckCard(
                        title: 'TLS / HTTPS Analysis',
                        description:
                            'Checks TLS handshakes, certificates, and Cloudflare trace IPs',
                        iconData: Icons.https_rounded,
                        isPending:
                            controller.isIdle ||
                            (controller.isRunning &&
                                controller.completedTestsCount < 8),
                        isRunning: controller.isScanningTlsTargets,
                        isSuccess: controller.isCompleted
                            ? controller.tlsAnalysisSuccess
                            : (controller.completedTestsCount > 7
                                  ? controller.tlsAnalysisSuccess
                                  : false),
                        result: controller.tlsAnalysisSummary != null
                            ? DiagnosticTestResult(
                                name: 'TLS / HTTPS Analysis',
                                success: controller.tlsAnalysisSummary!.success,
                                message:
                                    '${controller.tlsHandshakeSuccessCount} of ${controller.tlsAnalysisSummary!.results.length} handshakes succeeded',
                                latencyMs:
                                    controller.averageTlsHandshakeLatencyMs,
                                details:
                                    'Certificate mismatches: ${controller.tlsCertificateMismatchCount}\nCloudflare trace mismatches: ${controller.tlsTraceMismatchCount}\nTampering score: ${controller.tlsAnalysisSummary!.averageTamperingScore}/100\nFindings:\n${controller.tlsAnalysisSummary!.findings.isEmpty ? 'No strong TLS interception indicators detected.' : controller.tlsAnalysisSummary!.findings.join('\n')}',
                              )
                            : null,
                      ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 12),

                      // Website Reachability Scan checklist card
                      _DiagnosticCheckCard(
                        title: 'Website Reachability Scan',
                        description:
                            'Tests reachability of Google, YouTube, and famous AI tools',
                        iconData: Icons.public_off_rounded,
                        isPending:
                            controller.isIdle ||
                            (controller.isRunning &&
                                controller.completedTestsCount < 9),
                        isRunning: controller.isScanningWebsites,
                        isSuccess: controller.isCompleted
                            ? controller.reachableWebsitesCount > 0
                            : (controller.completedTestsCount > 9
                                  ? controller.reachableWebsitesCount > 0
                                  : false),
                        result: controller.isCompleted
                            ? DiagnosticTestResult(
                                name: 'Website Reachability Scan',
                                success: controller.reachableWebsitesCount > 0,
                                message:
                                    '${controller.reachableWebsitesCount} of 9 websites reachable',
                                details:
                                    'Checklist Scan results:\nReachable: ${controller.reachableWebsitesCount}\nBlocked: ${controller.blockedWebsitesCount}\nFailed/DNS/TLS: ${controller.failedWebsitesCount}\nAverage Latency: ${controller.averageWebsiteLatencyMs}ms',
                              )
                            : null,
                      ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 12),

                      // CDN Reachability Scan checklist card
                      _DiagnosticCheckCard(
                        title: 'CDN Reachability Scan',
                        description:
                            'Tests connectivity and latency to major global CDNs',
                        iconData: Icons.cloud_done_rounded,
                        isPending:
                            controller.isIdle ||
                            (controller.isRunning &&
                                controller.completedTestsCount < 10),
                        isRunning: controller.isScanningCdns,
                        isSuccess: controller.isCompleted
                            ? controller.reachableCdnsCount > 0
                            : (controller.completedTestsCount > 10
                                  ? controller.reachableCdnsCount > 0
                                  : false),
                        result: controller.isCompleted
                            ? DiagnosticTestResult(
                                name: 'CDN Reachability Scan',
                                success: controller.reachableCdnsCount > 0,
                                message:
                                    '${controller.reachableCdnsCount} of 6 CDNs reachable',
                                details:
                                    'Checklist Scan results:\nReachable: ${controller.reachableCdnsCount}\nBlocked: ${controller.blockedCdnsCount}\nFailed/DNS/TLS: ${controller.failedCdnsCount}\nAverage Latency: ${controller.averageCdnLatencyMs}ms',
                              )
                            : null,
                      ).animate().fadeIn(delay: 950.ms).slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 12),

                      // Social Media Accessibility Scan checklist card
                      _DiagnosticCheckCard(
                        title: 'Social Media Accessibility Scan',
                        description:
                            'Checks messaging and social platforms via primary & secondary endpoints',
                        iconData: Icons.forum_rounded,
                        isPending:
                            controller.isIdle ||
                            (controller.isRunning &&
                                controller.completedTestsCount < 11),
                        isRunning: controller.isScanningSocialMedia,
                        isSuccess: controller.isCompleted
                            ? (controller.accessibleSocialCount > 0 ||
                                  controller.partialSocialCount > 0)
                            : (controller.completedTestsCount > 11
                                  ? (controller.accessibleSocialCount > 0 ||
                                        controller.partialSocialCount > 0)
                                  : false),
                        result: controller.isCompleted
                            ? DiagnosticTestResult(
                                name: 'Social Media Accessibility Scan',
                                success:
                                    controller.accessibleSocialCount > 0 ||
                                    controller.partialSocialCount > 0,
                                message:
                                    '${controller.accessibleSocialCount} accessible, ${controller.partialSocialCount} partially accessible',
                                details:
                                    'Checklist Scan results:\nFully Accessible: ${controller.accessibleSocialCount}\nPartially Accessible: ${controller.partialSocialCount}\nBlocked/Censored: ${controller.blockedSocialCount}\nAverage Latency: ${controller.averageSocialLatencyMs}ms',
                              )
                            : null,
                      ).animate().fadeIn(delay: 1050.ms).slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 12),

                      // Protocol Accessibility checklist card
                      _DiagnosticCheckCard(
                        title: 'Protocol Accessibility Scan',
                        description:
                            'Checks ports and standard protocol capabilities (TCP/UDP/QUIC/WS/DoH/DoT/Ping)',
                        iconData: Icons.network_locked_rounded,
                        isPending:
                            controller.isIdle ||
                            (controller.isRunning &&
                                controller.completedTestsCount < 12),
                        isRunning: controller.isScanningProtocols,
                        isSuccess: controller.isCompleted
                            ? controller.protocolAccessibilitySuccess
                            : (controller.completedTestsCount >= 12
                                  ? controller.protocolAccessibilitySuccess
                                  : false),
                        result: controller.isCompleted
                            ? DiagnosticTestResult(
                                name: 'Protocol Accessibility Scan',
                                success: controller.protocolAccessibilitySuccess,
                                message:
                                    '${controller.supportedProtocolsCount} of 8 protocols supported, ${controller.blockedProtocolsCount} blocked',
                                details:
                                    'Protocol Scan results:\nSupported: ${controller.supportedProtocolsCount}\nBlocked: ${controller.blockedProtocolsCount}\nDetails of protocol support and individual domains are visible in the Protocol Accessibility section above.',
                              )
                            : null,
                      ).animate().fadeIn(delay: 1100.ms).slideY(begin: 0.1, end: 0),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ),
      floatingActionButton: Consumer<InternetDiagnosticsController>(
        builder: (context, controller, _) {
          final isRunning = controller.isRunning;
          return FloatingActionButton.extended(
            heroTag: 'run_diagnostics',
            onPressed: isRunning ? null : controller.runDiagnosticsSuite,
            icon: Icon(
              isRunning ? Icons.hourglass_empty : Icons.network_ping_rounded,
            ),
            label: Text(isRunning ? 'Diagnosing...' : 'Start Diagnostic'),
          ).animate().fadeIn(delay: 200.ms).scale(delay: 200.ms);
        },
      ),
    );
  }

  Widget _buildDiagnosticGauge(
    BuildContext context,
    InternetDiagnosticsController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    Color pulseColor = colorScheme.outlineVariant;
    String statusTitle = 'Ready to Analyze';
    String statusDesc = 'Press the start button to run tests';
    IconData centerIcon = Icons.sensors_rounded;
    Color centerIconColor = colorScheme.onSurfaceVariant;
    bool shouldRotate = false;

    if (controller.isRunning) {
      pulseColor = colorScheme.primary;
      statusTitle = 'Scanning Network';
      statusDesc = 'Testing DNS, sockets, routing, and reachability...';
      centerIcon = Icons.sync;
      centerIconColor = colorScheme.primary;
      shouldRotate = true;
    } else if (controller.isCompleted) {
      if (controller.overallInternetAccess) {
        if (controller.dnsSuccess &&
            controller.ipv4Success &&
            controller.ipv6Success &&
            controller.httpsSuccess &&
            controller.dnsAnalysisSuccess &&
            controller.tlsAnalysisSuccess &&
            controller.domesticIpSuccess &&
            controller.internationalIpSuccess &&
            controller.blockedWebsitesCount == 0 &&
            controller.blockedCdnsCount == 0) {
          pulseColor = colorScheme.success;
          statusTitle = 'Excellent Access';
          statusDesc = 'Unrestricted IPv4 & IPv6 internet connection';
          centerIcon = Icons.verified_rounded;
          centerIconColor = colorScheme.success;
        } else {
          pulseColor = colorScheme.warning;
          statusTitle = 'Partial Internet';
          statusDesc = 'Unrestricted access, but some protocols/sites failed';
          centerIcon = Icons.warning_amber_rounded;
          centerIconColor = colorScheme.warning;
        }
      } else {
        pulseColor = colorScheme.error;
        statusTitle = 'Offline / Blocked';
        statusDesc = 'No active route to the internet detected';
        centerIcon = Icons.gpp_bad_rounded;
        centerIconColor = colorScheme.error;
      }
    }

    return Center(
      child: Column(
        children: [
          // Dynamic Glowing Circular Radar
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Glowing Aura
                (() {
                  final container = Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pulseColor.withValues(alpha: 0.05),
                      border: Border.all(
                        color: pulseColor.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                  );

                  if (controller.isRunning) {
                    return container
                        .animate(onPlay: (c) => c.repeat())
                        .custom(
                          duration: 1.5.seconds,
                          builder: (context, value, child) => Container(
                            width: 170 + (value * 20),
                            height: 170 + (value * 20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: pulseColor.withValues(
                                  alpha: 0.2 * (1 - value),
                                ),
                                width: 2,
                              ),
                            ),
                          ),
                        )
                        .scale(duration: 1.5.seconds, curve: Curves.easeOut);
                  }

                  return container;
                })(),

                // Middle Ring
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pulseColor.withValues(alpha: 0.08),
                    border: Border.all(
                      color: pulseColor.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                ),

                // Rotating Scanner Ring (Only when running)
                if (shouldRotate)
                  Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              colorScheme.primary.withValues(alpha: 0),
                              colorScheme.primary.withValues(alpha: 0.6),
                            ],
                            stops: const [0.7, 1.0],
                          ),
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat())
                      .rotate(duration: 1.5.seconds),

                // Central Dashboard Circle
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: pulseColor.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: (() {
                      final icon = Icon(
                        centerIcon,
                        size: 46,
                        color: centerIconColor,
                      );

                      if (shouldRotate) {
                        return icon
                            .animate(onPlay: (c) => c.repeat())
                            .custom(
                              duration: 1.5.seconds,
                              builder: (context, value, child) =>
                                  Transform.rotate(
                                    angle: value * 6.28,
                                    child: child,
                                  ),
                            );
                      }

                      return icon;
                    })(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Diagnostics Status Title
          Text(
            statusTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ).animate(key: ValueKey(statusTitle)).fadeIn(duration: 300.ms),

          const SizedBox(height: 6),

          // Subtext / Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              statusDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ).animate(key: ValueKey(statusDesc)).fadeIn(duration: 300.ms),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewBadges(
    BuildContext context,
    InternetDiagnosticsController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final hasIpv4 = controller.isCompleted ? controller.ipv4Success : false;
    final hasIpv6 = controller.isCompleted ? controller.ipv6Success : false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildBadgeCard(
              context,
              label: 'IPv4 Network',
              statusText: controller.isIdle
                  ? 'Ready to test'
                  : (controller.isRunning && controller.completedTestsCount < 2
                        ? 'Testing...'
                        : (hasIpv4 ? 'Available' : 'Unavailable')),
              isActive: hasIpv4 && !controller.isIdle,
              color: hasIpv4 ? colorScheme.success : colorScheme.error,
              icon: Icons.four_g_mobiledata,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildBadgeCard(
              context,
              label: 'IPv6 Network',
              statusText: controller.isIdle
                  ? 'Ready to test'
                  : (controller.isRunning && controller.completedTestsCount < 3
                        ? 'Testing...'
                        : (hasIpv6 ? 'Available' : 'Unavailable')),
              isActive: hasIpv6 && !controller.isIdle,
              color: hasIpv6 ? colorScheme.success : colorScheme.error,
              icon: Icons.six_ft_apart,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(
    BuildContext context, {
    required String label,
    required String statusText,
    required bool isActive,
    required Color color,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPending =
        statusText == 'Ready to test' || statusText == 'Testing...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? color.withValues(alpha: 0.3)
              : (isPending
                    ? colorScheme.outlineVariant
                    : colorScheme.error.withValues(alpha: 0.15)),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.1)
                  : (isPending
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.error.withValues(alpha: 0.05)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22,
              color: isActive
                  ? color
                  : (isPending
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.error.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? color
                        : (isPending
                              ? colorScheme.onSurface
                              : colorScheme.error.withValues(alpha: 0.8)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDnsAnalysisDashboard(
    BuildContext context,
    InternetDiagnosticsController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (controller.isIdle ||
        (controller.isRunning && controller.completedTestsCount < 4)) {
      return const SizedBox.shrink();
    }

    final summary = controller.dnsAnalysisSummary;
    final isScanning =
        controller.isRunning &&
        controller.completedTestsCount == 4 &&
        summary == null;
    final providerCount =
        InternetDiagnosticsService.dnsAnalysisProviders.length;
    final respondedCount = summary?.successfulProviders ?? 0;
    final tamperingScore = summary?.tamperingScore ?? 0;
    final consistencyPercent = summary != null
        ? (summary.consistencyScore * 100).round()
        : 0;

    Color scoreColor = colorScheme.primary;
    String statusText = 'ANALYZING...';
    if (summary != null) {
      if (summary.tamperingScore >= 70) {
        scoreColor = colorScheme.error;
        statusText = 'HIGH RISK';
      } else if (summary.tamperingScore >= 35) {
        scoreColor = colorScheme.warning;
        statusText = 'SUSPICIOUS';
      } else {
        scoreColor = colorScheme.success;
        statusText = 'CONSISTENT';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DNS PROVIDER ANALYSIS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isScanning
                              ? 'Comparing ISP and public resolvers...'
                              : '$respondedCount of $providerCount providers responded',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (summary != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatBubble(
                      context,
                      label: 'Latency',
                      value: summary.averageLatencyMs != null
                          ? '${summary.averageLatencyMs}ms'
                          : 'N/A',
                      color: colorScheme.primary,
                      bgColor: colorScheme.primaryContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Consistency',
                      value: '$consistencyPercent%',
                      color: consistencyPercent >= 80
                          ? colorScheme.success
                          : colorScheme.warning,
                      bgColor: consistencyPercent >= 80
                          ? colorScheme.successContainer
                          : colorScheme.warningContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Tampering',
                      value: '$tamperingScore/100',
                      color: scoreColor,
                      bgColor: scoreColor.withValues(alpha: 0.12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double maxWidth = constraints.maxWidth;
                    final int crossAxisCount = (maxWidth / 220).floor().clamp(2, 6);
                    final double itemWidth = (maxWidth - (crossAxisCount - 1) * 10) / crossAxisCount;
                    final double childAspectRatio = itemWidth / 85;

                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: summary.providerResults.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        return _DnsProviderAnalysisCard(
                          result: summary.providerResults[index],
                          index: index,
                        );
                      },
                    );
                  },
                ),
                if (summary.findings.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      summary.findings.take(5).join('\n'),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildIpRoutingAnalysis(
    BuildContext context,
    InternetDiagnosticsController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    // Only show if diagnostics started and reached the domestic IP fetch step.
    if (controller.isIdle ||
        (controller.isRunning && controller.completedTestsCount < 5)) {
      return const SizedBox.shrink();
    }

    final hasDomestic =
        controller.domesticIpSuccess && controller.domesticIpResult != null;
    final hasInternational =
        controller.internationalIpSuccess &&
        controller.internationalIpResult != null;

    String domesticIp = 'Resolving...';
    String domesticGeo = 'Checking geolocation...';
    String domesticIsp = 'Resolving ISP...';
    int? domesticLatency;

    if (hasDomestic) {
      domesticIp = controller.domesticIpResult!.message
          .replaceFirst('IP retrieved: ', '')
          .trim();
      final details = controller.domesticIpResult!.details ?? '';
      domesticGeo = _extractDetailField(details, 'Geo Location:');
      domesticIsp = _extractDetailField(details, 'ISP/Network:');
      domesticLatency = controller.domesticIpResult!.latencyMs;
    } else if (controller.completedTestsCount > 4) {
      domesticIp = 'Failed to retrieve';
      domesticGeo = 'Unreachable domestic CDN';
      domesticIsp = 'Domestic gateway blocked';
    }

    String internationalIp = 'Resolving...';
    String internationalGeo = 'Checking geolocation...';
    String internationalIsp = 'Resolving ISP...';
    int? internationalLatency;

    if (hasInternational) {
      internationalIp = controller.internationalIpResult!.message
          .replaceFirst('IP retrieved: ', '')
          .trim();
      final details = controller.internationalIpResult!.details ?? '';
      internationalGeo = _extractDetailField(details, 'Geo Location:');
      internationalIsp = _extractDetailField(details, 'ISP/Network:');
      internationalLatency = controller.internationalIpResult!.latencyMs;
    } else if (controller.completedTestsCount > 5) {
      internationalIp = 'Failed to retrieve';
      internationalGeo = 'Unreachable global API';
      internationalIsp = 'International gateway blocked';
    }

    // Determine status badge colors and visual descriptors
    String statusBadgeText = 'ANALYZING...';
    Color badgeColor = colorScheme.primary;
    Color badgeBg = colorScheme.primaryContainer;
    String statusTitle = 'Analyzing Gateway Routing';
    IconData statusIcon = Icons.sync_rounded;
    bool isPulsing = true;

    if (controller.isCompleted) {
      final analysis = controller.routingAnalysisResult;
      isPulsing = false;
      if (analysis != null) {
        if (analysis.success) {
          if (analysis.message.contains('Direct Routing')) {
            statusBadgeText = 'MATCH';
            badgeColor = colorScheme.success;
            badgeBg = colorScheme.successContainer;
            statusTitle = 'Consistent Direct Routing';
            statusIcon = Icons.verified_rounded;
          } else {
            statusBadgeText = 'SPLIT ROUTING';
            badgeColor = colorScheme.warning;
            badgeBg = colorScheme.warningContainer;
            statusTitle = 'Proxy/Split Tunnel Active';
            statusIcon = Icons.alt_route_rounded;
          }
        } else {
          statusBadgeText = 'BLOCKED';
          badgeColor = colorScheme.error;
          badgeBg = colorScheme.errorContainer;
          statusTitle = 'Gateway Failure / Offline';
          statusIcon = Icons.gpp_bad_rounded;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PUBLIC IP ROUTING ANALYSIS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),

                  // Glowing Badge
                  Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            if (isPulsing)
                              BoxShadow(
                                color: badgeColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: Text(
                          statusBadgeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      )
                      .animate(onPlay: isPulsing ? (c) => c.repeat() : null)
                      .scale(
                        duration: 1.seconds,
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1.05, 1.05),
                        curve: Curves.easeInOut,
                      ),
                ],
              ),

              const SizedBox(height: 16),

              // Gateways Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 400;
                  final content = [
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildGatewayInfoCard(
                        context,
                        title: 'Domestic Gateway (Iran)',
                        ip: domesticIp,
                        geo: domesticGeo,
                        isp: domesticIsp,
                        latencyMs: domesticLatency,
                        icon: Icons.business_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                    if (isWide)
                      const SizedBox(width: 12)
                    else
                      const SizedBox(height: 12),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildGatewayInfoCard(
                        context,
                        title: 'International Gateway (Global)',
                        ip: internationalIp,
                        geo: internationalGeo,
                        isp: internationalIsp,
                        latencyMs: internationalLatency,
                        icon: Icons.public_rounded,
                        color: colorScheme.tertiary,
                      ),
                    ),
                  ];

                  if (isWide) {
                    return Row(children: content);
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: content
                          .map((e) => e is Expanded ? e.child : e)
                          .toList(),
                    );
                  }
                },
              ),

              // Diagnostics Box
              if (controller.isCompleted &&
                  controller.routingAnalysisResult != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(statusIcon, color: badgeColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    controller.routingAnalysisResult!.details ?? '',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildGatewayInfoCard(
    BuildContext context, {
    required String title,
    required String ip,
    required String geo,
    required String isp,
    required int? latencyMs,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isResolving = ip == 'Resolving...';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (latencyMs != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${latencyMs}ms',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // IP Address Value
          Text(
            ip,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              fontFamily: ip != 'Failed to retrieve' && ip != 'Resolving...'
                  ? 'monospace'
                  : null,
              color: isResolving
                  ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                  : (ip == 'Failed to retrieve'
                        ? colorScheme.error
                        : colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 4),

          // Location Details
          Text(
            geo,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // ISP / ASN Details
          Text(
            isp,
            style: TextStyle(
              fontSize: 10.5,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTlsAnalysisDashboard(
    BuildContext context,
    InternetDiagnosticsController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (controller.isIdle ||
        (controller.isRunning && controller.completedTestsCount < 8)) {
      return const SizedBox.shrink();
    }

    final summary = controller.tlsAnalysisSummary;
    final isScanning = controller.isScanningTlsTargets;
    final totalCount = InternetDiagnosticsService.tlsAnalysisTargets.length;
    final scannedCount = summary?.results.length ?? 0;
    final tamperingScore = summary?.averageTamperingScore ?? 0;
    final scoreColor = tamperingScore >= 70
        ? colorScheme.error
        : (tamperingScore >= 35 ? colorScheme.warning : colorScheme.success);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TLS / HTTPS ANALYSIS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isScanning
                              ? 'Checking certificates and Cloudflare traces...'
                              : 'Scan complete: $scannedCount of $totalCount targets verified',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (summary != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tamperingScore >= 70
                            ? 'HIGH RISK'
                            : (tamperingScore >= 35 ? 'SUSPICIOUS' : 'CLEAN'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (summary != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatBubble(
                      context,
                      label: 'Handshake',
                      value:
                          '${summary.successfulHandshakes}/${summary.results.length}',
                      color: colorScheme.success,
                      bgColor: colorScheme.successContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Avg TLS',
                      value: summary.averageHandshakeLatencyMs != null
                          ? '${summary.averageHandshakeLatencyMs}ms'
                          : 'N/A',
                      color: colorScheme.primary,
                      bgColor: colorScheme.primaryContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Cert Mismatch',
                      value: '${summary.certificateMismatches}',
                      color: summary.certificateMismatches == 0
                          ? colorScheme.success
                          : colorScheme.error,
                      bgColor: summary.certificateMismatches == 0
                          ? colorScheme.successContainer
                          : colorScheme.errorContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Tampering',
                      value: '$tamperingScore/100',
                      color: scoreColor,
                      bgColor: scoreColor.withValues(alpha: 0.12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double maxWidth = constraints.maxWidth;
                    final int crossAxisCount = (maxWidth / 220).floor().clamp(2, 6);
                    final double itemWidth = (maxWidth - (crossAxisCount - 1) * 10) / crossAxisCount;
                    final double childAspectRatio = itemWidth / 85;

                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: summary.results.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        return _TlsAnalysisCard(
                          result: summary.results[index],
                          index: index,
                        );
                      },
                    );
                  },
                ),
                if (summary.findings.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      summary.findings.join('\n'),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildWebsiteReachabilityDashboard(
    BuildContext context,
    InternetDiagnosticsController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    // Display only when the website reachability step starts
    if (controller.isIdle ||
        (controller.isRunning && controller.completedTestsCount < 9)) {
      return const SizedBox.shrink();
    }

    final websitesCount = controller.websiteResults.length;
    final totalCount = InternetDiagnosticsController.targetWebsites.length;
    final isScanning = controller.isScanningWebsites;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Summary Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WEBSITE REACHABILITY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isScanning
                              ? 'Scanning: $websitesCount of $totalCount websites...'
                              : 'Scan complete: $websitesCount targets verified',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar during scan
              if (isScanning) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: websitesCount / totalCount,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Summary Stats Chips
              if (websitesCount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatBubble(
                      context,
                      label: 'Reachable',
                      value: '${controller.reachableWebsitesCount}',
                      color: colorScheme.success,
                      bgColor: colorScheme.successContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Blocked',
                      value: '${controller.blockedWebsitesCount}',
                      color: colorScheme.error,
                      bgColor: colorScheme.errorContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Failed/TLS',
                      value: '${controller.failedWebsitesCount}',
                      color: colorScheme.warning,
                      bgColor: colorScheme.warningContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Avg Latency',
                      value: '${controller.averageWebsiteLatencyMs}ms',
                      color: colorScheme.primary,
                      bgColor: colorScheme.primaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Staggered Grid of Website Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final double maxWidth = constraints.maxWidth;
                  final int crossAxisCount = (maxWidth / 220).floor().clamp(2, 6);
                  final double itemWidth = (maxWidth - (crossAxisCount - 1) * 10) / crossAxisCount;
                  final double childAspectRatio = itemWidth / 85;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: totalCount,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder: (context, index) {
                      final target =
                          InternetDiagnosticsController.targetWebsites[index];
                      final name = target['name']!;
                      final domain = target['domain']!;

                      // Check if we have results for this index
                      final hasResult =
                          index < controller.websiteResults.length;
                      final result = hasResult
                          ? controller.websiteResults[index]
                          : null;
                      final isCurrentlyScanning =
                          isScanning &&
                          index == controller.websiteResults.length;

                      return _WebsiteReachabilityCard(
                        name: name,
                        domain: domain,
                        result: result,
                        isScanning: isCurrentlyScanning,
                        index: index,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildCdnReachabilityDashboard(
    BuildContext context,
    InternetDiagnosticsController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    // Display only when the CDN reachability step starts
    if (controller.isIdle ||
        (controller.isRunning && controller.completedTestsCount < 10)) {
      return const SizedBox.shrink();
    }

    final cdnsCount = controller.cdnResults.length;
    final totalCount = InternetDiagnosticsController.targetCdns.length;
    final isScanning = controller.isScanningCdns;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Summary Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CDN REACHABILITY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isScanning
                              ? 'Scanning: $cdnsCount of $totalCount CDNs...'
                              : 'Scan complete: $cdnsCount targets verified',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar during scan
              if (isScanning) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: cdnsCount / totalCount,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Summary Stats Chips
              if (cdnsCount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatBubble(
                      context,
                      label: 'Reachable',
                      value: '${controller.reachableCdnsCount}',
                      color: colorScheme.success,
                      bgColor: colorScheme.successContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Blocked',
                      value: '${controller.blockedCdnsCount}',
                      color: colorScheme.error,
                      bgColor: colorScheme.errorContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Failed/TLS',
                      value: '${controller.failedCdnsCount}',
                      color: colorScheme.warning,
                      bgColor: colorScheme.warningContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Avg Latency',
                      value: '${controller.averageCdnLatencyMs}ms',
                      color: colorScheme.primary,
                      bgColor: colorScheme.primaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Staggered Grid of CDN Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final double maxWidth = constraints.maxWidth;
                  final int crossAxisCount = (maxWidth / 220).floor().clamp(2, 6);
                  final double itemWidth = (maxWidth - (crossAxisCount - 1) * 10) / crossAxisCount;
                  final double childAspectRatio = itemWidth / 85;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: totalCount,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder: (context, index) {
                      final target =
                          InternetDiagnosticsController.targetCdns[index];
                      final name = target['name']!;
                      final domain = target['domain']!;

                      final hasResult = index < controller.cdnResults.length;
                      final result =
                          hasResult ? controller.cdnResults[index] : null;
                      final isCurrentScanning =
                          index == controller.cdnResults.length;

                      return _CdnReachabilityCard(
                        name: name,
                        domain: domain,
                        result: result,
                        isScanning: isScanning && isCurrentScanning,
                        index: index,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildSocialMediaAccessibilityDashboard(
    BuildContext context,
    InternetDiagnosticsController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    // Display only when the social media accessibility step starts
    if (controller.isIdle ||
        (controller.isRunning && controller.completedTestsCount < 11)) {
      return const SizedBox.shrink();
    }

    final socialCount = controller.socialMediaResults.length;
    final totalCount = InternetDiagnosticsController.targetSocialMedia.length;
    final isScanning = controller.isScanningSocialMedia;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Summary Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SOCIAL MEDIA ACCESSIBILITY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isScanning
                              ? 'Scanning: $socialCount of $totalCount services...'
                              : 'Scan complete: $socialCount targets verified',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar during scan
              if (isScanning) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: socialCount / totalCount,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Summary Stats Chips
              if (socialCount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatBubble(
                      context,
                      label: 'Accessible',
                      value: '${controller.accessibleSocialCount}',
                      color: colorScheme.success,
                      bgColor: colorScheme.successContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Partial',
                      value: '${controller.partialSocialCount}',
                      color: colorScheme.warning,
                      bgColor: colorScheme.warningContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Blocked',
                      value: '${controller.blockedSocialCount}',
                      color: colorScheme.error,
                      bgColor: colorScheme.errorContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Avg Latency',
                      value: '${controller.averageSocialLatencyMs}ms',
                      color: colorScheme.primary,
                      bgColor: colorScheme.primaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Staggered Grid of Social Media Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final double maxWidth = constraints.maxWidth;
                  final int crossAxisCount = (maxWidth / 220).floor().clamp(2, 6);
                  final double itemWidth = (maxWidth - (crossAxisCount - 1) * 10) / crossAxisCount;
                  final double childAspectRatio = itemWidth / 85;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: totalCount,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder: (context, index) {
                      final target = InternetDiagnosticsController
                          .targetSocialMedia[index];
                      final name = target['name']!;
                      final primary = target['primary']!;
                      final secondary = target['secondary']!;

                      // Check if we have results for this index
                      final hasResult =
                          index < controller.socialMediaResults.length;
                      final result = hasResult
                          ? controller.socialMediaResults[index]
                          : null;
                      final isCurrentlyScanning =
                          isScanning &&
                          index == controller.socialMediaResults.length;

                      return _SocialMediaCard(
                        name: name,
                        primaryDomain: primary,
                        secondaryDomain: secondary,
                        result: result,
                        isScanning: isCurrentlyScanning,
                        index: index,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildStatBubble(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  String _extractDetailField(String details, String label) {
    try {
      final lines = details.split('\n');
      for (final line in lines) {
        if (line.startsWith(label)) {
          return line.substring(label.length).trim();
        }
      }
    } catch (_) {}
    return 'Resolving...';
  }

  Widget _buildProtocolAccessibilityDashboard(
    BuildContext context,
    InternetDiagnosticsController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (controller.isIdle ||
        (controller.isRunning && controller.completedTestsCount < 11)) {
      return const SizedBox.shrink();
    }

    final isScanning = controller.isScanningProtocols;
    final summaries = controller.protocolAccessibilitySummaries;
    final totalCount = 8;
    final scannedCount = summaries.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROTOCOL ACCESSIBILITY SCAN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isScanning
                              ? 'Checking ports and standard protocol capabilities...'
                              : 'Scan complete: $scannedCount of $totalCount protocols verified',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: controller.blockedProtocolsCount > 0
                            ? colorScheme.error.withValues(alpha: 0.12)
                            : colorScheme.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        controller.blockedProtocolsCount > 0 ? 'BLOCKED DETECTED' : 'SECURE / CLEAN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: controller.blockedProtocolsCount > 0 ? colorScheme.error : colorScheme.success,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (summaries.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatBubble(
                      context,
                      label: 'Supported',
                      value: '${controller.supportedProtocolsCount}/$totalCount',
                      color: colorScheme.success,
                      bgColor: colorScheme.successContainer,
                    ),
                    _buildStatBubble(
                      context,
                      label: 'Blocked',
                      value: '${controller.blockedProtocolsCount}',
                      color: controller.blockedProtocolsCount == 0
                          ? colorScheme.success
                          : colorScheme.error,
                      bgColor: controller.blockedProtocolsCount == 0
                          ? colorScheme.successContainer
                          : colorScheme.errorContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double maxWidth = constraints.maxWidth;
                    final int crossAxisCount = (maxWidth / 220).floor().clamp(2, 6);
                    final double itemWidth = (maxWidth - (crossAxisCount - 1) * 10) / crossAxisCount;
                    final double childAspectRatio = itemWidth / 85;

                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: summaries.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        final summary = summaries[index];
                        return _ProtocolSummaryGridCard(
                          summary: summary,
                          index: index,
                        );
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtocolSummaryGridCard extends StatelessWidget {
  final ProtocolAccessibilitySummary summary;
  final int index;

  const _ProtocolSummaryGridCard({
    required this.summary,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color badgeBgColor = colorScheme.surfaceContainerHighest;
    Color badgeTextColor = colorScheme.onSurfaceVariant;
    Color cardBorderColor = colorScheme.outlineVariant.withValues(alpha: 0.15);
    IconData leadingIcon = Icons.help_outline_rounded;
    Color leadingIconColor = colorScheme.onSurfaceVariant;

    if (summary.isSupported) {
      badgeBgColor = colorScheme.successContainer;
      badgeTextColor = colorScheme.success;
      cardBorderColor = colorScheme.success.withValues(alpha: 0.15);
      leadingIcon = Icons.check_circle_rounded;
      leadingIconColor = colorScheme.success;
    } else if (summary.isBlocked) {
      badgeBgColor = colorScheme.errorContainer;
      badgeTextColor = colorScheme.error;
      cardBorderColor = colorScheme.error.withValues(alpha: 0.15);
      leadingIcon = Icons.lock_rounded;
      leadingIconColor = colorScheme.error;
    } else {
      badgeBgColor = colorScheme.warningContainer;
      badgeTextColor = colorScheme.warning;
      cardBorderColor = colorScheme.warning.withValues(alpha: 0.15);
      leadingIcon = Icons.warning_amber_rounded;
      leadingIconColor = colorScheme.warning;
    }

    // Determine custom icon based on protocol name
    switch (summary.protocolName) {
      case 'TCP HTTP':
        leadingIcon = Icons.http_rounded;
        break;
      case 'TCP HTTPS':
        leadingIcon = Icons.lock_outline_rounded;
        break;
      case 'UDP Connectivity':
        leadingIcon = Icons.compare_arrows_rounded;
        break;
      case 'HTTP/3 (QUIC)':
        leadingIcon = Icons.bolt_rounded;
        break;
      case 'WebSockets':
        leadingIcon = Icons.swap_calls_rounded;
        break;
      case 'DNS-over-HTTPS':
        leadingIcon = Icons.security_rounded;
        break;
      case 'DNS-over-TLS':
        leadingIcon = Icons.enhanced_encryption_rounded;
        break;
      case 'ICMP Ping':
        leadingIcon = Icons.network_ping_rounded;
        break;
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cardBorderColor, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showProtocolDetailsSheet(context, summary),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: leadingIconColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      leadingIcon,
                      size: 16,
                      color: leadingIconColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary.protocolName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      summary.isSupported
                          ? 'SUPPORTED'
                          : (summary.isBlocked ? 'BLOCKED' : 'FAILED'),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                  if (summary.isSupported && summary.averageLatencyMs > 0)
                    Text(
                      '${summary.averageLatencyMs}ms',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProtocolDetailsSheet(BuildContext context, ProtocolAccessibilitySummary summary) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    summary.protocolName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: summary.isSupported
                          ? colorScheme.successContainer
                          : (summary.isBlocked
                              ? colorScheme.errorContainer
                              : colorScheme.warningContainer),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      summary.isSupported
                          ? 'SUPPORTED'
                          : (summary.isBlocked ? 'BLOCKED' : 'FAILED'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: summary.isSupported
                            ? colorScheme.success
                            : (summary.isBlocked ? colorScheme.error : colorScheme.warning),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                summary.description,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Target Domains Checklist:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: summary.results.length,
                  itemBuilder: (context, idx) {
                    final result = summary.results[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: result.success 
                              ? colorScheme.success.withValues(alpha: 0.1)
                              : colorScheme.error.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                result.success ? Icons.check_rounded : Icons.close_rounded,
                                size: 16,
                                color: result.success ? colorScheme.success : colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  result.domain,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (result.success && result.latencyMs != null)
                                Text(
                                  '${result.latencyMs}ms',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          if (result.errorMessage != null || result.details != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                result.errorMessage ?? result.details ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: result.success 
                                      ? colorScheme.onSurfaceVariant
                                      : colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DnsProviderAnalysisCard extends StatelessWidget {
  final DnsProviderAnalysisResult result;
  final int index;

  const _DnsProviderAnalysisCard({required this.result, required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final suspiciousCount = result.queryResults
        .where((query) => query.suspiciousReasons.isNotEmpty)
        .length;
    final hasErrors = result.queryResults.any((query) => !query.success);
    final isClean = suspiciousCount == 0 && result.successRate >= 0.8;

    final statusColor = isClean
        ? colorScheme.success
        : (suspiciousCount > 0 ? colorScheme.error : colorScheme.warning);
    final statusText = isClean
        ? 'CLEAN'
        : (suspiciousCount > 0 ? 'TAMPER?' : (hasErrors ? 'PARTIAL' : 'MIXED'));

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withValues(alpha: 0.18), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDnsProviderSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      result.provider.usesSystemResolver
                          ? Icons.router_rounded
                          : Icons.dns_rounded,
                      size: 16,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.provider.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          result.provider.address,
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  Text(
                    result.averageLatencyMs != null
                        ? '${result.averageLatencyMs}ms'
                        : '${(result.successRate * 100).round()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(duration: 200.ms, delay: (20 * index).ms);
  }

  void _showDnsProviderSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = result.queryResults
        .map((query) {
          final answer = query.isNxDomain
              ? 'NXDOMAIN'
              : (query.ipAddresses.isEmpty
                    ? 'No answer'
                    : query.ipAddresses.join(', '));
          final issue = query.suspiciousReasons.isNotEmpty
              ? '\nIssues: ${query.suspiciousReasons.join(' ')}'
              : '';
          final error = query.error != null ? '\nError: ${query.error}' : '';
          return '${query.domain}: $answer (${query.latencyMs ?? 0}ms)$issue$error';
        })
        .join('\n\n');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(
                          Icons.dns_rounded,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.provider.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                result.provider.address,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSheetMetric(
                            context,
                            label: 'Success',
                            value: '${(result.successRate * 100).round()}%',
                            icon: Icons.check_circle_outline_rounded,
                            color: colorScheme.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSheetMetric(
                            context,
                            label: 'Latency',
                            value: result.averageLatencyMs != null
                                ? '${result.averageLatencyMs}ms'
                                : 'N/A',
                            icon: Icons.timer_outlined,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'DNS QUERY LOGS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        details,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.45,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSheetMetric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TlsAnalysisCard extends StatelessWidget {
  final TlsAnalysisResult result;
  final int index;

  const _TlsAnalysisCard({required this.result, required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isClean =
        result.handshakeSuccess &&
        result.certificateValid &&
        !result.certificateMismatch &&
        result.tamperingScore < 35;
    final statusColor = isClean
        ? colorScheme.success
        : (result.tamperingScore >= 70
              ? colorScheme.error
              : colorScheme.warning);
    final statusText = isClean
        ? 'VALID'
        : (result.handshakeSuccess ? 'CHECK' : 'FAILED');

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withValues(alpha: 0.18), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showTlsInfoSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      result.target.shouldTraceCloudflare
                          ? Icons.cloud_queue_rounded
                          : Icons.https_rounded,
                      size: 16,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.target.domain,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          result.target.expectedIp,
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  Text(
                    result.handshakeLatencyMs != null
                        ? '${result.handshakeLatencyMs}ms'
                        : '${result.tamperingScore}/100',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(duration: 200.ms, delay: (12 * index).ms);
  }

  void _showTlsInfoSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trace = result.traceResult;
    final traceText = trace == null
        ? 'Cloudflare trace: not required'
        : [
            'Cloudflare trace: ${trace.traceAvailable ? 'available' : 'unavailable'}',
            'Trace IP: ${trace.traceIp ?? 'N/A'}',
            'Detected public IP: ${trace.expectedPublicIp ?? 'N/A'}',
            'Trace match: ${trace.traceMatchesPublicIp ?? 'N/A'}',
            'Colo: ${trace.colo ?? 'N/A'}',
            'Trace TLS: ${trace.tlsProtocol ?? 'N/A'}',
            if (trace.error != null) 'Trace error: ${trace.error}',
          ].join('\n');
    final details = [
      'Domain: ${result.target.domain}',
      'Expected IP: ${result.target.expectedIp}',
      'Resolved IPs: ${result.resolvedIps.isEmpty ? 'N/A' : result.resolvedIps.join(', ')}',
      'Handshake: ${result.handshakeSuccess ? 'success' : 'failed'}',
      'Handshake latency: ${result.handshakeLatencyMs ?? 0}ms',
      'TLS version: ${result.tlsVersion}',
      'Certificate valid: ${result.certificateValid}',
      'Certificate mismatch: ${result.certificateMismatch}',
      'Certificate subject: ${result.certificateSubject ?? 'N/A'}',
      'Certificate issuer: ${result.certificateIssuer ?? 'N/A'}',
      'Valid from: ${result.certificateStart ?? 'N/A'}',
      'Valid until: ${result.certificateEnd ?? 'N/A'}',
      traceText,
      'Tampering score: ${result.tamperingScore}/100',
      if (result.findings.isNotEmpty) 'Findings: ${result.findings.join(' ')}',
      if (result.error != null) 'Error: ${result.error}',
    ].join('\n');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(
                          Icons.https_rounded,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.target.domain,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                result.target.expectedIp,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSheetMetric(
                            context,
                            label: 'Handshake',
                            value: result.handshakeSuccess ? 'OK' : 'FAIL',
                            icon: Icons.security_rounded,
                            color: result.handshakeSuccess
                                ? colorScheme.success
                                : colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSheetMetric(
                            context,
                            label: 'Tampering',
                            value: '${result.tamperingScore}/100',
                            icon: Icons.gpp_maybe_rounded,
                            color: result.tamperingScore >= 70
                                ? colorScheme.error
                                : (result.tamperingScore >= 35
                                      ? colorScheme.warning
                                      : colorScheme.success),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'TLS DIAGNOSTIC LOGS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        details,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.45,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSheetMetric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebsiteReachabilityCard extends StatelessWidget {
  final String name;
  final String domain;
  final WebsiteReachabilityResult? result;
  final bool isScanning;
  final int index;

  const _WebsiteReachabilityCard({
    required this.name,
    required this.domain,
    this.result,
    required this.isScanning,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color cardBorderColor = colorScheme.outlineVariant.withValues(alpha: 0.3);
    Color statusBgColor = colorScheme.surfaceContainerHighest;
    Color statusTextColor = colorScheme.onSurfaceVariant;
    String statusText = 'PENDING';
    bool showLatency = false;

    if (isScanning) {
      statusText = 'SCANNING';
      statusBgColor = colorScheme.primaryContainer;
      statusTextColor = colorScheme.primary;
    } else if (result != null) {
      showLatency =
          result!.status == ReachabilityStatus.reachable &&
          result!.latencyMs != null;
      switch (result!.status) {
        case ReachabilityStatus.reachable:
          statusText = 'REACHABLE';
          statusBgColor = colorScheme.successContainer;
          statusTextColor = colorScheme.success;
          cardBorderColor = colorScheme.success.withValues(alpha: 0.15);
          break;
        case ReachabilityStatus.blocked:
          statusText = 'BLOCKED';
          statusBgColor = colorScheme.errorContainer;
          statusTextColor = colorScheme.error;
          cardBorderColor = colorScheme.error.withValues(alpha: 0.15);
          break;
        case ReachabilityStatus.timeout:
          statusText = 'TIMEOUT';
          statusBgColor = colorScheme.warningContainer;
          statusTextColor = colorScheme.warning;
          cardBorderColor = colorScheme.warning.withValues(alpha: 0.15);
          break;
        case ReachabilityStatus.dnsFailure:
          statusText = 'DNS FAIL';
          statusBgColor = Colors.purple.shade100;
          statusTextColor = Colors.purple.shade800;
          break;
        case ReachabilityStatus.tlsFailure:
          statusText = 'TLS FAIL';
          statusBgColor = Colors.cyan.shade100;
          statusTextColor = Colors.cyan.shade800;
          cardBorderColor = Colors.cyan.withValues(alpha: 0.25);
          break;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cardBorderColor, width: 1),
      ),
      child: InkWell(
        onTap: result != null ? () => _showWebsiteInfoSheet(context) : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo and Name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getBrandColor(name).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getWebsiteIcon(name),
                      size: 16,
                      color: _getBrandColor(name),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          domain.replaceFirst('www.', ''),
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Status & Latency Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isScanning) ...[
                          const SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: statusTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Latency Pill
                  if (showLatency)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getBrandColor(name).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${result!.latencyMs}ms',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(duration: 200.ms, delay: (20 * index).ms);
  }

  void _showWebsiteInfoSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (result == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getBrandColor(name).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getWebsiteIcon(name),
                            size: 28,
                            color: _getBrandColor(name),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                domain,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            context,
                            label: 'Reachability',
                            value: result!.status.name.toUpperCase(),
                            icon: Icons.alt_route_rounded,
                            color:
                                result!.status == ReachabilityStatus.reachable
                                ? colorScheme.success
                                : colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoItem(
                            context,
                            label: 'Latency',
                            value: result!.latencyMs != null
                                ? '${result!.latencyMs}ms'
                                : 'N/A',
                            icon: Icons.timer_outlined,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Technical Details Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TECHNICAL LOGS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          tooltip: 'Copy details to clipboard',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: result?.errorDetails ?? ''),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Reachability details copied to clipboard',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        result?.errorDetails ??
                            'No further diagnostic data retrieved.',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.45,
                          color: result!.status == ReachabilityStatus.reachable
                              ? colorScheme.onSurface
                              : colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getWebsiteIcon(String name) {
    switch (name) {
      case 'Google':
        return Icons.language_rounded;
      case 'YouTube':
        return Icons.play_circle_fill_rounded;
      case 'GitHub':
        return Icons.code_rounded;
      case 'Wikipedia':
        return Icons.menu_book_rounded;
      case 'Reddit':
        return Icons.forum_rounded;
      case 'Stack Overflow':
        return Icons.layers_rounded;
      case 'ChatGPT':
        return Icons.chat_bubble_outline_rounded;
      case 'Claude':
        return Icons.psychology_rounded;
      case 'Gemini':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.public_rounded;
    }
  }

  Color _getBrandColor(String name) {
    switch (name) {
      case 'Google':
        return Colors.blue;
      case 'YouTube':
        return Colors.red;
      case 'GitHub':
        return Colors.blueGrey.shade800;
      case 'Wikipedia':
        return Colors.grey.shade700;
      case 'Reddit':
        return Colors.orange.shade800;
      case 'Stack Overflow':
        return Colors.orange.shade700;
      case 'ChatGPT':
        return Colors.teal;
      case 'Claude':
        return Colors.deepOrange.shade300;
      case 'Gemini':
        return Colors.indigo.shade400;
      default:
        return Colors.blue;
    }
  }
}

class _DiagnosticCheckCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData iconData;
  final Widget? customIcon;
  final bool isPending;
  final bool isRunning;
  final bool isSuccess;
  final DiagnosticTestResult? result;

  const _DiagnosticCheckCard({
    required this.title,
    required this.description,
    required this.iconData,
    this.customIcon,
    required this.isPending,
    required this.isRunning,
    required this.isSuccess,
    this.result,
  });

  @override
  State<_DiagnosticCheckCard> createState() => _DiagnosticCheckCardState();
}

class _DiagnosticCheckCardState extends State<_DiagnosticCheckCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget statusWidget = const SizedBox.shrink();

    if (widget.isPending) {
      statusWidget = Icon(
        Icons.radio_button_off_rounded,
        size: 20,
        color: colorScheme.outline.withValues(alpha: 0.4),
      );
    } else if (widget.isRunning) {
      statusWidget = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (widget.isSuccess) {
      statusWidget = Icon(
        Icons.check_circle_rounded,
        size: 22,
        color: colorScheme.success,
      );
    } else {
      statusWidget = Icon(
        Icons.cancel_rounded,
        size: 22,
        color: colorScheme.error,
      );
    }

    final isExpanded = _isExpanded && widget.result != null;

    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: widget.result != null
                ? () => setState(() => _isExpanded = !_isExpanded)
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Status Icon
                  statusWidget,

                  const SizedBox(width: 14),

                  // Text and Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: widget.isPending
                                ? colorScheme.onSurface.withValues(alpha: 0.6)
                                : colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Latency Badge
                  if (widget.result != null && widget.result!.latencyMs != null)
                    _buildLatencyBadge(
                      context,
                      widget.result!.latencyMs!,
                      widget.isSuccess,
                    ),

                  if (widget.result != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Technical Details Expanded Section
          if (isExpanded) ...[
            const Divider(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TECHNICAL LOGS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        tooltip: 'Copy details to clipboard',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.result?.details ?? ''),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Technical logs copied to clipboard',
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      widget.result?.details ?? 'No diagnostic logs recorded.',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: widget.isSuccess
                            ? colorScheme.onSurface
                            : colorScheme.error,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLatencyBadge(
    BuildContext context,
    int latencyMs,
    bool isSuccess,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    Color badgeBg = colorScheme.surfaceContainerHighest;
    Color badgeFg = colorScheme.onSurfaceVariant;

    if (isSuccess) {
      if (latencyMs < 100) {
        badgeBg = colorScheme.successContainer;
        badgeFg = colorScheme.success;
      } else if (latencyMs < 300) {
        badgeBg = colorScheme.primaryContainer;
        badgeFg = colorScheme.primary;
      } else {
        badgeBg = colorScheme.warningContainer;
        badgeFg = colorScheme.warning;
      }
    } else {
      badgeBg = colorScheme.errorContainer;
      badgeFg = colorScheme.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${latencyMs}ms',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: badgeFg,
        ),
      ),
    );
  }
}

class _SocialMediaCard extends StatelessWidget {
  final String name;
  final String primaryDomain;
  final String secondaryDomain;
  final SocialMediaResult? result;
  final bool isScanning;
  final int index;

  const _SocialMediaCard({
    required this.name,
    required this.primaryDomain,
    required this.secondaryDomain,
    this.result,
    required this.isScanning,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color cardBorderColor = colorScheme.outlineVariant.withValues(alpha: 0.3);
    Color statusBgColor = colorScheme.surfaceContainerHighest;
    Color statusTextColor = colorScheme.onSurfaceVariant;
    String statusText = 'PENDING';
    bool showLatency = false;

    if (isScanning) {
      statusText = 'SCANNING';
      statusBgColor = colorScheme.primaryContainer;
      statusTextColor = colorScheme.primary;
    } else if (result != null) {
      showLatency =
          result!.status != SocialMediaStatus.blocked &&
          result!.latencyMs != null;
      switch (result!.status) {
        case SocialMediaStatus.accessible:
          statusText = 'ACCESSIBLE';
          statusBgColor = colorScheme.successContainer;
          statusTextColor = colorScheme.success;
          cardBorderColor = colorScheme.success.withValues(alpha: 0.15);
          break;
        case SocialMediaStatus.partial:
          statusText = 'PARTIALLY';
          statusBgColor = colorScheme.warningContainer;
          statusTextColor = colorScheme.warning;
          cardBorderColor = colorScheme.warning.withValues(alpha: 0.25);
          break;
        case SocialMediaStatus.blocked:
          statusText = 'BLOCKED';
          statusBgColor = colorScheme.errorContainer;
          statusTextColor = colorScheme.error;
          cardBorderColor = colorScheme.error.withValues(alpha: 0.15);
          break;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cardBorderColor, width: 1),
      ),
      child: InkWell(
        onTap: result != null ? () => _showSocialMediaInfoSheet(context) : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo and Name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getBrandColor(name).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getWebsiteIcon(name),
                      size: 16,
                      color: _getBrandColor(name),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          primaryDomain,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Status & Latency Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: statusTextColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (showLatency)
                    Row(
                      children: [
                        Icon(
                          Icons.flash_on_rounded,
                          size: 10,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 1),
                        Text(
                          '${result!.latencyMs}ms',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.9,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSocialMediaInfoSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (result == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getBrandColor(name).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getWebsiteIcon(name),
                            size: 28,
                            color: _getBrandColor(name),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Primary: $primaryDomain  |  Secondary: $secondaryDomain',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            context,
                            label: 'Overall Status',
                            value: result!.status.name.toUpperCase(),
                            icon: Icons.shield_rounded,
                            color:
                                result!.status == SocialMediaStatus.accessible
                                ? colorScheme.success
                                : (result!.status == SocialMediaStatus.partial
                                      ? colorScheme.warning
                                      : colorScheme.error),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoItem(
                            context,
                            label: 'Avg Latency',
                            value: result!.latencyMs != null
                                ? '${result!.latencyMs}ms'
                                : 'N/A',
                            icon: Icons.timer_outlined,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'DUAL-ENDPOINT CONNECTIONS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Primary Endpoint Card
                    _buildEndpointDiagnosticCard(
                      context,
                      title: 'Primary Web Endpoint',
                      result: result!.primaryResult,
                    ),
                    const SizedBox(height: 16),

                    // Secondary Endpoint Card
                    _buildEndpointDiagnosticCard(
                      context,
                      title: 'Secondary API/CDN/Gateway',
                      result: result!.secondaryResult,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndpointDiagnosticCard(
    BuildContext context, {
    required String title,
    required WebsiteReachabilityResult result,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReachable = result.status == ReachabilityStatus.reachable;

    Color statusColor = colorScheme.error;
    IconData statusIcon = Icons.cancel_rounded;
    if (isReachable) {
      statusColor = colorScheme.success;
      statusIcon = Icons.check_circle_rounded;
    } else if (result.status == ReachabilityStatus.timeout) {
      statusColor = colorScheme.warning;
      statusIcon = Icons.hourglass_top_rounded;
    } else if (result.status == ReachabilityStatus.tlsFailure) {
      statusColor = Colors.cyan.shade600;
      statusIcon = Icons.lock_open_rounded;
    } else if (result.status == ReachabilityStatus.dnsFailure) {
      statusColor = Colors.purple.shade600;
      statusIcon = Icons.dns_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      result.status.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Target Host: ${result.domain}',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          if (result.latencyMs != null) ...[
            const SizedBox(height: 4),
            Text(
              'Latency: ${result.latencyMs}ms',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result.errorDetails ?? 'No logs recorded.',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helpers to fetch brand colors and icons
  Color _getBrandColor(String name) {
    switch (name) {
      case 'Telegram':
        return Colors.blue;
      case 'WhatsApp':
        return Colors.green.shade600;
      case 'Discord':
        return const Color(0xFF5865F2);
      case 'Instagram':
        return Colors.pink.shade600;
      case 'X (Twitter)':
        return Colors.grey.shade900;
      case 'Facebook':
        return const Color(0xFF1877F2);
      case 'TikTok':
        return Colors.blueGrey.shade900;
      case 'Snapchat':
        return Colors.amber.shade700;
      case 'Signal':
        return Colors.blueAccent.shade700;
      default:
        return Colors.blue;
    }
  }

  IconData _getWebsiteIcon(String name) {
    switch (name) {
      case 'Telegram':
        return Icons.send_rounded;
      case 'WhatsApp':
        return Icons.chat_rounded;
      case 'Discord':
        return Icons.sports_esports_rounded;
      case 'Instagram':
        return Icons.photo_camera_rounded;
      case 'X (Twitter)':
        return Icons.close_rounded;
      case 'Facebook':
        return Icons.thumb_up_rounded;
      case 'TikTok':
        return Icons.music_note_rounded;
      case 'Snapchat':
        return Icons.face_rounded;
      case 'Signal':
        return Icons.lock_rounded;
      default:
        return Icons.public_rounded;
    }
  }
}

class _CdnReachabilityCard extends StatelessWidget {
  final String name;
  final String domain;
  final WebsiteReachabilityResult? result;
  final bool isScanning;
  final int index;

  const _CdnReachabilityCard({
    required this.name,
    required this.domain,
    this.result,
    required this.isScanning,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color cardBorderColor = colorScheme.outlineVariant.withValues(alpha: 0.3);
    Color statusBgColor = colorScheme.surfaceContainerHighest;
    Color statusTextColor = colorScheme.onSurfaceVariant;
    String statusText = 'PENDING';
    bool showLatency = false;

    if (isScanning) {
      statusText = 'SCANNING';
      statusBgColor = colorScheme.primaryContainer;
      statusTextColor = colorScheme.primary;
    } else if (result != null) {
      showLatency =
          result!.status == ReachabilityStatus.reachable &&
          result!.latencyMs != null;
      switch (result!.status) {
        case ReachabilityStatus.reachable:
          statusText = 'REACHABLE';
          statusBgColor = colorScheme.successContainer;
          statusTextColor = colorScheme.success;
          cardBorderColor = colorScheme.success.withValues(alpha: 0.15);
          break;
        case ReachabilityStatus.blocked:
          statusText = 'BLOCKED';
          statusBgColor = colorScheme.errorContainer;
          statusTextColor = colorScheme.error;
          cardBorderColor = colorScheme.error.withValues(alpha: 0.15);
          break;
        case ReachabilityStatus.timeout:
          statusText = 'TIMEOUT';
          statusBgColor = colorScheme.warningContainer;
          statusTextColor = colorScheme.warning;
          cardBorderColor = colorScheme.warning.withValues(alpha: 0.15);
          break;
        case ReachabilityStatus.dnsFailure:
          statusText = 'DNS FAIL';
          statusBgColor = Colors.purple.shade100;
          statusTextColor = Colors.purple.shade800;
          break;
        case ReachabilityStatus.tlsFailure:
          statusText = 'TLS FAIL';
          statusBgColor = Colors.cyan.shade100;
          statusTextColor = Colors.cyan.shade800;
          cardBorderColor = Colors.cyan.withValues(alpha: 0.25);
          break;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cardBorderColor, width: 1),
      ),
      child: InkWell(
        onTap: result != null ? () => _showCdnInfoSheet(context) : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo and Name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getBrandColor(name).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCdnIcon(name),
                      size: 16,
                      color: _getBrandColor(name),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          domain.replaceFirst('www.', ''),
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Status & Latency Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isScanning) ...[
                          const SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: statusTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Latency Label
                  if (showLatency)
                    Text(
                      '${result!.latencyMs}ms',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCdnInfoSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (result == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getBrandColor(name).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getCdnIcon(name),
                            size: 28,
                            color: _getBrandColor(name),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                domain,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            context,
                            label: 'Reachability',
                            value: result!.status.name.toUpperCase(),
                            icon: Icons.alt_route_rounded,
                            color:
                                result!.status == ReachabilityStatus.reachable
                                    ? colorScheme.success
                                    : colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoItem(
                            context,
                            label: 'Latency',
                            value: result!.latencyMs != null
                                ? '${result!.latencyMs}ms'
                                : 'N/A',
                            icon: Icons.timer_outlined,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Technical Details Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TECHNICAL LOGS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          tooltip: 'Copy details to clipboard',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: result?.errorDetails ?? ''),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Reachability details copied to clipboard',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        result?.errorDetails ??
                            'No further diagnostic data retrieved.',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.45,
                          color: result!.status == ReachabilityStatus.reachable
                              ? colorScheme.onSurface
                              : colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helpers to fetch brand colors and icons
  Color _getBrandColor(String name) {
    switch (name) {
      case 'Cloudflare':
        return const Color(0xFFF38020);
      case 'Akamai':
        return const Color(0xFF002E5D);
      case 'Fastly':
        return const Color(0xFFFF2828);
      case 'AWS CloudFront':
        return const Color(0xFFFF9900);
      case 'Azure CDN':
        return const Color(0xFF0078D4);
      case 'Google CDN':
        return const Color(0xFF4285F4);
      default:
        return Colors.blue;
    }
  }

  IconData _getCdnIcon(String name) {
    switch (name) {
      case 'Cloudflare':
        return Icons.cloud_queue_rounded;
      case 'Akamai':
        return Icons.dns_rounded;
      case 'Fastly':
        return Icons.bolt_rounded;
      case 'AWS CloudFront':
        return Icons.alt_route_rounded;
      case 'Azure CDN':
        return Icons.cloud_sync_rounded;
      case 'Google CDN':
        return Icons.lan_rounded;
      default:
        return Icons.cloud_rounded;
    }
  }
}

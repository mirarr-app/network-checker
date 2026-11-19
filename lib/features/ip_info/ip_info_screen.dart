import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/services/internet_diagnostics_service.dart';
import '../../core/services/ip_info_service.dart';
import '../../core/theme/app_theme.dart';
import 'data/ip_info_targets.dart';
import 'ip_info_controller.dart';

class IpInfoScreen extends StatelessWidget {
  const IpInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IP info'),
        actions: [
          Consumer<IpInfoController>(
            builder: (context, controller, _) {
              if (controller.isCompleted) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset',
                  onPressed: controller.resetSuite,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<IpInfoController>(
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

                    // 1. Status header with the current public IP
                    _buildStatusHeader(context, controller),

                    const SizedBox(height: 16),

                    // 2. IP lookup details
                    _buildIpLookupCard(context, controller),

                    const SizedBox(height: 16),

                    // 3. IP purity score
                    _buildPurityCard(context, controller),

                    const SizedBox(height: 16),

                    // 4. Split-routing test
                    _buildSplitRoutingCard(context, controller),

                    const SizedBox(height: 16),

                    // 5. Connectivity latency
                    _buildLatencyCard(context, controller),

                    const SizedBox(height: 16),

                    // 6. Environment checks
                    _buildEnvironmentCard(context, controller),

                    if (controller.isCompleted) ...[
                      const SizedBox(height: 24),
                      _buildCopyReportCard(context, controller),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: Consumer<IpInfoController>(
        builder: (context, controller, _) {
          final isRunning = controller.isRunning;
          return FloatingActionButton.extended(
            heroTag: 'run_ip_info',
            onPressed: isRunning ? null : controller.runIpInfoSuite,
            icon: Icon(
              isRunning ? Icons.hourglass_empty : Icons.public_rounded,
            ),
            label: Text(isRunning ? 'Checking...' : 'Check my IP'),
          ).animate().fadeIn(delay: 200.ms).scale(delay: 200.ms);
        },
      ),
    );
  }

  // ── Status header ──────────────────────────────────────────────────────

  Widget _buildStatusHeader(
    BuildContext context,
    IpInfoController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    Color pulseColor = colorScheme.outlineVariant;
    String statusTitle = 'Ready to Check';
    String statusDesc = 'Press the button below to inspect your IP';
    IconData centerIcon = Icons.public_rounded;

    if (controller.isRunning) {
      pulseColor = colorScheme.primary;
      statusTitle = 'Checking your IP';
      statusDesc =
          'Looking up your address, purity, split routing and environment...';
      centerIcon = Icons.sync;
    } else if (controller.isCompleted) {
      final purity = controller.purity;
      final verdict = purity?.verdict ?? '';
      final isBogon = verdict.toLowerCase().contains('bogon') ||
          verdict.toLowerCase().contains('private') ||
          verdict.toLowerCase().contains('reserved');
      final isUnverified = verdict.toLowerCase().contains('unverified');

      if (isBogon) {
        pulseColor = colorScheme.outline;
        statusTitle = 'Private / Bogon IP';
        statusDesc = 'Private or reserved IP address (not publicly routable)';
        centerIcon = Icons.lan_rounded;
      } else if (isUnverified) {
        pulseColor = colorScheme.outlineVariant;
        statusTitle = 'Unverified IP';
        statusDesc = 'Purity signals could not be verified';
        centerIcon = Icons.help_outline_rounded;
      } else if (purity != null && purity.score >= 80) {
        pulseColor = colorScheme.success;
        statusTitle = 'Clean IP';
        statusDesc = 'Purity score ${purity.score}/100';
        centerIcon = Icons.verified_rounded;
      } else if (purity != null && purity.score >= 50) {
        pulseColor = colorScheme.warning;
        statusTitle = 'Suspicious IP';
        statusDesc = 'Purity score ${purity.score}/100';
        centerIcon = Icons.warning_amber_rounded;
      } else if (purity != null) {
        pulseColor = colorScheme.error;
        statusTitle = 'Flagged IP';
        statusDesc = 'Purity score ${purity.score}/100';
        centerIcon = Icons.gpp_bad_rounded;
      } else {
        pulseColor = colorScheme.warning;
        statusTitle = 'Checked';
        statusDesc = 'IP lookup finished, purity check unavailable';
        centerIcon = Icons.public_rounded;
      }
    }

    final publicIp = controller.lookup?.primaryIp;

    return Column(
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
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
                  child: Icon(centerIcon, size: 46, color: pulseColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          statusTitle,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ).animate(key: ValueKey(statusTitle)).fadeIn(duration: 300.ms),
        const SizedBox(height: 6),
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
        if (publicIp != null) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: publicIp));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('IP copied to clipboard')),
                  );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        publicIp,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (controller.isRunning) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: LinearProgressIndicator(
              value: controller.progressFraction,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${controller.completedSections} of ${IpInfoController.totalSections} sections done',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  // ── Section card shell ─────────────────────────────────────────────────

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

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
                          title,
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
                          subtitle,
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
                  if (trailing != null) trailing,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool monospace = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptySection(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: 18,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. IP lookup ───────────────────────────────────────────────────────

  Widget _buildIpLookupCard(
    BuildContext context,
    IpInfoController controller,
  ) {
    final lookup = controller.lookup;

    if (lookup == null) {
      return _buildSectionCard(
        context,
        title: 'IP LOOKUP',
        subtitle: controller.isRunning
            ? 'Fetching your public IP...'
            : 'Run the check to see your IP and location',
        child: _buildEmptySection(
          context,
          controller.isRunning
              ? 'Contacting IP echo services...'
              : 'Not checked yet',
        ),
      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
    }

    final geo = lookup.geo;
    return _buildSectionCard(
      context,
      title: 'IP LOOKUP',
      subtitle: 'Your public address, location and network',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            context,
            'IPv4',
            lookup.ipv4 ?? 'Unavailable',
            monospace: true,
          ),
          _buildInfoRow(
            context,
            'IPv6',
            lookup.ipv6 ?? 'Unavailable',
            monospace: true,
          ),
          if (geo != null) ...[
            _buildInfoRow(
              context,
              'Location',
              '${geo.countryName}, ${geo.regionName}, ${geo.cityName}',
            ),
            _buildInfoRow(context, 'ISP', geo.ispName),
            _buildInfoRow(
              context,
              'ASN',
              geo.asn.isNotEmpty
                  ? 'AS${geo.asn} (${geo.asnOrganization})'
                  : 'Unknown',
            ),
            if (geo.timeZone.isNotEmpty)
              _buildInfoRow(context, 'Timezone', geo.timeZone),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  // ── 3. IP purity ───────────────────────────────────────────────────────

  Widget _buildPurityCard(
    BuildContext context,
    IpInfoController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final purity = controller.purity;

    if (purity == null) {
      return _buildSectionCard(
        context,
        title: 'IP PURITY CHECK',
        subtitle: controller.isRunning && controller.completedSections >= 1
            ? 'Scoring your IP...'
            : (controller.isCompleted
                ? 'Purity check unavailable'
                : 'Run the check to score your IP'),
        child: _buildEmptySection(
          context,
          controller.isCompleted
              ? 'Purity check could not be completed'
              : (controller.lookup == null
                  ? 'Needs your public IP first'
                  : 'Checking Tor list, proxy flags and ASN...'),
        ),
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
    }

    final verdict = purity.verdict;
    final isBogon = verdict.toLowerCase().contains('bogon') ||
        verdict.toLowerCase().contains('private') ||
        verdict.toLowerCase().contains('reserved');
    final isUnverified = verdict.toLowerCase().contains('unverified');

    final Color scoreColor;
    final String verdictDesc;
    if (isBogon) {
      scoreColor = colorScheme.outline;
      verdictDesc =
          'This is a private, local, or reserved (bogon) IP address. External purity checks do not apply.';
    } else if (isUnverified) {
      scoreColor = colorScheme.outline;
      verdictDesc =
          'Purity signals could not be reached. Reputation is unverified.';
    } else if (purity.score >= 80) {
      scoreColor = colorScheme.success;
      verdictDesc =
          'Looks like a normal residential IP. Services are unlikely to flag it.';
    } else if (purity.score >= 50) {
      scoreColor = colorScheme.warning;
      verdictDesc =
          'Some signals look unusual. A few services may challenge or limit this IP.';
    } else {
      scoreColor = colorScheme.error;
      verdictDesc =
          'Strong signals of a proxy, datacenter or Tor exit. Expect blocks and captchas.';
    }

    return _buildSectionCard(
      context,
      title: 'IP PURITY CHECK',
      subtitle: 'Reputation score from free, transparent signals',
      trailing: _buildStatusChip(context, purity.verdict, scoreColor),
      child: Column(
        children: [
          Row(
            children: [
              _buildPurityScore(context, purity, scoreColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  verdictDesc,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (purity.factors.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...purity.factors.map((factor) {
              final IconData icon;
              final Color iconColor;
              if (factor.passed == null) {
                icon = Icons.help_outline_rounded;
                iconColor = colorScheme.onSurfaceVariant;
              } else if (factor.passed!) {
                icon = Icons.check_circle_rounded;
                iconColor = colorScheme.success;
              } else {
                icon = Icons.cancel_rounded;
                iconColor = colorScheme.error;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: iconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            factor.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            factor.detail,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (factor.passed == false)
                      Text(
                        '-${factor.penalty}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.error,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPurityScore(
    BuildContext context,
    dynamic source, [
    Color? color,
  ]) {
    final colorScheme = Theme.of(context).colorScheme;
    final IpPurityResult? purity = source is IpInfoController
        ? source.purity
        : (source is IpPurityResult ? source : null);

    final String verdict = purity?.verdict ??
        (source is String
            ? source
            : (source is PurityVerdict ? source.name : ''));
    final int score = purity?.score ?? 0;

    final isBogon = source == PurityVerdict.bogon ||
        verdict.toLowerCase().contains('bogon') ||
        verdict.toLowerCase().contains('private') ||
        verdict.toLowerCase().contains('reserved');
    final isUnverified = source == PurityVerdict.unverified ||
        verdict.toLowerCase().contains('unverified');

    final effectiveColor = color ??
        (isBogon || isUnverified
            ? colorScheme.outline
            : (score >= 80
                ? colorScheme.success
                : (score >= 50 ? colorScheme.warning : colorScheme.error)));

    final Widget badgeContent;
    if (isBogon) {
      badgeContent = Icon(
        Icons.lan_rounded,
        size: 32,
        color: effectiveColor,
      );
    } else if (isUnverified) {
      badgeContent = Icon(
        Icons.help_outline_rounded,
        size: 32,
        color: effectiveColor,
      );
    } else {
      badgeContent = Text(
        '$score',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: effectiveColor,
        ),
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveColor.withValues(alpha: 0.1),
        border: Border.all(color: effectiveColor, width: 2.5),
      ),
      child: Center(
        child: badgeContent,
      ),
    );
  }

  // ── 4. Split routing ───────────────────────────────────────────────────

  Widget _buildSplitRoutingCard(
    BuildContext context,
    IpInfoController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final results = controller.splitResults;
    final total = IpInfoTargets.splitRouteTargets.length;

    final subtitle = controller.isTestingSplit
        ? '${results.length} of $total sites tested...'
        : (results.isEmpty
              ? 'Run the check to see each site’s exit IP'
              : '${controller.splitReachableCount} of ${results.length} sites reachable');

    return _buildSectionCard(
      context,
      title: 'SPLIT ROUTING',
      subtitle: subtitle,
      trailing: controller.isTestingSplit
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: results.isEmpty
          ? _buildEmptySection(
              context,
              controller.isTestingSplit
                  ? 'Testing sites...'
                  : 'Not checked yet',
            )
          : Column(
              children: [
                for (final result in results)
                  _buildSplitRouteRow(context, result),
                if (controller.isTestingSplit)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Still testing ${total - results.length} sites...',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSplitRouteRow(BuildContext context, SplitRouteResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReachable =
        result.status == ReachabilityStatus.reachable;
    final statusColor = isReachable
        ? colorScheme.success
        : colorScheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isReachable
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            size: 18,
            color: statusColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  result.domain,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.exitIpFromTrace && result.exitIp != null) ...[
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          result.exitIp!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Trace',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (result.exitIpLocation != null)
                    Text(
                      result.exitIpLocation!,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ] else ...[
                  Text(
                    result.resolvedIp != null
                        ? 'DNS: ${result.resolvedIp}'
                        : (isReachable ? 'Reachable' : '--'),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily:
                          result.resolvedIp != null ? 'monospace' : null,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isReachable
                        ? 'Direct connection'
                        : (result.errorDetails ?? 'Unreachable'),
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            result.latencyMs != null ? '${result.latencyMs} ms' : '--',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Connectivity latency ────────────────────────────────────────────

  Widget _buildLatencyCard(
    BuildContext context,
    IpInfoController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final results = controller.latencyResults;
    final total = IpInfoTargets.latencyTargets.length;

    final subtitle = controller.isMeasuringLatency
        ? '${results.length} of $total services measured...'
        : (results.isEmpty
              ? 'Run the check for median latency to 12 services'
              : 'Average median: ${controller.averageLatencyMs ?? '--'} ms');

    return _buildSectionCard(
      context,
      title: 'CONNECTIVITY LATENCY',
      subtitle: subtitle,
      trailing: controller.isMeasuringLatency
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: results.isEmpty
          ? _buildEmptySection(
              context,
              controller.isMeasuringLatency
                  ? 'Measuring...'
                  : 'Not checked yet',
            )
          : Column(
              children: results.map((result) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          result.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        children: result.attempts.map((attempt) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: attempt != null
                                    ? colorScheme.success
                                    : colorScheme.error,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        result.medianLatencyMs != null
                            ? '${result.medianLatencyMs} ms'
                            : 'unreachable',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: result.reachable
                              ? colorScheme.onSurface
                              : colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  // ── 6. Environment checks ──────────────────────────────────────────────

  Widget _buildEnvironmentCard(
    BuildContext context,
    IpInfoController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasAnything =
        controller.dnsLeak != null ||
        controller.ipLeak != null ||
        controller.cloudflare != null ||
        controller.whois != null ||
        controller.globalPingResults.isNotEmpty;

    return _buildSectionCard(
      context,
      title: 'ENVIRONMENT',
      subtitle:
          'DNS leak, IP leak, Cloudflare, global ping and whois',
      trailing: controller.isCheckingEnvironment
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: !hasAnything
          ? _buildEmptySection(
              context,
              controller.isCheckingEnvironment
                  ? 'Running environment checks...'
                  : 'Not checked yet',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.dnsLeak != null) ...[
                  _buildEnvSubheader(context, 'DNS LEAK'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        controller.dnsLeak!.tampered ||
                                controller.dnsLeak!.leakDetected
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_rounded,
                        size: 20,
                        color: controller.dnsLeak!.tampered ||
                                controller.dnsLeak!.leakDetected
                            ? colorScheme.warning
                            : colorScheme.success,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          controller.dnsLeak!.verdict,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    'System DNS',
                    controller.dnsLeak!.systemDnsIps.isEmpty
                        ? 'Failed to resolve'
                        : controller.dnsLeak!.systemDnsIps.join(', '),
                    monospace: true,
                  ),
                  _buildInfoRow(
                    context,
                    'Cloudflare DoH',
                    controller.dnsLeak!.cloudflareDohIps.isEmpty
                        ? '--'
                        : controller.dnsLeak!.cloudflareDohIps.join(', '),
                    monospace: true,
                  ),
                  _buildInfoRow(
                    context,
                    'Google DoH',
                    controller.dnsLeak!.googleDohIps.isEmpty
                        ? '--'
                        : controller.dnsLeak!.googleDohIps.join(', '),
                    monospace: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (controller.ipLeak != null) ...[
                  _buildEnvSubheader(context, 'IP LEAK'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        controller.ipLeak!.consistent
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        size: 20,
                        color: controller.ipLeak!.consistent
                            ? colorScheme.success
                            : colorScheme.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          controller.ipLeak!.consistent
                              ? 'Every service sees the same public IP — no leak detected.'
                              : 'Services see different public IPs — traffic is split across paths.',
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...controller.ipLeak!.seenBy.entries.map(
                    (entry) => _buildInfoRow(
                      context,
                      entry.key,
                      entry.value ?? 'Unreachable',
                      monospace: true,
                    ),
                  ),
                  if (controller.ipLeak!.localInterfaces.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Local interfaces (what a browser WebRTC check would expose):',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...controller.ipLeak!.localInterfaces.map(
                      (interface) => _buildInfoRow(
                        context,
                        interface.name,
                        '${interface.address} (${interface.type})',
                        monospace: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                if (controller.cloudflare != null) ...[
                  _buildEnvSubheader(context, 'CLOUDFLARE'),
                  if (controller.cloudflare!.reachable) ...[
                    _buildInfoRow(
                      context,
                      'Edge',
                      '${controller.cloudflare!.colo ?? '--'}'
                      ' (${controller.cloudflare!.location ?? '--'})',
                      monospace: true,
                    ),
                    _buildInfoRow(
                      context,
                      'WARP',
                      controller.cloudflare!.warp ?? '--',
                    ),
                    _buildInfoRow(
                      context,
                      'TLS',
                      controller.cloudflare!.tlsVersion ?? '--',
                    ),
                    _buildInfoRow(
                      context,
                      'HTTP',
                      controller.cloudflare!.httpVersion ?? '--',
                    ),
                    _buildInfoRow(
                      context,
                      'Latency',
                      '${controller.cloudflare!.latencyMs ?? '--'} ms',
                    ),
                  ] else
                    Text(
                      'Unreachable (${controller.cloudflare!.error ?? 'unknown error'})',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                if (controller.globalPingResults.isNotEmpty) ...[
                  _buildEnvSubheader(context, 'GLOBAL PING'),
                  ...controller.globalPingResults.map((result) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  result.region,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            result.success
                                ? '${result.latencyMs} ms'
                                : 'failed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              color: result.success
                                  ? colorScheme.onSurface
                                  : colorScheme.error,
                            ),
                          ),
                          if (result.viaHttpFallback)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                'HTTPS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.warning,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
                if (controller.whois != null) ...[
                  _buildEnvSubheader(context, 'WHOIS'),
                  if (controller.whois!.error == null) ...[
                    _buildInfoRow(
                      context,
                      'Network',
                      controller.whois!.networkName ?? '--',
                    ),
                    _buildInfoRow(
                      context,
                      'Organization',
                      controller.whois!.organization ?? '--',
                    ),
                    _buildInfoRow(
                      context,
                      'Country',
                      controller.whois!.country ?? '--',
                    ),
                    _buildInfoRow(
                      context,
                      'Registered',
                      controller.whois!.registeredOn ?? '--',
                    ),
                    _buildInfoRow(
                      context,
                      'Last changed',
                      controller.whois!.lastChanged ?? '--',
                    ),
                    _buildInfoRow(
                      context,
                      'Abuse contact',
                      controller.whois!.abuseEmail ?? '--',
                    ),
                  ] else
                    Text(
                      'Lookup failed (${controller.whois!.error})',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.error,
                      ),
                    ),
                ],
              ],
            ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildEnvSubheader(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  // ── Copy report ────────────────────────────────────────────────────────

  Widget _buildCopyReportCard(
    BuildContext context,
    IpInfoController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.15),
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.insights_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Analyze with AI',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Paste this data in an AI tool like ChatGPT, Claude, or Gemini to get an explanation of your IP situation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                final report = controller.generateIpInfoReport();
                const promptText =
                    '\n\nAbove is the data gathered about my public IP. '
                    'Explain what my IP purity score means, whether my '
                    'traffic looks split across different exit IPs, and '
                    'whether anything looks like a leak. Be straight to '
                    'the point.';
                Clipboard.setData(ClipboardData(text: '$report$promptText'));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: colorScheme.onInverseSurface,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text('IP information copied to clipboard!'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: colorScheme.inverseSurface,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text(
                'Copy All Information',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(
          begin: 0.2,
          end: 0,
          curve: Curves.easeOutBack,
        );
  }
}

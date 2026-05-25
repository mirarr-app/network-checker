import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/services/dns_hunter_service.dart';
import '../../core/theme/app_theme.dart';
import 'dns_hunter_controller.dart';

class DnsHunterScreen extends StatefulWidget {
  const DnsHunterScreen({super.key});

  @override
  State<DnsHunterScreen> createState() => _DnsHunterScreenState();
}

class _DnsHunterScreenState extends State<DnsHunterScreen> {
  final _customDomainController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load ranges on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<DnsHunterController>();
      if (controller.availableRanges.isEmpty) {
        controller.loadRanges();
      }
    });
  }

  @override
  void dispose() {
    _customDomainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DNS Hunter'),
        actions: [
          Consumer<DnsHunterController>(
            builder: (context, controller, _) {
              if (controller.cleanResults.isNotEmpty) {
                return PopupMenuButton<DnsHunterSortMode>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort by',
                  onSelected: controller.setSortMode,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: DnsHunterSortMode.latency,
                      child: Row(
                        children: [
                          Icon(
                            Icons.check,
                            size: 18,
                            color: controller.sortMode == DnsHunterSortMode.latency
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                          const SizedBox(width: 8),
                          const Text('Sort by Latency'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: DnsHunterSortMode.ip,
                      child: Row(
                        children: [
                          Icon(
                            Icons.check,
                            size: 18,
                            color: controller.sortMode == DnsHunterSortMode.ip
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                          const SizedBox(width: 8),
                          const Text('Sort by IP'),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Consumer<DnsHunterController>(
            builder: (context, controller, _) {
              if (controller.state == DnsHunterState.completed) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset',
                  onPressed: controller.reset,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<DnsHunterController>(
        builder: (context, controller, _) {
          return switch (controller.state) {
            DnsHunterState.loadingRanges => _buildLoadingState(),
            DnsHunterState.error => _buildErrorState(controller),
            DnsHunterState.scanning || DnsHunterState.testingSecure => 
                _buildScanningState(controller),
            DnsHunterState.completed => _buildResultsState(controller),
            DnsHunterState.idle => _buildConfigState(controller),
          };
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading CIDR ranges...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(DnsHunterController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              controller.errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.error),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: controller.loadRanges,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigState(DnsHunterController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      children: [
        // Target selection
        _buildTargetSelector(controller, colorScheme),
        
        // Custom domain input (if custom target)
        if (controller.target == DnsHunterTarget.custom)
          _buildCustomDomainInput(controller, colorScheme),
        
        // Range selection header
        _buildRangeSelectionHeader(controller, colorScheme),
        
        // Range list
        Expanded(
          child: _buildRangeList(controller, colorScheme),
        ),
        
        // Start button
        _buildStartButton(controller, colorScheme),
      ],
    );
  }

  Widget _buildTargetSelector(DnsHunterController controller, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification Target',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: DnsHunterTarget.values.map((target) {
              final isSelected = controller.target == target;
              return ChoiceChip(
                label: Text(target.name),
                selected: isSelected,
                onSelected: (_) => controller.setTarget(target),
                avatar: isSelected ? const Icon(Icons.check, size: 18) : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _getTargetDescription(controller.target),
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  String _getTargetDescription(DnsHunterTarget target) {
    return switch (target) {
      DnsHunterTarget.twitter => 
          'Verify DNS returns Cloudflare IPs for x.com (clean = not blocked)',
      DnsHunterTarget.youtube => 
          'Verify DNS returns Google IPs for youtube.com (clean = not blocked)',
      DnsHunterTarget.custom => 
          'Test with a custom domain (any valid response = clean)',
    };
  }

  Widget _buildCustomDomainInput(DnsHunterController controller, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: TextField(
        controller: _customDomainController,
        decoration: const InputDecoration(
          hintText: 'Enter domain (e.g., telegram.org)',
          prefixIcon: Icon(Icons.language),
        ),
        onChanged: controller.setCustomDomain,
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  Widget _buildRangeSelectionHeader(DnsHunterController controller, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Ranges to Scan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${controller.selectedRanges.length} of ${controller.availableRanges.length} selected',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: controller.selectedRanges.length == controller.availableRanges.length
                ? controller.clearRangeSelection
                : controller.selectAllRanges,
            child: Text(
              controller.selectedRanges.length == controller.availableRanges.length
                  ? 'Deselect All'
                  : 'Select All',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeList(DnsHunterController controller, ColorScheme colorScheme) {
    // Group ranges by provider
    final grouped = <String, List<CidrRange>>{};
    for (final range in controller.availableRanges) {
      grouped.putIfAbsent(range.provider, () => []).add(range);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final provider = grouped.keys.elementAt(index);
        final ranges = grouped[provider]!;
        final selectedCount = ranges.where((r) => controller.selectedRanges.contains(r)).length;
        
        return ExpansionTile(
          title: Text(
            provider,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '$selectedCount / ${ranges.length} ranges selected',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          leading: Checkbox(
            value: selectedCount == ranges.length 
                ? true 
                : selectedCount == 0 
                    ? false 
                    : null,
            tristate: true,
            onChanged: (value) {
              if (value == true) {
                // Select all in this provider
                for (final range in ranges) {
                  if (!controller.selectedRanges.contains(range)) {
                    controller.toggleRangeSelection(range);
                  }
                }
              } else {
                // Deselect all in this provider (false or null)
                for (final range in ranges) {
                  if (controller.selectedRanges.contains(range)) {
                    controller.toggleRangeSelection(range);
                  }
                }
              }
            },
          ),
          children: ranges.map((range) {
            final isSelected = controller.selectedRanges.contains(range);
            return CheckboxListTile(
              value: isSelected,
              onChanged: (_) => controller.toggleRangeSelection(range),
              title: Text(
                range.cidr,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: colorScheme.primary,
                ),
              ),
              subtitle: Text('~${range.totalIps} IPs'),
              dense: true,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStartButton(DnsHunterController controller, ColorScheme colorScheme) {
    final totalIps = controller.selectedRanges.fold(0, (sum, r) => sum + r.totalIps);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (totalIps > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Will scan ~$totalIps IPs',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.selectedRanges.isNotEmpty
                    ? controller.startScan
                    : null,
                icon: const Icon(Icons.radar),
                label: const Text('Start Hunting'),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildScanningState(DnsHunterController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTestingSecure = controller.state == DnsHunterState.testingSecure;
    
    return Column(
      children: [
        // Progress section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Column(
            children: [
              // Phase indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isTestingSecure 
                          ? colorScheme.tertiaryContainer 
                          : colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isTestingSecure ? Icons.security : Icons.search,
                          size: 16,
                          color: isTestingSecure 
                              ? colorScheme.onTertiaryContainer 
                              : colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isTestingSecure ? 'Phase 2: Testing Secure DNS' : 'Phase 1: Hunting Clean DNS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isTestingSecure 
                                ? colorScheme.onTertiaryContainer 
                                : colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: isTestingSecure ? null : controller.progress,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 12),
              
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatChip(
                    icon: Icons.search,
                    label: '${controller.scannedIps}/${controller.totalIps}',
                    color: colorScheme.primary,
                  ),
                  _buildStatChip(
                    icon: Icons.check_circle,
                    label: '${controller.cleanCount} Clean',
                    color: colorScheme.success,
                  ),
                  if (isTestingSecure)
                    _buildStatChip(
                      icon: Icons.security,
                      label: '${controller.secureCount} Secure',
                      color: colorScheme.tertiary,
                    ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: -0.2, end: 0),
        
        // Live results
        Expanded(
          child: controller.cleanResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Hunting for clean DNS servers...',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : _buildResultsList(controller, colorScheme),
        ),
        
        // Stop button
        Container(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: controller.stopScan,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsState(DnsHunterController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Column(
            children: [
              // Success banner
              if (controller.cleanResults.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.tertiaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 40,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hunt Complete!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Found ${controller.cleanCount} clean DNS, ${controller.secureCount} with secure DNS support',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (controller.cleanResults.length > 10) ...[
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  final topIps = controller.cleanResults
                                      .take(10)
                                      .map((result) => result.ip)
                                      .join('\n');
                                  Clipboard.setData(ClipboardData(text: topIps));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Top 10 DNS IPs copied to clipboard'),
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy Top 10 IPs'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  final allIps = controller.cleanResults
                                      .map((result) => result.ip)
                                      .join('\n');
                                  Clipboard.setData(ClipboardData(text: allIps));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('All ${controller.cleanResults.length} DNS IPs copied to clipboard'),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_all),
                                label: const Text('Copy All IPs'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              final allIps = controller.cleanResults
                                  .map((result) => result.ip)
                                  .join('\n');
                              Clipboard.setData(ClipboardData(text: allIps));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('All DNS IPs copied to clipboard'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_all),
                            label: const Text('Copy All IPs'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
              
              if (controller.cleanResults.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 40,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No Clean DNS Found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try selecting more ranges or a different target',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        
        // Results tabs
        if (controller.cleanResults.isNotEmpty)
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 18),
                            const SizedBox(width: 6),
                            Text('Clean (${controller.cleanCount})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.security, size: 18),
                            const SizedBox(width: 6),
                            Text('Secure (${controller.secureCount})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildResultsList(controller, colorScheme),
                        _buildSecureResultsList(controller, colorScheme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultsList(DnsHunterController controller, ColorScheme colorScheme) {
    final results = controller.cleanResults;
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _DnsResultCard(
          result: result,
          index: index,
        );
      },
    );
  }

  Widget _buildSecureResultsList(DnsHunterController controller, ColorScheme colorScheme) {
    final results = controller.secureResults;
    
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.security, size: 48, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No secure DNS servers found',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Secure DNS supports DoH on port 443',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _DnsResultCard(
          result: result,
          index: index,
          showDohHint: true,
        );
      },
    );
  }
}

class _DnsResultCard extends StatelessWidget {
  final DnsHunterResult result;
  final int index;
  final bool showDohHint;

  const _DnsResultCard({
    required this.result,
    required this.index,
    this.showDohHint = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => _showDetailSheet(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: result.supportsSecureDns 
                      ? colorScheme.tertiaryContainer 
                      : colorScheme.successContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  result.supportsSecureDns ? Icons.security : Icons.check_circle,
                  color: result.supportsSecureDns 
                      ? colorScheme.tertiary 
                      : colorScheme.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              
              // IP and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.ip,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (showDohHint)
                      Text(
                        'DoH: https://${result.ip}/dns-query',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: colorScheme.tertiary,
                        ),
                      )
                    else if (result.resolvedIps.isNotEmpty)
                      Text(
                        'Resolved: ${result.resolvedIps.first}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Latency badge
              if (result.latencyMs != null)
                _buildLatencyBadge(colorScheme, result.latencyMs!),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 20 * (index % 20)))
        .slideX(begin: 0.1, end: 0, delay: Duration(milliseconds: 20 * (index % 20)));
  }

  Widget _buildLatencyBadge(ColorScheme colorScheme, int latencyMs) {
    Color backgroundColor;
    Color textColor;

    if (latencyMs < 50) {
      backgroundColor = colorScheme.successContainer;
      textColor = colorScheme.success;
    } else if (latencyMs < 100) {
      backgroundColor = colorScheme.primaryContainer;
      textColor = colorScheme.primary;
    } else if (latencyMs < 200) {
      backgroundColor = colorScheme.warningContainer;
      textColor = colorScheme.warning;
    } else {
      backgroundColor = colorScheme.errorContainer;
      textColor = colorScheme.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${latencyMs}ms',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            initialChildSize: 0.4,
            minChildSize: 0.3,
            maxChildSize: 0.7,
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
                            color: result.supportsSecureDns 
                                ? colorScheme.tertiaryContainer 
                                : colorScheme.successContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            result.supportsSecureDns ? Icons.security : Icons.dns,
                            size: 28,
                            color: result.supportsSecureDns 
                                ? colorScheme.tertiary 
                                : colorScheme.success,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Clean DNS Server',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              if (result.supportsSecureDns)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Supports Secure DNS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onTertiaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (result.latencyMs != null)
                          _buildLatencyBadge(colorScheme, result.latencyMs!),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Info fields
                    _buildInfoField(
                      context,
                      label: 'IP Address',
                      value: result.ip,
                      icon: Icons.dns,
                    ),
                    
                    if (result.supportsSecureDns)
                      _buildInfoField(
                        context,
                        label: 'DoH URL',
                        value: 'https://${result.ip}/dns-query',
                        icon: Icons.lock,
                      ),
                    
                    if (result.resolvedIps.isNotEmpty)
                      _buildInfoField(
                        context,
                        label: 'Resolved IPs',
                        value: result.resolvedIps.join(', '),
                        icon: Icons.public,
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

  Widget _buildInfoField(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.copy, size: 20, color: colorScheme.primary),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/services/edge_ip_scanner.dart';
import '../../core/theme/app_theme.dart';
import 'cf_ip_ranges.dart';
import 'edge_ip_checker_controller.dart';

class EdgeIpCheckerScreen extends StatefulWidget {
  const EdgeIpCheckerScreen({super.key});

  @override
  State<EdgeIpCheckerScreen> createState() => _EdgeIpCheckerScreenState();
}

enum _ResultFilter { all, excellent, good, average }

class _EdgeIpCheckerScreenState extends State<EdgeIpCheckerScreen> {
  late TextEditingController _inputController;
  _ResultFilter _currentFilter = _ResultFilter.all;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  void _onInputChanged(String text, EdgeIpCheckerController controller) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      controller.updateInput(text);
    });
  }

  void _shuffleInputLines(TextEditingController textCtrl, EdgeIpCheckerController controller) {
    final lines = textCtrl.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length <= 1) return;
    lines.shuffle();
    final shuffled = lines.join('\n');
    textCtrl.text = shuffled;
    controller.updateInput(shuffled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edge IP Scanner'),
        actions: [
          Consumer<EdgeIpCheckerController>(
            builder: (context, controller, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.workingIps.isNotEmpty && !controller.isScanning)
                    IconButton(
                      icon: const Icon(Icons.copy_all),
                      tooltip: 'Copy working IPs',
                      onPressed: () => _copyWorkingIps(context, controller),
                    ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                    onPressed: () => _showSettingsDialog(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<EdgeIpCheckerController>(
        builder: (context, controller, _) {
          return Column(
            children: [
              // Progress bar (shown during/after scan)
              if (controller.isScanning || controller.scannedCount > 0)
                _buildProgressBar(context, controller),

              // Main content
              Expanded(
                child: controller.isPreparingScan
                    ? _buildPreparingState(context)
                    : controller.workingIps.isNotEmpty
                        ? _buildResultsList(context, controller)
                        : _buildInputSection(context, controller),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<EdgeIpCheckerController>(
        builder: (context, controller, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toggle view button (if has results)
              if (controller.workingIps.isNotEmpty && !controller.isScanning)
                FloatingActionButton.small(
                  heroTag: 'toggle_view',
                  onPressed: () => _showInputDialog(context, controller),
                  child: const Icon(Icons.edit),
                ).animate().fadeIn(delay: 200.ms).scale(delay: 200.ms),
              if (controller.workingIps.isNotEmpty) const SizedBox(height: 12),

              // Main action button
              FloatingActionButton.extended(
                heroTag: 'scan_action',
                onPressed: controller.isScanning
                    ? controller.stopScan
                    : controller.parsedIpCount > 0
                        ? controller.startScan
                        : () => _showInputDialog(context, controller),
                icon: Icon(
                  controller.isScanning
                      ? Icons.stop
                      : controller.parsedIpCount > 0
                          ? Icons.play_arrow
                          : Icons.add,
                ),
                label: Text(
                  controller.isScanning
                      ? 'Stop'
                      : controller.parsedIpCount > 0
                          ? 'Scan ${controller.parsedIpCount} IPs'
                          : 'Add IPs',
                ),
              ).animate().fadeIn(delay: 100.ms).scale(delay: 100.ms),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, EdgeIpCheckerController controller) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          // Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: controller.isPreparingScan 
                  ? null 
                  : controller.isScanning 
                      ? controller.progress 
                      : 1.0,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 12),
          // Preparing message or stats row
          if (controller.isPreparingScan)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Preparing scan for ${controller.parsedIpCount} IPs...',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip(
                  context,
                  icon: Icons.check_circle,
                  label: '${controller.successCount}',
                  subtitle: 'Working',
                  color: colorScheme.success,
                ),
                _buildStatChip(
                  context,
                  icon: Icons.cancel,
                  label: '${controller.failureCount}',
                  subtitle: 'Failed',
                  color: colorScheme.error,
                ),
                _buildStatChip(
                  context,
                  icon: Icons.pending,
                  label: '${controller.parsedIpCount - controller.scannedCount}',
                  subtitle: 'Pending',
                  color: colorScheme.outline,
                ),
                _buildStatChip(
                  context,
                  icon: Icons.speed,
                  label: '${(controller.scannedCount / (controller.isScanning ? 1 : 1)).toStringAsFixed(0)}/s',
                  subtitle: 'Rate',
                  color: colorScheme.primary,
                ),
              ],
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPreparingState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Starting scan...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Initializing connections',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildInputSection(BuildContext context, EdgeIpCheckerController controller) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter IP addresses or CIDR ranges',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'One IP or range per line',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () {
                      _inputController.text = cloudflareIpRanges;
                      controller.updateInput(cloudflareIpRanges);
                      controller.updateConfig(testDomain: 'chatgpt.com');
                    },
                    icon: const Icon(Icons.cloud_outlined, size: 18),
                    label: const Text('Load CF IPs'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      _inputController.text = vercelIpRanges;
                      controller.updateInput(vercelIpRanges);
                      controller.updateConfig(testDomain: 'vercel.com');
                    },
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text('Load Vercel IPs'),
                  ),
                  if (controller.parsedIpCount > 0)
                    IconButton.filledTonal(
                      onPressed: () => _shuffleInputLines(_inputController, controller),
                      icon: const Icon(Icons.shuffle, size: 20),
                      tooltip: 'Shuffle ranges',
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Input field
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: '# Example inputs:\n104.18.0.0/20\n172.64.0.0/20\n104.18.1.1\n104.18.1.2',
                hintMaxLines: 10,
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              onChanged: (text) => _onInputChanged(text, controller),
            ),
          ),
          const SizedBox(height: 16),

          // Info row
          if (controller.parsedIpCount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Parsed ${controller.parsedIpCount} IP addresses to scan',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildResultsList(BuildContext context, EdgeIpCheckerController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    final workingIps = controller.workingIps;
    
    // Categorize IPs by latency
    final excellent = workingIps.where((ip) => (ip.latencyMs ?? 9999) < 100).toList();
    final good = workingIps.where((ip) => (ip.latencyMs ?? 9999) >= 100 && (ip.latencyMs ?? 9999) < 200).toList();
    final average = workingIps.where((ip) => (ip.latencyMs ?? 9999) >= 200).toList();
    
    // Get filtered list
    List<EdgeIpResult> filteredIps;
    switch (_currentFilter) {
      case _ResultFilter.excellent:
        filteredIps = excellent;
      case _ResultFilter.good:
        filteredIps = good;
      case _ResultFilter.average:
        filteredIps = average;
      case _ResultFilter.all:
        filteredIps = workingIps;
    }
    
    // Top 3 for hero section
    final topThree = workingIps.take(3).toList();
    
    return CustomScrollView(
      slivers: [
        // Top 3 Hero Section
        if (topThree.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildTopPerformers(context, topThree),
          ),
        
        // Quick Stats Cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildCategoryChip(
                  context,
                  label: 'All',
                  count: workingIps.length,
                  color: colorScheme.primary,
                  isSelected: _currentFilter == _ResultFilter.all,
                  onTap: () => setState(() => _currentFilter = _ResultFilter.all),
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context,
                  label: '<100ms',
                  count: excellent.length,
                  color: colorScheme.success,
                  isSelected: _currentFilter == _ResultFilter.excellent,
                  onTap: () => setState(() => _currentFilter = _ResultFilter.excellent),
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context,
                  label: '<200ms',
                  count: good.length,
                  color: Colors.orange,
                  isSelected: _currentFilter == _ResultFilter.good,
                  onTap: () => setState(() => _currentFilter = _ResultFilter.good),
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context,
                  label: '200ms+',
                  count: average.length,
                  color: colorScheme.error,
                  isSelected: _currentFilter == _ResultFilter.average,
                  onTap: () => setState(() => _currentFilter = _ResultFilter.average),
                ),
              ],
            ),
          ),
        ),
        
        // Section header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  _currentFilter == _ResultFilter.all 
                      ? 'All Results' 
                      : '${_getFilterLabel(_currentFilter)} (${filteredIps.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (filteredIps.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (filteredIps.length > 10) ...[
                        TextButton.icon(
                          onPressed: () => _copyFilteredIps(context, filteredIps),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy Top 10'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      TextButton.icon(
                        onPressed: () => _copyFilteredIps(context, filteredIps, copyAll: true),
                        icon: const Icon(Icons.copy_all, size: 16),
                        label: const Text('Copy All'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        
        // Compact IP Grid
        if (filteredIps.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'No IPs in this category',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final ip = filteredIps[index];
                  final globalRank = workingIps.indexOf(ip) + 1;
                  return _CompactIpCard(
                    result: ip,
                    rank: globalRank,
                    latencyColor: _getLatencyColor(colorScheme, ip.latencyMs),
                  );
                },
                childCount: filteredIps.length,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildTopPerformers(BuildContext context, List<EdgeIpResult> topThree) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.5),
            colorScheme.secondaryContainer.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Top Performers',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _copyTopIps(context, topThree),
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(topThree.length, (index) {
              final ip = topThree[index];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < topThree.length - 1 ? 8 : 0),
                  child: _TopIpCard(
                    result: ip,
                    rank: index + 1,
                    latencyColor: _getLatencyColor(colorScheme, ip.latencyMs),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }
  
  Widget _buildCategoryChip(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : colorScheme.onSurface,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? color : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getLatencyColor(ColorScheme colorScheme, double? latencyMs) {
    if (latencyMs == null) return colorScheme.outline;
    if (latencyMs < 100) return colorScheme.success;
    if (latencyMs < 200) return Colors.orange;
    return colorScheme.error;
  }
  
  String _getFilterLabel(_ResultFilter filter) {
    switch (filter) {
      case _ResultFilter.excellent:
        return 'Excellent (<100ms)';
      case _ResultFilter.good:
        return 'Good (<200ms)';
      case _ResultFilter.average:
        return 'Average (200ms+)';
      case _ResultFilter.all:
        return 'All';
    }
  }
  
  void _copyTopIps(BuildContext context, List<EdgeIpResult> ips) {
    final text = ips.map((ip) => ip.ip).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${ips.length} top IPs')),
    );
  }
  
  void _copyFilteredIps(BuildContext context, List<EdgeIpResult> ips, {bool copyAll = false}) {
    final toCopy = copyAll ? ips : ips.take(10).toList();
    final text = toCopy.map((ip) => ip.ip).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${toCopy.length} IPs')),
    );
  }

  void _showInputDialog(BuildContext context, EdgeIpCheckerController controller) {
    final textController = TextEditingController(text: controller.inputText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title row with load button
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Edit IP Addresses',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {
                              textController.text = cloudflareIpRanges;
                              controller.updateConfig(testDomain: 'chatgpt.com');
                            },
                            icon: const Icon(Icons.cloud_outlined, size: 18),
                            label: const Text('Load CF IPs'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              textController.text = vercelIpRanges;
                              controller.updateConfig(testDomain: 'vercel.com');
                            },
                            icon: const Icon(Icons.bolt, size: 18),
                            label: const Text('Load Vercel IPs'),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => _shuffleInputLines(textController, controller),
                            icon: const Icon(Icons.shuffle, size: 20),
                            tooltip: 'Shuffle ranges',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Input field
                  Expanded(
                    child: TextField(
                      controller: textController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: 'One IP or CIDR range per line...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            controller.clearAll();
                            Navigator.pop(context);
                          },
                          child: const Text('Clear All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () {
                            controller.updateInput(textController.text);
                            Navigator.pop(context);
                          },
                          child: const Text('Update'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final controller = context.read<EdgeIpCheckerController>();

    showDialog(
      context: context,
      builder: (context) {
        return _SettingsDialog(initialConfig: controller.config);
      },
    ).then((newConfig) {
      if (newConfig != null) {
        controller.updateConfig(
          testDomain: newConfig.testDomain,
          testPath: newConfig.testPath,
          port: newConfig.port,
          timeout: newConfig.timeout,
          maxWorkers: newConfig.maxWorkers,
          testDownload: newConfig.testDownload,
          downloadSize: newConfig.downloadSize,
        );
      }
    });
  }

  void _copyWorkingIps(BuildContext context, EdgeIpCheckerController controller) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('Copy IPs only'),
                subtitle: const Text('Plain list of working IPs'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: controller.getWorkingIpsText()));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Working IPs copied to clipboard')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Copy with details'),
                subtitle: const Text('IPs with latency and speed info'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: controller.getWorkingIpsDetailedText()));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Detailed results copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Top performer card for the hero section
class _TopIpCard extends StatelessWidget {
  final EdgeIpResult result;
  final int rank;
  final Color latencyColor;

  const _TopIpCard({
    required this.result,
    required this.rank,
    required this.latencyColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
    
    return GestureDetector(
      onTap: () => _copyIp(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(medal, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    result.ip,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: latencyColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${result.latencyMs?.toStringAsFixed(0) ?? 'N/A'}ms',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: latencyColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyIp(BuildContext context) {
    Clipboard.setData(ClipboardData(text: result.ip));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied: ${result.ip}')),
    );
  }
}

/// Compact IP card for the grid view
class _CompactIpCard extends StatelessWidget {
  final EdgeIpResult result;
  final int rank;
  final Color latencyColor;

  const _CompactIpCard({
    required this.result,
    required this.rank,
    required this.latencyColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _copyIp(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              // Rank indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: latencyColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: latencyColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // IP and latency
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      result.ip,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${result.latencyMs?.toStringAsFixed(0) ?? 'N/A'}ms',
                      style: TextStyle(
                        fontSize: 10,
                        color: latencyColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Copy icon
              Icon(
                Icons.copy,
                size: 14,
                color: colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyIp(BuildContext context) {
    Clipboard.setData(ClipboardData(text: result.ip));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: ${result.ip}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  final EdgeScanConfig initialConfig;

  const _SettingsDialog({required this.initialConfig});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late TextEditingController _domainController;
  late TextEditingController _pathController;
  late TextEditingController _portController;
  late TextEditingController _timeoutController;
  late TextEditingController _workersController;
  late bool _testDownload;

  @override
  void initState() {
    super.initState();
    _domainController = TextEditingController(text: widget.initialConfig.testDomain);
    _pathController = TextEditingController(text: widget.initialConfig.testPath);
    _portController = TextEditingController(text: widget.initialConfig.port.toString());
    _timeoutController = TextEditingController(text: widget.initialConfig.timeout.inSeconds.toString());
    _workersController = TextEditingController(text: widget.initialConfig.maxWorkers.toString());
    _testDownload = widget.initialConfig.testDownload;
  }

  @override
  void dispose() {
    _domainController.dispose();
    _pathController.dispose();
    _portController.dispose();
    _timeoutController.dispose();
    _workersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 400 ? screenWidth * 0.95 : 400.0;

    return AlertDialog(
      title: const Text('Scan Settings'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _domainController,
                decoration: const InputDecoration(
                  labelText: 'Test Domain (SNI)',
                  hintText: 'chatgpt.com',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pathController,
                decoration: const InputDecoration(
                  labelText: 'Test Path',
                  hintText: '/',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '443',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _timeoutController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Timeout (s)',
                        hintText: '3',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _workersController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Concurrent Workers',
                  hintText: '20',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Test Download'),
                subtitle: const Text('Measure download speed'),
                value: _testDownload,
                onChanged: (value) => setState(() => _testDownload = value),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final newConfig = EdgeScanConfig(
              testDomain: _domainController.text,
              testPath: _pathController.text,
              port: int.tryParse(_portController.text) ?? 443,
              timeout: Duration(seconds: int.tryParse(_timeoutController.text) ?? 3),
              maxWorkers: int.tryParse(_workersController.text) ?? 20,
              testDownload: _testDownload,
            );
            Navigator.pop(context, newConfig);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}


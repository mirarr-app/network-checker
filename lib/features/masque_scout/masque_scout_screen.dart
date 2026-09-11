import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/services/masque_scout_scanner.dart';
import 'data/masque_ip_ranges.dart';
import 'masque_scout_controller.dart';

class MasqueScoutScreen extends StatefulWidget {
  const MasqueScoutScreen({super.key});

  @override
  State<MasqueScoutScreen> createState() => _MasqueScoutScreenState();
}

enum _LatencyFilter { all, excellent, good, fair }

class _MasqueScoutScreenState extends State<MasqueScoutScreen> {
  late TextEditingController _inputController;
  _LatencyFilter _currentFilter = _LatencyFilter.all;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<MasqueScoutController>(context, listen: false);
    _inputController = TextEditingController(text: controller.inputText);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  void _onInputChanged(String text, MasqueScoutController controller) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      controller.updateInput(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masque Scout'),
        actions: [
          Consumer<MasqueScoutController>(
            builder: (context, controller, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.workingEndpoints.isNotEmpty && !controller.isScanning)
                    IconButton(
                      icon: const Icon(Icons.copy_all),
                      tooltip: 'Copy accessible endpoints',
                      onPressed: () => _copyWorkingEndpoints(context, controller),
                    ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                    onPressed: () => _showSettingsDialog(context, controller),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<MasqueScoutController>(
        builder: (context, controller, _) {
          return Column(
            children: [
              // Protocol Segment Selector
              _buildProtocolSelector(context, controller),

              // Multi-port toggle bar
              _buildMultiPortBar(context, controller),

              // Progress bar (when scanning or results present)
              if (controller.isScanning || controller.scannedCount > 0)
                _buildProgressBar(context, controller),

              // Main content
              Expanded(
                child: controller.isPreparingScan
                    ? _buildPreparingState(context)
                    : controller.workingEndpoints.isNotEmpty
                        ? _buildResultsList(context, controller)
                        : _buildInputSection(context, controller),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<MasqueScoutController>(
        builder: (context, controller, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.workingEndpoints.isNotEmpty && !controller.isScanning)
                FloatingActionButton.small(
                  heroTag: 'masque_toggle_view',
                  onPressed: () => _showInputDialog(context, controller),
                  child: const Icon(Icons.edit),
                ).animate().fadeIn(delay: 200.ms).scale(delay: 200.ms),
              if (controller.workingEndpoints.isNotEmpty) const SizedBox(height: 12),

              FloatingActionButton.extended(
                heroTag: 'masque_scan_action',
                onPressed: controller.isScanning
                    ? controller.stopScan
                    : controller.parsedCount > 0
                        ? controller.startScan
                        : () => _showInputDialog(context, controller),
                icon: Icon(
                  controller.isScanning
                      ? Icons.stop
                      : controller.parsedCount > 0
                          ? Icons.play_arrow
                          : Icons.add,
                ),
                label: Text(
                  controller.isScanning
                      ? 'Stop Scan'
                      : controller.parsedCount > 0
                          ? 'Scan ${controller.parsedCount} Endpoints'
                          : 'Add Endpoints',
                ),
              ).animate().fadeIn(delay: 100.ms).scale(delay: 100.ms),
            ],
          );
        },
      ),
    );
  }

  // ── Protocol Selector ───────────────────────────────────────────────────────

  Widget _buildProtocolSelector(BuildContext context, MasqueScoutController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<MasqueProtocol>(
              segments: const [
                ButtonSegment<MasqueProtocol>(
                  value: MasqueProtocol.h3,
                  label: Text('MASQUE H3 (QUIC)'),
                  icon: Icon(Icons.flash_on, size: 16),
                ),
                ButtonSegment<MasqueProtocol>(
                  value: MasqueProtocol.h2,
                  label: Text('MASQUE H2 (TCP)'),
                  icon: Icon(Icons.security, size: 16),
                ),
              ],
              selected: {controller.config.protocol},
              onSelectionChanged: controller.isScanning
                  ? null
                  : (newSelection) {
                      if (newSelection.isNotEmpty) {
                        controller.setProtocol(newSelection.first);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  // ── Multi-Port Toggle Bar ──────────────────────────────────────────────────

  Widget _buildMultiPortBar(BuildContext context, MasqueScoutController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Icon(
            Icons.device_hub,
            size: 18,
            color: controller.config.multiPort ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Multi-Port Scan',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  controller.config.multiPort
                      ? 'Ports: ${MasqueIpRanges.masquePorts.join(", ")}'
                      : 'Single Port: ${controller.config.defaultPort}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: controller.config.multiPort,
            onChanged: controller.isScanning
                ? null
                : (value) => controller.setMultiPort(value),
          ),
        ],
      ),
    );
  }

  // ── Progress Bar ───────────────────────────────────────────────────────────

  Widget _buildProgressBar(BuildContext context, MasqueScoutController controller) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        children: [
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
          if (controller.isPreparingScan)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Preparing endpoints...'),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  context,
                  'Scanned',
                  '${controller.scannedCount}/${controller.parsedCount}',
                  Icons.radar,
                ),
                _buildStatItem(
                  context,
                  'Accessible',
                  '${controller.successCount}',
                  Icons.check_circle,
                  color: Colors.green,
                ),
                _buildStatItem(
                  context,
                  'Failed',
                  '${controller.failureCount}',
                  Icons.cancel,
                  color: Colors.red,
                ),
                _buildStatItem(
                  context,
                  'Progress',
                  '${(controller.progress * 100).toStringAsFixed(0)}%',
                  Icons.timelapse,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? theme.colorScheme.primary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Preparing State ────────────────────────────────────────────────────────

  Widget _buildPreparingState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Preparing endpoints...'),
        ],
      ),
    );
  }

  // ── Input Section ──────────────────────────────────────────────────────────

  Widget _buildInputSection(BuildContext context, MasqueScoutController controller) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Protocol description banner
          Card(
            elevation: 0,
            color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.config.protocol.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          controller.config.protocol.description,
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
            ),
          ),
          const SizedBox(height: 12),

          // Preset Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.flash_on, size: 16),
                label: const Text('Seeds (Fast)'),
                onPressed: () {
                  _inputController.text = MasqueIpRanges.seedsPresetText;
                  controller.loadPreset(MasqueIpRanges.seedsPresetText);
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.tune, size: 16),
                label: const Text('Balanced (Samples)'),
                onPressed: () {
                  _inputController.text = MasqueIpRanges.balancedPresetText;
                  controller.loadPreset(MasqueIpRanges.balancedPresetText);
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.device_hub, size: 16),
                label: const Text('Multi-Port Seeds'),
                onPressed: () {
                  _inputController.text = MasqueIpRanges.multiPortSeedsPresetText;
                  controller.loadPreset(MasqueIpRanges.multiPortSeedsPresetText);
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.list, size: 16),
                label: const Text('All Subnets'),
                onPressed: () {
                  _inputController.text = MasqueIpRanges.defaultPresetText;
                  controller.loadPreset(MasqueIpRanges.defaultPresetText);
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.shuffle, size: 16),
                label: const Text('Shuffle'),
                onPressed: () {
                  controller.shuffleInput();
                  _inputController.text = controller.inputText;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Input text field
          TextField(
            controller: _inputController,
            onChanged: (text) => _onInputChanged(text, controller),
            maxLines: 15,
            decoration: InputDecoration(
              labelText: 'Endpoints or Subnets (one per line)',
              hintText: '162.159.196.1\n162.159.197.0/24\n162.159.198.1:443',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
              helperText: '${controller.parsedCount} endpoints parsed',
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear',
                onPressed: () {
                  _inputController.clear();
                  controller.clearAll();
                },
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Results List ───────────────────────────────────────────────────────────

  Widget _buildResultsList(BuildContext context, MasqueScoutController controller) {
    final results = _filterResults(controller.workingEndpoints);

    return Column(
      children: [
        // Filter bar
        _buildFilterBar(context, controller),

        // List
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    'No endpoints match current filter',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return _buildResultCard(context, result);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context, MasqueScoutController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text('All (${controller.workingEndpoints.length})'),
            selected: _currentFilter == _LatencyFilter.all,
            onSelected: (_) => setState(() => _currentFilter = _LatencyFilter.all),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('< 150ms'),
            selected: _currentFilter == _LatencyFilter.excellent,
            onSelected: (_) => setState(() => _currentFilter = _LatencyFilter.excellent),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('< 300ms'),
            selected: _currentFilter == _LatencyFilter.good,
            onSelected: (_) => setState(() => _currentFilter = _LatencyFilter.good),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('>= 300ms'),
            selected: _currentFilter == _LatencyFilter.fair,
            onSelected: (_) => setState(() => _currentFilter = _LatencyFilter.fair),
          ),
        ],
      ),
    );
  }

  List<MasqueScoutResult> _filterResults(List<MasqueScoutResult> results) {
    return switch (_currentFilter) {
      _LatencyFilter.all => results,
      _LatencyFilter.excellent => results.where((r) => (r.latencyMs ?? 999) < 150).toList(),
      _LatencyFilter.good => results.where((r) => (r.latencyMs ?? 999) >= 150 && (r.latencyMs ?? 999) < 300).toList(),
      _LatencyFilter.fair => results.where((r) => (r.latencyMs ?? 999) >= 300).toList(),
    };
  }

  Widget _buildResultCard(BuildContext context, MasqueScoutResult result) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final latency = result.latencyMs;

    Color latencyColor = Colors.green;
    if (latency == null || latency >= 300) {
      latencyColor = Colors.orange;
    } else if (latency >= 150) {
      latencyColor = Colors.amber.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: latencyColor.withValues(alpha: 0.15),
          child: Icon(
            result.protocol == MasqueProtocol.h3 ? Icons.flash_on : Icons.security,
            color: latencyColor,
            size: 20,
          ),
        ),
        title: Text(
          result.endpoint,
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
        subtitle: result.details != null
            ? Text(
                result.details!,
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: latencyColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: latencyColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                latency != null ? '${latency.toStringAsFixed(0)} ms' : 'N/A',
                style: TextStyle(
                  color: latencyColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Copy endpoint',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result.endpoint));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied: ${result.endpoint}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Input Dialog ───────────────────────────────────────────────────────────

  void _showInputDialog(BuildContext context, MasqueScoutController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Endpoints & Subnets'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      controller.updateInput(_inputController.text);
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
              body: _buildInputSection(context, controller),
            ),
          ),
        );
      },
    );
  }

  // ── Settings Dialog ────────────────────────────────────────────────────────

  void _showSettingsDialog(BuildContext context, MasqueScoutController controller) {
    var workers = controller.config.maxWorkers;
    var timeoutSec = controller.config.timeout.inSeconds;
    var multiPort = controller.config.multiPort;
    var sni = controller.config.sni;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Masque Scout Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Multi-port Switch
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Multi-Port Scanning'),
                      subtitle: const Text('Scan ports: 443, 500, 1701, 4500, 4443, 8443, 8095'),
                      value: multiPort,
                      onChanged: (val) => setDialogState(() => multiPort = val),
                    ),
                    const Divider(),

                    // Concurrency Slider
                    Text('Max Workers ($workers)'),
                    Slider(
                      value: workers.toDouble(),
                      min: 1,
                      max: 50,
                      divisions: 49,
                      label: '$workers',
                      onChanged: (v) => setDialogState(() => workers = v.toInt()),
                    ),

                    // Timeout Slider
                    Text('Timeout ($timeoutSec seconds)'),
                    Slider(
                      value: timeoutSec.toDouble(),
                      min: 1,
                      max: 15,
                      divisions: 14,
                      label: '$timeoutSec s',
                      onChanged: (v) => setDialogState(() => timeoutSec = v.toInt()),
                    ),
                    const Divider(),

                    // SNI
                    TextFormField(
                      initialValue: sni,
                      decoration: const InputDecoration(
                        labelText: 'SNI / Authority',
                        helperText: 'Default: cloudflareaccess.com',
                      ),
                      onChanged: (v) => sni = v.trim(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    controller.updateConfig(
                      maxWorkers: workers,
                      timeout: Duration(seconds: timeoutSec),
                      multiPort: multiPort,
                      sni: sni.isNotEmpty ? sni : 'cloudflareaccess.com',
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Copy Helpers ───────────────────────────────────────────────────────────

  void _copyWorkingEndpoints(BuildContext context, MasqueScoutController controller) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy Clean IP:Port List'),
                subtitle: Text('${controller.workingEndpoints.length} endpoints'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: controller.getWorkingEndpointsText()));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied endpoints to clipboard')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Copy Detailed Results with Latency'),
                subtitle: const Text('Includes protocol, latency, and status details'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: controller.getWorkingEndpointsDetailedText()));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied detailed results to clipboard')),
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

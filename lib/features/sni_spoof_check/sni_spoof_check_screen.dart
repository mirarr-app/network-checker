import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/services/sni_spoof_check_service.dart';
import 'sni_spoof_check_controller.dart';

class SniSpoofCheckScreen extends StatefulWidget {
  const SniSpoofCheckScreen({super.key});

  @override
  State<SniSpoofCheckScreen> createState() => _SniSpoofCheckScreenState();
}

class _SniSpoofCheckScreenState extends State<SniSpoofCheckScreen> {
  late TextEditingController _targetsController;
  late TextEditingController _portsController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _targetsController = TextEditingController();
    _portsController = TextEditingController(text: kDefaultSniPorts.join(','));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _targetsController.dispose();
    _portsController.dispose();
    super.dispose();
  }

  void _onTargetsChanged(String text, SniSpoofCheckController controller) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      controller.updateTargetsText(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SNI Spoof Check'),
        actions: [
          Consumer<SniSpoofCheckController>(
            builder: (context, controller, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.results.isNotEmpty && !controller.isScanning)
                  IconButton(
                    icon: const Icon(Icons.copy_all),
                    tooltip: 'Copy report',
                    onPressed: () => _copyReport(context, controller),
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () => _showSettingsDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Consumer<SniSpoofCheckController>(
        builder: (context, controller, _) {
          return Column(
            children: [
              // Slim top bar: just progress + your IP + status message
              if (controller.isScanning || controller.completedTargets > 0)
                _buildTopBar(context, controller),
              Expanded(
                child: controller.isPreparingScan
                    ? _buildPreparingState(context, controller)
                    : controller.results.isNotEmpty
                        ? _buildResultsList(context, controller)
                        : _buildInputSection(context, controller),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<SniSpoofCheckController>(
        builder: (context, controller, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.results.isNotEmpty && !controller.isScanning) ...[
                FloatingActionButton.small(
                  heroTag: 'sni_toggle_view',
                  onPressed: () => _showInputDialog(context, controller),
                  child: const Icon(Icons.edit),
                ).animate().fadeIn(delay: 200.ms).scale(delay: 200.ms),
                const SizedBox(width: 12),
              ],
              FloatingActionButton.extended(
                heroTag: 'sni_scan_action',
                onPressed: controller.isScanning
                    ? controller.stopScan
                    : controller.parsedTargetCount > 0
                        ? controller.startScan
                        : () => _showInputDialog(context, controller),
                icon: Icon(
                  controller.isScanning
                      ? Icons.stop
                      : controller.parsedTargetCount > 0
                          ? Icons.play_arrow
                          : Icons.add,
                ),
                label: Text(
                  controller.isScanning
                      ? 'Stop'
                      : controller.parsedTargetCount > 0
                          ? 'Scan ${controller.parsedTargetCount} targets'
                          : 'Add targets',
                ),
              ).animate().fadeIn(delay: 100.ms).scale(delay: 100.ms),
            ],
          );
        },
      ),
    );
  }

  // ── Top bar (progress + IP + status) ───────────────────────────────────────

  Widget _buildTopBar(BuildContext context, SniSpoofCheckController controller) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
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
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (controller.userPublicIp != null) ...[
                Icon(Icons.public, size: 14, color: cs.primary),
                const SizedBox(width: 4),
                Text(
                  'Your IP: ${controller.userPublicIp}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontFamily: 'monospace'),
                ),
                const Spacer(),
              ],
              if (controller.statusMessage.isNotEmpty)
                Flexible(
                  child: Text(
                    controller.statusMessage,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  // ── Preparing state ────────────────────────────────────────────────────────

  Widget _buildPreparingState(BuildContext context, SniSpoofCheckController controller) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: cs.primary),
          const SizedBox(height: 24),
          Text(
            controller.statusMessage.isNotEmpty
                ? controller.statusMessage
                : 'Starting scan...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${controller.parsedTargetCount} targets queued',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  // ── Input section ──────────────────────────────────────────────────────────

  Widget _buildInputSection(BuildContext context, SniSpoofCheckController controller) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Disclaimer banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Only God knows how internet works in Iran — results may be inaccurate.',
                    style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Header row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enter domains or IP addresses',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                    const SizedBox(height: 4),
                    Text('One target per line',
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  _targetsController.text = kDefaultSniTargets;
                  controller.updateTargetsText(kDefaultSniTargets);
                },
                icon: const Icon(Icons.list_alt, size: 18),
                label: const Text('Defaults'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Port row: text field + "All Ports" button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _portsController,
                  decoration: InputDecoration(
                    labelText: 'Ports',
                    hintText: '443',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    prefixIcon: const Icon(Icons.lan_outlined, size: 20),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  onChanged: (text) => controller.updatePortsText(text),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  final allPorts = kAllSniPorts.join(',');
                  _portsController.text = allPorts;
                  controller.updatePortsText(allPorts);
                },
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('All Ports'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // IP Check toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.vpn_lock_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('IP Verification', style: TextStyle(color: cs.onSurface))),
                Switch(
                  value: controller.config.enableIpCheck,
                  onChanged: (v) => controller.updateConfig(enableIpCheck: v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Targets input
          Expanded(
            child: TextField(
              controller: _targetsController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: '# Examples:\nhcaptcha.com\nwww.sciencedirect.com\nauth.vercel.com',
                hintMaxLines: 10,
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              onChanged: (text) => _onTargetsChanged(text, controller),
            ),
          ),
          const SizedBox(height: 12),

          if (controller.parsedTargetCount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${controller.parsedTargetCount} targets · ${controller.config.ports.length} port${controller.config.ports.length > 1 ? "s" : ""} each',
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  // ── Results list ───────────────────────────────────────────────────────────

  Widget _buildResultsList(BuildContext context, SniSpoofCheckController controller) {
    final cs = Theme.of(context).colorScheme;
    final results = controller.results;

    final ok = results.where((r) => r.status == SniResultStatus.ok).toList();
    final fail = results.where((r) => r.status == SniResultStatus.fail).toList();
    final error = results.where((r) => r.status == SniResultStatus.error).toList();
    final filtered = results.where((r) => r.status == SniResultStatus.filtered).toList();

    // Check if SNI spoofing is likely open:
    // At least one OK result with a port open and IP verified
    final hasIpVerified = ok.any((r) => r.ipCheckResult?.matched == true);
    final spoofLikelyOpen = ok.isNotEmpty && hasIpVerified;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        // SNI spoofing verdict banner
        if (!controller.isScanning && spoofLikelyOpen)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withValues(alpha: 0.15),
                  Colors.teal.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'SNI Spoofing is likely open',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

        if (!controller.isScanning && ok.isNotEmpty && !spoofLikelyOpen)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ports open, IP unverified',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

        if (ok.isNotEmpty) ...[
          _SectionHeader(title: 'OK — Open ports', count: ok.length, color: Colors.green),
          ...ok.map((r) => _ResultCard(result: r)),
          const SizedBox(height: 16),
        ],
        if (fail.isNotEmpty) ...[
          _SectionHeader(title: 'FAIL — All closed', count: fail.length, color: cs.error),
          ...fail.map((r) => _ResultCard(result: r)),
          const SizedBox(height: 16),
        ],
        if (error.isNotEmpty) ...[
          _SectionHeader(title: 'ERROR — Resolve failed', count: error.length, color: cs.outline),
          ...error.map((r) => _ResultCard(result: r)),
          const SizedBox(height: 16),
        ],
        if (filtered.isNotEmpty) ...[
          _SectionHeader(title: 'FILTERED — Internal IP', count: filtered.length, color: Colors.orange),
          ...filtered.map((r) => _ResultCard(result: r)),
        ],
      ],
    );
  }

  // ── Bottom sheet input dialog ──────────────────────────────────────────────

  void _showInputDialog(BuildContext context, SniSpoofCheckController controller) {
    final textCtrl = TextEditingController(text: controller.targetsText);
    final portsCtrl = TextEditingController(text: controller.portsText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text('Edit Targets', style: Theme.of(context).textTheme.titleLarge)),
                FilledButton.tonalIcon(onPressed: () { textCtrl.text = kDefaultSniTargets; }, icon: const Icon(Icons.list_alt, size: 18), label: const Text('Defaults')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: portsCtrl, decoration: InputDecoration(labelText: 'Ports', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true), style: const TextStyle(fontFamily: 'monospace', fontSize: 14))),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(onPressed: () { portsCtrl.text = kAllSniPorts.join(','); }, icon: const Icon(Icons.select_all, size: 18), label: const Text('All')),
              ]),
              const SizedBox(height: 12),
              Expanded(child: TextField(controller: textCtrl, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, decoration: InputDecoration(hintText: 'One domain or IP per line...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), style: const TextStyle(fontFamily: 'monospace', fontSize: 14))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () { controller.clearAll(); Navigator.pop(context); }, child: const Text('Clear All'))),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: FilledButton.icon(onPressed: () { controller.updateTargetsText(textCtrl.text); controller.updatePortsText(portsCtrl.text); Navigator.pop(context); }, icon: const Icon(Icons.check), label: const Text('Apply'))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Settings dialog ────────────────────────────────────────────────────────

  void _showSettingsDialog(BuildContext context) {
    final controller = Provider.of<SniSpoofCheckController>(context, listen: false);
    final config = controller.config;
    final timeoutCtrl = TextEditingController(text: config.timeout.toString());
    final retriesCtrl = TextEditingController(text: config.retries.toString());
    final concurrencyCtrl = TextEditingController(text: config.concurrency.toString());
    final manualIpCtrl = TextEditingController(text: config.manualIp ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Settings'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: timeoutCtrl, decoration: const InputDecoration(labelText: 'Timeout (seconds)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: retriesCtrl, decoration: const InputDecoration(labelText: 'Retries', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: concurrencyCtrl, decoration: const InputDecoration(labelText: 'Concurrency', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: manualIpCtrl, decoration: const InputDecoration(labelText: 'Manual IP (optional)', hintText: 'Leave empty for auto-detect', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () { controller.updateConfig(timeout: int.tryParse(timeoutCtrl.text), retries: int.tryParse(retriesCtrl.text), concurrency: int.tryParse(concurrencyCtrl.text), manualIp: manualIpCtrl.text.isEmpty ? null : manualIpCtrl.text); Navigator.pop(context); }, child: const Text('Apply')),
        ],
      ),
    );
  }

  void _copyReport(BuildContext context, SniSpoofCheckController controller) {
    Clipboard.setData(ClipboardData(text: controller.getDetailedReport()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report copied to clipboard')));
  }
}

// ─── Reusable widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _SectionHeader({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('$title [$count]', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SniIpResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = switch (result.status) {
      SniResultStatus.ok => Colors.green,
      SniResultStatus.fail => cs.error,
      SniResultStatus.filtered => Colors.orange,
      SniResultStatus.error => cs.outline,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: statusColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: statusColor.withValues(alpha: 0.25))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.target,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.ip.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        result.ip,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (result.ipCheckResult != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: result.ipCheckResult!.matched ? Colors.green.withValues(alpha: 0.15) : cs.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    result.ipCheckResult!.matched ? 'IP Verified' : 'IP Unverified${result.ipCheckResult!.detectedIp != null ? " (${result.ipCheckResult!.detectedIp})" : ""}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: result.ipCheckResult!.matched ? Colors.green : cs.error),
                  ),
                ),
            ],
          ),
          if (result.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(result.errorMessage!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
          if (result.portResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: result.portResults.map((p) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.isOpen ? Colors.green.withValues(alpha: 0.12) : cs.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.isOpen ? Colors.green.withValues(alpha: 0.3) : cs.error.withValues(alpha: 0.15)),
                ),
                child: Text('${p.port}', style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600, color: p.isOpen ? Colors.green : cs.error)),
              );
            }).toList()),
          ],
        ]),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
  }
}

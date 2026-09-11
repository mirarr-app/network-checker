import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/services/cloudflare_fix_service.dart';
import 'cloudflare_fix_controller.dart';

class CloudflareFixScreen extends StatefulWidget {
  const CloudflareFixScreen({super.key});

  @override
  State<CloudflareFixScreen> createState() => _CloudflareFixScreenState();
}

class _CloudflareFixScreenState extends State<CloudflareFixScreen> {
  late TextEditingController _textController;
  late TextEditingController _socksPortController;
  late TextEditingController _httpPortController;
  late TextEditingController _dnsServerController;
  late TextEditingController _remarkSuffixController;
  late TextEditingController _alpnController;
  late TextEditingController _cipherSuitesController;

  late TextEditingController _frag1PacketsController;
  late TextEditingController _frag1LengthsController;
  late TextEditingController _frag1DelaysController;
  late TextEditingController _frag1MaxSplitController;

  late TextEditingController _frag2PacketsController;
  late TextEditingController _frag2LengthsController;
  late TextEditingController _frag2DelaysController;
  late TextEditingController _frag2MaxSplitController;

  bool _showSettings = false;

  static const String _exampleVlessUrl =
      'vless://00000000-0000-0000-0000-000000000000@example.com:443?path=%2Fpath&security=tls&alpn=h3%2Ch2%2Chttp%2F1.1&encryption=none&host=example.com&fp=chrome&type=ws&sni=example.com#CloudflareFixExample';

  @override
  void initState() {
    super.initState();
    final controller = context.read<CloudflareFixController>();
    _textController = TextEditingController(text: controller.inputText);
    _socksPortController = TextEditingController(text: controller.socksPort.toString());
    _httpPortController = TextEditingController(text: controller.httpPort.toString());
    _dnsServerController = TextEditingController(text: controller.dnsServer);
    _remarkSuffixController = TextEditingController(text: controller.remarkSuffix);
    _alpnController = TextEditingController(text: controller.alpnText);
    _cipherSuitesController = TextEditingController(text: controller.cipherSuites);

    _frag1PacketsController = TextEditingController(text: controller.frag1Packets);
    _frag1LengthsController = TextEditingController(text: controller.frag1Lengths);
    _frag1DelaysController = TextEditingController(text: controller.frag1Delays);
    _frag1MaxSplitController = TextEditingController(text: controller.frag1MaxSplit);

    _frag2PacketsController = TextEditingController(text: controller.frag2Packets);
    _frag2LengthsController = TextEditingController(text: controller.frag2Lengths);
    _frag2DelaysController = TextEditingController(text: controller.frag2Delays);
    _frag2MaxSplitController = TextEditingController(text: controller.frag2MaxSplit);
  }

  @override
  void dispose() {
    _textController.dispose();
    _socksPortController.dispose();
    _httpPortController.dispose();
    _dnsServerController.dispose();
    _remarkSuffixController.dispose();
    _alpnController.dispose();
    _cipherSuitesController.dispose();

    _frag1PacketsController.dispose();
    _frag1LengthsController.dispose();
    _frag1DelaysController.dispose();
    _frag1MaxSplitController.dispose();

    _frag2PacketsController.dispose();
    _frag2LengthsController.dispose();
    _frag2DelaysController.dispose();
    _frag2MaxSplitController.dispose();
    super.dispose();
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _textController.text = data.text!;
      if (mounted) {
        context.read<CloudflareFixController>().setInputText(data.text!);
      }
    }
  }

  void _loadExample() {
    _textController.text = _exampleVlessUrl;
    context.read<CloudflareFixController>().setInputText(_exampleVlessUrl);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _syncControllersWithDefaults(CloudflareFixController controller) {
    controller.resetToDefaults();
    _socksPortController.text = controller.socksPort.toString();
    _httpPortController.text = controller.httpPort.toString();
    _dnsServerController.text = controller.dnsServer;
    _remarkSuffixController.text = controller.remarkSuffix;
    _alpnController.text = controller.alpnText;
    _cipherSuitesController.text = controller.cipherSuites;

    _frag1PacketsController.text = controller.frag1Packets;
    _frag1LengthsController.text = controller.frag1Lengths;
    _frag1DelaysController.text = controller.frag1Delays;
    _frag1MaxSplitController.text = controller.frag1MaxSplit;

    _frag2PacketsController.text = controller.frag2Packets;
    _frag2LengthsController.text = controller.frag2Lengths;
    _frag2DelaysController.text = controller.frag2Delays;
    _frag2MaxSplitController.text = controller.frag2MaxSplit;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = context.watch<CloudflareFixController>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high_rounded, color: Colors.amber),
            SizedBox(width: 10),
            Text('Patt\'s Cloudflare Fix'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showSettings ? Icons.tune : Icons.tune_outlined),
            tooltip: 'Toggle Settings',
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Supports VLESS+TLS+WS and VLESS+TLS+xHTTP links only. Note: Your client app must be updated to the latest Xray-core version for compatibility.',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 16),

                // Settings Panel (Collapsible)
                if (_showSettings) _buildSettingsPanel(context, controller),

                // Main Input Card
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'VLESS Share Link',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              children: [
                                TextButton.icon(
                                  onPressed: _pasteFromClipboard,
                                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                                  label: const Text('Paste'),
                                ),
                                TextButton.icon(
                                  onPressed: _loadExample,
                                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                                  label: const Text('Example'),
                                ),
                                if (controller.inputText.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _textController.clear();
                                      controller.clear();
                                    },
                                    tooltip: 'Clear input',
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _textController,
                          maxLines: 4,
                          minLines: 2,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Paste vless://... (VLESS+TLS+WS or VLESS+TLS+xHTTP)',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                          onChanged: (val) => controller.setInputText(val),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: controller.isProcessing
                              ? null
                              : () => controller.transform(),
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              controller.isProcessing
                                  ? 'Transforming...'
                                  : 'Transform to Cloudflare Fix JSON',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 350.ms),

                const SizedBox(height: 16),

                // Error Banner
                if (controller.errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: colorScheme.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            controller.errorMessage!,
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().shake(duration: 300.ms),

                // Results View
                if (controller.results.isNotEmpty) ...[
                  ...controller.results.map((res) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Summary info card
                        Card(
                          elevation: 0,
                          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                _buildSummaryChip(
                                  context,
                                  Icons.label_outlined,
                                  'Remarks',
                                  res.remarks,
                                ),
                                _buildSummaryChip(
                                  context,
                                  Icons.dns_outlined,
                                  'Server',
                                  '${res.address}:${res.port}',
                                ),
                                _buildSummaryChip(
                                  context,
                                  Icons.wifi_tethering_rounded,
                                  'Transport',
                                  res.network,
                                ),
                                _buildSummaryChip(
                                  context,
                                  Icons.lock_outline_rounded,
                                  'SNI',
                                  res.sni,
                                ),
                                _buildSummaryChip(
                                  context,
                                  Icons.fingerprint_rounded,
                                  'Fingerprint',
                                  res.fingerprint,
                                ),
                                _buildSummaryChip(
                                  context,
                                  Icons.alt_route_rounded,
                                  'ALPN',
                                  res.alpn.join(','),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // JSON Code output box
                        Card(
                          elevation: 0,
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Xray Config JSON',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    FilledButton.icon(
                                      onPressed: () => _copyToClipboard(
                                        res.formattedJson,
                                        'Cloudflare Fix JSON',
                                      ),
                                      icon: const Icon(Icons.copy_rounded, size: 16),
                                      label: const Text('Copy JSON'),
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: SelectableText(
                                    res.formattedJson,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPanel(BuildContext context, CloudflareFixController controller) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 550;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with title & Reset button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Configuration & TLS Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _syncControllersWithDefaults(controller),
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('Reset Defaults'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Section 1: TLS & Fingerprint Settings
                Text(
                  'TLS & Fingerprint',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),

                if (isCompact) ...[
                  DropdownButtonFormField<String>(
                    initialValue: kAvailableFingerprints.contains(controller.fingerprint)
                        ? controller.fingerprint
                        : 'unsafe',
                    decoration: const InputDecoration(
                      labelText: 'Fingerprint',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: kAvailableFingerprints
                        .map((fp) => DropdownMenuItem(
                              value: fp,
                              child: Text(fp),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) controller.setFingerprint(val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _alpnController,
                    decoration: const InputDecoration(
                      labelText: 'ALPN (comma separated)',
                      hintText: 'http/1.1',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => controller.setAlpnText(v),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: kAvailableFingerprints.contains(controller.fingerprint)
                              ? controller.fingerprint
                              : 'unsafe',
                          decoration: const InputDecoration(
                            labelText: 'Fingerprint',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: kAvailableFingerprints
                              .map((fp) => DropdownMenuItem(
                                    value: fp,
                                    child: Text(fp),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) controller.setFingerprint(val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _alpnController,
                          decoration: const InputDecoration(
                            labelText: 'ALPN (comma separated)',
                            hintText: 'http/1.1',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => controller.setAlpnText(v),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cipherSuitesController,
                        maxLines: 2,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Cipher Suites',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => controller.setCipherSuites(v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.restore_rounded),
                      tooltip: 'Reset Cipher Suites to default',
                      onPressed: () {
                        controller.resetCipherSuites();
                        _cipherSuitesController.text = controller.cipherSuites;
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Section 2: Finalmask TCP Fragmentation
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Finalmask TCP Fragmentation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Switch(
                      value: controller.enableFinalmask,
                      onChanged: (v) => controller.setEnableFinalmask(v),
                    ),
                  ],
                ),

                if (controller.enableFinalmask) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Packet 1 (tlshello)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (isCompact) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _frag1PacketsController,
                            decoration: const InputDecoration(
                              labelText: 'Packets',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag1Packets(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _frag1LengthsController,
                            decoration: const InputDecoration(
                              labelText: 'Lengths',
                              hintText: '0,104,1',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag1Lengths(v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _frag1DelaysController,
                            decoration: const InputDecoration(
                              labelText: 'Delays',
                              hintText: '0',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag1Delays(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _frag1MaxSplitController,
                            decoration: const InputDecoration(
                              labelText: 'MaxSplit',
                              hintText: '0',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag1MaxSplit(v),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _frag1PacketsController,
                            decoration: const InputDecoration(
                              labelText: 'Packets',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag1Packets(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _frag1LengthsController,
                            decoration: const InputDecoration(
                              labelText: 'Lengths',
                              hintText: '0,104,1',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag1Lengths(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _frag1DelaysController,
                            decoration: const InputDecoration(
                              labelText: 'Delays',
                              hintText: '0',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag1Delays(v),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),
                  Text(
                    'Packet 2 (1-1)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (isCompact) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _frag2PacketsController,
                            decoration: const InputDecoration(
                              labelText: 'Packets',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag2Packets(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _frag2LengthsController,
                            decoration: const InputDecoration(
                              labelText: 'Lengths',
                              hintText: '114,1',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag2Lengths(v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _frag2DelaysController,
                            decoration: const InputDecoration(
                              labelText: 'Delays',
                              hintText: '1',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag2Delays(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _frag2MaxSplitController,
                            decoration: const InputDecoration(
                              labelText: 'MaxSplit',
                              hintText: '11',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag2MaxSplit(v),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _frag2PacketsController,
                            decoration: const InputDecoration(
                              labelText: 'Packets',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag2Packets(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _frag2LengthsController,
                            decoration: const InputDecoration(
                              labelText: 'Lengths',
                              hintText: '114,1',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag2Lengths(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _frag2DelaysController,
                            decoration: const InputDecoration(
                              labelText: 'Delays',
                              hintText: '1',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag2Delays(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _frag2MaxSplitController,
                            decoration: const InputDecoration(
                              labelText: 'MaxSplit',
                              hintText: '11',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => controller.setFrag2MaxSplit(v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Section 3: Ports & DNS
                Text(
                  'Ports & DNS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                if (isCompact) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _socksPortController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'SOCKS Port',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final p = int.tryParse(v);
                            if (p != null) controller.setSocksPort(p);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _httpPortController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'HTTP Port',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final p = int.tryParse(v);
                            if (p != null) controller.setHttpPort(p);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _remarkSuffixController,
                    decoration: const InputDecoration(
                      labelText: 'Remark Suffix',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => controller.setRemarkSuffix(v),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _socksPortController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'SOCKS Port',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final p = int.tryParse(v);
                            if (p != null) controller.setSocksPort(p);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _httpPortController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'HTTP Port',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final p = int.tryParse(v);
                            if (p != null) controller.setHttpPort(p);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _remarkSuffixController,
                          decoration: const InputDecoration(
                            labelText: 'Remark Suffix',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => controller.setRemarkSuffix(v),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _dnsServerController,
                  decoration: const InputDecoration(
                    labelText: 'DNS DoH Server URL',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => controller.setDnsServer(v),
                ),
              ],
            );
          },
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildSummaryChip(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

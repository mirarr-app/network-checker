import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/services/cloudflare_fix_service.dart';
import '../../../core/widgets/responsive_widgets.dart';
import 'add_ech_controller.dart';

class AddEchScreen extends StatefulWidget {
  const AddEchScreen({super.key});

  @override
  State<AddEchScreen> createState() => _AddEchScreenState();
}

class _AddEchScreenState extends State<AddEchScreen> {
  late TextEditingController _textController;
  late TextEditingController _echConfigListController;
  late TextEditingController _socksPortController;
  late TextEditingController _httpPortController;
  late TextEditingController _dnsServerController;
  late TextEditingController _domesticDnsController;
  late TextEditingController _remarkSuffixController;
  late TextEditingController _alpnController;

  bool _showSettings = false;

  static const String _exampleVlessUrl =
      'vless://00000000-0000-0000-0000-000000000000@example.com:443?path=%2Fws&security=tls&alpn=http%2F1.1&encryption=none&host=example.com&fp=chrome&type=ws&sni=example.com#EchSample';

  @override
  void initState() {
    super.initState();
    final controller = context.read<AddEchController>();
    _textController = TextEditingController(text: controller.inputText);
    _echConfigListController = TextEditingController(text: controller.echConfigList);
    _socksPortController = TextEditingController(text: controller.socksPort.toString());
    _httpPortController = TextEditingController(text: controller.httpPort?.toString() ?? '');
    _dnsServerController = TextEditingController(text: controller.dnsServer);
    _domesticDnsController = TextEditingController(text: controller.domesticDns);
    _remarkSuffixController = TextEditingController(text: controller.remarkSuffix);
    _alpnController = TextEditingController(text: controller.alpnText);
  }

  @override
  void dispose() {
    _textController.dispose();
    _echConfigListController.dispose();
    _socksPortController.dispose();
    _httpPortController.dispose();
    _dnsServerController.dispose();
    _domesticDnsController.dispose();
    _remarkSuffixController.dispose();
    _alpnController.dispose();
    super.dispose();
  }

  void _syncControllersWithDefaults(AddEchController controller) {
    controller.resetToDefaults();
    _echConfigListController.text = controller.echConfigList;
    _socksPortController.text = controller.socksPort.toString();
    _httpPortController.text = controller.httpPort?.toString() ?? '';
    _dnsServerController.text = controller.dnsServer;
    _domesticDnsController.text = controller.domesticDns;
    _remarkSuffixController.text = controller.remarkSuffix;
    _alpnController.text = controller.alpnText;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AddEchController>();

    return Scaffold(
      appBar: AdaptiveAppBar(
        title: 'Add ECH',
        actions: [
          IconButton(
            icon: Icon(_showSettings ? Icons.tune : Icons.tune_outlined),
            tooltip: 'Toggle Settings',
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            _buildHeaderCard(context),
            const SizedBox(height: 16),

            // Input Card
            _buildInputCard(context, controller),
            const SizedBox(height: 16),

            // Settings Card (Collapsible)
            if (_showSettings) ...[
              _buildSettingsCard(context, controller),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            _buildActionButtons(context, controller),
            const SizedBox(height: 20),

            // Error Banner
            if (controller.errorMessage != null) ...[
              _buildErrorBanner(context, controller.errorMessage!),
              const SizedBox(height: 20),
            ],

            // Output Results Section
            if (controller.results.isNotEmpty)
              _buildOutputSection(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.enhanced_encryption_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Encrypted Client Hello (ECH)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Inject ECH configuration into proxy URIs (VLESS, VMess, Trojan, SS) or Xray JSON configs with FakeDNS and domestic routing rules.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(BuildContext context, AddEchController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Input Proxy Config or Share Link',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _textController.text = _exampleVlessUrl;
                      controller.setInputText(_exampleVlessUrl);
                    },
                    icon: const Icon(Icons.lightbulb_outline, size: 16),
                    label: const SingleLineButtonLabel(
                      'Sample',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              onChanged: (val) => controller.setInputText(val),
              maxLines: 6,
              minLines: 3,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Paste share link (vless://, vmess://, trojan://, ss://) or Xray JSON config...',
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste, size: 20),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null && data!.text!.isNotEmpty) {
                      _textController.text = data.text!;
                      controller.setInputText(data.text!);
                    }
                  },
                  tooltip: 'Paste from clipboard',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, AddEchController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'ECH & TLS Settings',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _syncControllersWithDefaults(controller),
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const SingleLineButtonLabel(
                      'Reset',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ECH Config List Field
            TextFormField(
              controller: _echConfigListController,
              decoration: InputDecoration(
                labelText: 'ECH Config List',
                hintText: 'cloudflare-ech.com+udp://1.1.1.1',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => controller.setEchConfigList(val),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                'cloudflare-ech.com+udp://1.1.1.1',
                'cloudflare-ech.com+tcp://1.1.1.1',
                'cloudflare-ech.com+udp://8.8.8.8',
              ].map((echVal) {
                return ActionChip(
                  label: Text(echVal, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    _echConfigListController.text = echVal;
                    controller.setEchConfigList(echVal);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Fingerprint Dropdown
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: controller.fingerprint,
              decoration: InputDecoration(
                labelText: 'uTLS Fingerprint',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: kAvailableFingerprints.map((fp) {
                return DropdownMenuItem(
                  value: fp,
                  child: Text(fp, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) controller.setFingerprint(val);
              },
            ),
            const SizedBox(height: 16),

            // ALPN
            TextFormField(
              controller: _alpnController,
              decoration: InputDecoration(
                labelText: 'ALPN (comma separated)',
                hintText: 'http/1.1, h2, h3',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => controller.setAlpnText(val),
            ),
            const SizedBox(height: 16),

            // Ports Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _socksPortController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'SOCKS Port',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      final p = int.tryParse(val);
                      if (p != null) controller.setSocksPort(p);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _httpPortController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'HTTP Port (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      final trimmed = val.trim();
                      if (trimmed.isEmpty) {
                        controller.setHttpPort(null);
                      } else {
                        final p = int.tryParse(trimmed);
                        if (p != null) controller.setHttpPort(p);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // DNS Servers
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dnsServerController,
                    decoration: InputDecoration(
                      labelText: 'DoH Server',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) => controller.setDnsServer(val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _domesticDnsController,
                    decoration: InputDecoration(
                      labelText: 'Domestic DNS',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) => controller.setDomesticDns(val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Remark Suffix
            TextFormField(
              controller: _remarkSuffixController,
              decoration: InputDecoration(
                labelText: 'Remark Suffix',
                hintText: '-ech',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => controller.setRemarkSuffix(val),
            ),
            const SizedBox(height: 8),

            // Allow Insecure
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow Insecure TLS', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Skip server certificate verification', style: TextStyle(fontSize: 12)),
              value: controller.allowInsecure,
              onChanged: (val) => controller.setAllowInsecure(val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AddEchController controller) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: controller.isProcessing ? null : () => controller.transform(),
            icon: controller.isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.enhanced_encryption),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                controller.isProcessing ? 'Generating...' : 'Add ECH & Generate JSON',
                maxLines: 1,
              ),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            _textController.clear();
            controller.clear();
          },
          icon: const Icon(Icons.clear_all),
          label: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Clear', maxLines: 1),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSection(BuildContext context, AddEchController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final results = controller.results;
    final selectedResult = controller.currentResult;

    if (selectedResult == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // If multiple results, show chips
            if (results.length > 1) ...[
              Text(
                'Generated Configs (${results.length})',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(results.length, (idx) {
                    final res = results[idx];
                    final isSelected = idx == controller.selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(res.remarks),
                        selected: isSelected,
                        onSelected: (_) => controller.setSelectedIndex(idx),
                      ),
                    );
                  }),
                ),
              ),
              const Divider(height: 24),
            ],

            // Result Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedResult.remarks,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ECH-Enabled Xray JSON Profile',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: selectedResult.formattedJson));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ECH Config copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Copy', maxLines: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metadata Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (selectedResult.proxyCount > 1)
                  Chip(
                    avatar: const Icon(Icons.hub_outlined, size: 16),
                    label: Text('${selectedResult.proxyCount} ECH Nodes Configured'),
                  ),
                Chip(
                  avatar: const Icon(Icons.vpn_key_outlined, size: 16),
                  label: Text('${selectedResult.protocol.toUpperCase()} / ${selectedResult.network.toUpperCase()}'),
                ),
                Chip(
                  avatar: const Icon(Icons.dns_outlined, size: 16),
                  label: Text('${selectedResult.address}:${selectedResult.port}'),
                ),
                Chip(
                  avatar: const Icon(Icons.security, size: 16),
                  label: Text('SNI: ${selectedResult.sni}'),
                ),
                Chip(
                  avatar: const Icon(Icons.fingerprint, size: 16),
                  label: Text('FP: ${selectedResult.fingerprint}'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // JSON Viewer Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                selectedResult.formattedJson,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/responsive_widgets.dart';
import 'load_balancer_controller.dart';

class LoadBalancerScreen extends StatefulWidget {
  const LoadBalancerScreen({super.key});

  @override
  State<LoadBalancerScreen> createState() => _LoadBalancerScreenState();
}

class _LoadBalancerScreenState extends State<LoadBalancerScreen> {
  final Map<int, TextEditingController> _textControllers = {};
  late TextEditingController _probeUrlController;
  late TextEditingController _probeIntervalController;
  late TextEditingController _remarksController;
  late TextEditingController _socksPortController;
  late TextEditingController _httpPortController;

  @override
  void initState() {
    super.initState();
    final controller = context.read<LoadBalancerController>();
    _probeUrlController = TextEditingController(text: controller.probeUrl);
    _probeIntervalController = TextEditingController(text: controller.probeInterval);
    _remarksController = TextEditingController(text: controller.remarks);
    _socksPortController = TextEditingController(text: controller.socksPort.toString());
    _httpPortController = TextEditingController(text: controller.httpPort?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _probeUrlController.dispose();
    _probeIntervalController.dispose();
    _remarksController.dispose();
    _socksPortController.dispose();
    _httpPortController.dispose();
    super.dispose();
  }

  TextEditingController _getControllerForNode(int index, String value) {
    if (!_textControllers.containsKey(index)) {
      _textControllers[index] = TextEditingController(text: value);
    } else if (_textControllers[index]!.text != value) {
      _textControllers[index]!.text = value;
    }
    return _textControllers[index]!;
  }

  void _showBulkImportDialog(BuildContext context, LoadBalancerController controller) {
    final bulkTextController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const DialogTitleRow(
          icon: Icons.playlist_add_rounded,
          title: 'Bulk Import Configs / URIs',
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste multiple share links (one per line) or complete Xray JSON configs below:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bulkTextController,
                  maxLines: 8,
                  minLines: 4,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'vless://...\nvless://...\n{\n  "outbounds": [...]\n}',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const SingleLineButtonLabel('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final text = bulkTextController.text.trim();
              if (text.isNotEmpty) {
                _textControllers.clear();
                controller.addBulkInputs(text);
              }
              Navigator.of(dialogCtx).pop();
            },
            icon: const Icon(Icons.check, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Import', maxLines: 1),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AdaptiveAppBar(
        title: 'Load Balancer',
      ),
      body: Consumer<LoadBalancerController>(
        builder: (context, controller, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                _buildHeaderCard(context),
                const SizedBox(height: 16),

                // Nodes Section
                _buildNodesSection(context, controller),
                const SizedBox(height: 16),

                // Balancer & Observatory Settings Card
                _buildSettingsCard(context, controller),
                const SizedBox(height: 16),

                // Port Settings Section
                _buildPortSettingsSection(context, controller),
                const SizedBox(height: 20),

                // Action Buttons
                _buildActionButtons(context, controller),
                const SizedBox(height: 20),

                // Error Message if present
                if (controller.errorMessage != null) ...[
                  _buildErrorBanner(context, controller.errorMessage!),
                  const SizedBox(height: 20),
                ],

                // Output JSON Section
                if (controller.generatedJson != null)
                  _buildOutputSection(context, controller.generatedJson!),
              ],
            ),
          );
        },
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
                Icons.balance_rounded,
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
                    'Xray Least-Ping Load Balancer',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Combine multiple Xray JSON configs or proxy URIs (VLESS, VMess, Trojan, SS, SOCKS, HTTP) into a single least-ping balanced configuration with Observatory latency probing.',
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

  Widget _buildNodesSection(BuildContext context, LoadBalancerController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final configs = controller.inputConfigs;

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
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Proxy Nodes',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${configs.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _showBulkImportDialog(context, controller),
                    icon: const Icon(Icons.playlist_add_rounded, size: 18),
                    label: const SingleLineButtonLabel('Bulk Import'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: configs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final textCtrl = _getControllerForNode(index, configs[index]);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.vpn_lock_outlined,
                          size: 18,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Node #${index + 1}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (configs.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: colorScheme.error,
                            onPressed: () {
                              _textControllers.remove(index);
                              controller.removeInputConfig(index);
                            },
                            tooltip: 'Remove Node',
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textCtrl,
                      onChanged: (val) => controller.setInputConfig(index, val),
                      maxLines: 3,
                      minLines: 1,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: 'Share link (vless://, vmess://, etc.) or Xray JSON config...',
                        filled: true,
                        fillColor: colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.content_paste, size: 18),
                          onPressed: () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null) {
                              textCtrl.text = data!.text!;
                              controller.setInputConfig(index, data.text!);
                            }
                          },
                          tooltip: 'Paste from clipboard',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => controller.addInputConfig(),
              icon: const Icon(Icons.add, size: 18),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Add Node Slot', maxLines: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, LoadBalancerController controller) {
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
            Text(
              'Balancer & Observatory Settings',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Balancer Strategy Dropdown
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: controller.strategyType,
              decoration: InputDecoration(
                labelText: 'Balancer Strategy',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'leastPing',
                  child: Text(
                    'leastPing (Lowest Latency - Recommended)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'roundRobin',
                  child: Text(
                    'roundRobin (Sequential Cycling)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'random',
                  child: Text(
                    'random (Random Node)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) controller.setStrategyType(val);
              },
            ),
            const SizedBox(height: 16),

            // Probe URL
            TextFormField(
              controller: _probeUrlController,
              decoration: InputDecoration(
                labelText: 'Observatory Probe URL',
                hintText: 'https://www.google.com/generate_204',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (val) => controller.setProbeUrl(val),
            ),
            const SizedBox(height: 16),

            // Probe Interval
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _probeIntervalController,
                  decoration: InputDecoration(
                    labelText: 'Probe Interval',
                    hintText: '3m, 1m, 30s',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (val) => controller.setProbeInterval(val),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: ['1m', '3m', '5m'].map((interval) {
                    return ActionChip(
                      label: Text(interval, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _probeIntervalController.text = interval;
                        controller.setProbeInterval(interval);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Remarks
            TextFormField(
              controller: _remarksController,
              decoration: InputDecoration(
                labelText: 'Profile Remarks (Name)',
                hintText: 'leastping',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (val) => controller.setRemarks(val),
            ),
            const SizedBox(height: 8),

            // Concurrency Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Probe Concurrency', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Probe all candidate nodes concurrently for fast latency updates',
                style: TextStyle(fontSize: 12),
              ),
              value: controller.enableConcurrency,
              onChanged: (val) => controller.setEnableConcurrency(val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortSettingsSection(BuildContext context, LoadBalancerController controller) {
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
            Text(
              'Local Inbound Ports',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _socksPortController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'SOCKS Port',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, LoadBalancerController controller) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: controller.isGenerating ? null : () => controller.generateBalancer(),
            icon: controller.isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.bolt),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                controller.isGenerating ? 'Generating...' : 'Generate Balancer Config',
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
            _textControllers.clear();
            controller.clear();
            _probeUrlController.text = controller.probeUrl;
            _probeIntervalController.text = controller.probeInterval;
            _remarksController.text = controller.remarks;
            _socksPortController.text = controller.socksPort.toString();
            _httpPortController.text = controller.httpPort?.toString() ?? '';
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

  Widget _buildOutputSection(BuildContext context, String jsonContent) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Generated Balancer JSON',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: jsonContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Balancer JSON copied to clipboard'),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                jsonContent,
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

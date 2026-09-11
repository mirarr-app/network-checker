import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'chain_controller.dart';

class ChainScreen extends StatefulWidget {
  const ChainScreen({super.key});

  @override
  State<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends State<ChainScreen> {
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getControllerForHop(int index, String value) {
    if (!_textControllers.containsKey(index)) {
      _textControllers[index] = TextEditingController(text: value);
    } else if (_textControllers[index]!.text != value) {
      _textControllers[index]!.text = value;
    }
    return _textControllers[index]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chain (Multi-Hop Config)'),
      ),
      body: Consumer<ChainController>(
        builder: (context, controller, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Feature Header Card
                _buildHeaderCard(context),
                const SizedBox(height: 16),

                // Nodes Section
                _buildNodesSection(context, controller),
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
                Icons.alt_route_rounded,
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
                    'Multi-Hop Proxy Chain',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chain VLESS, VMess, Trojan, SS, SOCKS, or HTTP nodes (Share Links or Xray JSON configs) from Local → Entry → Exit → Internet.',
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

  Widget _buildNodesSection(BuildContext context, ChainController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hopLinks = controller.hopLinks;

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
                Text(
                  'Chain Hops',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                if (hopLinks.length == 2)
                  IconButton.filledTonal(
                    onPressed: () => controller.swapHops(0, 1),
                    icon: const Icon(Icons.swap_vert, size: 20),
                    tooltip: 'Swap Entry & Exit',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: hopLinks.length,
              separatorBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(
                        Icons.south,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              ),
              itemBuilder: (context, index) {
                final isEntry = index == 0;
                final isExit = index == hopLinks.length - 1;

                String label;
                if (isEntry) {
                  label = 'Entry Node (Hop 0)';
                } else if (isExit) {
                  label = 'Exit Node (Hop ${hopLinks.length - 1})';
                } else {
                  label = 'Intermediate Node (Hop $index)';
                }

                final textCtrl = _getControllerForHop(index, hopLinks[index]);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isEntry
                              ? Icons.login
                              : isExit
                                  ? Icons.logout
                                  : Icons.compare_arrows,
                          size: 18,
                          color: isEntry
                              ? Colors.green
                              : isExit
                                  ? Colors.orange
                                  : colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (!isEntry && !isExit && hopLinks.length > 2)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: colorScheme.error,
                            onPressed: () {
                              controller.removeHopLink(index);
                            },
                            tooltip: 'Remove Hop',
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textCtrl,
                      onChanged: (val) => controller.setHopLink(index, val),
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
                              controller.setHopLink(index, data.text!);
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => controller.addHopLink(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Intermediate Hop'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortSettingsSection(BuildContext context, ChainController controller) {
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
                    initialValue: controller.socksPort.toString(),
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
                    initialValue: controller.httpPort.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'HTTP Port',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (val) {
                      final p = int.tryParse(val);
                      if (p != null) controller.setHttpPort(p);
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

  Widget _buildActionButtons(BuildContext context, ChainController controller) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: controller.isGenerating ? null : () => controller.generateChain(),
            icon: controller.isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.bolt),
            label: Text(controller.isGenerating ? 'Generating...' : 'Generate Xray Profile'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
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
          },
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                Text(
                  'Generated Xray Profile JSON',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: jsonContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Xray Profile copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
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

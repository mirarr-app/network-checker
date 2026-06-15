import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'vless_config_modifier_controller.dart';

class VlessConfigModifierScreen extends StatefulWidget {
  const VlessConfigModifierScreen({super.key});

  @override
  State<VlessConfigModifierScreen> createState() => _VlessConfigModifierScreenState();
}

class _VlessConfigModifierScreenState extends State<VlessConfigModifierScreen> {
  final _configsController = TextEditingController();
  final _ipsController = TextEditingController();

  @override
  void dispose() {
    _configsController.dispose();
    _ipsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VLESS Config Modifier'),
        actions: [
          Consumer<VlessConfigModifierController>(
            builder: (context, controller, _) {
              if (controller.generatedConfigs.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.clear_all),
                  tooltip: 'Clear all',
                  onPressed: () {
                    controller.clear();
                    _configsController.clear();
                    _ipsController.clear();
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<VlessConfigModifierController>(
        builder: (context, controller, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Original configs input
                _buildInputCard(
                  context,
                  title: 'VLESS Configs',
                  hint: 'Paste your VLESS configs here (one per line)\n\nvless://uuid@host:port?params#name',
                  controller: _configsController,
                  onChanged: controller.setConfigsInput,
                  icon: Icons.vpn_key_outlined,
                ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 16),
                
                // IPs input
                _buildInputCard(
                  context,
                  title: 'IP Addresses',
                  hint: 'Enter IPs (one per line)\n\nSupports:\n• Single IPs: 1.1.1.1\n• Custom ports: 1.1.1.1:2096\n• IP ranges: 1.1.1.1-1.1.1.10\n• CIDR notation: 192.168.1.0/24',
                  controller: _ipsController,
                  onChanged: controller.setIpsInput,
                  icon: Icons.dns_outlined,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 20),
                
                // Error message
                if (controller.errorMessage != null) ...[
                  Container(
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
                            controller.errorMessage!,
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().shake(),
                  const SizedBox(height: 16),
                ],
                
                // Progress message
                if (controller.isProcessing && controller.progressMessage.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            controller.progressMessage,
                            style: TextStyle(color: colorScheme.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),
                  const SizedBox(height: 16),
                ],
                
                // Generate button
                FilledButton.icon(
                  onPressed: controller.isProcessing 
                      ? null 
                      : () => controller.generateConfigs(),
                  icon: controller.isProcessing 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.autorenew),
                  label: Text(controller.isProcessing ? 'Generating...' : 'Generate Configs'),
                ).animate().fadeIn(delay: 200.ms).scale(delay: 200.ms),
                
                const SizedBox(height: 24),
                
                // Generated configs output
                if (controller.generatedConfigs.isNotEmpty) ...[
                  _buildOutputSection(context, controller),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputCard(
    BuildContext context, {
    required String title,
    required String hint,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  fontSize: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputSection(BuildContext context, VlessConfigModifierController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayedConfigs = controller.displayedConfigs;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with stats and copy button
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.output,
                size: 20,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generated Configs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${controller.parsedConfigs.length} config(s) × ${controller.ipCount} IP(s) = ${controller.totalGeneratedCount} total',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                await controller.copyAllToClipboard();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${controller.totalGeneratedCount} configs copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_all, size: 18),
              label: const Text('Copy All'),
            ),
          ],
        ).animate().fadeIn(delay: 300.ms),
        
        const SizedBox(height: 16),
        
        // Configs list with pagination
        Card(
          child: Column(
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedConfigs.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: colorScheme.outlineVariant,
                ),
                itemBuilder: (context, index) {
                  final config = displayedConfigs[index];
                  return _ConfigListItem(
                    key: ValueKey('config_$index'),
                    config: config,
                    index: index,
                  );
                },
              ),
              // Load more button
              if (controller.hasMore) ...[
                Divider(height: 1, color: colorScheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        'Showing ${displayedConfigs.length} of ${controller.totalGeneratedCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: controller.loadMore,
                        child: const Text('Load More'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0),
      ],
    );
  }
}

class _ConfigListItem extends StatelessWidget {
  final String config;
  final int index;

  const _ConfigListItem({
    super.key,
    required this.config,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Extract the host from config for display
    String displayHost = '';
    final atIndex = config.indexOf('@');
    final colonAfterHost = config.indexOf(':', atIndex);
    if (atIndex != -1 && colonAfterHost != -1) {
      displayHost = config.substring(atIndex + 1, colonAfterHost);
    }

    return InkWell(
      onTap: () => _copyConfig(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Index badge
            Container(
              width: 40,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Config text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayHost,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    config,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Copy button
            IconButton(
              icon: Icon(
                Icons.copy,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => _copyConfig(context),
              tooltip: 'Copy config',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyConfig(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: config));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Config copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive_widgets.dart';
import 'dns_scanner_controller.dart';

class DnsScannerScreen extends StatelessWidget {
  const DnsScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveAppBar(
        title: 'DNS Scanner',
        actions: [
          Consumer<DnsScannerController>(
            builder: (context, controller, _) {
              return PopupMenuButton<DnsSortMode>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort by',
                onSelected: controller.setSortMode,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: DnsSortMode.name,
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          size: 18,
                          color: controller.sortMode == DnsSortMode.name
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        const Text('Sort by Name'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: DnsSortMode.latency,
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          size: 18,
                          color: controller.sortMode == DnsSortMode.latency
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        const Text('Sort by Latency'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: DnsSortMode.status,
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          size: 18,
                          color: controller.sortMode == DnsSortMode.status
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        const Text('Sort by Status'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Consumer<DnsScannerController>(
            builder: (context, controller, _) {
              if (controller.scannedCount > 0 && !controller.isScanning) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset results',
                  onPressed: controller.resetResults,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<DnsScannerController>(
        builder: (context, controller, _) {
          return Column(
            children: [
              // Progress and stats bar
              if (controller.isScanning || controller.scannedCount > 0)
                _buildProgressBar(context, controller),

              // DNS provider list
              Expanded(
                child: _buildProviderList(context, controller),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<DnsScannerController>(
        builder: (context, controller, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add custom DNS FAB
              FloatingActionButton.small(
                heroTag: 'add_dns',
                onPressed: () => _showAddCustomDnsDialog(context),
                child: const Icon(Icons.add),
              ).animate().fadeIn(delay: 200.ms).scale(delay: 200.ms),
              const SizedBox(height: 12),
              // Scan all FAB
              FloatingActionButton.extended(
                heroTag: 'scan_all',
                onPressed: controller.isScanning
                    ? controller.stopScanning
                    : controller.scanAll,
                icon: Icon(controller.isScanning ? Icons.stop : Icons.play_arrow),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(controller.isScanning ? 'Stop' : 'Scan All', maxLines: 1),
                ),
              ).animate().fadeIn(delay: 100.ms).scale(delay: 100.ms),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, DnsScannerController controller) {
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
              value: controller.isScanning ? controller.progress : 1.0,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip(
                context,
                icon: Icons.check_circle,
                label: '${controller.successCount}',
                color: colorScheme.success,
              ),
              _buildStatChip(
                context,
                icon: Icons.cancel,
                label: '${controller.failureCount}',
                color: colorScheme.error,
              ),
              _buildStatChip(
                context,
                icon: Icons.pending,
                label: '${controller.totalCount - controller.scannedCount}',
                color: colorScheme.outline,
              ),
            ],
          ),
          // Show fastest DNS if available
          if (controller.fastestProviders.isNotEmpty && !controller.isScanning) ...[
            const SizedBox(height: 12),
            _buildFastestBadge(context, controller),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildFastestBadge(BuildContext context, DnsScannerController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    final fastest = controller.fastestProviders.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.tertiaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events,
            color: colorScheme.onPrimaryContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Fastest: ',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '${fastest.provider.name} (${fastest.result?.latencyMs}ms)',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildProviderList(BuildContext context, DnsScannerController controller) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 8),
      itemCount: controller.providers.length,
      itemBuilder: (context, index) {
        final provider = controller.providers[index];
        return _DnsProviderListItem(
          provider: provider,
          index: index,
          onTap: () => _showDnsInfoSheet(context, provider),
          onDelete: provider.provider.isCustom
              ? () => controller.removeCustomDns(provider.primaryAddress)
              : null,
        );
      },
    );
  }

  void _showDnsInfoSheet(BuildContext context, DnsProviderState providerState) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = providerState.provider;

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
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.85,
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
                    // Header with name and status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.name,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (providerState.result?.latencyMs != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getLatencyColor(colorScheme, providerState.result!.latencyMs!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${providerState.result!.latencyMs}ms',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _getLatencyTextColor(colorScheme, providerState.result!.latencyMs!),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Info fields
                    _buildInfoField(
                      context,
                      label: 'Primary Address',
                      value: provider.addresses.isNotEmpty ? provider.addresses.first : '-',
                      icon: Icons.dns,
                    ),
                    if (provider.addresses.length > 1)
                      _buildInfoField(
                        context,
                        label: 'Secondary Address',
                        value: provider.addresses[1],
                        icon: Icons.dns_outlined,
                      ),
                    if (provider.dohUrl != null)
                      _buildInfoField(
                        context,
                        label: 'DoH URL',
                        value: provider.dohUrl!,
                        icon: Icons.lock,
                      ),
                    if (provider.website.isNotEmpty)
                      _buildInfoField(
                        context,
                        label: 'Website',
                        value: provider.website,
                        icon: Icons.language,
                      ),
                    const SizedBox(height: 24),
                    // Scan button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          context.read<DnsScannerController>().scanSingle(providerState.primaryAddress);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.speed),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Test Latency', maxLines: 1),
                        ),
                      ),
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
                      fontFamily: label.contains('Address') || label.contains('URL') ? 'monospace' : null,
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

  Color _getLatencyColor(ColorScheme colorScheme, int latencyMs) {
    if (latencyMs < 50) return colorScheme.successContainer;
    if (latencyMs < 100) return colorScheme.primaryContainer;
    if (latencyMs < 200) return colorScheme.warningContainer;
    return colorScheme.errorContainer;
  }

  Color _getLatencyTextColor(ColorScheme colorScheme, int latencyMs) {
    if (latencyMs < 50) return colorScheme.success;
    if (latencyMs < 100) return colorScheme.primary;
    if (latencyMs < 200) return colorScheme.warning;
    return colorScheme.error;
  }

  void _showAddCustomDnsDialog(BuildContext context) {
    final controller = context.read<DnsScannerController>();
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom DNS'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter DNS server IP addresses, one per line:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  autofocus: true,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: '8.8.8.8\n1.1.1.1\n9.9.9.9',
                    prefixIcon: Icon(Icons.dns),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\n]')),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Cancel', maxLines: 1),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  controller.addCustomDns(textController.text);
                  Navigator.of(context).pop();
                }
              },
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Add', maxLines: 1),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DnsProviderListItem extends StatelessWidget {
  final DnsProviderState provider;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _DnsProviderListItem({
    required this.provider,
    required this.index,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget tile = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status icon
              _buildStatusIcon(colorScheme),
              const SizedBox(width: 12),
              // Provider info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.provider.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.primaryAddress,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (!provider.provider.isCustom) ...[
                      const SizedBox(height: 4),
                      Text(
                        provider.provider.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (provider.result != null && !provider.result!.success) ...[
                      const SizedBox(height: 4),
                      Text(
                        provider.result!.errorMessage ?? 'Failed',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.error,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Latency or custom badge
              if (provider.provider.isCustom && provider.status == DnsCheckStatus.idle)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Custom',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                )
              else if (provider.result?.latencyMs != null)
                _buildLatencyBadge(context, provider.result!.latencyMs!),
            ],
          ),
        ),
      ),
    );

    // Add dismissible for custom DNS
    if (onDelete != null) {
      tile = Dismissible(
        key: Key(provider.primaryAddress),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete, color: colorScheme.onErrorContainer),
        ),
        onDismissed: (_) => onDelete!(),
        child: tile,
      );
    }

    return tile
        .animate()
        .fadeIn(delay: Duration(milliseconds: 20 * (index % 20)))
        .slideX(begin: 0.1, end: 0, delay: Duration(milliseconds: 20 * (index % 20)));
  }

  Widget _buildStatusIcon(ColorScheme colorScheme) {
    switch (provider.status) {
      case DnsCheckStatus.idle:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.dns_outlined,
            color: colorScheme.outline,
            size: 20,
          ),
        );
      case DnsCheckStatus.checking:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case DnsCheckStatus.success:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.successContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.check_circle,
            color: colorScheme.success,
            size: 24,
          ),
        );
      case DnsCheckStatus.failure:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.cancel,
            color: colorScheme.error,
            size: 24,
          ),
        );
    }
  }

  Widget _buildLatencyBadge(BuildContext context, int latencyMs) {
    final colorScheme = Theme.of(context).colorScheme;

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
}


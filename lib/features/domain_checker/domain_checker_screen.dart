import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/database.dart' show Preset;
import 'domain_checker_controller.dart';

class DomainCheckerScreen extends StatelessWidget {
  const DomainCheckerScreen({super.key});

  bool get _isDesktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Domain Checker'),
        actions: [
          Consumer<DomainCheckerController>(
            builder: (context, controller, _) {
              final goodDomains = controller.domains
                  .where((d) => d.status == CheckStatus.success)
                  .map((d) => d.domain)
                  .toList();

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (goodDomains.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.copy_all),
                      tooltip: 'Copy good domains',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: goodDomains.join('\n')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${goodDomains.length} domains copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  if (controller.checkedCount > 0 && !controller.isChecking)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Reset results',
                      onPressed: controller.resetResults,
                    ),
                  if (!controller.isChecking)
                    IconButton(
                      icon: const Icon(Icons.restart_alt),
                      tooltip: 'Reset database',
                      onPressed: () => _showResetDatabaseDialog(context, controller),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<DomainCheckerController>(
        builder: (context, controller, _) {
          if (controller.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Column(
            children: [
              // Presets Row
              _buildPresetsBar(context, controller),
              
              // Preset Action Bar (edit mode toggle)
              _buildPresetActionBar(context, controller),

              // Progress and stats bar
              if (controller.isChecking || controller.checkedCount > 0)
                _buildProgressBar(context, controller),
              
              // Domain list
              Expanded(
                child: _isDesktop 
                    ? _buildDesktopLayout(context, controller)
                    : _buildMobileLayout(context, controller),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<DomainCheckerController>(
        builder: (context, controller, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add domain FAB
              FloatingActionButton.small(
                heroTag: 'add_domain',
                onPressed: () => _showAddDomainDialog(context),
                child: const Icon(Icons.add),
              ).animate().fadeIn(delay: 200.ms).scale(delay: 200.ms),
              const SizedBox(width: 12),
              // Check all FAB
              FloatingActionButton.extended(
                heroTag: 'check_all',
                onPressed: controller.isChecking 
                    ? controller.stopChecking 
                    : controller.checkAll,
                icon: Icon(controller.isChecking ? Icons.stop : Icons.play_arrow),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(controller.isChecking ? 'Stop' : 'Check All', maxLines: 1),
                ),
              ).animate().fadeIn(delay: 100.ms).scale(delay: 100.ms),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPresetsBar(BuildContext context, DomainCheckerController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Icon(Icons.folder_special, size: 20, color: colorScheme.primary),
            const SizedBox(width: 12),
            ...controller.presets.map((preset) => _buildPresetChip(context, controller, preset)),
            _buildNewPresetButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(BuildContext context, DomainCheckerController controller, Preset preset) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = controller.activePreset?.id == preset.id;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: isActive ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => controller.selectPreset(preset),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  preset.name,
                  style: TextStyle(
                    color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                if (isActive && !preset.isSystem) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showEditPresetNameDialog(context, controller, preset),
                    child: Icon(
                      Icons.edit,
                      size: 14,
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showDeletePresetDialog(context, controller, preset),
                    child: Icon(
                      Icons.delete,
                      size: 14,
                      color: colorScheme.error,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewPresetButton(BuildContext context, DomainCheckerController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showCreatePresetDialog(context, controller),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 15,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'New Preset',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetActionBar(BuildContext context, DomainCheckerController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    final preset = controller.activePreset;
    if (preset == null) return const SizedBox.shrink();

    final isEditMode = controller.isEditMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isEditMode 
            ? colorScheme.errorContainer.withValues(alpha: 0.12) 
            : colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(
            color: isEditMode 
                ? colorScheme.error.withValues(alpha: 0.25) 
                : colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEditMode ? Icons.edit_attributes : Icons.settings_ethernet,
            size: 18,
            color: isEditMode ? colorScheme.error : colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEditMode 
                  ? 'Edit Mode: Tap domains to delete' 
                  : '${preset.name} Preset (${controller.totalCount} domains)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isEditMode ? colorScheme.error : colorScheme.onSurface,
              ),
            ),
          ),
          if (isEditMode) ...[
            // Delete All Button (Soft tinted pill)
            Material(
              color: colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showDeleteAllDomainsDialog(context, controller, preset),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_sweep,
                        size: 16,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Delete All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Done Button (Filled primary pill)
            Material(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => controller.setEditMode(false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check,
                        size: 16,
                        color: colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // Edit List Button (Soft tinted primary pill)
            Material(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => controller.setEditMode(true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_note,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Edit List',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showResetDatabaseDialog(BuildContext context, DomainCheckerController controller) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Database'),
          content: const Text(
            'This will delete all custom presets and domains, and restore default domains. Are you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await controller.resetDatabase();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Database reset successfully'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePresetDialog(BuildContext context, DomainCheckerController controller) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Preset'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Preset Name (e.g. Cloudflare)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  await controller.createPreset(name);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showEditPresetNameDialog(BuildContext context, DomainCheckerController controller, Preset preset) {
    final textController = TextEditingController(text: preset.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Preset'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'New Preset Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  await controller.editPresetName(preset.id, name);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _showDeletePresetDialog(BuildContext context, DomainCheckerController controller, Preset preset) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Preset'),
          content: Text('Are you sure you want to delete the preset "${preset.name}" and all its domains?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () async {
                await controller.deletePreset(preset.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAllDomainsDialog(BuildContext context, DomainCheckerController controller, Preset preset) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Domains'),
          content: Text('Are you sure you want to delete all domains in "${preset.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () async {
                await controller.deleteAllDomainsInActivePreset();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressBar(BuildContext context, DomainCheckerController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          // Progress indicator
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: controller.isChecking ? controller.progress : 1.0,
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Stats row
          _buildStatChip(
            context,
            icon: Icons.check_circle,
            label: '${controller.successCount}',
            color: colorScheme.success,
          ),
          const SizedBox(width: 16),
          _buildStatChip(
            context,
            icon: Icons.cancel,
            label: '${controller.failureCount}',
            color: colorScheme.error,
          ),
          const SizedBox(width: 16),
          _buildStatChip(
            context,
            icon: Icons.pending,
            label: '${controller.totalCount - controller.checkedCount}',
            color: colorScheme.outline,
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
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
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, DomainCheckerController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (int i = 0; i < controller.domains.length; i++)
            _DomainChip(
              domain: controller.domains[i],
              index: i,
              isEditMode: controller.isEditMode,
              onTap: controller.isEditMode
                  ? () => controller.removeDomain(controller.domains[i].domain)
                  : () => controller.checkSingle(controller.domains[i].domain),
              onDelete: () => controller.removeDomain(controller.domains[i].domain),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, DomainCheckerController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 480 ? 2 : (constraints.maxWidth < 720 ? 3 : 4);
        final textScaler = MediaQuery.textScalerOf(context);
        final itemHeight = textScaler.scale(92).clamp(92.0, 140.0);
        final itemWidth = (constraints.maxWidth - 16 - (crossAxisCount - 1) * 8) / crossAxisCount;
        final childAspectRatio = (itemWidth / itemHeight).clamp(1.1, 2.2);
        
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 80, top: 8, left: 8, right: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: controller.domains.length,
          itemBuilder: (context, index) {
            final domain = controller.domains[index];
            return _DomainGridItem(
              domain: domain,
              index: index,
              isEditMode: controller.isEditMode,
              onTap: controller.isEditMode
                  ? () => controller.removeDomain(domain.domain)
                  : () => controller.checkSingle(domain.domain),
              onDelete: () => controller.removeDomain(domain.domain),
            );
          },
        );
      },
    );
  }

  void _showAddDomainDialog(BuildContext context) {
    final controller = context.read<DomainCheckerController>();
    final textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Domains'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: textController,
              autofocus: true,
              maxLines: 8,
              minLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Enter domains, one per line:\nexample.com\ngoogle.com\ncloudflare.com',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.language),
                ),
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final lines = textController.text
                    .split('\n')
                    .map((line) => line.trim())
                    .where((line) => line.isNotEmpty)
                    .toList();
                if (lines.isNotEmpty) {
                  for (final domain in lines) {
                    controller.addDomain(domain);
                  }
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

/// Compact chip design for desktop
class _DomainChip extends StatelessWidget {
  final DomainCheckState domain;
  final int index;
  final bool isEditMode;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _DomainChip({
    required this.domain,
    required this.index,
    required this.isEditMode,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    final (bgColor, borderColor) = switch (domain.status) {
      CheckStatus.success => (
        colorScheme.success.withValues(alpha: 0.15),
        colorScheme.success.withValues(alpha: 0.4),
      ),
      CheckStatus.failure => (
        colorScheme.error.withValues(alpha: 0.15),
        colorScheme.error.withValues(alpha: 0.4),
      ),
      CheckStatus.checking => (
        colorScheme.primary.withValues(alpha: 0.1),
        colorScheme.primary.withValues(alpha: 0.3),
      ),
      CheckStatus.idle => (
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    };

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusIndicator(colorScheme, isEditMode),
              const SizedBox(width: 8),
              Text(
                domain.domain,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              if (domain.status == CheckStatus.success && domain.result?.responseTimeMs != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${domain.result!.responseTimeMs}ms',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.success,
                    ),
                  ),
                ),
              ],
              if (!domain.isDefault) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.star,
                  size: 12,
                  color: colorScheme.tertiary.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 10 * (index % 50)))
        .slideX(begin: 0.05, end: 0, delay: Duration(milliseconds: 10 * (index % 50)));
  }

  Widget _buildStatusIndicator(ColorScheme colorScheme, bool isEditMode) {
    const double size = 16;
    
    if (isEditMode) {
      return Icon(
        Icons.remove_circle,
        color: colorScheme.error,
        size: size,
      );
    }
    
    return switch (domain.status) {
      CheckStatus.idle => Icon(
        Icons.circle_outlined,
        color: colorScheme.outline,
        size: size,
      ),
      CheckStatus.checking => SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      CheckStatus.success => Icon(
        Icons.check_circle,
        color: colorScheme.success,
        size: size,
      ),
      CheckStatus.failure => Icon(
        Icons.cancel,
        color: colorScheme.error,
        size: size,
      ),
    };
  }
}

/// Card design for mobile
class _DomainGridItem extends StatelessWidget {
  final DomainCheckState domain;
  final int index;
  final bool isEditMode;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _DomainGridItem({
    required this.domain,
    required this.index,
    required this.isEditMode,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    final cardColor = switch (domain.status) {
      CheckStatus.success => colorScheme.success.withValues(alpha: 0.15),
      CheckStatus.failure => colorScheme.error.withValues(alpha: 0.15),
      _ => null,
    };
    
    return Card(
      color: cardColor,
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatusIcon(colorScheme, isEditMode),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  domain.domain,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (domain.status == CheckStatus.success && domain.result?.responseTimeMs != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${domain.result!.responseTimeMs}ms',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.success,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 15 * (index % 30)))
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), delay: Duration(milliseconds: 15 * (index % 30)));
  }

  Widget _buildStatusIcon(ColorScheme colorScheme, bool isEditMode) {
    const double iconSize = 24;
    
    if (isEditMode) {
      return Icon(
        Icons.remove_circle,
        color: colorScheme.error,
        size: iconSize,
      );
    }
    
    return switch (domain.status) {
      CheckStatus.idle => Icon(
        Icons.circle_outlined,
        color: colorScheme.outline,
        size: iconSize,
      ),
      CheckStatus.checking => SizedBox(
        width: iconSize,
        height: iconSize,
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      CheckStatus.success => Icon(
        Icons.check_circle,
        color: colorScheme.success,
        size: iconSize,
      ),
      CheckStatus.failure => Icon(
        Icons.cancel,
        color: colorScheme.error,
        size: iconSize,
      ),
    };
  }
}

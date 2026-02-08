import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../../core/services/cdn_config_scanner.dart';
import '../../core/theme/app_theme.dart';
import 'cdn_config_scan_controller.dart';

class CdnConfigScanScreen extends StatefulWidget {
  const CdnConfigScanScreen({super.key});

  @override
  State<CdnConfigScanScreen> createState() => _CdnConfigScanScreenState();
}

class _CdnConfigScanScreenState extends State<CdnConfigScanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<CdnConfigScanController>();
      controller.initialize();
      controller.fetchLatestVersion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CDN Config Scan'),
        actions: [
          Consumer<CdnConfigScanController>(
            builder: (context, controller, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.results.isNotEmpty && !controller.isScanning)
                    IconButton(
                      icon: const Icon(Icons.copy_all),
                      tooltip: 'Copy results',
                      onPressed: () => _showCopyDialog(context, controller),
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
      body: Consumer<CdnConfigScanController>(
        builder: (context, controller, _) {
          return Column(
            children: [
              // Stepper indicator
              _buildStepIndicator(context, controller),
              
              // Main content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentStep(context, controller),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context, CdnConfigScanController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = [
      ('Binary', Icons.download),
      ('Config', Icons.code),
      ('IPs', Icons.list),
      ('Scan', Icons.speed),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == controller.currentStep.index;
          final isCompleted = index < controller.currentStep.index;
          final (label, icon) = steps[index];
          
          return Expanded(
            child: Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted || isActive
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                GestureDetector(
                  onTap: isCompleted
                      ? () => controller.goToStep(CdnScanStep.values[index])
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? colorScheme.primaryContainer
                          : isCompleted
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCompleted ? Icons.check : icon,
                          size: 16,
                          color: isActive
                              ? colorScheme.onPrimaryContainer
                              : isCompleted
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            color: isActive
                                ? colorScheme.onPrimaryContainer
                                : isCompleted
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context, CdnConfigScanController controller) {
    switch (controller.currentStep) {
      case CdnScanStep.binarySetup:
        return _BinarySetupStep(key: const ValueKey('binary'));
      case CdnScanStep.configInput:
        return _ConfigInputStep(key: const ValueKey('config'));
      case CdnScanStep.ipInput:
        return _IpInputStep(key: const ValueKey('ip'));
      case CdnScanStep.scanning:
        return _ScanningStep(key: const ValueKey('scan'));
    }
  }

  void _showCopyDialog(BuildContext context, CdnConfigScanController controller) {
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
                subtitle: const Text('IPs with latency info'),
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

  void _showSettingsDialog(BuildContext context) {
    final controller = context.read<CdnConfigScanController>();

    showDialog(
      context: context,
      builder: (context) {
        return _SettingsDialog(
          initialConfig: controller.scanConfig,
          installedVersion: controller.installedVersion,
          onRedownload: () {
            Navigator.pop(context);
            controller.goToStep(CdnScanStep.binarySetup);
          },
        );
      },
    ).then((newConfig) {
      if (newConfig != null) {
        controller.updateScanConfig(
          concurrentInstances: newConfig.concurrentInstances,
          timeout: newConfig.timeout,
          testUrl: newConfig.testUrl,
          basePort: newConfig.basePort,
        );
      }
    });
  }
}

/// Binary Setup Step
class _BinarySetupStep extends StatelessWidget {
  const _BinarySetupStep({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<CdnConfigScanController>(
      builder: (context, controller, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Platform info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.computer, color: colorScheme.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Platform',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                          Text(
                            controller.platformDisplayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Status card
              Expanded(
                child: _buildStatusContent(context, controller),
              ),

              // Action button
              _buildActionButton(context, controller),
            ],
          ),
        ).animate().fadeIn();
      },
    );
  }

  Widget _buildStatusContent(BuildContext context, CdnConfigScanController controller) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (controller.binaryState) {
      case BinaryDownloadState.checking:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text('Checking xray installation...',
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ],
          ),
        );

      case BinaryDownloadState.installed:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: colorScheme.primary, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xray Installed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Version: ${controller.installedVersion ?? 'Unknown'}',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                await controller.deleteXray();
                await controller.fetchLatestVersion();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Download different version'),
            ),
          ],
        );

      case BinaryDownloadState.notInstalled:
        return _VersionSelectionWidget(controller: controller);

      case BinaryDownloadState.downloading:
      case BinaryDownloadState.extracting:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                value: controller.downloadProgress,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                controller.binaryState == BinaryDownloadState.downloading
                    ? 'Downloading xray...'
                    : 'Extracting and setting up...',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                '${(controller.downloadProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        );

      case BinaryDownloadState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'Download Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                controller.downloadError ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controller.fetchLatestVersion,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildActionButton(BuildContext context, CdnConfigScanController controller) {
    switch (controller.binaryState) {
      case BinaryDownloadState.installed:
        return FilledButton.icon(
          onPressed: controller.nextStep,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Continue to Config'),
        );

      case BinaryDownloadState.notInstalled:
        return FilledButton.icon(
          onPressed: controller.versionToDownload != null &&
                  controller.versionToDownload!.isNotEmpty
              ? controller.downloadXray
              : null,
          icon: const Icon(Icons.download),
          label: Text(controller.versionToDownload != null
              ? 'Download ${controller.versionToDownload}'
              : 'Download Xray'),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

/// Config Input Step
class _ConfigInputStep extends StatefulWidget {
  const _ConfigInputStep({super.key});

  @override
  State<_ConfigInputStep> createState() => _ConfigInputStepState();
}

class _ConfigInputStepState extends State<_ConfigInputStep> {
  late TextEditingController _configController;

  @override
  void initState() {
    super.initState();
    final controller = context.read<CdnConfigScanController>();
    _configController = TextEditingController(text: controller.configJson);
  }

  @override
  void dispose() {
    _configController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<CdnConfigScanController>(
      builder: (context, controller, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with file picker
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xray Config JSON',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Paste config or select file',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _pickConfigFile(controller),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Open File'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Config text field
              Expanded(
                child: TextField(
                  controller: _configController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: '{\n  "inbounds": [...],\n  "outbounds": [...],\n  ...\n}',
                    hintMaxLines: 10,
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: controller.configError,
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  onChanged: controller.updateConfigJson,
                ),
              ),
              const SizedBox(height: 16),

              // Parsed info
              if (controller.isConfigValid)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Config Valid',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Outbound Address: ${controller.originalAddress}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Inbound Port: ${controller.originalPort}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.1, end: 0),

              const SizedBox(height: 16),

              // Navigation buttons
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.previousStep,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: controller.isConfigValid ? controller.nextStep : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continue to IPs'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn();
      },
    );
  }

  Future<void> _pickConfigFile(CdnConfigScanController controller) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await controller.loadConfigFromFile(file);
        _configController.text = controller.configJson;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $e')),
        );
      }
    }
  }
}

/// IP Input Step
class _IpInputStep extends StatefulWidget {
  const _IpInputStep({super.key});

  @override
  State<_IpInputStep> createState() => _IpInputStepState();
}

class _IpInputStepState extends State<_IpInputStep> {
  late TextEditingController _ipController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final controller = context.read<CdnConfigScanController>();
    _ipController = TextEditingController(text: controller.ipInput);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _ipController.dispose();
    super.dispose();
  }

  void _onIpInputChanged(String text, CdnConfigScanController controller) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      controller.updateIpInput(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<CdnConfigScanController>(
      builder: (context, controller, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter IP Addresses',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'One IP or CIDR range per line',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final clipboardData = await Clipboard.getData('text/plain');
                      if (clipboardData?.text != null) {
                        _ipController.text = clipboardData!.text!;
                        controller.updateIpInput(clipboardData.text!);
                      }
                    },
                    icon: const Icon(Icons.paste, size: 18),
                    label: const Text('Paste'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // IP text field
              Expanded(
                child: TextField(
                  controller: _ipController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: '# Examples:\n104.18.0.0/24\n172.64.0.1\n172.64.0.2',
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
                  onChanged: (text) => _onIpInputChanged(text, controller),
                ),
              ),
              const SizedBox(height: 16),

              // IP count info
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
                          'Parsed ${controller.parsedIpCount} IP addresses',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.1, end: 0),

              const SizedBox(height: 16),

              // Navigation buttons
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.previousStep,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: controller.parsedIpCount > 0 ? controller.nextStep : null,
                      icon: const Icon(Icons.play_arrow),
                      label: Text('Start Scan (${controller.parsedIpCount} IPs)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn();
      },
    );
  }
}

/// Scanning Step
class _ScanningStep extends StatelessWidget {
  const _ScanningStep({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<CdnConfigScanController>(
      builder: (context, controller, _) {
        return Column(
          children: [
            // Progress bar
            _buildProgressBar(context, controller),

            // Results
            Expanded(
              child: controller.results.isEmpty
                  ? _buildEmptyState(context, controller)
                  : _buildResultsList(context, controller),
            ),

            // Action button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.isScanning ? null : controller.previousStep,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: controller.isScanning
                        ? FilledButton.icon(
                            onPressed: controller.stopScan,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop Scan'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.error,
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: controller.parsedIpCount > 0
                                ? controller.startScan
                                : null,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Scan Again'),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ).animate().fadeIn();
      },
    );
  }

  Widget _buildProgressBar(BuildContext context, CdnConfigScanController controller) {
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
              value: controller.isPreparingScan ? null : controller.progress,
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
            ],
          ),
        ],
      ),
    );
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

  Widget _buildEmptyState(BuildContext context, CdnConfigScanController controller) {
    final colorScheme = Theme.of(context).colorScheme;

    // Show error if there's a scan error
    if (controller.scanError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 24),
              Text(
                'Scan Failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
                ),
                child: Text(
                  controller.scanError!,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onErrorContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  controller.clearScanError();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.isPreparingScan || controller.isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              controller.isPreparingScan ? 'Starting xray instances...' : 'Scanning IPs...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Testing ${controller.parsedIpCount} IP addresses',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'No working IPs found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, CdnConfigScanController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    final results = controller.results;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final latencyColor = _getLatencyColor(colorScheme, result.latencyMs);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: latencyColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: latencyColor,
                  ),
                ),
              ),
            ),
            title: Text(
              result.ip,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              '${result.latencyMs?.toStringAsFixed(0) ?? 'N/A'}ms',
              style: TextStyle(
                color: latencyColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result.ip));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied: ${result.ip}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Color _getLatencyColor(ColorScheme colorScheme, double? latencyMs) {
    if (latencyMs == null) return colorScheme.outline;
    if (latencyMs < 500) return colorScheme.success;
    if (latencyMs < 1000) return Colors.orange;
    return colorScheme.error;
  }
}

/// Version selection widget for binary setup
class _VersionSelectionWidget extends StatefulWidget {
  final CdnConfigScanController controller;

  const _VersionSelectionWidget({required this.controller});

  @override
  State<_VersionSelectionWidget> createState() => _VersionSelectionWidgetState();
}

class _VersionSelectionWidgetState extends State<_VersionSelectionWidget> {
  late TextEditingController _customVersionController;

  @override
  void initState() {
    super.initState();
    _customVersionController = TextEditingController(text: widget.controller.customVersion);
  }

  @override
  void dispose() {
    _customVersionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = widget.controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: colorScheme.error, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xray Not Installed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Choose a version to download',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Version selection toggle
        Row(
          children: [
            Expanded(
              child: _VersionOptionTile(
                title: 'Latest Version',
                subtitle: controller.isFetchingLatest
                    ? 'Fetching...'
                    : controller.latestVersion ?? 'Unknown',
                isSelected: !controller.useCustomVersion,
                onTap: () => controller.setUseCustomVersion(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VersionOptionTile(
                title: 'Custom Version',
                subtitle: 'Enter manually',
                isSelected: controller.useCustomVersion,
                onTap: () => controller.setUseCustomVersion(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Custom version input (shown when custom is selected)
        if (controller.useCustomVersion)
          TextField(
            controller: _customVersionController,
            decoration: InputDecoration(
              labelText: 'Version Tag',
              hintText: 'e.g., v24.12.18',
              helperText: 'Enter the exact GitHub release tag (format: vYY.MM.DD)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.tag),
            ),
            onChanged: controller.setCustomVersion,
          ).animate().fadeIn().slideY(begin: -0.1, end: 0),

        // Refresh button for latest version
        if (!controller.useCustomVersion && controller.downloadError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton.icon(
              onPressed: controller.fetchLatestVersion,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry fetching latest'),
            ),
          ),
      ],
    );
  }
}

class _VersionOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _VersionOptionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 20,
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings Dialog
class _SettingsDialog extends StatefulWidget {
  final CdnScanConfig initialConfig;
  final String? installedVersion;
  final VoidCallback onRedownload;

  const _SettingsDialog({
    required this.initialConfig,
    this.installedVersion,
    required this.onRedownload,
  });

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late TextEditingController _instancesController;
  late TextEditingController _timeoutController;
  late TextEditingController _testUrlController;
  late TextEditingController _basePortController;
  int? _parallelCount;

  @override
  void initState() {
    super.initState();
    _instancesController = TextEditingController(
        text: widget.initialConfig.concurrentInstances.toString());
    _timeoutController = TextEditingController(
        text: widget.initialConfig.timeout.inSeconds.toString());
    _testUrlController =
        TextEditingController(text: widget.initialConfig.testUrl);
    _basePortController =
        TextEditingController(text: widget.initialConfig.basePort.toString());
    _instancesController.addListener(_onInstancesChanged);
    _onInstancesChanged();
  }

  @override
  void dispose() {
    _instancesController.removeListener(_onInstancesChanged);
    _instancesController.dispose();
    _timeoutController.dispose();
    _testUrlController.dispose();
    _basePortController.dispose();
    super.dispose();
  }

  void _onInstancesChanged() {
    final parsed = int.tryParse(_instancesController.text);
    if (parsed == _parallelCount) return;
    setState(() {
      _parallelCount = parsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 400 ? screenWidth * 0.95 : 400.0;
    final cpuCores = Platform.numberOfProcessors;
    final baseCores = cpuCores > 0 ? cpuCores : 1;
    final defaultParallel = baseCores * 2;
    final warnThreshold = baseCores * 8;
    final showWarning =
        _parallelCount != null && _parallelCount! > warnThreshold;

    return AlertDialog(
      title: const Text('Scan Settings'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Version info
              if (widget.installedVersion != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: Text('Xray ${widget.installedVersion}'),
                  trailing: TextButton(
                    onPressed: widget.onRedownload,
                    child: const Text('Change'),
                  ),
                ),
                const Divider(),
              ],
              
              TextField(
                controller: _instancesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Parallel Tests',
                  helperText: 'Default: ${defaultParallel} (2 x CPU cores)',
                ),
              ),
              if (showWarning) ...[
                const SizedBox(height: 8),
                Text(
                  'Warning: Very high parallelism can overload the system.',
                  style: TextStyle(
                    color: colorScheme.tertiary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _timeoutController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Timeout (seconds)',
                  helperText: 'Max time to wait for each IP test',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _testUrlController,
                decoration: const InputDecoration(
                  labelText: 'Test URL',
                  helperText: 'URL to test connectivity',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _basePortController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Base Port',
                  helperText: 'Starting port for xray instances',
                ),
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
            final newConfig = CdnScanConfig(
              concurrentInstances:
                  int.tryParse(_instancesController.text) ?? defaultParallel,
              timeout: Duration(
                  seconds: int.tryParse(_timeoutController.text) ?? 10),
              testUrl: _testUrlController.text.isNotEmpty
                  ? _testUrlController.text
                  : 'https://www.gstatic.com/generate_204',
              basePort: int.tryParse(_basePortController.text) ?? 10808,
            );
            Navigator.pop(context, newConfig);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}


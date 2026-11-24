import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/responsive_widgets.dart';
import 'sms_encoder_controller.dart';

class SmsEncoderScreen extends StatefulWidget {
  const SmsEncoderScreen({super.key});

  @override
  State<SmsEncoderScreen> createState() => _SmsEncoderScreenState();
}

class _SmsEncoderScreenState extends State<SmsEncoderScreen> {
  final _encodeInputController = TextEditingController();
  final _decodeInputController = TextEditingController();

  @override
  void dispose() {
    _encodeInputController.dispose();
    _decodeInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveAppBar(
        title: 'SMS Encoder',
        actions: [
          Consumer<SmsEncoderController>(
            builder: (context, controller, _) {
              if (controller.encodedText.isNotEmpty ||
                  controller.decodedText.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.clear_all),
                  tooltip: 'Clear all',
                  onPressed: () {
                    controller.clear();
                    _encodeInputController.clear();
                    _decodeInputController.clear();
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<SmsEncoderController>(
        builder: (context, controller, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encoder Section
                _buildEncoderCard(context, controller)
                    .animate()
                    .fadeIn()
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 24),

                // Decoder Section
                _buildDecoderCard(context, controller)
                    .animate(delay: 100.ms)
                    .fadeIn()
                    .slideY(begin: 0.1, end: 0),


        
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEncoderCard(BuildContext context, SmsEncoderController controller) {
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
                  child: Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Encode (English → Persian)',
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
              controller: _encodeInputController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter English text to encode...',
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
                fontSize: 14,
              ),
              onChanged: controller.setInputForEncoding,
            ),
            if (controller.encodedText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Encoded Result:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await controller.copyEncodedToClipboard();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Encoded text copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Copy', maxLines: 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  controller.encodedText,
                  style: TextStyle(
                    fontFamily: 'MonoVazir',
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDecoderCard(BuildContext context, SmsEncoderController controller) {
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
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.lock_open_outlined,
                    size: 20,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Decode (Persian → English)',
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
              controller: _decodeInputController,
              maxLines: 3,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'Enter Persian text to decode...',
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
                fontFamily: 'MonoVazir',
                fontSize: 16,
              ),
              onChanged: controller.setInputForDecoding,
            ),
            if (controller.decodedText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Decoded Result:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await controller.copyDecodedToClipboard();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Decoded text copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Copy', maxLines: 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  controller.decodedText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/widgets/responsive_widgets.dart';

const _githubUrl = 'https://github.com/mirarr-app/network-checker';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _copied = false;

  Future<void> _launchUrl() async {
    final uri = Uri.parse(_githubUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(const ClipboardData(text: _githubUrl));
    if (mounted) {
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL copied to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDrawerScope = HomeDrawerScope.maybeOf(context) != null;

    final body = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/duckie.png',
                width: 96,
                height: 96,
                fit: BoxFit.contain,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
            const SizedBox(height: 24),

            // App name
            Text(
              'Network Checker',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 100.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 8),

            // Version
            Text(
              'Version $appVersion',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 150.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 32),

            // URL with launch and copy buttons
            Builder(
              builder: (context) {
                final textScaler = MediaQuery.textScalerOf(context);
                final isNarrow = (MediaQuery.sizeOf(context).width / textScaler.scale(1.0)) < 550;
                final urlFontSize = isNarrow ? 12.0 : 14.0;
                final padding = isNarrow ? 12.0 : 20.0;
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: isNarrow ? 12 : 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: isNarrow
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.code, size: 16, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: GestureDetector(
                                    onTap: _launchUrl,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SelectableText(
                                        _githubUrl,
                                        style: TextStyle(
                                          fontSize: urlFontSize,
                                          fontFamily: 'monospace',
                                          color: colorScheme.primary,
                                          decoration: TextDecoration.underline,
                                          decorationColor: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _launchUrl,
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Open', maxLines: 1),
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonalIcon(
                                  onPressed: _copied ? null : _copyUrl,
                                  icon: Icon(
                                    _copied ? Icons.check : Icons.copy,
                                    size: 16,
                                  ),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(_copied ? 'Copied!' : 'Copy', maxLines: 1),
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.code, size: 20, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Flexible(
                              child: GestureDetector(
                                onTap: _launchUrl,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SelectableText(
                                    _githubUrl,
                                    style: TextStyle(
                                      fontSize: urlFontSize,
                                      fontFamily: 'monospace',
                                      color: colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                      decorationColor: colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            FilledButton.tonalIcon(
                              onPressed: _launchUrl,
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Open', maxLines: 1),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              onPressed: _copied ? null : _copyUrl,
                              icon: Icon(
                                _copied ? Icons.check : Icons.copy,
                                size: 18,
                              ),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(_copied ? 'Copied!' : 'Copy', maxLines: 1),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                );
              },
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 24),

          
          ],
        ),
      ),
    );

    if (hasDrawerScope) {
      return Scaffold(
        appBar: const AdaptiveAppBar(title: 'About'),
        body: body,
      );
    }
    return body;
  }
}

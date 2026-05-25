import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/services/version_check_service.dart';
import '../../core/widgets/custom_title_bar.dart';
import '../about/about_screen.dart';
import '../cdn_config_scan/cdn_config_scan_screen.dart';
import '../dns_hunter/dns_hunter_screen.dart';
import '../dns_scanner/dns_scanner_screen.dart';
import '../domain_checker/domain_checker_screen.dart';
import '../edge_ip_checker/edge_ip_checker_screen.dart';
import '../sms_encoder/sms_encoder_screen.dart';
import '../vless_config_modifier/vless_config_modifier_screen.dart';
import '../netlify_generator/netlify_generator_screen.dart';
import '../akamai_scan/akamai_scan_screen.dart';
import '../sni_spoof_check/sni_spoof_check_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _versionCheckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    if (_versionCheckDone || !mounted) return;
    _versionCheckDone = true;
    final latest = await checkForUpdate(appVersion);
    if (!mounted) return;
    if (latest != null) {
      _showUpdateDialog(latest);
    }
  }

  Future<void> _showUpdateDialog(String latestVersion) async {
    final context = this.context;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.amber),
            SizedBox(width: 8),
            Text('Update available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version of Network Checker is available.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Current: $appVersion  →  Latest: $latestVersion',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              final uri = Uri.parse(releasesPageUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open releases'),
          ),
        ],
      ),
    );
  }

  // CDN Scan is available on desktop (Linux/Windows) and Android
  static final bool _showCdnScan = Platform.isLinux || Platform.isWindows || Platform.isAndroid;
  // SMS Encoder is only available on Android
  static final bool _showSmsEncoder = Platform.isAndroid;
  // About page: desktop and Android (via drawer)
  static final bool _showAbout = Platform.isLinux || Platform.isWindows || Platform.isMacOS || Platform.isAndroid;

  // Mobile & Desktop: same screen list (drawer on mobile, rail on desktop)
  List<Widget> get _screens => [
    const DomainCheckerScreen(),
    const DnsScannerScreen(),
    const DnsHunterScreen(),
    const EdgeIpCheckerScreen(),
    const AkamaiScanScreen(),
    const SniSpoofCheckScreen(),
    const VlessConfigModifierScreen(),
    const NetlifyGeneratorScreen(),
    if (_showSmsEncoder) const SmsEncoderScreen(),
    if (_showCdnScan) const CdnConfigScanScreen(),
    if (_showAbout) const AboutScreen(),
  ];

  List<Widget> get _desktopScreens => _screens;

  List<NavigationRailDestination> get _railDestinations => [
    const NavigationRailDestination(
      icon: Icon(Icons.language_outlined),
      selectedIcon: Icon(Icons.language),
      label: Text('Domains'),
    ),
    const NavigationRailDestination(
      icon: Icon(Icons.dns_outlined),
      selectedIcon: Icon(Icons.dns),
      label: Text('DNS'),
    ),
    const NavigationRailDestination(
      icon: Icon(Icons.radar_outlined),
      selectedIcon: Icon(Icons.radar),
      label: Text('Hunter'),
    ),
    const NavigationRailDestination(
      icon: Icon(Icons.router_outlined),
      selectedIcon: Icon(Icons.router),
      label: Text('Edge'),
    ),
    const NavigationRailDestination(
      icon: Icon(Icons.cloud_sync_outlined),
      selectedIcon: Icon(Icons.cloud_sync),
      label: Text('Akamai'),
    ),
    const NavigationRailDestination(
      icon: Icon(Icons.fingerprint_outlined),
      selectedIcon: Icon(Icons.fingerprint),
      label: Text('SNI Check'),
    ),
    const NavigationRailDestination(
      icon: Icon(Icons.vpn_key_outlined),
      selectedIcon: Icon(Icons.vpn_key),
      label: Text('VLESS'),
    ),
    const NavigationRailDestination(
      icon: Icon(Icons.bolt_outlined),
      selectedIcon: Icon(Icons.bolt),
      label: Text('Netlify'),
    ),
    if (_showSmsEncoder)
      const NavigationRailDestination(
        icon: Icon(Icons.sms_outlined),
        selectedIcon: Icon(Icons.sms),
        label: Text('SMS'),
      ),
    if (_showCdnScan)
      const NavigationRailDestination(
        icon: Icon(Icons.speed_outlined),
        selectedIcon: Icon(Icons.speed),
        label: Text('CDN Scan'),
      ),
    if (_showAbout)
      const NavigationRailDestination(
        icon: Icon(Icons.info_outline),
        selectedIcon: Icon(Icons.info),
        label: Text('About'),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use NavigationRail for wider screens (tablet/desktop)
        final isWideScreen = constraints.maxWidth >= 600;

        if (isWideScreen) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_selectedIndex),
              child: _screens[_selectedIndex],
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            left: 8,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              child: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                tooltip: 'Open menu',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final colorScheme = Theme.of(context).colorScheme;
    var index = 0;
    final items = <_DrawerItem>[
      _DrawerItem(icon: Icons.language, label: 'Domains', index: index++),
      _DrawerItem(icon: Icons.dns, label: 'DNS', index: index++),
      _DrawerItem(icon: Icons.radar, label: 'Hunter', index: index++),
      _DrawerItem(icon: Icons.router, label: 'Edge', index: index++),
      _DrawerItem(icon: Icons.cloud_sync, label: 'Akamai', index: index++),
      _DrawerItem(icon: Icons.fingerprint, label: 'SNI Check', index: index++),
      _DrawerItem(icon: Icons.vpn_key, label: 'VLESS', index: index++),
      _DrawerItem(icon: Icons.bolt, label: 'Netlify', index: index++),
      if (_showSmsEncoder) _DrawerItem(icon: Icons.sms, label: 'SMS', index: index++),
      if (_showCdnScan) _DrawerItem(icon: Icons.speed, label: 'CDN Scan', index: index++),
      if (_showAbout) _DrawerItem(icon: Icons.info, label: 'About', index: index++),
    ];

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Premium modern header
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 20,
              20,
              20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.primaryContainer.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.network_check_rounded,
                    size: 36,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Network Checker',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v$appVersion',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Staggered list items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = _selectedIndex == item.index;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedIndex = item.index);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: colorScheme.primary.withValues(alpha: 0.15),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Left Indicator Strip for active item
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 4,
                            height: isSelected ? 20 : 0,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(width: isSelected ? 12 : 0),

                          // Icon
                          Icon(
                            item.icon,
                            size: 22,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 16),

                          // Label
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ),

                          // Chevron trailing arrow for active
                          if (isSelected)
                            Icon(
                              Icons.arrow_right_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: (30 * index).ms, duration: 300.ms).slideX(begin: -0.05, end: 0, curve: Curves.easeOutCubic);
              },
            ),
          ),
        ],
      ),
    );}

  Widget _buildDesktopLayout() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCustomTitleBar = Platform.isLinux || Platform.isWindows;

    return Scaffold(
      body: Column(
        children: [
          if (hasCustomTitleBar) const CustomTitleBar(),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  minWidth: 96,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.network_check,
                            size: 28,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Network\nChecker',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations: _railDestinations,
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2, end: 0),
                VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: colorScheme.outlineVariant,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_selectedIndex),
                      child: _desktopScreens[_selectedIndex],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String label;
  final int index;

  _DrawerItem({required this.icon, required this.label, required this.index});
}

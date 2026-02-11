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
    const VlessConfigModifierScreen(),
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
      icon: Icon(Icons.vpn_key_outlined),
      selectedIcon: Icon(Icons.vpn_key),
      label: Text('VLESS'),
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
      _DrawerItem(icon: Icons.vpn_key, label: 'VLESS', index: index++),
      if (_showSmsEncoder) _DrawerItem(icon: Icons.sms, label: 'SMS', index: index++),
      if (_showCdnScan) _DrawerItem(icon: Icons.speed, label: 'CDN Scan', index: index++),
      if (_showAbout) _DrawerItem(icon: Icons.info, label: 'About', index: index++),
    ];

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.network_check, size: 48, color: colorScheme.onPrimaryContainer),
                const SizedBox(height: 8),
                Text(
                  'NetCheck',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          ...items.map((item) => ListTile(
                leading: Icon(item.icon, color: _selectedIndex == item.index ? colorScheme.primary : null),
                title: Text(item.label),
                selected: _selectedIndex == item.index,
                onTap: () {
                  setState(() => _selectedIndex = item.index);
                  Navigator.pop(context);
                },
              )),
        ],
      ),
    );
  }

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
                        Text(
                          'NetCheck',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
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

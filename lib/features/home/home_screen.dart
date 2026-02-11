import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/widgets/custom_title_bar.dart';
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

  // CDN Scan is available on desktop (Linux/Windows) and Android
  static final bool _showCdnScan = Platform.isLinux || Platform.isWindows || Platform.isAndroid;
  // SMS Encoder is only available on Android
  static final bool _showSmsEncoder = Platform.isAndroid;

  List<Widget> get _screens => [
    const DomainCheckerScreen(),
    const DnsScannerScreen(),
    const DnsHunterScreen(),
    const EdgeIpCheckerScreen(),
    const VlessConfigModifierScreen(),
    if (_showSmsEncoder) const SmsEncoderScreen(),
    if (_showCdnScan) const CdnConfigScanScreen(),
  ];

  List<NavigationDestination> get _destinations => [
    const NavigationDestination(
      icon: Icon(Icons.language_outlined),
      selectedIcon: Icon(Icons.language),
      label: 'Domains',
    ),
    const NavigationDestination(
      icon: Icon(Icons.dns_outlined),
      selectedIcon: Icon(Icons.dns),
      label: 'DNS',
    ),
    const NavigationDestination(
      icon: Icon(Icons.radar_outlined),
      selectedIcon: Icon(Icons.radar),
      label: 'Hunter',
    ),
    const NavigationDestination(
      icon: Icon(Icons.router_outlined),
      selectedIcon: Icon(Icons.router),
      label: 'Edge',
    ),
    const NavigationDestination(
      icon: Icon(Icons.vpn_key_outlined),
      selectedIcon: Icon(Icons.vpn_key),
      label: 'VLESS',
    ),
    if (_showSmsEncoder)
      const NavigationDestination(
        icon: Icon(Icons.sms_outlined),
        selectedIcon: Icon(Icons.sms),
        label: 'SMS',
      ),
    if (_showCdnScan)
      const NavigationDestination(
        icon: Icon(Icons.speed_outlined),
        selectedIcon: Icon(Icons.speed),
        label: 'CDN Scan',
      ),
  ];

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
      body: AnimatedSwitcher(
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: _destinations,
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
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
                      child: _screens[_selectedIndex],
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

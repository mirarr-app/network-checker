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
import '../masque_scout/masque_scout_screen.dart';
import '../sms_encoder/sms_encoder_screen.dart';
import '../vless_config_modifier/vless_config_modifier_screen.dart';
import '../chain/chain_screen.dart';
import '../netlify_generator/netlify_generator_screen.dart';
import '../akamai_scan/akamai_scan_screen.dart';
import '../patt/sni_spoof_check/sni_spoof_check_screen.dart';
import '../patt/cloudflare_fix/cloudflare_fix_screen.dart';
import '../internet_diagnostics/internet_diagnostics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _versionCheckDone = false;
  final Set<String> _expandedSections = {'Patt'};

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

  List<Widget> get _screens => [
    const InternetDiagnosticsScreen(),
    const DomainCheckerScreen(),
    const DnsScannerScreen(),
    const DnsHunterScreen(),
    const EdgeIpCheckerScreen(),
    const MasqueScoutScreen(),
    const AkamaiScanScreen(),
    const SniSpoofCheckScreen(),
    const CloudflareFixScreen(),
    const VlessConfigModifierScreen(),
    const ChainScreen(),
    const NetlifyGeneratorScreen(),
    if (_showSmsEncoder) const SmsEncoderScreen(),
    if (_showCdnScan) const CdnConfigScanScreen(),
    if (_showAbout) const AboutScreen(),
  ];

  List<Widget> get _desktopScreens => _screens;

  List<_NavItem> get _navItems {
    var idx = 0;
    return [
      _NavItem(
        label: 'Diagnostics',
        icon: Icons.network_ping_outlined,
        selectedIcon: Icons.network_ping,
        index: idx++,
      ),
      _NavItem(
        label: 'Domains',
        icon: Icons.language_outlined,
        selectedIcon: Icons.language,
        index: idx++,
      ),
      _NavItem(
        label: 'DNS',
        icon: Icons.dns_outlined,
        selectedIcon: Icons.dns,
        index: idx++,
      ),
      _NavItem(
        label: 'Hunter',
        icon: Icons.radar_outlined,
        selectedIcon: Icons.radar,
        index: idx++,
      ),
      _NavItem(
        label: 'Edge',
        icon: Icons.router_outlined,
        selectedIcon: Icons.router,
        index: idx++,
      ),
      _NavItem(
        label: 'Masque Scout',
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
        index: idx++,
      ),
      _NavItem(
        label: 'Akamai',
        icon: Icons.cloud_sync_outlined,
        selectedIcon: Icons.cloud_sync,
        index: idx++,
      ),
      _NavItem(
        label: 'Patt',
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune,
        children: [
          _NavItem(
            label: 'SNI Check',
            icon: Icons.fingerprint_outlined,
            selectedIcon: Icons.fingerprint,
            index: idx++,
          ),
          _NavItem(
            label: 'Patt\'s Cloudflare Fix',
            icon: Icons.auto_fix_high_outlined,
            selectedIcon: Icons.auto_fix_high,
            index: idx++,
          ),
        ],
      ),
      _NavItem(
        label: 'VLESS',
        icon: Icons.vpn_key_outlined,
        selectedIcon: Icons.vpn_key,
        index: idx++,
      ),
      _NavItem(
        label: 'Chain',
        icon: Icons.alt_route_outlined,
        selectedIcon: Icons.alt_route,
        index: idx++,
      ),
      _NavItem(
        label: 'Netlify',
        icon: Icons.bolt_outlined,
        selectedIcon: Icons.bolt,
        index: idx++,
      ),
      if (_showSmsEncoder)
        _NavItem(
          label: 'SMS',
          icon: Icons.sms_outlined,
          selectedIcon: Icons.sms,
          index: idx++,
        ),
      if (_showCdnScan)
        _NavItem(
          label: 'CDN Scan',
          icon: Icons.speed_outlined,
          selectedIcon: Icons.speed,
          index: idx++,
        ),
      if (_showAbout)
        _NavItem(
          label: 'About',
          icon: Icons.info_outline,
          selectedIcon: Icons.info,
          index: idx++,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
    final navItems = _navItems;

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
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
          // Navigation items list
          ...navItems.map((item) => _buildDrawerNavItem(item, colorScheme)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDrawerNavItem(_NavItem item, ColorScheme colorScheme) {
    if (item.isParent) {
      final isExpanded = _expandedSections.contains(item.label);
      final containsActive = item.containsIndex(_selectedIndex);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSections.remove(item.label);
                  } else {
                    _expandedSections.add(item.label);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: containsActive
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: containsActive
                      ? Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          width: 1,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 22,
                      color: containsActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: containsActive ? FontWeight.w600 : FontWeight.w500,
                          color: containsActive
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: containsActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Column(
                  children: item.children!
                      .map((child) => _buildDrawerChildItem(child, colorScheme))
                      .toList(),
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      );
    }

    final isSelected = _selectedIndex == item.index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () {
          if (item.index != null) {
            setState(() => _selectedIndex = item.index!);
            Navigator.pop(context);
          }
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
              Icon(
                isSelected && item.selectedIcon != null ? item.selectedIcon! : item.icon,
                size: 22,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 16),
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
    );
  }

  Widget _buildDrawerChildItem(_NavItem child, ColorScheme colorScheme) {
    final isSelected = _selectedIndex == child.index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          if (child.index != null) {
            setState(() => _selectedIndex = child.index!);
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: isSelected ? 16 : 0,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: isSelected ? 8 : 0),
              Icon(
                isSelected && child.selectedIcon != null ? child.selectedIcon! : child.icon,
                size: 18,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  child.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.arrow_right_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCustomTitleBar = Platform.isLinux || Platform.isWindows;
    final navItems = _navItems;

    return Scaffold(
      body: Column(
        children: [
          if (hasCustomTitleBar) const CustomTitleBar(),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: Container(
                    color: colorScheme.surfaceContainerLow,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.network_check,
                                  size: 24,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Network Checker',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'v$appVersion',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            children: navItems
                                .map((item) => _buildDesktopNavItem(item, colorScheme))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
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

  Widget _buildDesktopNavItem(_NavItem item, ColorScheme colorScheme) {
    if (item.isParent) {
      final isExpanded = _expandedSections.contains(item.label);
      final containsActive = item.containsIndex(_selectedIndex);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSections.remove(item.label);
                  } else {
                    _expandedSections.add(item.label);
                  }
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: containsActive
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: containsActive
                      ? Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          width: 1,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: containsActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: containsActive ? FontWeight.w600 : FontWeight.w500,
                          color: containsActive
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: containsActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(left: 14, top: 2),
                child: Column(
                  children: item.children!
                      .map((child) => _buildDesktopChildItem(child, colorScheme))
                      .toList(),
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      );
    }

    final isSelected = _selectedIndex == item.index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          if (item.index != null) {
            setState(() => _selectedIndex = item.index!);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: isSelected ? 16 : 0,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: isSelected ? 8 : 0),
              Icon(
                isSelected && item.selectedIcon != null ? item.selectedIcon! : item.icon,
                size: 20,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.arrow_right_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopChildItem(_NavItem child, ColorScheme colorScheme) {
    final isSelected = _selectedIndex == child.index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          if (child.index != null) {
            setState(() => _selectedIndex = child.index!);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: isSelected ? 14 : 0,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: isSelected ? 6 : 0),
              Icon(
                isSelected && child.selectedIcon != null ? child.selectedIcon! : child.icon,
                size: 16,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  child.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.arrow_right_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final int? index;
  final List<_NavItem>? children;

  const _NavItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.index,
    this.children,
  });

  bool get isParent => children != null && children!.isNotEmpty;

  bool containsIndex(int selectedIndex) {
    if (index == selectedIndex) return true;
    if (children != null) {
      return children!.any((child) => child.containsIndex(selectedIndex));
    }
    return false;
  }
}

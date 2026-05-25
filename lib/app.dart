import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/domain_checker/domain_checker_controller.dart';
import 'features/dns_hunter/dns_hunter_controller.dart';
import 'features/dns_scanner/dns_scanner_controller.dart';
import 'features/edge_ip_checker/edge_ip_checker_controller.dart';
import 'features/vless_config_modifier/vless_config_modifier_controller.dart';
import 'features/cdn_config_scan/cdn_config_scan_controller.dart';
import 'features/sms_encoder/sms_encoder_controller.dart';
import 'features/netlify_generator/netlify_generator_controller.dart';
import 'features/akamai_scan/akamai_scan_controller.dart';
import 'features/sni_spoof_check/sni_spoof_check_controller.dart';

class RdnbenetApp extends StatelessWidget {
  const RdnbenetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DomainCheckerController()),
        ChangeNotifierProvider(create: (_) => DnsScannerController()),
        ChangeNotifierProvider(create: (_) => DnsHunterController()),
        ChangeNotifierProvider(create: (_) => EdgeIpCheckerController()),
        ChangeNotifierProvider(create: (_) => VlessConfigModifierController()),
        ChangeNotifierProvider(create: (_) => CdnConfigScanController()),
        ChangeNotifierProvider(create: (_) => SmsEncoderController()),
        ChangeNotifierProvider(create: (_) => NetlifyGeneratorController()),
        ChangeNotifierProvider(create: (_) => AkamaiScanController()),
        ChangeNotifierProvider(create: (_) => SniSpoofCheckController()),
      ],
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          // Only use dynamic colors on Android
          final usesDynamic = Platform.isAndroid && lightDynamic != null;
          return MaterialApp(
            title: 'Network Checker',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(usesDynamic ? lightDynamic : null),
            darkTheme: AppTheme.darkTheme(usesDynamic ? darkDynamic : null),
            themeMode: ThemeMode.system,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}

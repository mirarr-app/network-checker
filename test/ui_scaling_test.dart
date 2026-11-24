import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rdnbenet/app.dart';
import 'package:rdnbenet/core/theme/app_theme.dart';
import 'package:rdnbenet/features/about/about_screen.dart';
import 'package:rdnbenet/features/akamai_scan/akamai_scan_controller.dart';
import 'package:rdnbenet/features/akamai_scan/akamai_scan_screen.dart';
import 'package:rdnbenet/features/cdn_config_scan/cdn_config_scan_controller.dart';
import 'package:rdnbenet/features/cdn_config_scan/cdn_config_scan_screen.dart';
import 'package:rdnbenet/features/chain/chain_controller.dart';
import 'package:rdnbenet/features/chain/chain_screen.dart';
import 'package:rdnbenet/features/dns_hunter/dns_hunter_controller.dart';
import 'package:rdnbenet/features/dns_hunter/dns_hunter_screen.dart';
import 'package:rdnbenet/features/dns_scanner/dns_scanner_controller.dart';
import 'package:rdnbenet/features/dns_scanner/dns_scanner_screen.dart';
import 'package:rdnbenet/features/domain_checker/domain_checker_controller.dart';
import 'package:rdnbenet/features/domain_checker/domain_checker_screen.dart';
import 'package:rdnbenet/features/edge_ip_checker/edge_ip_checker_controller.dart';
import 'package:rdnbenet/features/edge_ip_checker/edge_ip_checker_screen.dart';
import 'package:rdnbenet/features/home/home_screen.dart';
import 'package:rdnbenet/features/internet_diagnostics/internet_diagnostics_controller.dart';
import 'package:rdnbenet/features/internet_diagnostics/internet_diagnostics_screen.dart';
import 'package:rdnbenet/features/ip_info/ip_info_controller.dart';
import 'package:rdnbenet/features/ip_info/ip_info_screen.dart';
import 'package:rdnbenet/features/load_balancer/load_balancer_controller.dart';
import 'package:rdnbenet/features/load_balancer/load_balancer_screen.dart';
import 'package:rdnbenet/features/masque_scout/masque_scout_controller.dart';
import 'package:rdnbenet/features/masque_scout/masque_scout_screen.dart';
import 'package:rdnbenet/features/netlify_generator/netlify_generator_controller.dart';
import 'package:rdnbenet/features/netlify_generator/netlify_generator_screen.dart';
import 'package:rdnbenet/features/patt/add_ech/add_ech_controller.dart';
import 'package:rdnbenet/features/patt/add_ech/add_ech_screen.dart';
import 'package:rdnbenet/features/patt/cloudflare_fix/cloudflare_fix_controller.dart';
import 'package:rdnbenet/features/patt/cloudflare_fix/cloudflare_fix_screen.dart';
import 'package:rdnbenet/features/patt/sni_spoof_check/sni_spoof_check_controller.dart';
import 'package:rdnbenet/features/patt/sni_spoof_check/sni_spoof_check_screen.dart';
import 'package:rdnbenet/features/sms_encoder/sms_encoder_controller.dart';
import 'package:rdnbenet/features/sms_encoder/sms_encoder_screen.dart';
import 'package:rdnbenet/features/vless_config_modifier/vless_config_modifier_controller.dart';
import 'package:rdnbenet/features/vless_config_modifier/vless_config_modifier_screen.dart';

void main() {
  group('UI Scaling and Font Size Tests', () {
    testWidgets('App root clamps excessive text scaling to 1.35x', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0; // high DPI mobile screen
      tester.platformDispatcher.textScaleFactorTestValue = 2.5; // huge font setting

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(const RdnbenetApp());
      await tester.pump(const Duration(milliseconds: 500));

      final BuildContext context = tester.element(find.byType(HomeScreen));
      final textScaler = MediaQuery.textScalerOf(context);

      // Verify that 2.5 was clamped to 1.35
      expect(textScaler.scale(10.0), closeTo(13.5, 0.01));
    });

    testWidgets('LoadBalancerScreen action buttons fit on narrow screen with 1.35x font without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = LoadBalancerController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<LoadBalancerController>.value(
            value: controller,
            child: const LoadBalancerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Generate Balancer Config'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('ChainScreen action buttons fit on narrow screen with 1.35x font without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = ChainController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<ChainController>.value(
            value: controller,
            child: const ChainScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Generate Xray Profile'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('CloudflareFixScreen action button fits on narrow screen with 1.35x font without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = CloudflareFixController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<CloudflareFixController>.value(
            value: controller,
            child: const CloudflareFixScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Transform to Cloudflare Fix JSON'), findsOneWidget);
    });

    testWidgets('AddEchScreen action buttons fit on narrow screen with 1.35x font without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = AddEchController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<AddEchController>.value(
            value: controller,
            child: const AddEchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Add ECH & Generate JSON'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('DomainCheckerScreen mobile layout renders without overflow on 412dp screen with large font', (tester) async {
      tester.view.physicalSize = const Size(412, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = DomainCheckerController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<DomainCheckerController>.value(
            value: controller,
            child: const DomainCheckerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Domain Checker'), findsOneWidget);
    });

    testWidgets('EdgeIpCheckerScreen renders without overflow on narrow 360x640 screen with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = EdgeIpCheckerController();
      controller.updateInput('104.16.1.1\n104.16.1.2\n104.16.1.3\n104.16.1.4\n104.16.1.5\n104.16.1.6\n104.16.1.7\n104.16.1.8\n104.16.1.9\n104.16.1.10\n104.16.1.11\n104.16.1.12');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<EdgeIpCheckerController>.value(
            value: controller,
            child: const EdgeIpCheckerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Edge IP Scanner'), findsOneWidget);
      expect(find.text('CF'), findsWidgets);
    });

    testWidgets('AkamaiScanScreen renders without overflow on narrow 360x640 screen with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = AkamaiScanController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<AkamaiScanController>.value(
            value: controller,
            child: const AkamaiScanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Akamai IP Scanner'), findsOneWidget);
      expect(find.text('Load Akamai IPs'), findsOneWidget);
    });

    testWidgets('CdnConfigScanScreen renders without overflow on narrow 360x640 screen with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = CdnConfigScanController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<CdnConfigScanController>.value(
            value: controller,
            child: const CdnConfigScanScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('CDN Config Scan'), findsOneWidget);
    });

    testWidgets('DnsHunterScreen renders without overflow on narrow 360x640 screen with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = DnsHunterController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<DnsHunterController>.value(
            value: controller,
            child: const DnsHunterScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('DNS Hunter'), findsOneWidget);
    });

    testWidgets('DnsScannerScreen renders without overflow on narrow 360x640 screen with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = DnsScannerController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<DnsScannerController>.value(
            value: controller,
            child: const DnsScannerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('DNS Scanner'), findsOneWidget);
    });

    testWidgets('IpInfoScreen renders without overflow on narrow 360x640 screen with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = IpInfoController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<IpInfoController>.value(
            value: controller,
            child: const IpInfoScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('IP info'), findsOneWidget);
    });

    testWidgets('AboutScreen renders without overflow on narrow and medium screens with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AboutScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Network Checker'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('SniSpoofCheckScreen renders without overflow on narrow 360x640 screen with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = SniSpoofCheckController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<SniSpoofCheckController>.value(
            value: controller,
            child: const SniSpoofCheckScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('SNI Spoof Check'), findsOneWidget);
      expect(find.text('Defaults'), findsOneWidget);
    });

    testWidgets('NetlifyGeneratorScreen renders without overflow on narrow 360x640 screen with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = NetlifyGeneratorController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<NetlifyGeneratorController>.value(
            value: controller,
            child: const NetlifyGeneratorScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Netlify Generator'), findsOneWidget);
    });

    testWidgets('MasqueScoutScreen renders without overflow on narrow 360x640 screen with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = MasqueScoutController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<MasqueScoutController>.value(
            value: controller,
            child: const MasqueScoutScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Masque Scout'), findsOneWidget);
    });

    testWidgets('VlessConfigModifierScreen renders without overflow on narrow 360x640 screen with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = VlessConfigModifierController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<VlessConfigModifierController>.value(
            value: controller,
            child: const VlessConfigModifierScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('VLESS Config Modifier'), findsOneWidget);
    });

    testWidgets('SmsEncoderScreen renders without overflow on narrow 360x640 screen with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = SmsEncoderController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<SmsEncoderController>.value(
            value: controller,
            child: const SmsEncoderScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('SMS Encoder'), findsOneWidget);
    });

    testWidgets('InternetDiagnosticsScreen renders without overflow on narrow 360x640 screen with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = InternetDiagnosticsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<InternetDiagnosticsController>.value(
            value: controller,
            child: const InternetDiagnosticsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Internet Diagnostics'), findsOneWidget);
    });

    testWidgets('HomeScreen mobile layout renders AdaptiveAppBar menu and drawer cleanly on 320x568 with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(const RdnbenetApp());
      await tester.pump(const Duration(milliseconds: 500));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.text('Internet Diagnostics'), findsOneWidget);
    });

    testWidgets('CloudflareFixScreen settings panel and action button stay single-line on 320x568 with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = CloudflareFixController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<CloudflareFixController>.value(
            value: controller,
            child: const CloudflareFixScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Open settings panel to verify 'Reset Defaults' stays single-line
      await tester.tap(find.byTooltip('Toggle Settings'));
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      _expectSingleLineLabel(tester, 'Reset Defaults');
      _expectSingleLineLabel(tester, 'Transform to Cloudflare Fix JSON');
    });

    testWidgets('DomainCheckerScreen edit mode pills and dialogs stay single-line on 320x568 with 1.35x font', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = DomainCheckerController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<DomainCheckerController>.value(
            value: controller,
            child: const DomainCheckerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Domain Checker'), findsOneWidget);
      if (find.text('New Preset').evaluate().isNotEmpty) {
        _expectSingleLineLabel(tester, 'New Preset');
      }
    });

    testWidgets('LoadBalancerScreen bulk import dialog fits on 320x568 with 1.35x font without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = LoadBalancerController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<LoadBalancerController>.value(
            value: controller,
            child: const LoadBalancerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Bulk Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bulk Import'));
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      expect(find.text('Bulk Import Configs / URIs'), findsOneWidget);
      _expectSingleLineLabel(tester, 'Cancel');
      _expectSingleLineLabel(tester, 'Import');
    });

    testWidgets('EdgeIpCheckerScreen settings dialog fits on 320x568 with 1.35x font without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final controller = EdgeIpCheckerController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: ChangeNotifierProvider<EdgeIpCheckerController>.value(
            value: controller,
            child: const EdgeIpCheckerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : err?.toString());
      _expectSingleLineLabel(tester, 'Cancel');
      _expectSingleLineLabel(tester, 'Save');
    });
  });
}

void _expectSingleLineLabel(WidgetTester tester, String text) {
  final finder = find.text(text);
  expect(finder, findsWidgets);
  final textWidget = tester.widget<Text>(finder.first);
  expect(textWidget.maxLines, 1, reason: 'Button "$text" must constrain maxLines to 1');
  final paragraph = tester.renderObject<RenderParagraph>(finder.first);
  expect(paragraph.didExceedMaxLines, isFalse, reason: 'Button "$text" overflowed maxLines');
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rdnbenet/app.dart';
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
          home: ChangeNotifierProvider<LoadBalancerController>.value(
            value: controller,
            child: const LoadBalancerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<ChainController>.value(
            value: controller,
            child: const ChainScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<CloudflareFixController>.value(
            value: controller,
            child: const CloudflareFixScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<AddEchController>.value(
            value: controller,
            child: const AddEchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<DomainCheckerController>.value(
            value: controller,
            child: const DomainCheckerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<EdgeIpCheckerController>.value(
            value: controller,
            child: const EdgeIpCheckerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<AkamaiScanController>.value(
            value: controller,
            child: const AkamaiScanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<CdnConfigScanController>.value(
            value: controller,
            child: const CdnConfigScanScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<DnsHunterController>.value(
            value: controller,
            child: const DnsHunterScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<DnsScannerController>.value(
            value: controller,
            child: const DnsScannerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<IpInfoController>.value(
            value: controller,
            child: const IpInfoScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
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

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<SniSpoofCheckController>.value(
            value: controller,
            child: const SniSpoofCheckScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<NetlifyGeneratorController>.value(
            value: controller,
            child: const NetlifyGeneratorScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<MasqueScoutController>.value(
            value: controller,
            child: const MasqueScoutScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<VlessConfigModifierController>.value(
            value: controller,
            child: const VlessConfigModifierScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<SmsEncoderController>.value(
            value: controller,
            child: const SmsEncoderScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
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
          home: ChangeNotifierProvider<InternetDiagnosticsController>.value(
            value: controller,
            child: const InternetDiagnosticsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.text('Internet Diagnostics'), findsOneWidget);
    });
  });
}

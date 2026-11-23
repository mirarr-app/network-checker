import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rdnbenet/core/services/ip_info_service.dart';
import 'package:rdnbenet/features/ip_info/ip_info_controller.dart';
import 'package:rdnbenet/features/ip_info/ip_info_screen.dart';

void main() {
  Widget buildTestScreen(IpInfoController controller) {
    return MaterialApp(
      home: ChangeNotifierProvider<IpInfoController>.value(
        value: controller,
        child: const IpInfoScreen(),
      ),
    );
  }

  group('IpInfoScreen UI Tests', () {
    testWidgets('renders input field, header, and check button', (tester) async {
      final controller = IpInfoController();
      await tester.pumpWidget(buildTestScreen(controller));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('IP info'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text('Enter IPv4 or IPv6 address (or leave empty for auto scan)'),
        findsOneWidget,
      );
      expect(find.text('Ready to Check'), findsOneWidget);
      expect(find.text('Check my IP'), findsOneWidget);
    });

    testWidgets('typing in manual IP field updates FAB label and shows clear button',
        (tester) async {
      final controller = IpInfoController();
      await tester.pumpWidget(buildTestScreen(controller));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Check my IP'), findsOneWidget);
      expect(find.byIcon(Icons.clear_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), '1.1.1.1');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Check entered IP'), findsOneWidget);
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Check my IP'), findsOneWidget);
      expect(find.byIcon(Icons.clear_rounded), findsNothing);
    });

    testWidgets('submitting invalid IP shows error message in UI', (tester) async {
      final controller = IpInfoController();
      await tester.pumpWidget(buildTestScreen(controller));
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'invalid-ip-address');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Check'));
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Invalid IP address format'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('displays both IPv4 and IPv6 when dual-stack is detected',
        (tester) async {
      final controller = IpInfoController();
      controller.setResultsForTesting(
        lookup: const IpLookupInfo(
          ipv4: '198.51.100.25',
          ipv6: '2001:db8:85a3::8a2e:370:7334',
        ),
        status: IpInfoStatus.completed,
      );

      await tester.pumpWidget(buildTestScreen(controller));
      await tester.pump(const Duration(seconds: 1));

      // IPv4 and IPv6 badges in the header and rows in the IP Lookup card
      expect(find.text('198.51.100.25'), findsAtLeast(1));
      expect(find.text('2001:db8:85a3::8a2e:370:7334'), findsAtLeast(1));
      expect(find.text('IPv4'), findsAtLeast(1));
      expect(find.text('IPv6'), findsAtLeast(1));
    });

    testWidgets('displays manual target banner and switch button in manual mode',
        (tester) async {
      final controller = IpInfoController();
      controller.setResultsForTesting(
        targetIp: '8.8.8.8',
        lookup: const IpLookupInfo(ipv4: '8.8.8.8'),
        status: IpInfoStatus.completed,
      );

      await tester.pumpWidget(buildTestScreen(controller));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Manual target: 8.8.8.8'), findsOneWidget);
      expect(find.text('Auto-detect my IP'), findsOneWidget);
    });

    testWidgets('typing in manual IP field clears previous error message',
        (tester) async {
      final controller = IpInfoController();
      controller.setResultsForTesting(
        errorMessage: 'Invalid IP address format. Please enter a valid IPv4 or IPv6 address.',
        status: IpInfoStatus.idle,
      );

      await tester.pumpWidget(buildTestScreen(controller));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Invalid IP address format'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Invalid IP address format'), findsNothing);
      expect(controller.errorMessage, isNull);
    });

    testWidgets('clicking inspect on IPv6 switches active inspected address in dual stack',
        (tester) async {
      final controller = IpInfoController();
      controller.setResultsForTesting(
        lookup: const IpLookupInfo(
          ipv4: '192.168.1.1',
          ipv6: 'fd00::1',
        ),
        status: IpInfoStatus.completed,
      );

      await tester.pumpWidget(buildTestScreen(controller));
      await tester.pump(const Duration(seconds: 1));

      expect(controller.activeIp, '192.168.1.1');

      // Tap inspect button on IPv6
      final inspectBtn = find.widgetWithText(OutlinedButton, 'Inspect');
      await tester.ensureVisible(inspectBtn);
      await tester.tap(inspectBtn);
      await tester.pumpAndSettle();

      expect(controller.activeIp, 'fd00::1');
      expect(controller.isManual, isFalse);
    });
  });
}

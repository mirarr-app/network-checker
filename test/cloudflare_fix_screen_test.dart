import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rdnbenet/features/patt/cloudflare_fix/cloudflare_fix_controller.dart';
import 'package:rdnbenet/features/patt/cloudflare_fix/cloudflare_fix_screen.dart';

void main() {
  testWidgets('CloudflareFixScreen renders with centered title', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
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

    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Patt\'s Cloudflare Fix')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(Icon),
      ),
      // Settings button icon tune_outlined is the only icon in AppBar actions
      findsOneWidget,
    );
  });
}

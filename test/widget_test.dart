import 'package:flutter_test/flutter_test.dart';

import 'package:rdnbenet/app.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RdnbenetApp());

    // Verify that the app loads with navigation sidebar
    expect(find.text('Network Checker'), findsAtLeast(1));
    expect(find.text('Diagnostics'), findsAtLeast(1));

    // Verify Patt section and SNI Check sub-item are present
    expect(find.text('Patt'), findsAtLeast(1));
    expect(find.text('SNI Check'), findsAtLeast(1));

    // Verify the Diagnostics section has the IP info sub-item
    expect(find.text('Internet Diagnostics'), findsAtLeast(1));
    expect(find.text('IP info'), findsAtLeast(1));

    // Let staggered animation timers complete
    await tester.pump(const Duration(seconds: 2));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rdnbenet/features/vless_config_modifier/vless_config_modifier_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VlessConfigModifierController Tests', () {
    late VlessConfigModifierController controller;

    setUp(() {
      controller = VlessConfigModifierController();
    });

    test('replaces IP but keeps original port when port is not specified in IP input', () async {
      controller.setConfigsInput('vless://some-uuid@original-host.com:443?security=tls#my-config');
      controller.setIpsInput('1.1.1.1\n8.8.8.8');

      await controller.generateConfigs();

      expect(controller.errorMessage, isNull);
      expect(controller.generatedConfigs.length, equals(2));
      expect(
        controller.generatedConfigs[0],
        equals('vless://some-uuid@1.1.1.1:443?security=tls#my-config'),
      );
      expect(
        controller.generatedConfigs[1],
        equals('vless://some-uuid@8.8.8.8:443?security=tls#my-config'),
      );
    });

    test('replaces IP and changes port when port is specified in IP input', () async {
      controller.setConfigsInput('vless://some-uuid@original-host.com:443?security=tls#my-config');
      controller.setIpsInput('1.1.1.1:2096\n8.8.8.8:8080\n9.9.9.9');

      await controller.generateConfigs();

      expect(controller.errorMessage, isNull);
      expect(controller.generatedConfigs.length, equals(3));
      expect(
        controller.generatedConfigs[0],
        equals('vless://some-uuid@1.1.1.1:2096?security=tls#my-config'),
      );
      expect(
        controller.generatedConfigs[1],
        equals('vless://some-uuid@8.8.8.8:8080?security=tls#my-config'),
      );
      expect(
        controller.generatedConfigs[2],
        equals('vless://some-uuid@9.9.9.9:443?security=tls#my-config'),
      );
    });
  });
}

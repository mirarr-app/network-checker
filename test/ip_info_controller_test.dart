import 'package:flutter_test/flutter_test.dart';
import 'package:rdnbenet/core/services/ip_info_service.dart';
import 'package:rdnbenet/features/ip_info/ip_info_controller.dart';

void main() {
  group('IpInfoController - cleanIpInput', () {
    test('trims whitespace', () {
      expect(IpInfoController.cleanIpInput('  1.1.1.1  '), '1.1.1.1');
      expect(
        IpInfoController.cleanIpInput('  2606:4700:4700::1111  '),
        '2606:4700:4700::1111',
      );
    });

    test('strips brackets from IPv6', () {
      expect(
        IpInfoController.cleanIpInput('[2001:db8::1]'),
        '2001:db8::1',
      );
      expect(
        IpInfoController.cleanIpInput('  [2600:1f14::86]  '),
        '2600:1f14::86',
      );
    });

    test('leaves regular IPv4 and IPv6 untouched', () {
      expect(IpInfoController.cleanIpInput('8.8.8.8'), '8.8.8.8');
      expect(
        IpInfoController.cleanIpInput('fe80::1ff:fe23:4567'),
        'fe80::1ff:fe23:4567',
      );
    });

    test('strips port, URL scheme, path, and CIDR from IPv4', () {
      expect(IpInfoController.cleanIpInput('1.1.1.1:8080'), '1.1.1.1');
      expect(IpInfoController.cleanIpInput('http://1.1.1.1:8080/'), '1.1.1.1');
      expect(IpInfoController.cleanIpInput('https://1.1.1.1/test'), '1.1.1.1');
      expect(IpInfoController.cleanIpInput('10.0.0.1/24'), '10.0.0.1');
    });

    test('strips port, URL scheme, CIDR, and zone index from IPv6', () {
      expect(
        IpInfoController.cleanIpInput('[2001:db8::1]:8080'),
        '2001:db8::1',
      );
      expect(
        IpInfoController.cleanIpInput('https://[2001:db8::1]:443/'),
        '2001:db8::1',
      );
      expect(
        IpInfoController.cleanIpInput('fe80::1%eth0'),
        'fe80::1',
      );
      expect(
        IpInfoController.cleanIpInput('2001:db8::1/64'),
        '2001:db8::1',
      );
    });
  });

  group('IpInfoController - manual IP validation and suite execution', () {
    test('rejects invalid IP string and sets errorMessage', () async {
      final controller = IpInfoController();
      expect(controller.errorMessage, isNull);

      await controller.runIpInfoSuiteInternal(
        manualIp: 'not-an-ip',
        splitTargets: const [],
        latencyTargets: const [],
        skipEnvironment: true,
      );

      expect(controller.errorMessage, isNotNull);
      expect(
        controller.errorMessage,
        contains('Invalid IP address format'),
      );
      expect(controller.isIdle, isTrue);
      expect(controller.targetIp, isNull);
      expect(controller.isManual, isFalse);

      controller.clearError();
      expect(controller.errorMessage, isNull);
    });

    test('rejects out-of-range IPv4 numbers', () async {
      final controller = IpInfoController();
      await controller.runIpInfoSuiteInternal(
        manualIp: '999.999.999.999',
        splitTargets: const [],
        latencyTargets: const [],
        skipEnvironment: true,
      );
      expect(controller.errorMessage, isNotNull);
      expect(controller.isIdle, isTrue);
    });

    test('accepts valid manual IPv4 and sets isManual', () async {
      final controller = IpInfoController();
      // Use bogon IP so external HTTP calls in purity are skipped
      await controller.runIpInfoSuiteInternal(
        manualIp: '192.168.1.100',
        splitTargets: const [],
        latencyTargets: const [],
        skipEnvironment: true,
      );

      expect(controller.errorMessage, isNull);
      expect(controller.isManual, isTrue);
      expect(controller.targetIp, '192.168.1.100');
      expect(controller.lookup, isNotNull);
      expect(controller.lookup!.ipv4, '192.168.1.100');
      expect(controller.lookup!.ipv6, isNull);
      expect(controller.lookup!.primaryIp, '192.168.1.100');
      expect(controller.isCompleted, isTrue);
    });

    test('accepts valid manual IPv6 and sets isManual', () async {
      final controller = IpInfoController();
      // Use bogon IPv6 so external HTTP calls in purity are skipped
      await controller.runIpInfoSuiteInternal(
        manualIp: 'fd00::1',
        splitTargets: const [],
        latencyTargets: const [],
        skipEnvironment: true,
      );

      expect(controller.errorMessage, isNull);
      expect(controller.isManual, isTrue);
      expect(controller.targetIp, 'fd00::1');
      expect(controller.lookup, isNotNull);
      expect(controller.lookup!.ipv4, isNull);
      expect(controller.lookup!.ipv6, 'fd00::1');
      expect(controller.lookup!.primaryIp, 'fd00::1');
      expect(controller.isCompleted, isTrue);
    });

    test('accepts bracketed IPv6 and cleans it', () async {
      final controller = IpInfoController();
      await controller.runIpInfoSuiteInternal(
        manualIp: '[fd12:3456::1]',
        splitTargets: const [],
        latencyTargets: const [],
        skipEnvironment: true,
      );

      expect(controller.errorMessage, isNull);
      expect(controller.isManual, isTrue);
      expect(controller.targetIp, 'fd12:3456::1');
      expect(controller.lookup!.ipv6, 'fd12:3456::1');
    });

    test('resetSuite clears manual IP and error', () async {
      final controller = IpInfoController();
      await controller.runIpInfoSuiteInternal(
        manualIp: '10.0.0.1',
        splitTargets: const [],
        latencyTargets: const [],
        skipEnvironment: true,
      );
      expect(controller.isManual, isTrue);

      controller.resetSuite();

      expect(controller.isManual, isFalse);
      expect(controller.targetIp, isNull);
      expect(controller.errorMessage, isNull);
      expect(controller.lookup, isNull);
      expect(controller.isIdle, isTrue);
    });

    test('inspectAddress toggles inspected target in dual-stack without clearing auto mode', () async {
      final controller = IpInfoController();
      controller.setResultsForTesting(
        lookup: const IpLookupInfo(
          ipv4: '198.51.100.1',
          ipv6: '2001:db8::1',
        ),
        status: IpInfoStatus.completed,
      );

      expect(controller.isManual, isFalse);
      expect(controller.activeIp, '198.51.100.1');

      await controller.inspectAddress('2001:db8::1');

      expect(controller.isManual, isFalse);
      expect(controller.inspectedIp, '2001:db8::1');
      expect(controller.activeIp, '2001:db8::1');
      expect(controller.lookup!.ipv4, '198.51.100.1');
      expect(controller.lookup!.ipv6, '2001:db8::1');

      await controller.inspectAddress('198.51.100.1');
      expect(controller.isManual, isFalse);
      expect(controller.inspectedIp, '198.51.100.1');
      expect(controller.activeIp, '198.51.100.1');
    });

    test('generateIpInfoReport formats manual and dual-stack info correctly', () async {
      final controller = IpInfoController();
      await controller.runIpInfoSuiteInternal(
        manualIp: '127.0.0.1',
        splitTargets: const [],
        latencyTargets: const [],
        skipEnvironment: true,
      );

      final report = controller.generateIpInfoReport();
      expect(report, contains('Mode: Manual query (127.0.0.1)'));
      expect(report, contains('IPv4: 127.0.0.1'));
      expect(report, contains('IPv6: Unavailable'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rdnbenet/core/services/masque_scout_scanner.dart';
import 'package:rdnbenet/features/masque_scout/data/masque_ip_ranges.dart';
import 'package:rdnbenet/features/masque_scout/masque_scout_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MasqueIpRanges Data & Presets', () {
    test('contains verified Aether MASQUE ports', () {
      expect(MasqueIpRanges.masquePorts, equals([443, 500, 1701, 4500, 4443, 8443, 8095]));
      expect(MasqueProtocol.h3.defaultPort, equals(443));
      expect(MasqueProtocol.h2.defaultPort, equals(443));
    });

    test('has valid IPv4 and IPv6 seeds', () {
      expect(MasqueIpRanges.masqueSeedsV4, isNotEmpty);
      expect(MasqueIpRanges.masqueSeedsV6, isNotEmpty);
      for (final seed in MasqueIpRanges.masqueSeedsV4) {
        expect(seed.contains('.'), isTrue);
      }
      for (final seed in MasqueIpRanges.masqueSeedsV6) {
        expect(seed.contains(':'), isTrue);
      }
    });

    test('sampleIpsFromCidrs extracts valid IPs within bounds', () {
      final samples = MasqueIpRanges.sampleIpsFromCidrs(
        ['162.159.192.0/30'],
        perCidr: 2,
      );
      expect(samples.length, equals(2));
      expect(samples.first.startsWith('162.159.192.'), isTrue);
    });

    test('preset texts are populated properly', () {
      expect(MasqueIpRanges.seedsPresetText, contains('162.159.196.1'));
      expect(MasqueIpRanges.defaultPresetText, contains('162.159.196.0/24'));
      expect(MasqueIpRanges.balancedPresetText, isNotEmpty);
      expect(MasqueIpRanges.multiPortSeedsPresetText, contains(':8095'));
      expect(MasqueIpRanges.multiPortSeedsPresetText, contains(':500'));
    });
  });

  group('MasqueScoutScanner Endpoint Parsing', () {
    test('parses plain IPv4 and IPv6 without ports to default port', () {
      const input = '162.159.192.1\n[2606:4700:d0::a29f:c001]';
      final parsed = MasqueScoutScanner.parseEndpointInput(input, defaultPort: 443);
      expect(parsed, equals([
        '162.159.192.1:443',
        '[2606:4700:d0::a29f:c001]:443',
      ]));
    });

    test('parses IPv4 and IPv6 with explicit ports', () {
      const input = '162.159.192.1:8443\n[2606:4700:d0::a29f:c001]:8095';
      final parsed = MasqueScoutScanner.parseEndpointInput(input);
      expect(parsed, equals([
        '162.159.192.1:8443',
        '[2606:4700:d0::a29f:c001]:8095',
      ]));
    });

    test('multi-port expansion expands unadorned IPs across all Aether MASQUE ports', () {
      const input = '162.159.192.1';
      final parsed = MasqueScoutScanner.parseEndpointInput(input, multiPort: true);
      expect(parsed.length, equals(7));
      for (final port in MasqueIpRanges.masquePorts) {
        expect(parsed.contains('162.159.192.1:$port'), isTrue);
      }
    });

    test('multi-port expansion preserves explicit ports without multiplying', () {
      const input = '162.159.192.1:1234\n162.159.192.2';
      final parsed = MasqueScoutScanner.parseEndpointInput(input, multiPort: true);
      expect(parsed.contains('162.159.192.1:1234'), isTrue);
      // 1 from explicit port + 7 from unadorned IP
      expect(parsed.length, equals(8));
    });

    test('expands CIDR ranges correctly', () {
      const input = '192.168.1.0/30';
      final parsed = MasqueScoutScanner.parseEndpointInput(input, defaultPort: 443);
      expect(parsed, equals([
        '192.168.1.1:443',
        '192.168.1.2:443',
      ]));
    });

    test('skips invalid input', () {
      const input = 'invalid_host\n999.999.999.999\n1.1.1.1:9999999\n162.159.192.1:443';
      final parsed = MasqueScoutScanner.parseEndpointInput(input);
      expect(parsed, equals(['162.159.192.1:443']));
    });
  });

  group('MasqueScoutConfig & Result', () {
    test('default configuration matches MASQUE requirements', () {
      const config = MasqueScoutConfig();
      expect(config.protocol, equals(MasqueProtocol.h3));
      expect(config.defaultPort, equals(443));
      expect(config.timeout, equals(const Duration(seconds: 4)));
      expect(config.maxWorkers, equals(15));
      expect(config.multiPort, equals(false));
      expect(config.ports, equals(MasqueIpRanges.masquePorts));
    });

    test('copyWith works properly', () {
      const config = MasqueScoutConfig();
      final updated = config.copyWith(
        protocol: MasqueProtocol.h2,
        multiPort: true,
        maxWorkers: 32,
      );
      expect(updated.protocol, equals(MasqueProtocol.h2));
      expect(updated.multiPort, equals(true));
      expect(updated.maxWorkers, equals(32));
      expect(updated.timeout, equals(const Duration(seconds: 4)));
    });

    test('MasqueScoutResult handles working and failure states', () {
      final working = MasqueScoutResult(
        ip: '162.159.192.1',
        port: 443,
        protocol: MasqueProtocol.h3,
        success: true,
        latencyMs: 120,
      );
      expect(working.success, isTrue);
      expect(working.endpoint, equals('162.159.192.1:443'));
      expect(working.latencyMs, equals(120));
      expect(working.errorMessage, isNull);

      final failed = MasqueScoutResult(
        ip: '162.159.192.1',
        port: 443,
        protocol: MasqueProtocol.h3,
        success: false,
        latencyMs: null,
        errorMessage: 'Connection timed out',
      );
      expect(failed.success, isFalse);
      expect(failed.latencyMs, isNull);
      expect(failed.errorMessage, equals('Connection timed out'));
    });
  });

  group('MasqueScoutController State Management', () {
    test('initializes with seed endpoints and default protocol', () {
      final controller = MasqueScoutController();
      expect(controller.config.protocol, equals(MasqueProtocol.h3));
      expect(controller.config.multiPort, equals(false));
      expect(controller.parsedEndpoints, isNotEmpty);
      expect(controller.parsedCount, equals(controller.parsedEndpoints.length));
      expect(controller.isScanning, isFalse);
    });

    test('toggle multi-port expands endpoints dynamically', () {
      final controller = MasqueScoutController();
      final initialCount = controller.parsedEndpoints.length;
      controller.setMultiPort(true);
      expect(controller.config.multiPort, isTrue);
      expect(controller.parsedEndpoints.length, equals(initialCount * 7));

      controller.setMultiPort(false);
      expect(controller.config.multiPort, isFalse);
      expect(controller.parsedEndpoints.length, equals(initialCount));
    });

    test('switching protocol updates config and default port', () {
      final controller = MasqueScoutController();
      controller.setProtocol(MasqueProtocol.h2);
      expect(controller.config.protocol, equals(MasqueProtocol.h2));
      expect(controller.config.defaultPort, equals(443));
    });

    test('loadPreset updates input text and endpoint count', () {
      final controller = MasqueScoutController();
      controller.loadPreset(MasqueIpRanges.balancedPresetText);
      expect(controller.inputText, equals(MasqueIpRanges.balancedPresetText));
      expect(controller.parsedEndpoints, isNotEmpty);
    });
  });
}

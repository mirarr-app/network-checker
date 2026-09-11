/// Cloudflare MASQUE IP ranges, seeds, and ports extracted from Aether project
class MasqueIpRanges {
  // ── MASQUE IPv4 Seeds ───────────────────────────────────────────────────────
  static const List<String> masqueSeedsV4 = [
    '162.159.196.1',
    '162.159.195.1',
    '162.159.192.1',
    '162.159.197.3',
    '162.159.197.1',
    '162.159.198.2',
    '162.159.198.1',
    '162.159.193.1',
  ];

  // ── MASQUE IPv4 CIDRs ───────────────────────────────────────────────────────
  static const List<String> masqueCidrsV4 = [
    '162.159.196.0/24',
    '162.159.195.0/24',
    '162.159.192.0/24',
    '162.159.193.0/24',
    '162.159.204.0/24',
    '162.159.197.0/24',
    '162.159.198.0/24',
    '172.65.251.0/24',
    '188.114.96.0/24',
    '188.114.97.0/24',
    '188.114.98.0/24',
    '188.114.99.0/24',
    '162.159.36.0/24',
    '162.159.46.0/24',
  ];

  // ── Aether MASQUE Ports ─────────────────────────────────────────────────────
  // Aether prober.rs: pub const MASQUE_PORTS: &[u16] = &[443, 500, 1701, 4500, 4443, 8443, 8095];
  static const List<int> masquePorts = [
    443,
    500,
    1701,
    4500,
    4443,
    8443,
    8095,
  ];

  // ── MASQUE IPv6 Seeds ───────────────────────────────────────────────────────
  static const List<String> masqueSeedsV6 = [
    '2606:4700:d0::a29f:c602',
    '2606:4700:d1::a29f:c602',
    '2606:4700:d0::a29f:c601',
    '2606:4700:d0::a29f:c001',
  ];

  // ── MASQUE IPv6 CIDRs ───────────────────────────────────────────────────────
  static const List<String> masqueCidrsV6 = [
    '2606:4700:d0::/48',
    '2606:4700:102::/48',
    '2606:4700:d1::/48',
  ];

  // ── CDN Anycast Pool ────────────────────────────────────────────────────────
  static const List<String> cdnAnycastPool = [
    '104.16.0.0/24',
    '104.17.0.0/24',
    '104.18.0.0/24',
    '104.19.0.0/24',
    '104.20.0.0/24',
    '104.21.0.0/24',
    '104.22.0.0/24',
    '104.24.0.0/24',
    '104.25.0.0/24',
    '104.26.0.0/24',
    '104.27.0.0/24',
    '104.28.0.0/24',
    '172.64.0.0/24',
    '172.65.0.0/24',
    '172.66.0.0/24',
    '172.67.0.0/24',
    '188.114.96.0/24',
    '188.114.97.0/24',
    '188.114.98.0/24',
    '188.114.99.0/24',
  ];

  // ── Text Presets ────────────────────────────────────────────────────────────

  /// Seeds Only (Fast)
  static String get seedsPresetText {
    final buffer = StringBuffer();
    buffer.writeln('# MASQUE Seeds (Fastest Check)');
    for (final s in masqueSeedsV4) {
      buffer.writeln(s);
    }
    return buffer.toString();
  }

  /// Default MASQUE preset text (seeds + CIDRs)
  static String get defaultPresetText {
    final buffer = StringBuffer();
    buffer.writeln('# MASQUE Seeds');
    for (final s in masqueSeedsV4) {
      buffer.writeln(s);
    }
    buffer.writeln('');
    buffer.writeln('# MASQUE Subnets');
    for (final c in masqueCidrsV4) {
      buffer.writeln(c);
    }
    return buffer.toString();
  }

  /// Sampled CIDRs preset for balanced scan
  static String get balancedPresetText {
    final buffer = StringBuffer();
    buffer.writeln('# MASQUE Seeds');
    for (final s in masqueSeedsV4) {
      buffer.writeln(s);
    }
    buffer.writeln('');
    buffer.writeln('# Sampled MASQUE Subnet IPs');
    final sampled = sampleIpsFromCidrs(masqueCidrsV4, perCidr: 5);
    for (final ip in sampled) {
      buffer.writeln(ip);
    }
    return buffer.toString();
  }

  /// Multi-port Seeds Preset
  static String get multiPortSeedsPresetText {
    final buffer = StringBuffer();
    buffer.writeln('# MASQUE Seeds Multi-Port (Aether Ports: 443, 500, 1701, 4500, 4443, 8443, 8095)');
    for (final s in masqueSeedsV4) {
      for (final port in masquePorts) {
        buffer.writeln('$s:$port');
      }
    }
    return buffer.toString();
  }

  /// Generates a sample of IPs from CIDRs
  static List<String> sampleIpsFromCidrs(List<String> cidrs, {int perCidr = 5}) {
    final sampled = <String>[];
    for (final cidr in cidrs) {
      final parts = cidr.split('/');
      if (parts.length != 2) continue;
      final ipParts = parts[0].split('.').map((p) => int.tryParse(p) ?? 0).toList();
      if (ipParts.length != 4) continue;
      final prefix = int.tryParse(parts[1]) ?? 24;
      if (prefix < 16 || prefix > 30) continue;

      final hostBits = 32 - prefix;
      final maxHosts = (1 << hostBits) - 2;
      final count = maxHosts < perCidr ? maxHosts : perCidr;

      final base = (ipParts[0] << 24) | (ipParts[1] << 16) | (ipParts[2] << 8) | ipParts[3];
      final seen = <int>{};
      var counter = 1;
      while (seen.length < count && counter <= maxHosts) {
        final offset = counter++;
        if (seen.add(offset)) {
          final ipInt = base + offset;
          final ipStr = '${(ipInt >> 24) & 0xFF}.${(ipInt >> 16) & 0xFF}.${(ipInt >> 8) & 0xFF}.${ipInt & 0xFF}';
          sampled.add(ipStr);
        }
      }
    }
    return sampled;
  }
}

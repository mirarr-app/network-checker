/// Model for a DNS provider
class DnsProvider {
  final int id;
  final String name;
  final String description;
  final List<String> addresses;
  final String? dohUrl;
  final String website;
  final bool isCustom;

  const DnsProvider({
    required this.id,
    required this.name,
    required this.description,
    required this.addresses,
    this.dohUrl,
    required this.website,
    this.isCustom = false,
  });

  /// Create a custom DNS provider from a single IP address
  factory DnsProvider.custom(String address, int id) {
    return DnsProvider(
      id: id,
      name: address,
      description: 'Custom DNS server',
      addresses: [address],
      website: '',
      isCustom: true,
    );
  }
}

/// List of default DNS providers
const List<DnsProvider> defaultDnsProviders = [
  DnsProvider(
    id: 1,
    name: 'Cloudflare',
    description: 'Fast and private DNS service',
    addresses: ['1.1.1.1', '1.0.0.1'],
    dohUrl: 'https://cloudflare-dns.com/dns-query',
    website: 'https://www.cloudflare.com',
  ),
  DnsProvider(
    id: 2,
    name: 'Google Public DNS',
    description: "Google's free DNS service",
    addresses: ['8.8.8.8', '8.8.4.4'],
    dohUrl: 'https://dns.google/dns-query',
    website: 'https://developers.google.com/speed/public-dns',
  ),
  DnsProvider(
    id: 3,
    name: 'OpenDNS',
    description: 'Secure DNS service with content filtering',
    addresses: ['208.67.222.222', '208.67.220.220'],
    dohUrl: 'https://doh.opendns.com/dns-query',
    website: 'https://www.opendns.com',
  ),
  DnsProvider(
    id: 4,
    name: 'OpenDNS 2',
    description: 'Secure DNS service with content filtering',
    addresses: ['208.67.222.220', '208.67.220.222'],
    dohUrl: 'https://doh.opendns.com/dns-query',
    website: 'https://www.opendns.com',
  ),
  DnsProvider(
    id: 5,
    name: 'Quad9 Unfiltered',
    description: 'Security-focused DNS service',
    addresses: ['9.9.9.10', '149.112.112.10'],
    dohUrl: 'https://dns10.quad9.net/dns-query',
    website: 'https://www.quad9.net',
  ),
  DnsProvider(
    id: 6,
    name: 'Yandex DNS',
    description: 'Russian DNS service with security features',
    addresses: ['77.88.8.8', '77.88.8.1'],
    dohUrl: 'https://common.dot.dns.yandex.net',
    website: 'https://dns.yandex.com',
  ),
  DnsProvider(
    id: 7,
    name: 'Shecan',
    description: 'Iranian DNS service for bypassing sanction',
    addresses: ['178.22.122.100', '185.51.200.2'],
    dohUrl: 'https://free.shecan.ir/dns-query',
    website: 'https://shecan.ir',
  ),
  DnsProvider(
    id: 8,
    name: 'Radar Game',
    description: 'Gaming-focused DNS service',
    addresses: ['10.202.10.10', '10.202.10.11'],
    dohUrl: null,
    website: 'https://radar.game',
  ),
  DnsProvider(
    id: 9,
    name: 'Electro',
    description: 'Best Local DNS service for Iranian users',
    addresses: ['78.157.42.100', '78.157.42.101'],
    dohUrl: 'https://dns.electrotm.org/dns-query',
    website: 'https://electrotm.org',
  ),
  DnsProvider(
    id: 10,
    name: 'AdGuard Unfiltered',
    description: 'Privacy-focused DNS',
    addresses: ['94.140.14.140', '94.140.14.141'],
    dohUrl: 'https://unfiltered.adguard-dns.com/dns-query',
    website: 'https://adguard.com/en/adguard-dns/overview.html',
  ),
  DnsProvider(
    id: 11,
    name: 'DynX DNS Adblocker',
    description: 'Just Ad blocking',
    addresses: ['109.70.74.38', '109.70.74.68'],
    dohUrl: 'https://dns.dynx.pro/dns-query',
    website: 'https://www.dynx.pro',
  ),
  DnsProvider(
    id: 12,
    name: 'DynX DNS Anti-Sanctions',
    description: 'Bypassing the sanction by changing the geolocation for Iranian users',
    addresses: ['10.139.177.18', '10.139.177.16'],
    dohUrl: null,
    website: 'https://www.dynx.pro',
  ),
  DnsProvider(
    id: 13,
    name: 'Begzar DNS Anti-Sanctions',
    description: 'Bypassing the sanction',
    addresses: ['185.55.225.25', '185.55.226.26'],
    dohUrl: null,
    website: 'https://begzar.ir',
  ),
];


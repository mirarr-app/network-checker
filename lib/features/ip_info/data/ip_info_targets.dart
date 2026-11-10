import '../../core/services/ip_info_service.dart';

/// Target lists for the IP info section, mirroring the website's split-routing
/// and connectivity test lists (ipfinal.com).
class IpInfoTargets {
  /// Websites for the split-routing test: per-site exit IP, resolved IP,
  /// latency and reachability.
  static const List<SplitRouteTarget> splitRouteTargets = [
    SplitRouteTarget(name: 'NetEase', domain: '163.com'),
    SplitRouteTarget(name: 'ByteDance', domain: 'bytedance.com'),
    SplitRouteTarget(name: 'Cloudflare', domain: 'cloudflare.com'),
    SplitRouteTarget(name: 'Qualcomm', domain: 'qualcomm.com'),
    SplitRouteTarget(name: 'Discord', domain: 'discord.com'),
    SplitRouteTarget(name: 'X', domain: 'x.com'),
    SplitRouteTarget(name: 'Medium', domain: 'medium.com'),
    SplitRouteTarget(name: 'Signal', domain: 'signal.org'),
    SplitRouteTarget(name: 'Claude', domain: 'claude.ai'),
    SplitRouteTarget(name: 'Anthropic', domain: 'anthropic.com'),
    SplitRouteTarget(name: 'GitHub', domain: 'github.com'),
    SplitRouteTarget(name: 'Google', domain: 'google.com'),
    SplitRouteTarget(name: 'YouTube', domain: 'youtube.com'),
    SplitRouteTarget(name: 'ChatGPT', domain: 'chatgpt.com'),
    SplitRouteTarget(name: 'Gemini', domain: 'gemini.google.com'),
    SplitRouteTarget(name: 'Netflix', domain: 'netflix.com'),
    SplitRouteTarget(name: 'Taobao', domain: 'taobao.com'),
    SplitRouteTarget(name: 'WeChat', domain: 'wechat.com'),
    SplitRouteTarget(name: 'Baidu', domain: 'baidu.com'),
    SplitRouteTarget(name: 'Wikipedia', domain: 'wikipedia.org'),
    SplitRouteTarget(name: 'Reddit', domain: 'reddit.com'),
    SplitRouteTarget(name: 'Stack Overflow', domain: 'stackoverflow.com'),
    SplitRouteTarget(name: 'Telegram', domain: 'telegram.org'),
    SplitRouteTarget(name: 'Instagram', domain: 'instagram.com'),
    SplitRouteTarget(name: 'Facebook', domain: 'facebook.com'),
    SplitRouteTarget(name: 'TikTok', domain: 'tiktok.com'),
    SplitRouteTarget(name: 'Apple', domain: 'apple.com'),
    SplitRouteTarget(name: 'Microsoft', domain: 'microsoft.com'),
    SplitRouteTarget(name: 'Amazon', domain: 'amazon.com'),
    SplitRouteTarget(name: 'Bing', domain: 'bing.com'),
    SplitRouteTarget(name: 'Yandex', domain: 'yandex.com'),
  ];

  /// Services for the connectivity latency test (the website's exact list):
  /// median latency of 3 attempts each.
  static const List<SplitRouteTarget> latencyTargets = [
    SplitRouteTarget(name: 'ByteDance', domain: 'bytedance.com'),
    SplitRouteTarget(name: 'Taobao', domain: 'taobao.com'),
    SplitRouteTarget(name: 'WeChat', domain: 'wechat.com'),
    SplitRouteTarget(name: 'Baidu', domain: 'baidu.com'),
    SplitRouteTarget(name: 'GitHub', domain: 'github.com'),
    SplitRouteTarget(name: 'Cloudflare', domain: 'cloudflare.com'),
    SplitRouteTarget(name: 'Google', domain: 'google.com'),
    SplitRouteTarget(name: 'YouTube', domain: 'youtube.com'),
    SplitRouteTarget(name: 'ChatGPT', domain: 'chatgpt.com'),
    SplitRouteTarget(name: 'Claude', domain: 'claude.ai'),
    SplitRouteTarget(name: 'X', domain: 'x.com'),
    SplitRouteTarget(name: 'Netflix', domain: 'netflix.com'),
  ];

  /// Endpoints for the global ping test, spread across regions.
  static const List<GlobalPingTarget> globalPingTargets = [
    GlobalPingTarget(
      name: 'Cloudflare DNS',
      target: '1.1.1.1',
      region: 'Global anycast',
    ),
    GlobalPingTarget(
      name: 'Google DNS',
      target: '8.8.8.8',
      region: 'Global anycast',
    ),
    GlobalPingTarget(
      name: 'Quad9 DNS',
      target: '9.9.9.9',
      region: 'Global anycast',
    ),
    GlobalPingTarget(name: 'Google', target: 'google.com', region: 'US'),
    GlobalPingTarget(
      name: 'Cloudflare',
      target: 'cloudflare.com',
      region: 'US',
    ),
    GlobalPingTarget(name: 'GitHub', target: 'github.com', region: 'US'),
    GlobalPingTarget(name: 'Baidu', target: 'baidu.com', region: 'China'),
    GlobalPingTarget(name: 'Yandex', target: 'yandex.com', region: 'Russia'),
  ];
}

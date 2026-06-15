import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Data class for isolate communication (must be top-level for compute)
class _GenerationInput {
  final List<Map<String, dynamic>> configs;
  final List<String> ips;

  _GenerationInput(this.configs, this.ips);
}

/// Parsed config data for isolate (simple map instead of class)
class ParsedConfigData {
  final String uuid;
  final String host;
  final int port;
  final String queryString;
  final String fragment;

  ParsedConfigData({
    required this.uuid,
    required this.host,
    required this.port,
    required this.queryString,
    required this.fragment,
  });

  Map<String, dynamic> toMap() => {
    'uuid': uuid,
    'host': host,
    'port': port,
    'queryString': queryString,
    'fragment': fragment,
  };

  static ParsedConfigData fromMap(Map<String, dynamic> map) => ParsedConfigData(
    uuid: map['uuid'],
    host: map['host'],
    port: map['port'],
    queryString: map['queryString'],
    fragment: map['fragment'],
  );

  String withHost(String newHost) {
    return 'vless://$uuid@$newHost:$port?$queryString#$fragment';
  }
}

// ============= TOP-LEVEL FUNCTIONS FOR ISOLATES =============

/// Parses IPs in isolate - top level function required for compute()
List<String> _parseIpsIsolate(String input) {
  final lines = input.split('\n');
  final ips = <String>[];

  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty) continue;

    if (line.contains('/')) {
      ips.addAll(_expandCidrRangeIsolate(line));
    } else if (line.contains('-')) {
      final rangeParts = line.split('-');
      if (rangeParts.length == 2) {
        ips.addAll(_expandIpRangeIsolate(rangeParts[0].trim(), rangeParts[1].trim()));
      }
    } else {
      ips.add(line);
    }
  }

  return ips;
}

/// Expands CIDR range in isolate
List<String> _expandCidrRangeIsolate(String cidr) {
  final ips = <String>[];
  
  try {
    final parts = cidr.split('/');
    if (parts.length != 2) return [cidr];
    
    final ipParts = parts[0].split('.').map(int.parse).toList();
    final prefixLength = int.parse(parts[1]);
    
    if (ipParts.length != 4 || prefixLength < 0 || prefixLength > 32) {
      return [cidr];
    }

    final ipInt = (ipParts[0] << 24) | (ipParts[1] << 16) | (ipParts[2] << 8) | ipParts[3];
    final hostBits = 32 - prefixLength;
    final hostCount = 1 << hostBits;
    final networkMask = 0xFFFFFFFF << hostBits;
    final networkAddr = ipInt & networkMask;
    
    final startOffset = hostBits >= 8 ? 1 : 0;
    final endOffset = hostBits >= 8 ? hostCount - 1 : hostCount;
    
    // Limit to prevent memory issues
    const maxIps = 100000;
    final actualEnd = (endOffset - startOffset) > maxIps ? startOffset + maxIps : endOffset;
    
    for (var i = startOffset; i < actualEnd; i++) {
      final hostIp = networkAddr + i;
      ips.add('${(hostIp >> 24) & 0xFF}.${(hostIp >> 16) & 0xFF}.${(hostIp >> 8) & 0xFF}.${hostIp & 0xFF}');
    }
  } catch (e) {
    ips.add(cidr);
  }
  
  return ips;
}

/// Expands IP range in isolate
List<String> _expandIpRangeIsolate(String start, String end) {
  final ips = <String>[];
  
  try {
    final startParts = start.split('.').map(int.parse).toList();
    final endParts = end.split('.').map(int.parse).toList();
    
    if (startParts.length != 4 || endParts.length != 4) {
      return [start];
    }

    final startInt = (startParts[0] << 24) | (startParts[1] << 16) | (startParts[2] << 8) | startParts[3];
    final endInt = (endParts[0] << 24) | (endParts[1] << 16) | (endParts[2] << 8) | endParts[3];
    
    const maxIps = 100000;
    final actualEnd = (endInt - startInt) > maxIps ? startInt + maxIps : endInt;
    
    for (var ipInt = startInt; ipInt <= actualEnd; ipInt++) {
      ips.add('${(ipInt >> 24) & 0xFF}.${(ipInt >> 16) & 0xFF}.${(ipInt >> 8) & 0xFF}.${ipInt & 0xFF}');
    }
  } catch (e) {
    ips.add(start);
  }
  
  return ips;
}

/// Parses VLESS configs in isolate
List<Map<String, dynamic>> _parseConfigsIsolate(String input) {
  final configs = <Map<String, dynamic>>[];
  final lines = input.split('\n');
  
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('vless://')) continue;
    
    try {
      final withoutPrefix = trimmed.substring(8);
      final fragmentSplit = withoutPrefix.split('#');
      final fragment = fragmentSplit.length > 1 ? fragmentSplit[1] : '';
      final beforeFragment = fragmentSplit[0];
      
      final querySplit = beforeFragment.split('?');
      final queryString = querySplit.length > 1 ? querySplit[1] : '';
      final beforeQuery = querySplit[0];
      
      final atSplit = beforeQuery.split('@');
      if (atSplit.length != 2) continue;
      
      final uuid = atSplit[0];
      final hostPort = atSplit[1];
      
      final colonIndex = hostPort.lastIndexOf(':');
      if (colonIndex == -1) continue;
      
      final host = hostPort.substring(0, colonIndex);
      final port = int.tryParse(hostPort.substring(colonIndex + 1));
      if (port == null) continue;

      configs.add({
        'uuid': uuid,
        'host': host,
        'port': port,
        'queryString': queryString,
        'fragment': fragment,
      });
    } catch (e) {
      // Skip invalid configs
    }
  }
  
  return configs;
}

/// Generates configs in isolate - this is the heavy operation
List<String> _generateConfigsIsolate(_GenerationInput input) {
  final results = <String>[];
  
  for (final configMap in input.configs) {
    final uuid = configMap['uuid'] as String;
    final defaultPort = configMap['port'] as int;
    final queryString = configMap['queryString'] as String;
    final fragment = configMap['fragment'] as String;
    
    for (final ip in input.ips) {
      String targetIp = ip;
      int targetPort = defaultPort;
      
      final colonIndex = ip.lastIndexOf(':');
      if (colonIndex != -1) {
        final firstColonIndex = ip.indexOf(':');
        final hasMultipleColons = firstColonIndex != colonIndex;
        final hasBrackets = ip.startsWith('[') && ip.contains(']');
        
        if (!hasMultipleColons || hasBrackets) {
          final portStr = ip.substring(colonIndex + 1);
          final parsedPort = int.tryParse(portStr);
          if (parsedPort != null) {
            targetIp = ip.substring(0, colonIndex);
            targetPort = parsedPort;
          }
        }
      }
      
      results.add('vless://$uuid@$targetIp:$targetPort?$queryString#$fragment');
    }
  }
  
  return results;
}

// ============= CONTROLLER =============

class VlessConfigModifierController extends ChangeNotifier {
  String _configsInput = '';
  String _ipsInput = '';
  List<ParsedConfigData> _parsedConfigs = [];
  int _ipCount = 0;
  List<String> _generatedConfigs = [];
  String? _errorMessage;
  bool _isProcessing = false;
  String _progressMessage = '';

  // Pagination for large lists
  static const int _pageSize = 100;
  int _displayedCount = _pageSize;

  // Getters
  String get configsInput => _configsInput;
  String get ipsInput => _ipsInput;
  List<ParsedConfigData> get parsedConfigs => _parsedConfigs;
  int get ipCount => _ipCount;
  List<String> get generatedConfigs => _generatedConfigs;
  List<String> get displayedConfigs => _generatedConfigs.take(_displayedCount).toList();
  bool get hasMore => _displayedCount < _generatedConfigs.length;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _isProcessing;
  String get progressMessage => _progressMessage;
  
  int get totalGeneratedCount => _generatedConfigs.length;

  /// Sets the VLESS configs input
  void setConfigsInput(String input) {
    _configsInput = input;
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets the IPs input
  void setIpsInput(String input) {
    _ipsInput = input;
    _errorMessage = null;
    notifyListeners();
  }

  /// Loads more configs for display (pagination)
  void loadMore() {
    if (_displayedCount < _generatedConfigs.length) {
      _displayedCount = (_displayedCount + _pageSize).clamp(0, _generatedConfigs.length);
      notifyListeners();
    }
  }

  /// Generates new configs with all combinations using isolates
  Future<void> generateConfigs() async {
    if (_isProcessing) return;
    
    _isProcessing = true;
    _errorMessage = null;
    _progressMessage = 'Parsing VLESS configs...';
    _displayedCount = _pageSize;
    notifyListeners();

    try {
      // Step 1: Parse configs in isolate
      final configMaps = await compute(_parseConfigsIsolate, _configsInput);
      
      if (configMaps.isEmpty) {
        _errorMessage = 'No valid VLESS configs found. Make sure they start with "vless://"';
        _isProcessing = false;
        _progressMessage = '';
        notifyListeners();
        return;
      }

      _parsedConfigs = configMaps.map((m) => ParsedConfigData.fromMap(m)).toList();
      _progressMessage = 'Found ${_parsedConfigs.length} config(s). Parsing IPs...';
      notifyListeners();

      // Step 2: Parse IPs in isolate
      final ips = await compute(_parseIpsIsolate, _ipsInput);
      
      if (ips.isEmpty) {
        _errorMessage = 'No valid IPs found. Enter one IP per line.';
        _isProcessing = false;
        _progressMessage = '';
        notifyListeners();
        return;
      }

      _ipCount = ips.length;
      final totalConfigs = _parsedConfigs.length * ips.length;
      _progressMessage = 'Generating $totalConfigs configs...';
      notifyListeners();

      // Step 3: Generate configs in isolate
      final input = _GenerationInput(configMaps, ips);
      _generatedConfigs = await compute(_generateConfigsIsolate, input);

      _progressMessage = '';
      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error generating configs: $e';
      _isProcessing = false;
      _progressMessage = '';
      notifyListeners();
    }
  }

  /// Copies all generated configs to clipboard (in isolate for large lists)
  Future<void> copyAllToClipboard() async {
    if (_generatedConfigs.isEmpty) return;
    
    // For very large lists, join in isolate
    String text;
    if (_generatedConfigs.length > 10000) {
      text = await compute((List<String> configs) => configs.join('\n'), _generatedConfigs);
    } else {
      text = _generatedConfigs.join('\n');
    }
    
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Clears all inputs and outputs
  void clear() {
    _configsInput = '';
    _ipsInput = '';
    _parsedConfigs = [];
    _ipCount = 0;
    _generatedConfigs = [];
    _errorMessage = null;
    _progressMessage = '';
    _displayedCount = _pageSize;
    notifyListeners();
  }
}

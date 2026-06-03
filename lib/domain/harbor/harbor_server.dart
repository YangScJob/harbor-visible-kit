import 'package:harbor_visible_kit/domain/harbor/harbor_connection.dart';

/// Harbor server address saved for quick selection.
class HarborServer {
  final String host;
  final int port;

  const HarborServer({required this.host, required this.port});

  String get id => buildId(host: host, port: port);

  String get registry => '$host:$port';

  String get displayLabel => registry;

  bool get isValid => host.isNotEmpty && port > 0;

  Map<String, dynamic> toJson() => {'id': id, 'host': host, 'port': port};

  factory HarborServer.fromJson(Map<String, dynamic> json) {
    return HarborServer(
      host: json['host'] as String? ?? '',
      port: _parsePort(json['port']),
    );
  }

  factory HarborServer.fromConnection(HarborConnection connection) {
    return HarborServer(host: connection.host, port: connection.port);
  }

  static String buildId({required String host, required int port}) {
    final normalizedHost = host.trim().toLowerCase();
    return '$normalizedHost:$port';
  }

  static int _parsePort(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 8085;
    return 8085;
  }
}

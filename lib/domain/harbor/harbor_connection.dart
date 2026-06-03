/// Harbor connection configuration model.
class HarborConnection {
  final String host;
  final int port;
  final String username;
  final String password;

  const HarborConnection({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  /// Stable identifier for a Harbor host, port, and username.
  String get id => buildId(host: host, port: port, username: username);

  /// Display label for selectors.
  String get displayLabel => '$registry / $username';

  /// Full base URL used by Dio.
  String get baseUrl => 'http://$host:$port';

  /// Registry address used by the Harbor Registry API.
  String get registry => '$host:$port';

  /// Whether the connection fields are complete enough to use.
  bool get isValid =>
      host.isNotEmpty && port > 0 && username.isNotEmpty && password.isNotEmpty;

  /// Serializes the connection, including the password.
  Map<String, dynamic> toJson() => {
    'id': id,
    'host': host,
    'port': port,
    'username': username,
    'password': password,
  };

  /// Deserializes a connection from JSON.
  factory HarborConnection.fromJson(Map<String, dynamic> json) {
    return HarborConnection(
      host: json['host'] as String? ?? '',
      port: _parsePort(json['port']),
      username: json['username'] as String? ?? 'admin',
      password: json['password'] as String? ?? '',
    );
  }

  /// Empty connection configuration.
  factory HarborConnection.empty() => const HarborConnection(
    host: '',
    port: 8085,
    username: 'admin',
    password: '',
  );

  HarborConnection copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
  }) {
    return HarborConnection(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  static String buildId({
    required String host,
    required int port,
    required String username,
  }) {
    final normalizedHost = host.trim().toLowerCase();
    final normalizedUser = username.trim();
    return '$normalizedHost:$port|$normalizedUser';
  }

  static int _parsePort(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 8085;
    return 8085;
  }
}

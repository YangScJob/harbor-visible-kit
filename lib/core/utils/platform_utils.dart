import 'dart:io' show Platform;

/// Cross-platform utility helpers.
class PlatformUtils {
  PlatformUtils._();

  /// Default downloads path.
  static String get downloadsPath {
    if (Platform.isWindows) {
      final userProfile =
          Platform.environment['USERPROFILE'] ?? r'C:\Users\Default';
      return '$userProfile\\Downloads';
    }
    final home = Platform.environment['HOME'] ?? '/root';
    return '$home/Downloads';
  }
}

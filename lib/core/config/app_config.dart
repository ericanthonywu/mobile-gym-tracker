import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide configuration constants.
class AppConfig {
  AppConfig._();

  /// Base URL for the API — read from .env file or compile-time variable with fallback to hosted backend URL
  static String get baseUrl {
    final envUrl = dotenv.env['BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl.endsWith('/') ? '${envUrl}api' : envUrl;
    }
    return const String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'http://srv1743851.hstgr.cloud:3001/api',
    );
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around flutter_secure_storage for JWT token & local preference persistence.
class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _tokenKey = 'gym_tracker_jwt';
  static const String _mensConfirmedKey = 'mens_last_confirmed_date';

  static Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  static Future<String?> getToken() => _storage.read(key: _tokenKey);
  static Future<void> deleteToken() => _storage.delete(key: _tokenKey);
  static Future<bool> hasToken() async => (await _storage.read(key: _tokenKey)) != null;

  static Future<void> saveMensConfirmedDate(String dateStr) => _storage.write(key: _mensConfirmedKey, value: dateStr);
  static Future<String?> getMensConfirmedDate() => _storage.read(key: _mensConfirmedKey);
}

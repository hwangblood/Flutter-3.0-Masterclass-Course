import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oauth2/oauth2.dart' as oauth2 show Credentials;

import 'package:repo_viewer/auth/infrastructure/credentials_storage/credentials_storage.dart';

class SecureCredentialsStorage implements CredentialsStorage {
  static const _key = 'oauth2_credentials';

  final FlutterSecureStorage _storage;

  /// runtime cache of credentials
  oauth2.Credentials? _cachedCredentials;

  SecureCredentialsStorage(this._storage);

  @override
  Future<oauth2.Credentials?> read() async {
    if (_cachedCredentials != null) {
      return _cachedCredentials;
    }

    // Could throw a [PlatformException].
    String? jsonStr = await _storage.read(key: _key);

    try {
      if (jsonStr != null) {
        // Throws a [FormatException] if the JSON is incorrectly formatted.
        _cachedCredentials = oauth2.Credentials.fromJson(jsonStr);
      }
    } on FormatException {
      return null;
    }
    return _cachedCredentials;
  }

  @override
  Future<void> save(oauth2.Credentials credentials) {
    _cachedCredentials = credentials;
    return _storage.write(key: _key, value: credentials.toJson());
  }

  @override
  Future<void> clear() {
    _cachedCredentials = null;
    return _storage.delete(key: _key);
  }
}

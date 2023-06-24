import 'package:oauth2/oauth2.dart' as oauth2 show Credentials;

abstract class CredentialsStorage {
  Future<oauth2.Credentials?> read();

  Future<void> save(oauth2.Credentials credentials);

  Future<void> clear();
}

import 'package:flutter/services.dart';

import 'package:oauth2/oauth2.dart' as oauth2 show Credentials;

import 'package:repo_viewer/auth/infrastructure/credentials_storage/credentials_storage.dart';

class GithubAuthenticator {
  final CredentialsStorage _credentialsStorage;

  GithubAuthenticator(this._credentialsStorage);

  /// Get the signed in credentials, it hold the access token.
  /// No Credentials when user is not signed in, and Github does not use required tokens, but we still show a way to deal with it
  Future<oauth2.Credentials?> getSignedInCredentials() async {
    oauth2.Credentials? storedCredentials;
    try {
      storedCredentials = await _credentialsStorage.read();

      if (storedCredentials != null) {
        if (storedCredentials.canRefresh && storedCredentials.isExpired) {
          // TODO: refresh the access token
        }
      }
    } on PlatformException {
      return null;
    }

    return storedCredentials;
  }

  Future<bool> checkSignedIn() => getSignedInCredentials().then(
        (credentials) => credentials != null ? true : false,
      );
}

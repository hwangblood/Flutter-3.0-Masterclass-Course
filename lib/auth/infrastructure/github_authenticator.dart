import 'package:flutter/services.dart';

import 'package:dartz/dartz.dart' as dartz;

import 'package:repo_viewer/auth/domain/auth_failure.dart';
import 'package:repo_viewer/auth/infrastructure/credentials_storage/credentials_storage.dart';

import 'package:oauth2/oauth2.dart' as oauth2;

/// Query parameters for redirect callback, it just contains the authorization code
typedef QueryParams = Map<String, String>;

class GithubAuthenticator {
  // TODO: don't use plain text here
  static const clientID = '8c18a431995a651c125c';
  static const clientSecret = '8bedf732ec05aa9f76d6b095a609839ed383f50c';

  /// Scopes define the access for personal tokens.
  static const scopes = ['read:user', 'repo'];

  /// Url to request a user's GitHub identity
  /// https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#1-request-a-users-github-identity
  static final authorizationEndpoint = Uri.parse(
    'https://github.com/login/oauth/authorize',
  );

  /// Url to request user's access token
  /// https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#2-users-are-redirected-back-to-your-site-by-github
  static final tokenEndpoint = Uri.parse(
    'https://github.com/login/oauth/access_token',
  );

  /// redirect url after authorization, only redirect for web platform
  static final redirectUrl = Uri.parse('http://locahost:3000/callback');

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

  oauth2.AuthorizationCodeGrant createGrant() => oauth2.AuthorizationCodeGrant(
        clientID,
        authorizationEndpoint,
        tokenEndpoint,
        secret: clientSecret,
      );

  Uri getAuthorizationUrl(oauth2.AuthorizationCodeGrant grant) =>
      grant.getAuthorizationUrl(
        redirectUrl,
        scopes: scopes,
      );

  /// when exception is happened return an [AuthFailure], otherwise nothing
  ///
  /// [dartz.Unit] means the same thing as void, just noting to return
  Future<dartz.Either<AuthFailure, dartz.Unit>> handleAuthorizationResponse(
    oauth2.AuthorizationCodeGrant grant,
    QueryParams queryParams,
  ) async {
    try {
      /// Throws [FormatException] or [AuthorizationException]
      final httpClient = await grant.handleAuthorizationResponse(queryParams);
      await _credentialsStorage.save(httpClient.credentials);
    } on FormatException catch (e) {
      return dartz.left(AuthFailure.server(e.message));
    } on oauth2.AuthorizationException catch (e) {
      return dartz.left(AuthFailure.server('${e.error}: ${e.description}'));
    } on PlatformException {
      return dartz.left(const AuthFailure.storage());
    }
    return const dartz.Right(dartz.unit);
  }
}

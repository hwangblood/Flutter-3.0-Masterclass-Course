import 'package:flutter/services.dart';

import 'package:dartz/dartz.dart' as dartz;
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;

import 'package:repo_viewer/auth/domain/auth_failure.dart';
import 'package:repo_viewer/auth/infrastructure/credentials_storage/credentials_storage.dart';
import 'package:repo_viewer/core/infrastructure/dio_extensions.dart';

/// Query parameters for redirect callback, it just contains the authorization code
typedef QueryParams = Map<String, String>;

class GithubOauthHttpClient extends http.BaseClient {
  final httpClient = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // receive the response in json formats from Github Oauth
    request.headers['Accept'] = 'application/json';
    return httpClient.send(request);
  }
}

class GithubAuthenticator {
  // TODO: don't use plain text here
  static const clientId = '8c18a431995a651c125c';
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

  static final revocationEndpoint = Uri.parse(
    'https://api.github.com/applications/$clientId/grant',
  );

  final CredentialsStorage _credentialsStorage;

  final Dio _dio;

  GithubAuthenticator(
    this._credentialsStorage,
    this._dio,
  );

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
        (credentials) => credentials != null,
      );

  oauth2.AuthorizationCodeGrant createGrant() => oauth2.AuthorizationCodeGrant(
        clientId,
        authorizationEndpoint,
        tokenEndpoint,
        secret: clientSecret,
        httpClient: GithubOauthHttpClient(),
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

  /// User sign-out, return [AuthFailure] when error happens
  Future<dartz.Either<AuthFailure, dartz.Unit>> signOut() async {
    final accessToken = await _credentialsStorage.read().then(
          (value) => value?.accessToken,
        );
    try {
      try {
        // revoke the access token from github, it will be invalid
        // https://docs.github.com/en/rest/apps/oauth-applications?apiVersion=2022-11-28#delete-an-app-authorization
        _dio.deleteUri(
          revocationEndpoint,
          data: {
            'access_token': accessToken,
          },
          options: Options(
            headers: {
              'Accept': 'application/vnd.github+json',
              'Authorization': 'Bearer $accessToken'
            },
          ),
        );
      } on DioException catch (e) {
        // SokectException means the network connection is offline.
        // when SokectException happens, it should be DioExceptionType.unknown,
        // because DioException wraps another exception inside of its instance.
        if (e.isNoConnectionException) {
          // Ignoring the exception
        } else {
          rethrow;
        }
      }
      await _credentialsStorage.clear();
    } on PlatformException {
      return dartz.left(const AuthFailure.storage());
    }
    return dartz.right(dartz.unit);
  }
}

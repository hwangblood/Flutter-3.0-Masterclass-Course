import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:repo_viewer/auth/domain/auth_failure.dart';
import 'package:repo_viewer/auth/infrastructure/github_authenticator.dart';

part 'auth_notifier.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const AuthState._();
  const factory AuthState.initial() = _Initial;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.authenticated() = _Authenticated;
  const factory AuthState.failure(AuthFailure failure) = _Failure;
}

/// Authentication Callback function
/// param [Uri] the authorization url
/// return [Uri] should be a redirect uri with authorization code parameter
/// It looks like: http://localhost:3000/callback?code=adsafgerwx
typedef AuthUriCallback = Future<Uri> Function(Uri);

class AuthNotifier extends StateNotifier<AuthState> {
  final GithubAuthenticator _authenticator;

  AuthNotifier(GithubAuthenticator authenticator)
      : _authenticator = authenticator,
        super(const AuthState.initial());

  Future<void> checkAndUpdateAuthState() async {
    state = (await _authenticator.checkSignedIn())
        ? const AuthState.authenticated()
        : const AuthState.unauthenticated();
  }

  Future<void> signIn(AuthUriCallback authorizationCallback) async {
    final grant = _authenticator.createGrant();
    final authorizationUrl = _authenticator.getAuthorizationUrl(grant);

    final redirectUrl = await authorizationCallback(authorizationUrl);
    final failureOrSuccess = await _authenticator.handleAuthorizationResponse(
      grant,
      redirectUrl.queryParameters,
    );
    state = failureOrSuccess.fold(
      (l) => AuthState.failure(l),
      (r) => const AuthState.authenticated(),
    );
    grant.close();
  }
}

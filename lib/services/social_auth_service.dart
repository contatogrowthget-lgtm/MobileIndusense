import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/config/social_config.dart';
import 'api_client.dart';

/// Resultado do login no Google/Apple: token para a API validar.
class SocialToken {
  final String token;
  final String? nome;
  const SocialToken(this.token, {this.nome});
}

/// Exceção para quando o usuário fecha a janela de login (não mostramos erro).
class SocialCancelado implements Exception {}

class SocialAuthService {
  GoogleSignIn? _google;

  GoogleSignIn get _g {
    final apple = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
    return _google ??= GoogleSignIn(
      scopes: const ['email', 'profile'],
      clientId: apple ? SocialConfig.googleIosClientId : null,
      serverClientId: apple ? null : SocialConfig.googleWebClientId,
    );
  }

  Future<SocialToken> google() async {
    if (!SocialConfig.googleConfigurado) {
      throw ApiException(
        'Login com Google ainda não configurado. Siga o SOCIAL_LOGIN.md e coloque os IDs em social_config.dart.',
      );
    }
    try {
      await _g.signOut(); // sempre mostra a escolha de conta
      final conta = await _g.signIn();
      if (conta == null) throw SocialCancelado();
      final auth = await conta.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw ApiException('O Google não devolveu o idToken. Confira o ID do cliente Web/iOS.');
      }
      return SocialToken(idToken, nome: conta.displayName);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') throw SocialCancelado();
      throw ApiException('Google: ${e.message ?? e.code}');
    }
  }

  Future<SocialToken> apple() async {
    if (!SocialConfig.appleConfigurado) {
      throw ApiException(
        'Login com Apple ainda não configurado. Ative "Sign in with Apple" no Xcode (veja SOCIAL_LOGIN.md).',
      );
    }
    try {
      final cred = await SignInWithApple.getAppleIDCredential(scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ]);
      final token = cred.identityToken;
      if (token == null) throw ApiException('A Apple não devolveu o token de identidade.');
      final nome = [cred.givenName, cred.familyName].whereType<String>().join(' ').trim();
      return SocialToken(token, nome: nome.isEmpty ? null : nome);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw SocialCancelado();
      throw ApiException('Apple: ${e.message}');
    } on PlatformException catch (e) {
      throw ApiException('Apple: ${e.message ?? e.code}');
    }
  }
}

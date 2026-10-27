import 'package:flutter/foundation.dart';

/// Chaves do login social. Enquanto estiverem vazias, os botões aparecem,
/// mas avisam que falta configurar (sem travar o app).
/// Passo a passo em SOCIAL_LOGIN.md, na raiz do projeto.
class SocialConfig {
  SocialConfig._();

  /// Google Cloud > Credenciais > ID do cliente OAuth do tipo **iOS**
  /// (serve para iPhone e Mac). Ex.: 1234-abcd.apps.googleusercontent.com
  static const String googleIosClientId = '';

  /// Google Cloud > Credenciais > ID do cliente OAuth do tipo **Aplicativo da Web**.
  /// No Android é ele que gera o idToken enviado para a API.
  static const String googleWebClientId = '';

  /// true depois de ativar "Sign in with Apple" no Xcode (exige conta Apple Developer).
  static const bool appleEnabled = false;

  static bool get _apple =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);

  static bool get googleConfigurado {
    if (kIsWeb) return false;
    if (_apple) return googleIosClientId.isNotEmpty;
    if (defaultTargetPlatform == TargetPlatform.android) return googleWebClientId.isNotEmpty;
    return false;
  }

  /// O botão da Apple só aparece em iPhone/iPad/Mac.
  static bool get mostrarApple => _apple;

  static bool get appleConfigurado => _apple && appleEnabled;
}

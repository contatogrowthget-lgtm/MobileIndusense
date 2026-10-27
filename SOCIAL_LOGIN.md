# Login com Google e Apple

Os botões já estão na tela de login. Enquanto não houver chaves, eles avisam
"ainda não configurado" (o app não trava). Para ligar de verdade:

## 0. Troque o identificador do app

Google e Apple exigem um identificador seu. Hoje ele é `com.example.indusense`.
No Xcode (abra `ios/Runner.xcworkspace` e `macos/Runner.xcworkspace`), em
**Runner > Signing & Capabilities > Bundle Identifier**, coloque algo como
`com.suaempresa.indusense`. Use o mesmo valor nos passos abaixo.

## 1. Google

1. Acesse https://console.cloud.google.com, crie um projeto e configure a **Tela de consentimento OAuth** (tipo Externo).
2. Em **Credenciais > Criar credenciais > ID do cliente OAuth**, crie:
   - um do tipo **iOS**, com o Bundle ID do passo 0 (serve para iPhone e Mac);
   - um do tipo **Aplicativo da Web** (usado pelo Android).
3. No app, em `lib/core/config/social_config.dart`, preencha:
   ```dart
   static const String googleIosClientId = 'XXXX.apps.googleusercontent.com'; // o do tipo iOS
   static const String googleWebClientId = 'YYYY.apps.googleusercontent.com'; // o do tipo Web
   ```
4. iPhone e Mac: no `Info.plist` (`ios/Runner/Info.plist` e `macos/Runner/Info.plist`), adicione o
   "iOS URL scheme" que o Google mostra na credencial iOS (é o ID ao contrário, `com.googleusercontent.apps.XXXX`):
   ```xml
   <key>CFBundleURLTypes</key>
   <array><dict>
     <key>CFBundleURLSchemes</key>
     <array><string>com.googleusercontent.apps.XXXX</string></array>
   </dict></array>
   ```
5. Mac: no Xcode, em **Signing & Capabilities**, adicione **Keychain Sharing**.
6. Android: crie também uma credencial **Android** com o pacote e o SHA-1
   (`cd android && ./gradlew signingReport`).
7. Na API (`indusense-api/.env`), coloque os IDs aceitos e reinicie:
   ```
   GOOGLE_CLIENT_IDS=XXXX.apps.googleusercontent.com,YYYY.apps.googleusercontent.com
   ```

## 2. Apple (precisa da conta Apple Developer, US$ 99/ano)

1. No Xcode, em **Signing & Capabilities > + Capability**, adicione **Sign in with Apple** (no projeto iOS e no macOS).
2. No app, em `social_config.dart`: `static const bool appleEnabled = true;`
3. Na API (`indusense-api/.env`):
   ```
   APPLE_CLIENT_IDS=com.suaempresa.indusense
   ```

## Como funciona

O app abre a janela do Google/Apple, recebe um token e manda para a API
(`POST /v1/auth/google` ou `/v1/auth/apple`). A API confere o token direto no
Google/Apple, cria a conta no primeiro acesso (perfil Visualizador) e devolve a
mesma sessão do login por e-mail. Se o e-mail já existir, entra na conta existente.

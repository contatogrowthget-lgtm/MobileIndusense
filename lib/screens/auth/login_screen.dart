import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/social_config.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_provider.dart';
import '../../widgets/auth_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _senhaVisivel = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _erro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.statusCritico,
    ));
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_emailController.text.trim(), _senhaController.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      HapticFeedback.heavyImpact();
      _erro(auth.errorMessage ?? 'Erro ao realizar login.');
    }
  }

  Future<void> _social(Future<bool> Function() metodo) async {
    final auth = context.read<AuthProvider>();
    final ok = await metodo();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else if (auth.errorMessage != null) {
      _erro(auth.errorMessage!);
    }
  }

  void _esqueciSenha() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_reset_rounded, color: AuthColors.azul, size: 32),
        title: const Text('Esqueceu a senha?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Peça ao administrador do InduSense para redefinir a sua senha no painel (Usuários). '
          'Se a sua conta é do Google ou da Apple, entre pelo botão correspondente.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(140, 46)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      ondasAltura: 84,
      child: SafeArea(
        child: LayoutBuilder(builder: (context, tela) {
          final largura = (tela.maxWidth - 48).clamp(0.0, 412.0);
          final larguraFoto = (largura * .40).clamp(120.0, 170.0);
          final alturaFoto = larguraFoto * 450 / 348;
          // cabe na tela sem rolar; só rola se o teclado abrir ou a tela for baixa
          final lateral = ((tela.maxWidth - 460) / 2).clamp(24.0, double.infinity);
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: lateral),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tela.maxHeight),
              child: IntrinsicHeight(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SizedBox(height: 12),
                      // ---------- cabeçalho: marca + título à esquerda, foto à direita
                      SizedBox(
                        height: alturaFoto - 8,
                        child: Stack(clipBehavior: Clip.none, children: [
                          Positioned(
                            top: -6,
                            right: -30,
                            width: larguraFoto,
                            child: Entrada(
                              atrasoMs: 150,
                              deslocamento: -12,
                              child: Image.asset('assets/images/login_hero.png',
                                  fit: BoxFit.contain, filterQuality: FilterQuality.high),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(right: larguraFoto - 26),
                            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              SizedBox(height: 6),
                              Entrada(child: BrandWordmark(fonte: 30, simbolo: false)),
                              Spacer(),
                              Entrada(atrasoMs: 80, child: TituloAzul('Bem-vindo\n', 'de volta!', fonte: 30)),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      const Entrada(
                        atrasoMs: 110,
                        child: Text('Acesse sua conta para continuar monitorando o que realmente importa.',
                            style: TextStyle(color: AuthColors.texto, fontSize: 14.5, height: 1.4)),
                      ),
                      const Spacer(),
                      const SizedBox(height: 18),
                      // ---------- formulário
                      Entrada(
                        atrasoMs: 160,
                        child: AuthCard(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                          child: Form(
                            key: _formKey,
                            child: AutofillGroup(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: TextInputAction.next,
                                  style: authTextoCampo,
                                  decoration: authCampo('E-mail corporativo', Icons.mail_outline_rounded),
                                  validator: (v) => (v == null || !v.contains('@') || !v.contains('.'))
                                      ? 'Informe um e-mail válido'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _senhaController,
                                  obscureText: !_senhaVisivel,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) {
                                    if (!auth.loading) _entrar();
                                  },
                                  style: authTextoCampo,
                                  decoration: authCampo(
                                    'Senha',
                                    Icons.lock_outline_rounded,
                                    sufixo: OlhoSenha(
                                      visivel: _senhaVisivel,
                                      onTap: () => setState(() => _senhaVisivel = !_senhaVisivel),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.length < 4) ? 'Senha muito curta' : null,
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _esqueciSenha,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AuthColors.azul,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Esqueci a senha',
                                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GradientButton(
                                  carregando: auth.carregandoVia == 'email',
                                  onPressed: auth.loading ? null : _entrar,
                                  texto: 'Entrar',
                                ),
                                const SizedBox(height: 18),
                                const OuDivisor(),
                                const SizedBox(height: 14),
                                Row(children: [
                                  Expanded(
                                    child: BotaoSocial(
                                      rotulo: 'Google',
                                      icone: const GoogleLogo(size: 22),
                                      carregando: auth.carregandoVia == 'google',
                                      onPressed: auth.loading ? null : () => _social(auth.loginGoogle),
                                    ),
                                  ),
                                  if (SocialConfig.mostrarApple) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: BotaoSocial(
                                        rotulo: 'Apple',
                                        escuro: true,
                                        icone: const Icon(Icons.apple, color: Colors.white, size: 24),
                                        carregando: auth.carregandoVia == 'apple',
                                        onPressed: auth.loading ? null : () => _social(auth.loginApple),
                                      ),
                                    ),
                                  ],
                                ]),
                                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const Text('Não tem conta?', style: TextStyle(color: AuthColors.texto, fontSize: 14)),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pushNamed('/cadastro'),
                                    style: TextButton.styleFrom(foregroundColor: AuthColors.azul),
                                    child: const Text('Cadastre-se',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                                  ),
                                ]),
                              ]),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 64), // espaço das ondas
                    ]),
                  ),
            ),
          );
        }),
      ),
    );
  }
}

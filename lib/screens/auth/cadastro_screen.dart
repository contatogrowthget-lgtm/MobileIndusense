import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/social_config.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_provider.dart';
import '../../widgets/auth_ui.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  bool _senhaVisivel = false;
  bool _confirmaVisivel = false;
  bool _aceitou = false;
  bool _avisarTermos = false;

  late final TapGestureRecognizer _tapTermos = TapGestureRecognizer()..onTap = () => _mostrarTexto(_termos);
  late final TapGestureRecognizer _tapPrivacidade = TapGestureRecognizer()..onTap = () => _mostrarTexto(_privacidade);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _tapTermos.dispose();
    _tapPrivacidade.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    final valido = _formKey.currentState!.validate();
    if (!_aceitou) {
      HapticFeedback.heavyImpact();
      setState(() => _avisarTermos = true);
    }
    if (!valido || !_aceitou) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final ok = await auth.cadastrar(
      nome: _nomeController.text.trim(),
      email: _emailController.text.trim(),
      senha: _senhaController.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
    } else {
      _erro(auth.errorMessage ?? 'Erro ao cadastrar.');
    }
  }

  void _erro(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.statusCritico,
      ));

  Future<void> _social(Future<bool> Function() metodo) async {
    final auth = context.read<AuthProvider>();
    final ok = await metodo();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
    } else if (auth.errorMessage != null) {
      _erro(auth.errorMessage!);
    }
  }

  static const _termos = (
    'Termos de Uso',
    'O InduSense é uma ferramenta de apoio ao monitoramento de ambientes industriais. '
        'As leituras de sensores e as análises de câmera ajudam a equipe a agir mais rápido, '
        'mas não substituem os procedimentos de segurança, inspeções e responsáveis técnicos da empresa.\n\n'
        'Você é responsável por manter a sua senha em sigilo e por usar o sistema apenas para fins de trabalho. '
        'O administrador da sua empresa pode alterar o seu perfil de acesso ou desativar a conta.',
  );

  static const _privacidade = (
    'Política de Privacidade',
    'Guardamos o seu nome, e-mail, cargo, empresa e foto de perfil para identificar você no sistema, '
        'além dos aparelhos e horários de acesso, para a segurança da conta.\n\n'
        'As imagens das câmeras são usadas para verificar o uso de EPI. As fotos de ocorrências ficam visíveis '
        'apenas para usuários da sua empresa. Você pode pedir a correção ou a exclusão dos seus dados ao administrador.',
  );

  void _mostrarTexto((String, String) t) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.$1, style: const TextStyle(color: AuthColors.tinta, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(t.$2, style: const TextStyle(color: AuthColors.texto, fontSize: 14.5, height: 1.55)),
          const SizedBox(height: 20),
          GradientButton(
            texto: 'Li e concordo',
            carregando: false,
            onPressed: () {
              setState(() {
                _aceitou = true;
                _avisarTermos = false;
              });
              Navigator.pop(ctx);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      ondasAltura: 70,
      child: SafeArea(
        child: LayoutBuilder(builder: (context, tela) {
          final lateral = ((tela.maxWidth - 440) / 2).clamp(24.0, double.infinity);
          // cabe na tela sem rolar; só rola com o teclado aberto ou em tela baixa
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: lateral),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tela.maxHeight),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: IconButton(
                            tooltip: 'Voltar',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              fixedSize: const Size(46, 46),
                              side: const BorderSide(color: AuthColors.borda),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded, color: AuthColors.tinta, size: 22),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Entrada(child: TituloAzul('Crie sua conta\nno ', 'InduSense', fonte: 32)),
                      const SizedBox(height: 8),
                      const Entrada(
                        atrasoMs: 60,
                        child: Text('Acompanhe sensores, câmeras e alertas em tempo real.',
                            style: TextStyle(color: AuthColors.texto, fontSize: 15, height: 1.4)),
                      ),
                      const SizedBox(height: 22),
                      Entrada(
                        atrasoMs: 120,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          TextFormField(
                            controller: _nomeController,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            style: authTextoCampo,
                            decoration: authCampo('Nome completo', Icons.person_outline_rounded),
                            validator: (v) => (v == null || v.trim().length < 3) ? 'Informe seu nome completo' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            style: authTextoCampo,
                            decoration: authCampo('E-mail corporativo', Icons.mail_outline_rounded),
                            validator: (v) =>
                                (v == null || !v.contains('@') || !v.contains('.')) ? 'Informe um e-mail válido' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _senhaController,
                            obscureText: !_senhaVisivel,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.next,
                            style: authTextoCampo,
                            decoration: authCampo('Senha', Icons.lock_outline_rounded,
                                sufixo: OlhoSenha(
                                    visivel: _senhaVisivel, onTap: () => setState(() => _senhaVisivel = !_senhaVisivel))),
                            validator: (v) => (v == null || v.length < 6) ? 'Mínimo de 6 caracteres' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmarSenhaController,
                            obscureText: !_confirmaVisivel,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!auth.loading) _cadastrar();
                            },
                            style: authTextoCampo,
                            decoration: authCampo('Confirmar senha', Icons.lock_outline_rounded,
                                sufixo: OlhoSenha(
                                    visivel: _confirmaVisivel,
                                    onTap: () => setState(() => _confirmaVisivel = !_confirmaVisivel))),
                            validator: (v) => v != _senhaController.text ? 'As senhas não conferem' : null,
                          ),
                          const SizedBox(height: 14),
                          _termosCheck(),
                          const SizedBox(height: 16),
                          GradientButton(
                            carregando: auth.loading && auth.carregandoVia == null,
                            onPressed: auth.loading ? null : _cadastrar,
                            texto: 'Cadastrar',
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
                                  icone: const Icon(Icons.apple, color: AuthColors.tinta, size: 24),
                                  carregando: auth.carregandoVia == 'apple',
                                  onPressed: auth.loading ? null : () => _social(auth.loginApple),
                                ),
                              ),
                            ],
                          ]),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Text('Já tem uma conta?', style: TextStyle(color: AuthColors.texto, fontSize: 14)),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(foregroundColor: AuthColors.azul),
                              child: const Text('Entrar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                            ),
                          ]),
                        ]),
                      ),
                      const Spacer(),
                      const SizedBox(height: 40), // espaço das ondas
                    ]),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _termosCheck() {
    final cor = _avisarTermos && !_aceitou ? AppColors.statusCritico : AuthColors.borda;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _aceitou = !_aceitou;
        _avisarTermos = false;
        HapticFeedback.selectionClick();
      }),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _aceitou ? authGradiente : null,
            color: _aceitou ? null : Colors.white,
            border: _aceitou ? null : Border.all(color: cor, width: 1.6),
          ),
          child: _aceitou ? const Icon(Icons.check_rounded, color: Colors.white, size: 17) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                  color: _avisarTermos && !_aceitou ? AppColors.statusCritico : AuthColors.texto, fontSize: 13.5),
              children: [
                const TextSpan(text: 'Li e aceito os '),
                TextSpan(
                    text: 'Termos de Uso',
                    recognizer: _tapTermos,
                    style: const TextStyle(color: AuthColors.azul, fontWeight: FontWeight.w700)),
                const TextSpan(text: ' e a '),
                TextSpan(
                    text: 'Política de Privacidade',
                    recognizer: _tapPrivacidade,
                    style: const TextStyle(color: AuthColors.azul, fontWeight: FontWeight.w700)),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

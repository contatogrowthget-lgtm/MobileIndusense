import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/profile_service.dart';
import '../../widgets/settings_ui.dart';
import '../../widgets/ui.dart';

/// Troca da própria senha (PATCH /users/profile/password).
/// Por segurança a API desconecta os outros aparelhos — avisamos quantos.
class AlterarSenhaScreen extends StatefulWidget {
  const AlterarSenhaScreen({super.key});

  @override
  State<AlterarSenhaScreen> createState() => _AlterarSenhaScreenState();
}

class _AlterarSenhaScreenState extends State<AlterarSenhaScreen> {
  final _form = GlobalKey<FormState>();
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirma = TextEditingController();
  final _ver = <String, bool>{'atual': false, 'nova': false, 'confirma': false};
  bool _salvando = false;
  String? _erroAtual;

  @override
  void initState() {
    super.initState();
    for (final c in [_atual, _nova, _confirma]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirma.dispose();
    super.dispose();
  }

  // -------- regras
  bool get _tamanho => _nova.text.length >= 8;
  bool get _maiuscula => RegExp(r'[A-Z]').hasMatch(_nova.text);
  bool get _numero => RegExp(r'\d').hasMatch(_nova.text);
  bool get _simbolo => RegExp(r'[^A-Za-z0-9]').hasMatch(_nova.text);
  bool get _diferente => _nova.text.isNotEmpty && _nova.text != _atual.text;

  /// 0 a 4
  int get _forca {
    if (_nova.text.isEmpty) return 0;
    var f = 0;
    if (_nova.text.length >= 6) f++;
    if (_tamanho) f++;
    if (_maiuscula && RegExp(r'[a-z]').hasMatch(_nova.text)) f++;
    if (_numero) f++;
    if (_simbolo) f++;
    return f.clamp(1, 4);
  }

  static const _rotulos = ['', 'Fraca', 'Razoável', 'Boa', 'Forte'];
  static const _cores = [
    AppColors.statusOffline,
    AppColors.statusCritico,
    AppColors.statusAtencao,
    Color(0xFF3B82F6),
    AppColors.statusNormal,
  ];

  bool get _podeSalvar =>
      _atual.text.isNotEmpty && _nova.text.length >= 6 && _diferente && _nova.text == _confirma.text;

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    setState(() => _erroAtual = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final encerradas = await ProfileService().alterarSenha(atual: _atual.text, nova: _nova.text);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => _Sucesso(encerradas: encerradas));
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      if (e.message.toLowerCase().contains('atual')) {
        setState(() => _erroAtual = e.message);
        _form.currentState!.validate();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _campo(String chave, TextEditingController c, String hint, {String? Function(String?)? validator, bool ultimo = false}) {
    final visivel = _ver[chave]!;
    return TextFormField(
      controller: c,
      obscureText: !visivel,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: ultimo
          ? (_) {
              if (_podeSalvar) _salvar();
            }
          : null,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: visivel ? 'Esconder' : 'Mostrar',
          icon: Icon(visivel ? Icons.visibility_off_rounded : Icons.visibility_rounded),
          onPressed: () => setState(() => _ver[chave] = !visivel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final forca = _forca;
    final cor = _cores[forca];

    return Scaffold(
      appBar: AppBar(title: const Text('Alterar senha')),
      bottomNavigationBar: BottomActionBar(
        label: 'Alterar senha',
        icon: Icons.lock_reset_rounded,
        loading: _salvando,
        onPressed: _podeSalvar ? _salvar : null,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            FadeSlideIn(
              child: AppCard(
                gradient: AppGradients.hero,
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.shield_moon_rounded, color: AppColors.cyan, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Proteja a sua conta',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                      SizedBox(height: 3),
                      Text(
                        'Depois da troca, os outros celulares e navegadores saem da conta. Este aparelho continua conectado.',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 22),
            LabeledField(
              label: 'Senha atual',
              child: _campo('atual', _atual, 'Digite a senha que você usa hoje',
                  validator: (v) => (v ?? '').isEmpty ? 'Informe a senha atual.' : _erroAtual),
            ),
            LabeledField(
              label: 'Nova senha',
              child: _campo('nova', _nova, 'Mínimo de 6 caracteres', validator: (v) {
                final s = v ?? '';
                if (s.length < 6) return 'A nova senha precisa ter pelo menos 6 caracteres.';
                if (s == _atual.text) return 'A nova senha precisa ser diferente da atual.';
                return null;
              }),
            ),

            // medidor de força
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: _nova.text.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          for (var i = 1; i <= 4; i++) ...[
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i <= forca ? cor : cor.withOpacity(.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            if (i < 4) const SizedBox(width: 6),
                          ],
                        ]),
                        const SizedBox(height: 8),
                        Text('Senha ${_rotulos[forca].toLowerCase()}',
                            style: TextStyle(color: cor, fontWeight: FontWeight.w800, fontSize: 12.5)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _Regra('8+ caracteres', _tamanho),
                          _Regra('Letra maiúscula', _maiuscula),
                          _Regra('Número', _numero),
                          _Regra('Símbolo (!@#)', _simbolo),
                          _Regra('Diferente da atual', _diferente),
                        ]),
                      ]),
                    ),
            ),

            LabeledField(
              label: 'Confirmar nova senha',
              child: _campo('confirma', _confirma, 'Repita a nova senha',
                  ultimo: true, validator: (v) => v != _nova.text ? 'As senhas não são iguais.' : null),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _confirma.text.isEmpty ? 0 : 1,
              child: Row(children: [
                const SizedBox(width: 4),
                Icon(
                  _confirma.text == _nova.text ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 16,
                  color: _confirma.text == _nova.text ? AppColors.statusNormal : AppColors.statusCritico,
                ),
                const SizedBox(width: 6),
                Text(
                  _confirma.text == _nova.text ? 'As senhas conferem' : 'As senhas ainda não conferem',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _confirma.text == _nova.text ? AppColors.statusNormal : AppColors.statusCritico,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Regra extends StatelessWidget {
  final String texto;
  final bool ok;
  const _Regra(this.texto, this.ok);

  @override
  Widget build(BuildContext context) {
    final cor = ok ? AppColors.statusNormal : mutedText(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? AppColors.statusNormal.withOpacity(.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ok ? Colors.transparent : cor.withOpacity(.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ok ? Icons.check_rounded : Icons.circle_outlined, size: 14, color: cor),
        const SizedBox(width: 5),
        Text(texto, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Diálogo de sucesso com o check animado.
class _Sucesso extends StatelessWidget {
  final int encerradas;
  const _Sucesso({required this.encerradas});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 650),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.brand),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Senha alterada!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          encerradas == 0
              ? 'Use a nova senha da próxima vez que entrar.'
              : encerradas == 1
                  ? 'Por segurança, 1 outro aparelho foi desconectado da sua conta.'
                  : 'Por segurança, $encerradas outros aparelhos foram desconectados da sua conta.',
          textAlign: TextAlign.center,
          style: TextStyle(color: mutedText(context), fontSize: 13.5, height: 1.4),
        ),
      ]),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
          onPressed: () => Navigator.pop(context),
          child: const Text('Pronto'),
        ),
      ],
    );
  }
}

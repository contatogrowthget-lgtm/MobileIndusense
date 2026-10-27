import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../widgets/foto_picker.dart';
import '../../widgets/settings_ui.dart';
import '../../widgets/ui.dart';
import '../../widgets/user_avatar.dart';

/// Editar perfil: foto (câmera ou galeria), nome, e-mail, cargo e empresa.
/// Mesmo comportamento da tela Configurações > Perfil do painel web.
class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _form = GlobalKey<FormState>();
  late final UserModel _original;
  late final TextEditingController _nome;
  late final TextEditingController _email;
  late final TextEditingController _cargo;
  late final TextEditingController _empresa;

  Uint8List? _novaFoto;
  bool _removerFoto = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _original = context.read<AuthProvider>().user!;
    _nome = TextEditingController(text: _original.nome);
    _email = TextEditingController(text: _original.email);
    _cargo = TextEditingController(text: _original.cargo ?? '');
    _empresa = TextEditingController(text: _original.empresa ?? '');
    for (final c in [_nome, _email, _cargo, _empresa]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_nome, _email, _cargo, _empresa]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _fotoMudou => _novaFoto != null || _removerFoto;
  bool get _temFotoAgora => _novaFoto != null || (!_removerFoto && _original.avatar != null);

  bool get _alterado =>
      _fotoMudou ||
      _nome.text.trim() != _original.nome ||
      _email.text.trim().toLowerCase() != _original.email.toLowerCase() ||
      _cargo.text.trim() != (_original.cargo ?? '') ||
      _empresa.text.trim() != (_original.empresa ?? '');

  Future<void> _escolherFoto() async {
    final e = await escolherFoto(context, temFoto: _temFotoAgora);
    if (e == null || !mounted) return;
    setState(() {
      if (e.remover) {
        _novaFoto = null;
        _removerFoto = _original.avatar != null;
      } else {
        _novaFoto = e.jpeg;
        _removerFoto = false;
      }
    });
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final email = _email.text.trim().toLowerCase();
      final novo = await ProfileService().atualizar(
        nome: _nome.text,
        email: email != _original.email.toLowerCase() ? email : null,
        cargo: _cargo.text,
        empresa: _empresa.text,
        avatar: _novaFoto != null ? ProfileService.dataUrlJpeg(_novaFoto!) : (_removerFoto ? '' : null),
      );
      if (!mounted) return;
      await context.read<AuthProvider>().atualizarUsuario(novo);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_rounded, color: AppColors.cyan, size: 20),
          SizedBox(width: 10),
          Text('Perfil atualizado!'),
        ]),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _voltar() async {
    if (!_alterado) {
      Navigator.of(context).pop();
      return;
    }
    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar alterações?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('As mudanças que você fez ainda não foram salvas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar editando')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar', style: TextStyle(color: AppColors.statusCritico)),
          ),
        ],
      ),
    );
    if (sair == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final previa = UserModel(
      id: _original.id,
      nome: _nome.text.trim().isEmpty ? _original.nome : _nome.text.trim(),
      email: _email.text,
      avatar: _original.avatar,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: _voltar),
        title: const Text('Editar perfil'),
      ),
      bottomNavigationBar: BottomActionBar(
        label: 'Salvar alterações',
        icon: Icons.check_rounded,
        loading: _salvando,
        onPressed: _alterado ? _salvar : null,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // ---------- foto
            Center(
              child: GestureDetector(
                onTap: _escolherFoto,
                child: Stack(clipBehavior: Clip.none, children: [
                  Hero(
                    tag: 'avatar-perfil',
                    child: UserAvatar(
                      user: previa,
                      size: 116,
                      ring: true,
                      preview: _novaFoto,
                      semFoto: _removerFoto && _novaFoto == null,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: AppGradients.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                      ),
                      child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: _escolherFoto,
                icon: Icon(cameraDisponivel ? Icons.add_a_photo_rounded : Icons.upload_rounded, size: 18),
                label: Text(_temFotoAgora ? 'Trocar foto' : 'Adicionar foto'),
              ),
            ),
            if (_fotoMudou)
              Center(
                child: Text(
                  _removerFoto && _novaFoto == null ? 'A foto será removida ao salvar' : 'Nova foto pronta — toque em Salvar',
                  style: const TextStyle(color: AppColors.statusAtencao, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: 22),

            // ---------- dados
            LabeledField(
              label: 'Nome completo',
              child: TextFormField(
                controller: _nome,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded), hintText: 'Seu nome'),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Informe o seu nome.' : null,
              ),
            ),
            LabeledField(
              label: 'E-mail',
              hint: 'É o e-mail que você usa para entrar.',
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.alternate_email_rounded)),
                validator: (v) {
                  final e = (v ?? '').trim();
                  if (e.isEmpty) return 'Informe o e-mail.';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return 'E-mail inválido.';
                  return null;
                },
              ),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: LabeledField(
                  label: 'Cargo',
                  child: TextFormField(
                    controller: _cargo,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.work_outline_rounded), hintText: 'Ex.: Técnico'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'Empresa',
                  child: TextFormField(
                    controller: _empresa,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (_alterado) _salvar();
                    },
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.business_rounded), hintText: 'Empresa'),
                  ),
                ),
              ),
            ]),

            // ---------- perfil de acesso (só leitura)
            const SizedBox(height: 4),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.electric.withOpacity(.13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _original.perfil == 'ADMIN' ? Icons.admin_panel_settings_rounded : Icons.shield_outlined,
                    color: AppColors.electric,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Perfil de acesso: ${_original.perfilLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(_descricaoPerfil(_original.perfil),
                        style: TextStyle(color: mutedText(context), fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  static String _descricaoPerfil(String? p) {
    switch (p) {
      case 'ADMIN':
        return 'Acesso total: usuários, salas, sensores e alertas.';
      case 'OPERADOR':
        return 'Pode resolver alertas e ocorrências. Só um administrador muda o perfil.';
      default:
        return 'Pode ver os dados. Só um administrador muda o perfil.';
    }
  }
}

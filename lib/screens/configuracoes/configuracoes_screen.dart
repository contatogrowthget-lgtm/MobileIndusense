import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/server_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../widgets/foto_picker.dart';
import '../../widgets/server_dialog.dart';
import '../../widgets/settings_ui.dart';
import '../../widgets/ui.dart';
import '../../widgets/user_avatar.dart';
import '../perfil/alterar_senha_screen.dart';
import '../perfil/editar_perfil_screen.dart';
import '../perfil/sessoes_screen.dart';

/// Aba "Perfil": cartão do usuário, conta, aparência, notificações e servidor.
class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  static const _kPush = 'notif_push';
  static const _kCriticos = 'notif_criticos';
  static const _kAtencao = 'notif_atencao';

  bool _notificacoesPush = true;
  bool _alertasCriticos = true;
  bool _alertasAtencao = true;

  bool _enviandoFoto = false;
  int? _sessoes;

  bool? _servidorOk;
  int? _latenciaMs;

  @override
  void initState() {
    super.initState();
    _carregarPrefs();
    _atualizar();
  }

  Future<void> _atualizar() async {
    await Future.wait([_testarServidor(), _contarSessoes(), context.read<AuthProvider>().recarregarPerfil()]);
  }

  Future<void> _carregarPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificacoesPush = p.getBool(_kPush) ?? true;
      _alertasCriticos = p.getBool(_kCriticos) ?? true;
      _alertasAtencao = p.getBool(_kAtencao) ?? true;
    });
  }

  Future<void> _salvarPref(String k, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(k, v);
  }

  Future<void> _testarServidor() async {
    final sw = Stopwatch()..start();
    final erro = await ServerConfig.test(ServerConfig.apiUrl);
    if (!mounted) return;
    setState(() {
      _servidorOk = erro == null;
      _latenciaMs = sw.elapsedMilliseconds;
    });
  }

  Future<void> _contarSessoes() async {
    try {
      final l = await ProfileService().sessoes();
      if (mounted) setState(() => _sessoes = l.length);
    } catch (_) {}
  }

  Future<void> _trocarFoto(UserModel user) async {
    final escolha = await escolherFoto(context, temFoto: user.avatar != null);
    if (escolha == null || !mounted) return;
    setState(() => _enviandoFoto = true);
    try {
      final novo = await ProfileService().atualizar(
        avatar: escolha.remover ? '' : ProfileService.dataUrlJpeg(escolha.jpeg!),
      );
      if (!mounted) return;
      await context.read<AuthProvider>().atualizarUsuario(novo);
      HapticFeedback.lightImpact();
      _aviso(escolha.remover ? 'Foto removida.' : 'Foto atualizada!');
    } on ApiException catch (e) {
      _aviso(e.message, erro: true);
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

  void _aviso(String msg, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(erro ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: erro ? const Color(0xFFFCA5A5) : AppColors.cyan, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
    ));
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela));
    if (mounted) _contarSessoes();
  }

  Future<void> _confirmarLogout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: AppColors.statusCritico, size: 30),
        title: const Text('Sair da conta?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Você vai precisar entrar de novo com e-mail e senha neste aparelho.',
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusCritico, minimumSize: const Size(110, 46)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final tema = context.watch<ThemeProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _atualizar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 32),
          children: [
            const FadeSlideIn(
              child: Padding(
                padding: EdgeInsets.only(bottom: 16, left: 2),
                child: Text('Perfil', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.8)),
              ),
            ),
            if (user != null) FadeSlideIn(index: 1, child: _cabecalho(user)),
            const SizedBox(height: 26),
            FadeSlideIn(
              index: 2,
              child: SettingsGroup(title: 'Conta', children: [
                SettingsItem(
                  icon: Icons.badge_rounded,
                  title: 'Editar perfil',
                  subtitle: 'Nome, e-mail, cargo, empresa e foto',
                  onTap: () => _abrir(const EditarPerfilScreen()),
                ),
                SettingsItem(
                  icon: Icons.lock_rounded,
                  color: const Color(0xFF8B5CF6),
                  title: 'Alterar senha',
                  subtitle: 'Os outros aparelhos são desconectados',
                  onTap: () => _abrir(const AlterarSenhaScreen()),
                ),
                SettingsItem(
                  icon: Icons.devices_rounded,
                  color: AppColors.cyan,
                  title: 'Aparelhos conectados',
                  subtitle: _sessoes == null
                      ? 'Onde a sua conta está aberta'
                      : _sessoes == 1
                          ? 'Só este aparelho'
                          : '$_sessoes aparelhos com a conta aberta',
                  trailing: _sessoes != null && _sessoes! > 1
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          _Contador(_sessoes!),
                          Icon(Icons.chevron_right_rounded, color: mutedText(context)),
                        ])
                      : null,
                  onTap: () => _abrir(const SessoesScreen()),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              index: 3,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  child: Text('APARÊNCIA',
                      style: TextStyle(
                          color: mutedText(context), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                ),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: SegmentedPicker<ThemeMode>(
                    value: tema.themeMode,
                    onChanged: tema.setMode,
                    options: const [
                      (ThemeMode.light, Icons.light_mode_rounded, 'Claro'),
                      (ThemeMode.dark, Icons.dark_mode_rounded, 'Escuro'),
                      (ThemeMode.system, Icons.brightness_auto_rounded, 'Auto'),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              index: 4,
              child: SettingsGroup(title: 'Notificações', children: [
                SettingsSwitch(
                  icon: Icons.notifications_active_rounded,
                  color: AppColors.electric,
                  title: 'Notificações',
                  subtitle: 'Avisos de alerta neste aparelho',
                  value: _notificacoesPush,
                  onChanged: (v) {
                    setState(() => _notificacoesPush = v);
                    _salvarPref(_kPush, v);
                  },
                ),
                SettingsSwitch(
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.statusCritico,
                  title: 'Alertas críticos',
                  value: _alertasCriticos && _notificacoesPush,
                  onChanged: (v) {
                    setState(() => _alertasCriticos = v);
                    _salvarPref(_kCriticos, v);
                  },
                ),
                SettingsSwitch(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.statusAtencao,
                  title: 'Alertas de atenção',
                  value: _alertasAtencao && _notificacoesPush,
                  onChanged: (v) {
                    setState(() => _alertasAtencao = v);
                    _salvarPref(_kAtencao, v);
                  },
                ),
              ]),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              index: 5,
              child: SettingsGroup(title: 'Sistema', children: [
                SettingsItem(
                  icon: Icons.dns_rounded,
                  color: const Color(0xFF0EA5E9),
                  title: 'Servidor',
                  subtitle: ServerConfig.apiUrl.replaceFirst(RegExp(r'^https?://'), ''),
                  trailing: _StatusServidor(ok: _servidorOk, ms: _latenciaMs),
                  onTap: () async {
                    final mudou = await showServerDialog(context);
                    if (!mounted || !mudou) return;
                    setState(() => _servidorOk = null);
                    _atualizar();
                    _aviso('Servidor atualizado. Puxe as telas para baixo para recarregar.');
                  },
                ),
                SettingsItem(
                  icon: Icons.info_rounded,
                  color: const Color(0xFF64748B),
                  title: 'Sobre o InduSense',
                  subtitle: 'Versão 1.0.0 · Growth Get',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'InduSense',
                    applicationVersion: '1.0.0',
                    applicationIcon: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/icon/app_icon.png',
                          width: 48, height: 48, errorBuilder: (_, __, ___) => const Icon(Icons.sensors, size: 40)),
                    ),
                    applicationLegalese: 'Growth Get — Monitoramento Ambiental Industrial',
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              index: 6,
              child: SettingsGroup(children: [
                SettingsItem(
                  icon: Icons.logout_rounded,
                  title: 'Sair da conta',
                  destructive: true,
                  trailing: const SizedBox.shrink(),
                  onTap: _confirmarLogout,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ cabeçalho
  Widget _cabecalho(UserModel user) {
    final desde = user.createdAt == null ? null : DateFormat("MMM 'de' y", 'pt_BR').format(user.createdAt!);
    final completo = user.completude >= 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: Stack(children: [
          // brilhos decorativos
          Positioned(right: -40, top: -50, child: _Bolha(170, Colors.white.withOpacity(.07))),
          Positioned(right: 60, bottom: -70, child: _Bolha(140, AppColors.cyan.withOpacity(.12))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                GestureDetector(
                  onTap: _enviandoFoto ? null : () => _trocarFoto(user),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Hero(
                      tag: 'avatar-perfil',
                      child: UserAvatar(user: user, size: 78, ring: true, gapColor: const Color(0xFF0F2D6B)),
                    ),
                    if (_enviandoFoto)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
                          child: const Center(
                            child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                          ),
                        ),
                      ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.photo_camera_rounded, size: 15, color: AppColors.primary),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.nome.isEmpty ? 'Sem nome' : user.nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.4)),
                    const SizedBox(height: 3),
                    Text(
                      [user.cargo, user.empresa].whereType<String>().join(' · ').isEmpty
                          ? user.email
                          : [user.cargo, user.empresa].whereType<String>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _Etiqueta(
                        icon: user.perfil == 'ADMIN' ? Icons.verified_user_rounded : Icons.person_rounded,
                        texto: user.perfilLabel,
                      ),
                      if (desde != null) _Etiqueta(icon: Icons.event_rounded, texto: 'Desde $desde'),
                    ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(.10)),
                ),
                child: Row(children: [
                  const Icon(Icons.alternate_email_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ),
                  if (!completo)
                    GestureDetector(
                      onTap: () => _abrir(const EditarPerfilScreen()),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: user.completude),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => CircularProgressIndicator(
                              value: v,
                              strokeWidth: 3,
                              color: AppColors.cyan,
                              backgroundColor: Colors.white24,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${(user.completude * 100).round()}% completo',
                            style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w800, fontSize: 12)),
                      ]),
                    )
                  else
                    const Icon(Icons.verified_rounded, color: AppColors.cyan, size: 20),
                ]),
              ),
              if (!completo) ...[
                const SizedBox(height: 10),
                Text(
                  'Falta ${_juntar(user.faltando)} para completar o seu perfil.',
                  style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 12),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  static String _juntar(List<String> l) {
    if (l.isEmpty) return '';
    if (l.length == 1) return l.first;
    return '${l.sublist(0, l.length - 1).join(', ')} e ${l.last}';
  }
}

class _Bolha extends StatelessWidget {
  final double size;
  final Color color;
  const _Bolha(this.size, this.color);

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _Etiqueta extends StatelessWidget {
  final IconData icon;
  final String texto;
  const _Etiqueta({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(texto, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _Contador extends StatelessWidget {
  final int n;
  const _Contador(this.n);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppColors.cyan.withOpacity(.16), borderRadius: BorderRadius.circular(10)),
        child: Text('$n', style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w800, fontSize: 12)),
      );
}

class _StatusServidor extends StatelessWidget {
  final bool? ok;
  final int? ms;
  const _StatusServidor({required this.ok, required this.ms});

  @override
  Widget build(BuildContext context) {
    if (ok == null) {
      return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    }
    final cor = ok! ? AppColors.statusNormal : AppColors.statusCritico;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      PulseDot(color: cor, size: 7),
      const SizedBox(width: 2),
      Text(ok! ? (ms != null ? '$ms ms' : 'Online') : 'Offline',
          style: TextStyle(color: cor, fontWeight: FontWeight.w800, fontSize: 12)),
    ]);
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../widgets/user_avatar.dart';

import '../../core/theme/app_theme.dart';
import '../../models/alert_model.dart';
import '../../models/camera_model.dart';
import '../../models/sala_model.dart';
import '../../models/sensor_model.dart';
import '../../services/alert_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/camera_service.dart';
import '../../services/sala_service.dart';
import '../../widgets/camera_hero_card.dart';
import '../../widgets/sensor_glance.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/ui.dart';
import '../camera/camera_screen.dart';
import '../home_shell.dart';

class DashboardScreen extends StatefulWidget {
  /// false quando a aba não está visível (pausa o vídeo ao vivo).
  final bool ativo;
  const DashboardScreen({super.key, this.ativo = true});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _salaService = SalaService();
  final _cameraService = CameraService();
  final _alertService = AlertService();

  List<SalaComSensores>? _salas;
  List<AlertModel> _alertas = [];
  EpiResumoModel? _epi;
  List<CameraModel> _cameras = [];
  DateTime? _atualizado;
  String? _erro;
  bool _carregando = true;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _carregar();
    _autoRefresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (widget.ativo) _carregar(silencioso: true);
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso && _salas == null) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    // Partes opcionais: se falharem, só não aparecem.
    _alertService.getAlerts().then((a) {
      if (mounted) setState(() => _alertas = a);
    }).catchError((_) {});
    _cameraService.resumo().then((r) {
      if (mounted) setState(() => _epi = r);
    }).catchError((_) {});
    _cameraService.cameras().then((c) {
      if (mounted) setState(() => _cameras = c);
    }).catchError((_) {});

    try {
      final salas = await _salaService.getSalasComSensores();
      if (!mounted) return;
      setState(() {
        _salas = salas;
        _erro = null;
        _carregando = false;
        _atualizado = DateTime.now();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (silencioso && _salas != null) return;
      setState(() {
        _erro = e.message;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar as salas.';
        _carregando = false;
      });
    }
  }

  void _irPara(int aba, String rota) {
    final scope = HomeShellScope.maybeOf(context);
    if (scope != null) {
      scope.goTo(aba);
    } else {
      Navigator.of(context).pushNamed(rota);
    }
  }

  void _abrirCamera(CameraModel c) => Navigator.of(context)
      .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => CameraScreen(camera: c)));

  String _saudacao() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _carregar,
          color: AppColors.accent,
          child: _corpo(user?.nome),
        ),
      ),
    );
  }

  Widget _corpo(String? nome) {
    if (_carregando) return const LoadingWidget(mensagem: 'Conectando aos ambientes...');
    if (_erro != null) {
      return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        _cabecalho(nome),
        const SizedBox(height: 40),
        AppErrorWidget(mensagem: _erro!, onRetry: _carregar),
      ]);
    }

    final salas = _salas ?? [];
    final sensores = salas.expand((s) => s.sensores).toList();
    final online = sensores.where((s) => s.online).length;
    final criticos = sensores.where((s) => s.status == SensorStatus.critico).length;
    final atencao = sensores.where((s) => s.status == SensorStatus.atencao).length;
    final naoLidos = _alertas.where((a) => !a.lido).toList()..sort((a, b) => b.dataHora.compareTo(a.dataHora));
    final camReal = _cameras.where((c) => c.real).toList()
      ..sort((a, b) => (b.online ? 1 : 0).compareTo(a.online ? 1 : 0));

    var i = 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _cabecalho(nome),
        const SizedBox(height: 22),
        FadeSlideIn(
          index: i++,
          child: camReal.isNotEmpty
              ? CameraHeroCard(
                  camera: camReal.first,
                  ativo: widget.ativo,
                  alertas: naoLidos.length,
                  onAbrir: () => _abrirCamera(camReal.first),
                  onAlertas: () => _irPara(HomeTabs.alertas, '/alertas'),
                )
              : _statusCard(criticos: criticos, atencao: atencao, online: online, total: sensores.length),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(index: i++, child: _acoes(naoLidos.length)),
        if (sensores.isNotEmpty) ...[
          const SizedBox(height: 26),
          _titulo('Leituras agora', null),
          FadeSlideIn(index: i++, child: _carrossel(salas)),
        ],
        if (camReal.isNotEmpty) ...[
          const SizedBox(height: 14),
          FadeSlideIn(
            index: i++,
            child: _faixaStatus(criticos: criticos, atencao: atencao, online: online, total: sensores.length),
          ),
        ],
        const SizedBox(height: 14),
        FadeSlideIn(index: i++, child: _numeros(online, sensores.length, naoLidos.length)),
        const SizedBox(height: 28),
        _titulo('Ambientes', salas.isEmpty ? null : '${salas.length}'),
        if (salas.isEmpty)
          const EmptyStateWidget(
            icon: Icons.meeting_room_outlined,
            titulo: 'Nenhuma sala cadastrada',
            mensagem: 'Cadastre uma sala no painel e ligue o ESP32 dela.',
          )
        else
          ...salas.map((sala) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FadeSlideIn(
                  index: i++,
                  child: _salaLinha(sala),
                ),
              )),
        if (naoLidos.isNotEmpty) ...[
          const SizedBox(height: 18),
          _titulo('Alertas recentes', null, acao: 'Ver todos', onAcao: () => _irPara(HomeTabs.alertas, '/alertas')),
          ...naoLidos.take(3).map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _alertaMini(a),
              )),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ cabeçalho
  Widget _cabecalho(String? nome) {
    final primeiro = (nome ?? '').trim().split(' ').first;
    final hoje = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${hoje[0].toUpperCase()}${hoje.substring(1)}',
                style: TextStyle(color: mutedText(context), fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: primeiro.isEmpty ? _saudacao() : '${_saudacao()}, '),
                if (primeiro.isNotEmpty) TextSpan(text: primeiro, style: const TextStyle(color: AppColors.accent)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -.9, height: 1.1),
            ),
          ]),
        ),
        _botaoRedondo(Icons.contactless_rounded, 'Escanear tag NFC', () => Navigator.of(context).pushNamed('/nfc-scan')),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _irPara(HomeTabs.perfil, '/configuracoes'),
          child: UserAvatar(user: context.watch<AuthProvider>().user, size: 50, ring: true),
        ),
      ]),
    );
  }

  Widget _botaoRedondo(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
        message: tooltip,
        child: Material(
          color: Theme.of(context).cardColor,
          elevation: isDark(context) ? 0 : 6,
          shadowColor: const Color(0x331E4FB8),
          shape: CircleBorder(side: isDark(context) ? const BorderSide(color: AppColors.darkBorder) : BorderSide.none),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 52, height: 52, child: Icon(icon, size: 24, color: AppColors.accent)),
          ),
        ),
      );

  Widget _titulo(String texto, String? contador, {String? acao, VoidCallback? onAcao}) => Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 2),
        child: Row(children: [
          Text(texto, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.4)),
          if (contador != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(contador,
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          ],
          const Spacer(),
          if (acao != null)
            TextButton(
              onPressed: onAcao,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(acao, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ]),
            ),
        ]),
      );

  // ------------------------------------------------------------ ações rápidas
  Widget _acoes(int alertas) {
    Widget tile(IconData icon, String texto, VoidCallback onTap, {bool destaque = false, int badge = 0}) {
      final dark = isDark(context);
      final fundo = destaque ? Colors.transparent : Theme.of(context).cardColor;
      final cor = destaque ? Colors.white : (dark ? Colors.white : AppColors.accent);
      return Expanded(
        child: Material(
          color: fundo,
          borderRadius: BorderRadius.circular(26),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onTap,
            child: Container(
              height: 104,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: destaque ? AppGradients.hero : null,
                border: !destaque && dark ? Border.all(color: AppColors.darkBorder) : null,
                boxShadow: destaque
                    ? [BoxShadow(color: AppColors.accent.withOpacity(.35), blurRadius: 22, offset: const Offset(0, 10))]
                    : (dark ? null : [BoxShadow(color: const Color(0xFF1E4FB8).withOpacity(.07), blurRadius: 22, offset: const Offset(0, 8))]),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Stack(clipBehavior: Clip.none, children: [
                  Icon(icon, color: cor, size: 26),
                  if (badge > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.statusCritico, borderRadius: BorderRadius.circular(8)),
                        child: Text('$badge',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                Text(texto, style: TextStyle(color: cor, fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      tile(Icons.videocam_outlined, 'Câmeras', () => _irPara(HomeTabs.cameras, '/cameras')),
      const SizedBox(width: 12),
      tile(Icons.contactless_rounded, 'Escanear', () => Navigator.of(context).pushNamed('/nfc-scan'), destaque: true),
      const SizedBox(width: 12),
      tile(Icons.notifications_none_rounded, 'Alertas', () => _irPara(HomeTabs.alertas, '/alertas'), badge: alertas),
    ]);
  }

  // ------------------------------------------------------------ status geral
  (String, String, Color) _resumo({required int criticos, required int atencao, required int online, required int total}) {
    if (criticos > 0) {
      return (
        criticos == 1 ? '1 sensor em nível crítico' : '$criticos sensores em nível crítico',
        'Verifique os ambientes em vermelho.',
        AppColors.statusCritico
      );
    }
    if (atencao > 0) {
      return (
        atencao == 1 ? '1 ponto pede atenção' : '$atencao pontos pedem atenção',
        'Nada crítico, mas vale acompanhar.',
        AppColors.statusAtencao
      );
    }
    if (total > 0 && online == 0) {
      return ('Sensores sem comunicação', 'Nenhum sensor enviou dados agora.', AppColors.statusOffline);
    }
    return ('Tudo sob controle', 'Todos os parâmetros dentro dos limites.', AppColors.statusNormal);
  }

  /// Faixa fina com o estado geral (quando a câmera ocupa o destaque).
  Widget _faixaStatus({required int criticos, required int atencao, required int online, required int total}) {
    final (titulo, detalhe, cor) = _resumo(criticos: criticos, atencao: atencao, online: online, total: total);
    final hora = _atualizado == null ? '' : DateFormat('HH:mm').format(_atualizado!);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      child: Row(children: [
        PulseDot(color: cor, size: 9),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            Text(detalhe, style: TextStyle(color: mutedText(context), fontSize: 12.5)),
          ]),
        ),
        if (hora.isNotEmpty) Text(hora, style: TextStyle(color: mutedText(context), fontSize: 12)),
      ]),
    );
  }

  /// Cartão grande quando não há câmera.
  Widget _statusCard({required int criticos, required int atencao, required int online, required int total}) {
    final (titulo, detalhe, cor) = _resumo(criticos: criticos, atencao: atencao, online: online, total: total);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(34), gradient: AppGradients.hero),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PulseDot(color: cor),
          const SizedBox(width: 4),
          const Text('AO VIVO',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ]),
        const SizedBox(height: 26),
        Text(titulo,
            style: const TextStyle(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: -.6, height: 1.12)),
        const SizedBox(height: 8),
        Text(detalhe, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 22),
        Text('$online de $total sensores online', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ------------------------------------------------------------ números
  Widget _numeros(int online, int total, int alertas) {
    final epi = _epi;
    final itens = <(String, String, Color?)>[
      ('$online', total == 1 ? 'sensor\nonline' : 'de $total sensores\nonline', null),
      ('$alertas', alertas == 1 ? 'alerta\nnão lido' : 'alertas\nnão lidos', alertas > 0 ? AppColors.statusCritico : null),
      if (epi != null && epi.camerasTotal > 0) ...[
        ('${epi.pessoasDetectadas}', epi.pessoasDetectadas == 1 ? 'pessoa nas\ncâmeras' : 'pessoas nas\ncâmeras', null),
        (
          epi.conformidadeMedia == null ? '—' : '${epi.conformidadeMedia}%',
          'conformidade\nde EPI',
          epi.conformidadeMedia == null ? null : ScoreRing.colorFor(epi.conformidadeMedia)
        ),
      ],
    ];
    return LayoutBuilder(builder: (context, c) {
      final colunas = c.maxWidth >= 700 ? 4 : 2;
      final largura = (c.maxWidth - 12 * (colunas - 1)) / colunas;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final it in itens)
            SizedBox(
              width: largura,
              child: AppCard(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(children: [
                  Text(it.$1,
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.5, color: it.$3)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(it.$2,
                        maxLines: 2,
                        style: TextStyle(color: mutedText(context), fontSize: 12.5, height: 1.25)),
                  ),
                ]),
              ),
            ),
        ],
      );
    });
  }

  // ------------------------------------------------------------ leituras agora
  Widget _carrossel(List<SalaComSensores> salas) {
    final itens = <(SensorModel, String)>[
      for (final sala in salas)
        for (final sensor in sala.sensores) (sensor, sala.sala.nome),
    ];
    int peso(SensorModel x) => !x.online
        ? 3
        : x.status == SensorStatus.critico
            ? 0
            : x.status == SensorStatus.atencao
                ? 1
                : 2;
    itens.sort((a, b) => peso(a.$1).compareTo(peso(b.$1)));
    final mostrar = itens.take(10).toList();
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: mostrar.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 162,
          child: SensorGlanceCard(
            sensor: mostrar[i].$1,
            salaNome: salas.length > 1 ? mostrar[i].$2 : null,
            onTap: () => Navigator.of(context).pushNamed('/sensor-detalhe', arguments: mostrar[i].$1.id),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ ambientes
  Widget _salaLinha(SalaComSensores s) {
    final status = s.statusGeral;
    final cor = statusColor(status.name);
    final leituras = s.sensores
        .where((x) => x.online)
        .take(3)
        .map((x) => x.qualidadeTexto != null
            ? 'ar ${x.qualidadeTexto!.toLowerCase()}'
            : '${x.valorAtual.abs() >= 100 ? x.valorAtual.toStringAsFixed(0) : x.valorAtual.toStringAsFixed(1)} ${x.tipo.unidade}')
        .join(' · ');
    final sub = leituras.isNotEmpty
        ? leituras
        : [if (s.sala.setor.isNotEmpty) s.sala.setor, '${s.sensores.length} sensor${s.sensores.length == 1 ? '' : 'es'}']
            .join(' · ');

    return AppCard(
      radius: 26,
      padding: const EdgeInsets.all(10),
      onTap: () => Navigator.of(context).pushNamed('/sala-detalhe', arguments: s.sala.id),
      child: Row(children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cor.withOpacity(.26), cor.withOpacity(.08)],
            ),
          ),
          child: Stack(children: [
            Center(child: Icon(Icons.factory_rounded, color: cor, size: 30)),
            Positioned(
              right: 9,
              top: 9,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).cardColor, width: 2),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.sala.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, letterSpacing: -.2)),
            const SizedBox(height: 4),
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: mutedText(context), fontSize: 13)),
            if (s.totalAlertas > 0) ...[
              const SizedBox(height: 6),
              Text('${s.totalAlertas} fora do limite',
                  style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(Icons.more_horiz_rounded, color: mutedText(context)),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------ alertas
  Widget _alertaMini(AlertModel a) {
    final cor = statusColor(a.severidade.name);
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _irPara(HomeTabs.alertas, '/alertas'),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: cor.withOpacity(0.13), borderRadius: BorderRadius.circular(12)),
          child: Icon(sensorIcon(a.tipo.name), color: cor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.sensorNome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              '${a.tipo.label}: ${a.valorMedido.toStringAsFixed(1)} ${a.tipo.unidade} · limite ${a.limite.toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: mutedText(context), fontSize: 12.5),
            ),
          ]),
        ),
        Text(DateFormat('HH:mm').format(a.dataHora), style: TextStyle(color: mutedText(context), fontSize: 12)),
      ]),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/camera_model.dart';
import '../../models/sala_model.dart';
import '../../models/sensor_model.dart';
import '../../services/camera_service.dart';
import '../../services/auth_provider.dart';
import '../../services/nfc_service.dart';
import '../../services/sala_service.dart';
import '../../widgets/auth_image.dart';
import '../../widgets/anim.dart';
import '../../widgets/camera_hero_card.dart';
import '../../widgets/sensor_glance.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/ui.dart';
import '../camera/camera_screen.dart';
import '../nfc/nfc_scan_screen.dart';

class SalaDetailScreen extends StatefulWidget {
  final String salaId;
  const SalaDetailScreen({super.key, required this.salaId});

  @override
  State<SalaDetailScreen> createState() => _SalaDetailScreenState();
}

class _SalaDetailScreenState extends State<SalaDetailScreen> {
  final SalaService _salaService = SalaService();
  final CameraService _cameraService = CameraService();

  SalaModel? _sala;
  List<SensorModel>? _sensores;
  MonitoramentoModel? _mon;
  VisionStatus? _live;
  String? _cameraSelecionada;
  bool _carregando = true;
  String? _erro;
  Timer? _timerMon;
  Timer? _timerLive;

  @override
  void initState() {
    super.initState();
    _carregar();
    _timerMon = Timer.periodic(const Duration(seconds: 5), (_) => _carregarMonitoramento());
    _timerLive = Timer.periodic(const Duration(seconds: 2), (_) => _carregarAoVivo());
  }

  @override
  void dispose() {
    _timerMon?.cancel();
    _timerLive?.cancel();
    super.dispose();
  }

  CameraModel? get _camera {
    final cams = _mon?.camerasVisiveis ?? const <CameraModel>[];
    if (cams.isEmpty) return null;
    return cams.firstWhere((c) => c.id == _cameraSelecionada, orElse: () => cams.first);
  }

  Future<void> _carregarMonitoramento() async {
    try {
      final mon = await _cameraService.monitoramento(widget.salaId);
      if (mounted) setState(() => _mon = mon);
    } catch (_) {
      // API antiga ou fora do ar: a tela continua com os sensores.
    }
  }

  /// Os mesmos números do painel da câmera (localhost:8000).
  Future<void> _carregarAoVivo() async {
    final origin = _camera?.visionOrigin;
    if (origin == null) {
      if (_live != null && mounted) setState(() => _live = null);
      return;
    }
    try {
      final st = await VisionService.status(origin);
      if (mounted) setState(() => _live = st);
    } catch (_) {
      if (_live != null && mounted) setState(() => _live = null);
    }
  }

  void _abrirCamera(CameraModel cam) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CameraScreen(camera: cam),
    ));
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final sala = await _salaService.getSalaById(widget.salaId);
      final sensores = await _salaService.getSensoresPorSala(widget.salaId);
      await _carregarMonitoramento();
      _carregarAoVivo();
      if (!mounted) return;
      setState(() {
        _sala = sala;
        _sensores = sensores;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar os sensores da sala.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _sala?.nome ?? 'Ambiente',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_sala != null &&
              NfcService.instance.plataformaSuportada &&
              context.watch<AuthProvider>().user?.perfil == 'ADMIN')
            IconButton(
              tooltip: 'Configurar tag NFC da porta',
              icon: const Icon(Icons.nfc_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => NfcScanScreen(gravarEm: _sala)),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_carregando) {
      return const SkeletonList(itens: 4, altura: 96, topo: Padding(padding: EdgeInsets.only(bottom: 16), child: Skeleton(height: 170, radius: 32)));
    }
    if (_erro != null) return AppErrorWidget(mensagem: _erro!, onRetry: _carregar);

    final sala = _sala!;
    final sensores = _sensores ?? [];

    return RefreshIndicator(
      onRefresh: _carregar,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FadeSlideIn(child: _hero(sala, sensores)),
          ..._secaoCameras(),
          const SizedBox(height: 24),
          const Text('Sensores', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.4)),
          const SizedBox(height: 12),
          if (sensores.isEmpty)
            const EmptyStateWidget(
              icon: Icons.sensors_off_rounded,
              titulo: 'Nenhum sensor vinculado',
              mensagem: 'Cadastre um módulo ESP32/IoT nesta área para iniciar a telemetria.',
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sensores.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 230,
                mainAxisExtent: 206,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final sensor = sensores[index];
                return FadeSlideIn(
                  index: index + 1,
                  child: SensorGlanceCard(
                    sensor: sensor,
                    onTap: () => Navigator.of(context).pushNamed('/sensor-detalhe', arguments: sensor.id),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ topo
  Widget _hero(SalaModel sala, List<SensorModel> sensores) {
    final online = sensores.where((x) => x.online).toList();
    final normais = online.where((x) => x.status == SensorStatus.normal).length;
    final fora = online.length - normais;
    final frac = online.isEmpty ? 0.0 : normais / online.length;
    final titulo = sensores.isEmpty
        ? 'Sem sensores'
        : online.isEmpty
            ? 'Sensores sem sinal'
            : fora == 0
                ? 'Tudo normal'
                : '$fora fora do limite';

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: Stack(children: [
          Positioned(
            right: -50,
            top: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.08)),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -70,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.06)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 16, 20),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (sala.setor.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(sala.setor.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
                    ),
                  const SizedBox(height: 14),
                  Text(titulo,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.8, height: 1.1)),
                  const SizedBox(height: 6),
                  Text('${online.length} de ${sensores.length} sensores online',
                      style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                  const SizedBox(height: 14),
                  Row(children: [
                    const PulseDot(color: Colors.white, size: 7),
                    const SizedBox(width: 4),
                    Text('ao vivo · ${sala.codigo.isEmpty ? 'sala' : sala.codigo}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ]),
              ),
              ArcGauge(
                fraction: frac,
                color: Colors.white,
                size: 118,
                stroke: 11,
                center: Column(mainAxisSize: MainAxisSize.min, children: [
                  CountUp(
                    value: frac * 100,
                    suffix: '%',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -1),
                  ),
                  const Text('normais', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------ câmeras / EPI
  List<Widget> _secaoCameras() {
    final mon = _mon;
    if (mon == null || mon.cameras.isEmpty) return const [];
    final cams = mon.camerasVisiveis;
    final cam = _camera!;
    final live = _live != null && _live!.cameraOnline ? _live : null;
    final dim = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final score = live != null ? live.conformidade : (cam.online ? cam.epiConformidade : null);
    final pessoas = live?.pessoas ?? cam.pessoas;
    final abertas = mon.ocorrencias.where((o) => !o.resolvido).toList();
    final semEpiAgora = live?.lista.where((p) => p.status == 'NAO_CONFORME').toList() ?? const [];

    Color corScore(int? v) => v == null
        ? AppColors.statusOffline
        : v >= 95
            ? AppColors.statusNormal
            : v >= 80
                ? AppColors.statusAtencao
                : AppColors.statusCritico;

    return [
      const SizedBox(height: 24),
      Row(children: [
        Expanded(
          child: Text('Câmera e EPI',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ),
        if (live != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.statusNormal, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('ao vivo', style: TextStyle(color: dim, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
      ]),
      const SizedBox(height: 12),
      CameraHeroCard(camera: cam, onAbrir: () => _abrirCamera(cam)),
      if (cams.length > 1) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: cams
                .map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.codigo ?? c.nome),
                        selected: c.id == cam.id,
                        avatar: Icon(c.online ? Icons.videocam_rounded : Icons.videocam_off_rounded, size: 16),
                        onSelected: (_) => setState(() {
                          _cameraSelecionada = c.id;
                          _live = null;
                        }),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
              width: 74,
              height: 74,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (score ?? 0) / 100,
                    strokeWidth: 7,
                    backgroundColor: corScore(score).withOpacity(.15),
                    color: corScore(score),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(score == null ? '—' : '$score%',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Conformidade de EPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  score == null
                      ? (cam.online ? (pessoas == 0 ? 'Ninguém na cena agora' : 'Analisando as pessoas') : 'Câmera sem conexão')
                      : score >= 95
                          ? 'Bom desempenho · meta ≥ 95%'
                          : 'Abaixo da meta de 95%',
                  style: TextStyle(color: dim, fontSize: 12.5),
                ),
              ]),
            ),
          ]),
          if (live != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              _mini('${live.pessoas}', 'na cena', null),
              _mini('${live.conformes}', 'conformes', AppColors.statusNormal),
              _mini('${live.naoConformes}', 'não conf.', AppColors.statusCritico),
              _mini('${live.inconclusivos}', 'inconcl.', AppColors.statusAtencao),
            ]),
            const SizedBox(height: 14),
            ...live.porItem.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    SizedBox(width: 92, child: Text(epiLabel(e.key), style: const TextStyle(fontSize: 13))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (e.value ?? 0) / 100,
                          minHeight: 8,
                          backgroundColor: dim.withOpacity(.15),
                          color: corScore(e.value),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(e.value == null ? '—' : '${e.value}%',
                          textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ]),
                )),
          ],
          if (semEpiAgora.isNotEmpty || abertas.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: cam.videoUrl != null ? () => _abrirCamera(cam) : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusAtencao.withOpacity(.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.statusAtencao),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      semEpiAgora.isNotEmpty
                          ? semEpiAgora.map((p) => 'Pessoa ${p.id}: sem ${juntarEpis(p.faltando)}').join(' • ')
                          : '${abertas.length} ${abertas.length == 1 ? 'ocorrência aberta' : 'ocorrências abertas'}. '
                              'Última: ${abertas.first.mensagem.toLowerCase()} às ${DateFormat('HH:mm').format(abertas.first.dataHora)}.',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ),
          ],
        ]),
      ),
      if (mon.ocorrencias.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text('Ocorrências nas últimas 24 h', style: TextStyle(color: dim, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: mon.ocorrencias.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final o = mon.ocorrencias[i];
              return SizedBox(
                width: 170,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 170,
                      height: 96,
                      child: o.fotoUrl != null
                          ? AuthImage(path: o.fotoUrl!)
                          : const ColoredBox(color: Colors.black12, child: Icon(Icons.image_not_supported_outlined)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(o.mensagem, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  Text(DateFormat('dd/MM HH:mm').format(o.dataHora), style: TextStyle(color: dim, fontSize: 11.5)),
                ]),
              );
            },
          ),
        ),
      ],
    ];
  }

  Widget _mini(String n, String l, Color? cor) => Expanded(
        child: Column(children: [
          Text(n, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cor)),
          Text(l, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
        ]),
      );
}

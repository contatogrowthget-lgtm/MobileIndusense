import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/camera_model.dart';
import '../../services/api_client.dart';
import '../../services/camera_service.dart';
import '../../widgets/anim.dart';
import '../../widgets/camera_hero_card.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/ui.dart';
import '../camera/camera_screen.dart';

/// Aba Câmeras: todas as câmeras com vídeo ao vivo, pessoas e conformidade de EPI.
class CamerasScreen extends StatefulWidget {
  final bool ativo;
  const CamerasScreen({super.key, this.ativo = true});

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  final _service = CameraService();
  List<CameraModel>? _cameras;
  EpiResumoModel? _resumo;
  String? _erro;
  bool _mostrarDemo = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregar();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (widget.ativo) _carregar();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    _service.resumo().then((r) {
      if (mounted) setState(() => _resumo = r);
    }).catchError((_) {});
    try {
      final cams = await _service.cameras();
      if (!mounted) return;
      setState(() {
        _cameras = cams;
        _erro = null;
      });
    } on ApiException catch (e) {
      if (!mounted || _cameras != null) return;
      setState(() => _erro = e.statusCode == 404
          ? 'A API ainda não tem as rotas de câmera. Atualize a pasta indusense-api.'
          : e.message);
    } catch (_) {
      if (mounted && _cameras == null) setState(() => _erro = 'Não foi possível carregar as câmeras.');
    }
  }

  void _abrir(CameraModel c) => Navigator.of(context)
      .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => CameraScreen(camera: c)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(onRefresh: _carregar, color: AppColors.accent, child: _corpo()),
      ),
    );
  }

  Widget _corpo() {
    final todas = _cameras;
    if (todas == null && _erro == null) {
      return const SkeletonList(itens: 2, altura: 300, padding: EdgeInsets.fromLTRB(20, 80, 20, 20));
    }

    final reais = (todas ?? []).where((c) => c.real).toList()
      ..sort((a, b) => (b.online ? 1 : 0).compareTo(a.online ? 1 : 0));
    final demo = (todas ?? []).where((c) => !c.real).toList();
    final lista = [...reais, if (_mostrarDemo || reais.isEmpty) ...demo];
    final r = _resumo;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        TelaTitulo(
          titulo: 'Câmeras',
          subtitulo: 'Visão computacional · uso de EPI',
          acao: r == null
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: (r.camerasOnline > 0 ? AppColors.statusNormal : AppColors.statusOffline).withOpacity(0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (r.camerasOnline > 0) const PulseDot(size: 7) else const Icon(Icons.videocam_off_rounded, size: 14),
                    const SizedBox(width: 4),
                    Text('${r.camerasOnline}/${r.camerasTotal} online',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: r.camerasOnline > 0 ? AppColors.statusNormal : AppColors.statusOffline,
                        )),
                  ]),
                ),
        ),
        if (r != null) ...[
          FadeSlideIn(child: _resumoCard(r)),
          const SizedBox(height: 22),
        ],
        if (_erro != null)
          AppErrorWidget(mensagem: _erro!, onRetry: _carregar)
        else if (lista.isEmpty)
          const EmptyStateWidget(
            icon: Icons.videocam_off_outlined,
            titulo: 'Nenhuma câmera cadastrada',
            mensagem: 'Ligue o sistema de câmera (iniciar-tudo) e ela aparece aqui sozinha.',
          )
        else
          for (var i = 0; i < lista.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: FadeSlideIn(index: i, child: _cameraItem(lista[i])),
            ),
        if (reais.isNotEmpty && demo.isNotEmpty)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _mostrarDemo = !_mostrarDemo),
              icon: Icon(_mostrarDemo ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              label: Text(_mostrarDemo
                  ? 'Ocultar câmeras de demonstração'
                  : 'Mostrar ${demo.length} câmera${demo.length == 1 ? '' : 's'} de demonstração'),
            ),
          ),
      ],
    );
  }

  Widget _resumoCard(EpiResumoModel r) {
    final cor = ScoreRing.colorFor(r.conformidadeMedia);
    return AppCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
      child: Row(children: [
        ArcGauge(
          fraction: (r.conformidadeMedia ?? 0) / 100,
          color: r.conformidadeMedia == null ? AppColors.statusOffline : cor,
          size: 104,
          stroke: 10,
          center: Column(mainAxisSize: MainAxisSize.min, children: [
            r.conformidadeMedia == null
                ? const Text('—', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))
                : CountUp(
                    value: r.conformidadeMedia!.toDouble(),
                    suffix: '%',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -1),
                  ),
            Text('EPI', style: TextStyle(color: mutedText(context), fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Conformidade agora', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            Row(children: [
              _num(r.pessoasDetectadas, 'pessoas', null),
              _num(r.abertas, 'abertas', r.abertas > 0 ? AppColors.statusCritico : AppColors.statusNormal),
              _num(r.ocorrenciasHoje, 'hoje', AppColors.statusAtencao),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _num(int n, String l, Color? cor) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CountUp(
            value: n.toDouble(),
            style: TextStyle(color: cor, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.6),
          ),
          Text(l, style: TextStyle(color: mutedText(context), fontSize: 11.5)),
        ]),
      );

  Widget _cameraItem(CameraModel c) {
    final cor = !c.online
        ? AppColors.statusOffline
        : ScoreRing.colorFor(c.epiConformidade);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CameraHeroCard(camera: c, ativo: widget.ativo, onAbrir: () => _abrir(c)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(
              [
                if (c.salaNome != null) c.salaNome!,
                c.online ? (c.ocorrencia ?? 'Nenhuma ocorrência no momento') : (c.ultimoContatoRelativo ?? 'Sem conexão'),
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.online && c.ocorrencia != null ? AppColors.statusCritico : mutedText(context),
                fontSize: 12.5,
                fontWeight: c.online && c.ocorrencia != null ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: cor.withOpacity(0.13), borderRadius: BorderRadius.circular(12)),
          child: Text(c.online ? '${c.epiConformidade}% EPI' : 'offline',
              style: TextStyle(color: cor, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ),
      ]),
    ]);
  }
}

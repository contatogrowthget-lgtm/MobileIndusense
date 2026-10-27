import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/camera_model.dart';
import '../../services/camera_service.dart';
import '../../widgets/glass.dart';
import '../../widgets/mjpeg_view.dart';

/// Câmera em tela cheia, no mesmo visual do painel do sistema de câmera
/// (http://localhost:8000): vídeo, pessoas agora, EPIs e ocorrências.
class CameraScreen extends StatefulWidget {
  final CameraModel camera;
  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _C {
  static const bg = Color(0xFF0B0D10);
  static const steel = Color(0xFF15181D);
  static const steel2 = Color(0xFF1C2027);
  static const line = Color(0xFF2A2F37);
  static const text = Color(0xFFE9E7E2);
  static const dim = Color(0xFF8F989F);
  static const hazard = Color(0xFFF2C230);
  static const ok = Color(0xFF43C17F);
  static const bad = Color(0xFFEF5350);
  static const warn = Color(0xFFE8A33D);
  static const info = Color(0xFF6FA8DC);
}

const _statusLabel = {
  'CONFORME': 'Conforme',
  'NAO_CONFORME': 'Não conforme',
  'INCONCLUSIVO': 'Inconclusivo',
  'ANALISANDO': 'Analisando',
};
const _ordem = {'NAO_CONFORME': 0, 'INCONCLUSIVO': 1, 'ANALISANDO': 2, 'CONFORME': 3};

Color _corStatus(String s) => switch (s) {
      'CONFORME' => _C.ok,
      'NAO_CONFORME' => _C.bad,
      'INCONCLUSIVO' => _C.warn,
      _ => _C.info,
    };

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  VisionStatus? _st;
  List<VisionEvent> _eventos = [];
  bool _alcancavel = true;
  bool _videoOk = false;
  bool _alerta = false;
  int? _ultimoEvento;
  Timer? _timer;
  Timer? _relogio;
  String _hora = '';
  late final AnimationController _pulso =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  String? get _origin => widget.camera.visionOrigin;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _tickRelogio();
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) => _tickRelogio());
    _poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _relogio?.cancel();
    _pulso.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _tickRelogio() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    if (mounted) setState(() => _hora = '${two(n.hour)}:${two(n.minute)}:${two(n.second)}');
  }

  Future<void> _poll() async {
    final origin = _origin;
    if (origin == null) return;
    try {
      final st = await VisionService.status(origin);
      if (!mounted) return;
      final novo = _ultimoEvento != null && st.ultimoEvento > _ultimoEvento!;
      if (_ultimoEvento == null || st.ultimoEvento != _ultimoEvento) {
        _ultimoEvento = st.ultimoEvento;
        _carregarEventos();
      }
      if (novo && _alerta) {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      }
      setState(() {
        _st = st;
        _alcancavel = true;
      });
    } catch (_) {
      if (mounted) setState(() => _alcancavel = false);
    } finally {
      if (mounted) _timer = Timer(const Duration(milliseconds: 900), _poll);
    }
  }

  Future<void> _carregarEventos() async {
    final origin = _origin;
    if (origin == null) return;
    try {
      final ev = await VisionService.eventos(origin);
      if (mounted) setState(() => _eventos = ev);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cam = widget.camera;
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: _C.bg),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: LayoutBuilder(builder: (context, c) {
            final largo = c.maxWidth >= 900;
            final contadores = _contadores(cam);
            if (largo) {
              final header = _header(cam, largo);
              final video = _video(cam);
              return SafeArea(child: Column(children: [
                header,
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(children: [video, const SizedBox(height: 14), contadores, _exigidos()]),
                        ),
                      ),
                      const SizedBox(width: 18),
                      SizedBox(
                        width: 370,
                        child: Column(children: [
                          Expanded(child: _painel('Pessoas agora', null, _pessoas())),
                          const SizedBox(height: 16),
                          Expanded(child: _painel('Ocorrências', _botaoAlerta(), _listaEventos())),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ]));
            }
            // celular: vídeo ocupando o topo, botões de vidro por cima
            return ListView(padding: EdgeInsets.zero, children: [
              _heroCelular(cam),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  contadores,
                  _exigidos(),
                  const SizedBox(height: 14),
                  _painel('Pessoas agora', null, _pessoas(), scroll: false),
                  const SizedBox(height: 14),
                  _painel('Ocorrências', _botaoAlerta(), _listaEventos(), scroll: false),
                ]),
              ),
            ]);
          }),
      ),
    );
  }

  // ----------------------------------------------------------------- topo
  Widget _header(CameraModel cam, bool largo) {
    final st = _st;
    final online = _alcancavel && (st?.cameraOnline ?? false) && _videoOk;
    final chips = <Widget>[
      _chip(online ? 'Câmera online${st != null && st.largura > 0 ? ' · ${st.largura}×${st.altura}' : ''}' : 'Câmera offline',
          online ? _C.ok : _C.bad),
      _chip(
        st == null
            ? 'Detector'
            : !st.detectorPronto
                ? 'Detector parado'
                : st.erroDetector != null
                    ? 'Falha na análise'
                    : 'Detecção ativa',
        st == null ? _C.dim : (st.detectorPronto && st.erroDetector == null ? _C.ok : _C.warn),
      ),
      if (st != null)
        _chip('${st.fps.toStringAsFixed(0)} fps${st.latenciaMs != null ? ' · ${st.latenciaMs} ms' : ''}', null),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
      decoration: const BoxDecoration(color: _C.steel, border: Border(bottom: BorderSide(color: _C.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: _C.text),
            tooltip: 'Fechar',
          ),
          const _Listras(size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cam.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: .3)),
              Text(cam.salaNome ?? 'Monitoramento de EPI',
                  style: const TextStyle(color: _C.dim, fontSize: 12.5)),
            ]),
          ),
          if (largo) ...[...chips.map((c) => Padding(padding: const EdgeInsets.only(left: 8), child: c))],
          const SizedBox(width: 12),
          Text(_hora,
              style: const TextStyle(
                  color: _C.text, fontSize: 18, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        if (!largo)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8),
            child: Wrap(spacing: 8, runSpacing: 8, children: chips),
          ),
      ]),
    );
  }

  Widget _chip(String texto, Color? cor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: _C.steel2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cor == _C.bad ? _C.bad.withOpacity(.5) : _C.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (cor != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
            const SizedBox(width: 7),
          ],
          Text(texto, style: TextStyle(color: cor == null || cor == _C.dim ? _C.dim : _C.text, fontSize: 12.5)),
        ]),
      );

  // ----------------------------------------------------------------- celular
  Widget _heroCelular(CameraModel cam) {
    final st = _st;
    final topo = MediaQuery.of(context).padding.top;
    final alto = MediaQuery.of(context).size.height;
    final url = cam.videoUrl;
    final alarme = (st?.naoConformes ?? 0) > 0;
    final online = _alcancavel && (st?.cameraOnline ?? false) && _videoOk;

    return AnimatedBuilder(
      animation: _pulso,
      builder: (context, child) => Container(
        foregroundDecoration: alarme
            ? BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
                border: Border.all(color: Color.lerp(_C.hazard, _C.bad, _pulso.value)!, width: 4),
              )
            : null,
        child: child,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
        child: SizedBox(
          height: (alto * .62).clamp(380.0, 620.0),
          child: Stack(fit: StackFit.expand, children: [
            const ColoredBox(color: Colors.black),
            if (url == null)
              const _SemSinal('Esta câmera não tem vídeo ao vivo', 'Ligue o sistema de câmera (iniciar-tudo).')
            else
              MjpegView(
                url: url,
                fit: BoxFit.cover,
                onStateChanged: (ok) {
                  if (mounted) setState(() => _videoOk = ok);
                },
                errorWidget: _SemSinal('Sem sinal da câmera', 'Tentando reconectar em ${_origin ?? url}'),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .32, .62, 1],
                  colors: [Color(0xB3000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
                ),
              ),
            ),
            // botões do topo
            Positioned(
              top: topo + 10,
              left: 16,
              right: 16,
              child: Row(children: [
                GlassCircle(
                  size: 52,
                  tooltip: 'Voltar',
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                const Spacer(),
                GlassCircle(
                  size: 52,
                  tooltip: _alerta ? 'Desligar som de alerta' : 'Ligar som de alerta',
                  onTap: () => setState(() => _alerta = !_alerta),
                  child: Icon(_alerta ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                      color: _alerta ? _C.hazard : Colors.white),
                ),
              ]),
            ),
            // título
            Positioned(
              top: topo + 82,
              left: 22,
              right: 22,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cam.salaNome ?? cam.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -.6, height: 1.1)),
                const SizedBox(height: 4),
                Text(cam.salaNome == null ? 'Monitoramento de EPI' : cam.nome,
                    style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w400)),
              ]),
            ),
            // base: ao vivo, detector, relógio
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Row(children: [
                GlassPill(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: online ? _C.ok : _C.bad, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 7),
                    Text(online ? 'AO VIVO' : 'SEM SINAL',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6)),
                  ]),
                ),
                const SizedBox(width: 8),
                if (st != null)
                  Flexible(
                    child: GlassPill(
                      child: Text(
                        !st.detectorPronto
                            ? 'Detector parado'
                            : st.erroDetector != null
                                ? 'Falha na análise'
                                : 'Detecção · ${st.fps.toStringAsFixed(0)} fps',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                const Spacer(),
                Text(_hora,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- vídeo
  Widget _video(CameraModel cam) {
    final alarme = (_st?.naoConformes ?? 0) > 0;
    final url = cam.videoUrl;
    final quadro = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: url == null
              ? const _SemSinal('Esta câmera não tem vídeo ao vivo', 'Ligue o sistema de câmera (iniciar-tudo).')
              : MjpegView(
                  url: url,
                  onStateChanged: (ok) {
                    if (mounted) setState(() => _videoOk = ok);
                  },
                  errorWidget: _SemSinal('Sem sinal da câmera', 'Tentando reconectar em ${_origin ?? url}'),
                ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _pulso,
      builder: (context, child) => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: _C.steel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: alarme ? Color.lerp(_C.hazard, _C.bad, _pulso.value)! : _C.line,
            width: alarme ? 4 : 1,
          ),
        ),
        child: child,
      ),
      child: quadro,
    );
  }

  Widget _contadores(CameraModel cam) {
    final st = _st;
    Widget item(String n, String l, Color? cor) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n,
                  style: TextStyle(
                      color: cor ?? _C.text,
                      fontSize: 28,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: 4),
              Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.dim, fontSize: 11.5)),
            ]),
          ),
        );
    Widget sep() => Container(width: 1, height: 52, color: _C.line);
    return Container(
      decoration: BoxDecoration(
          color: _C.steel, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.line)),
      child: Row(children: [
        item('${st?.pessoas ?? cam.pessoas}', 'na cena', null),
        sep(),
        item(st == null ? '—' : '${st.conformes}', 'conformes', _C.ok),
        sep(),
        item(st == null ? '—' : '${st.naoConformes}', 'não conformes', _C.bad),
        sep(),
        item(st == null ? '—' : '${st.inconclusivos}', 'inconclusivos', _C.warn),
        sep(),
        item(st == null ? '—' : '${st.ocorrenciasHoje}', 'hoje', null),
      ]),
    );
  }

  Widget _exigidos() {
    final st = _st;
    if (st == null || st.exigidos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 2),
      child: Text.rich(TextSpan(children: [
        const TextSpan(text: 'EPIs exigidos: ', style: TextStyle(color: _C.dim)),
        TextSpan(text: st.exigidos.map(epiLabel).join(', '), style: const TextStyle(color: _C.text)),
      ]), style: const TextStyle(fontSize: 12.5)),
    );
  }

  // ----------------------------------------------------------------- painéis
  Widget _painel(String titulo, Widget? acao, Widget corpo, {bool scroll = true}) {
    return Container(
      decoration: BoxDecoration(
          color: _C.steel, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.line)),
      child: Column(mainAxisSize: scroll ? MainAxisSize.max : MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _C.line))),
          child: Row(children: [
            Expanded(
                child: Text(titulo,
                    style: const TextStyle(color: _C.text, fontSize: 17, fontWeight: FontWeight.w700))),
            if (acao != null) acao,
          ]),
        ),
        if (scroll) Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: corpo))
        else Padding(padding: const EdgeInsets.all(12), child: corpo),
      ]),
    );
  }

  Widget _vazio(String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: Center(child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: _C.dim))),
      );

  Widget _pessoas() {
    final st = _st;
    if (_origin == null) return _vazio('Esta câmera não está ligada ao sistema de visão.');
    if (!_alcancavel) {
      return _vazio('Não foi possível ler o sistema de câmera em $_origin. Confira se ele está ligado.');
    }
    if (st == null) return _vazio('Conectando…');
    if (!st.cameraOnline) return _vazio('Aguardando a câmera voltar.');
    if (st.lista.isEmpty) return _vazio('Ninguém na área monitorada.');

    final pessoas = [...st.lista]
      ..sort((a, b) {
        final o = (_ordem[a.status] ?? 9).compareTo(_ordem[b.status] ?? 9);
        return o != 0 ? o : a.id.compareTo(b.id);
      });

    return Column(children: pessoas.map(_pessoaCard).toList());
  }

  Widget _pessoaCard(VisionPerson p) {
    final cor = _corStatus(p.status);
    final nc = p.status == 'NAO_CONFORME';
    // borda esquerda colorida: o arredondamento vem do ClipRRect (borda não uniforme não aceita borderRadius)
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
      decoration: BoxDecoration(
        color: nc ? _C.bad.withOpacity(.07) : _C.steel2,
        border: Border(left: BorderSide(color: cor, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Pessoa ${p.id}', style: const TextStyle(color: _C.text, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
              child: Text('há ${p.vistoHa.round()}s na cena',
                  style: const TextStyle(color: _C.dim, fontSize: 11.5))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: nc ? _C.bad : cor.withOpacity(.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_statusLabel[p.status] ?? p.status,
                style: TextStyle(color: nc ? Colors.white : cor, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 6) / 2;
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: p.itens.entries.map((e) {
              final conf = p.confs[e.key];
              final pct = conf == null ? '' : ' ${(conf * 100).round()}%';
              final (Color c2, String marca) = switch (e.value) {
                true => (_C.ok, '✓$pct'),
                false => (_C.bad, '✗'),
                null => (_C.warn, '?$pct'),
              };
              return Container(
                width: w,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(5)),
                child: Row(children: [
                  Expanded(
                      child: Text(epiLabel(e.key),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: e.value == false ? _C.bad : _C.text, fontSize: 13))),
                  Text(marca, style: TextStyle(color: c2, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              );
            }).toList(),
          );
        }),
      ]),
        ),
      ),
    );
  }

  Widget _botaoAlerta() => TextButton.icon(
        onPressed: () => setState(() => _alerta = !_alerta),
        style: TextButton.styleFrom(
          backgroundColor: _alerta ? _C.hazard : Colors.transparent,
          foregroundColor: _alerta ? _C.bg : _C.dim,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999), side: BorderSide(color: _alerta ? _C.hazard : _C.line)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(_alerta ? Icons.notifications_active_rounded : Icons.notifications_off_outlined, size: 16),
        label: Text(_alerta ? 'Alerta ligado' : 'Alerta desligado', style: const TextStyle(fontSize: 12)),
      );

  Widget _listaEventos() {
    final origin = _origin;
    if (_eventos.isEmpty) return _vazio('Nenhuma ocorrência registrada.');
    return Column(
      children: [
        for (var i = 0; i < _eventos.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: i == 0 ? _C.hazard.withOpacity(.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  width: 96,
                  height: 54,
                  child: _eventos[i].foto != null && origin != null
                      ? GestureDetector(
                          onTap: () => _verFoto('$origin${_eventos[i].foto}'),
                          child: Image.network('$origin${_eventos[i].foto}',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black)),
                        )
                      : const ColoredBox(color: Colors.black),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pessoa ${_eventos[i].pessoa}',
                      style: const TextStyle(color: _C.text, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    _eventos[i].faltando.isEmpty
                        ? 'EPI incompleto'
                        : 'Sem ${_eventos[i].faltando.map(epiLabel).join(', ').toLowerCase()}',
                    style: const TextStyle(color: _C.bad, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(_eventos[i].dataHora, style: const TextStyle(color: _C.dim, fontSize: 11.5)),
                ]),
              ),
            ]),
          ),
      ],
    );
  }

  void _verFoto(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(children: [
          InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SemSinal extends StatelessWidget {
  final String titulo;
  final String detalhe;
  const _SemSinal(this.titulo, this.detalhe);

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_rounded, color: _C.dim, size: 34),
            const SizedBox(height: 8),
            Text(titulo, style: const TextStyle(color: _C.text, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(detalhe, textAlign: TextAlign.center, style: const TextStyle(color: _C.dim, fontSize: 12.5)),
          ]),
        ),
      );
}

/// Quadradinho zebrado (marca do sistema de câmera).
class _Listras extends StatelessWidget {
  final double size;
  const _Listras({required this.size});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CustomPaint(size: Size.square(size), painter: _ListrasPainter()),
      );
}

class _ListrasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _C.bg);
    final p = Paint()
      ..color = _C.hazard
      ..strokeWidth = size.width / 5;
    for (double x = -size.width; x < size.width * 2; x += size.width / 2.5) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

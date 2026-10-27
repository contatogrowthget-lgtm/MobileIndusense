import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/alert_model.dart';
import '../models/sensor_model.dart';
import 'anim.dart';

/// Aviso grande por cima do app quando um sensor sai do limite.
/// Fundo desfocado, faixa de alerta correndo, ondas saindo do ícone,
/// valor subindo e o tempo fora do limite contando ao vivo.
class AlertOverlay extends StatefulWidget {
  final ValueNotifier<AlertModel?> alerta;
  final ValueNotifier<int> fila;
  final int sonecaMin;
  final VoidCallback onCiente;
  final VoidCallback onLembrar;
  final VoidCallback onVerSala;

  const AlertOverlay({
    super.key,
    required this.alerta,
    required this.fila,
    required this.sonecaMin,
    required this.onCiente,
    required this.onLembrar,
    required this.onVerSala,
  });

  @override
  State<AlertOverlay> createState() => _AlertOverlayState();
}

class _AlertOverlayState extends State<AlertOverlay> with TickerProviderStateMixin {
  late final AnimationController _entrada =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..forward();
  late final AnimationController _ondas =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  late final AnimationController _faixa =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  late final AnimationController _tremor =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  // criada uma vez: CurvedAnimation com reverseCurve registra listener no pai
  late final CurvedAnimation _curva =
      CurvedAnimation(parent: _entrada, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
  Timer? _relogio;
  Timer? _tremorTimer;
  bool _saindo = false;

  @override
  void initState() {
    super.initState();
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // o sino "treme" a cada 3 s
    _tremor.forward();
    _tremorTimer = Timer.periodic(const Duration(seconds: 3), (_) => _tremor.forward(from: 0));
    widget.alerta.addListener(_mudou);
  }

  void _mudou() {
    // já saindo: não reanima (cancelaria o reverse e o botão ficaria travado)
    if (!mounted || _saindo) return;
    _entrada.forward(from: .6);
    _tremor.forward(from: 0);
    setState(() {});
  }

  @override
  void dispose() {
    widget.alerta.removeListener(_mudou);
    _relogio?.cancel();
    _tremorTimer?.cancel();
    _curva.dispose();
    _entrada.dispose();
    _ondas.dispose();
    _faixa.dispose();
    _tremor.dispose();
    super.dispose();
  }

  Future<void> _sair(VoidCallback acao) async {
    if (_saindo) return;
    _saindo = true;
    await _entrada.reverse();
    acao();
  }

  static String _dur(DateTime desde) {
    final d = DateTime.now().difference(desde);
    if (d.inMinutes < 1) return '${d.inSeconds.clamp(0, 59)} s';
    if (d.inHours < 1) return '${d.inMinutes} min';
    final m = d.inMinutes % 60;
    return '${d.inHours} h${m > 0 ? ' $m' : ''}';
  }

  static IconData _icone(SensorType t) => switch (t) {
        SensorType.temperatura => Icons.thermostat_rounded,
        SensorType.umidade => Icons.water_drop_rounded,
        SensorType.qualidadeAr => Icons.air_rounded,
        SensorType.gas => Icons.local_fire_department_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final a = widget.alerta.value;
    if (a == null) return const SizedBox.shrink();
    final critico = a.severidade == SensorStatus.critico;
    final cor = critico ? AppColors.statusCritico : AppColors.statusAtencao;
    final un = a.tipo.unidade;
    final dec = a.valorAgora.abs() >= 100 ? 0 : 1;

    final curva = _curva;

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        // fundo escurecido e desfocado
        Positioned.fill(
          child: FadeTransition(
            opacity: _entrada,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: ColoredBox(color: const Color(0xFF0A1A3F).withOpacity(.45)),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AnimatedBuilder(
                  animation: curva,
                  builder: (_, child) => Opacity(
                    opacity: _entrada.value.clamp(0.0, 1.0),
                    child: Transform.scale(scale: .82 + .18 * curva.value, child: child),
                  ),
                  child: _cartao(a, critico, cor, un, dec),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _cartao(AlertModel a, bool critico, Color cor, String un, int dec) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: cor.withOpacity(.35), blurRadius: 50, offset: const Offset(0, 20))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // faixa listrada correndo
        SizedBox(
          height: 10,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _faixa,
            builder: (_, __) => CustomPaint(painter: _ListrasPainter(_faixa.value, cor)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ícone com ondas
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(alignment: Alignment.center, children: [
                AnimatedBuilder(
                  animation: _ondas,
                  builder: (_, __) => CustomPaint(size: const Size(132, 132), painter: _OndasPainter(_ondas.value, cor)),
                ),
                AnimatedBuilder(
                  animation: _tremor,
                  builder: (_, child) => Transform.rotate(
                    angle: math.sin(_tremor.value * math.pi * 6) * .18 * (1 - _tremor.value),
                    child: child,
                  ),
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color.lerp(cor, Colors.white, .15)!, cor],
                      ),
                      boxShadow: [BoxShadow(color: cor.withOpacity(.5), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Icon(_icone(a.tipo), color: Colors.white, size: 36),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: cor.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
              child: Text(critico ? 'ALERTA CRÍTICO' : 'ATENÇÃO',
                  style: TextStyle(color: cor, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
            ),
            const SizedBox(height: 12),
            Text(a.titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.8, height: 1.1)),
            const SizedBox(height: 6),
            Text([a.salaNome, a.sensorNome].whereType<String>().join(' · '),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 18),
            // leitura
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F8FD),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE6EDF7)),
              ),
              child: IntrinsicHeight(
                child: Row(children: [
                  _bloco(
                    'Agora',
                    Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic, children: [
                      CountUp(
                        value: a.valorAgora,
                        decimals: dec,
                        style: TextStyle(color: cor, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1),
                      ),
                      const SizedBox(width: 3),
                      Text(un, style: TextStyle(color: cor, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xFFE6EDF7)),
                  _bloco(
                    a.acima ? 'Máximo' : 'Mínimo',
                    Text('${CountUp.fmt(a.limite, a.limite.abs() >= 100 ? 0 : 1)} $un',
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xFFE6EDF7)),
                  _bloco(
                    'Fora há',
                    Text(_dur(a.dataHora),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Verifique o ambiente. O alerta fecha sozinho quando a leitura voltar ao normal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            // botões
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: critico
                      ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)])
                      : AppGradients.hero,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: cor.withOpacity(.35), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _sair(widget.onCiente),
                    child: const Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('OK, estou ciente',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(0, 50),
                    side: const BorderSide(color: Color(0xFFE3EBF6)),
                  ),
                  onPressed: () => _sair(widget.onLembrar),
                  icon: const Icon(Icons.alarm_rounded, size: 18),
                  label: Text('Lembrar em ${widget.sonecaMin} min', style: const TextStyle(fontSize: 13.5)),
                ),
              ),
              if (a.salaId != null || a.salaCodigo != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    minimumSize: const Size(0, 50),
                    side: const BorderSide(color: Color(0xFFE3EBF6)),
                  ),
                  onPressed: () => _sair(widget.onVerSala),
                  child: const Text('Ver sala', style: TextStyle(fontSize: 13.5)),
                ),
              ],
            ]),
            ValueListenableBuilder<int>(
              valueListenable: widget.fila,
              builder: (_, n, __) => n > 1
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('+${n - 1} outro${n - 1 == 1 ? '' : 's'} alerta${n - 1 == 1 ? '' : 's'} aguardando',
                          style: TextStyle(color: cor, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    )
                  : const SizedBox.shrink(),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _bloco(String rotulo, Widget valor) => Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(rotulo,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: valor),
        ]),
      );
}

class _OndasPainter extends CustomPainter {
  final double t;
  final Color cor;
  _OndasPainter(this.t, this.cor);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final f = (t + i / 3) % 1.0;
      canvas.drawCircle(
        c,
        37 + (s.width / 2 - 37) * f,
        Paint()..color = cor.withOpacity((1 - f) * .22),
      );
    }
  }

  @override
  bool shouldRepaint(_OndasPainter o) => o.t != t || o.cor != cor;
}

class _ListrasPainter extends CustomPainter {
  final double t;
  final Color cor;
  _ListrasPainter(this.t, this.cor);

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = cor);
    final p = Paint()..color = Colors.white.withOpacity(.28);
    const passo = 22.0;
    final desloc = t * passo;
    for (double x = -passo * 2 + desloc; x < s.width + passo; x += passo) {
      final path = Path()
        ..moveTo(x, s.height)
        ..lineTo(x + 10, 0)
        ..lineTo(x + 20, 0)
        ..lineTo(x + 10, s.height)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_ListrasPainter o) => o.t != t || o.cor != cor;
}

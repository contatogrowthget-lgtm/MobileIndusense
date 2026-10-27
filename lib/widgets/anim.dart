import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'ui.dart';

/// Peças animadas reutilizáveis: número que conta, arco medidor e esqueleto
/// de carregamento com brilho passando.

/// Número que sobe até o valor (e anima de novo quando o valor muda).
class CountUp extends StatelessWidget {
  final double value;
  final int decimals;
  final TextStyle? style;
  final String suffix;
  final Duration duration;

  const CountUp({
    super.key,
    required this.value,
    this.decimals = 0,
    this.style,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
  });

  static String fmt(double v, int d) => v.toStringAsFixed(d).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text('${fmt(v, decimals)}$suffix', style: style),
      );
}

/// Arco de 240° que enche até [fraction] (0..1), com degradê e ponta brilhante.
class ArcGauge extends StatelessWidget {
  final double fraction;
  final Color color;
  final double size;
  final double stroke;
  final Widget? center;

  const ArcGauge({
    super.key,
    required this.fraction,
    required this.color,
    this.size = 160,
    this.stroke = 14,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final trilho = isDark(context) ? Colors.white10 : const Color(0xFFE8EFF9);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (_, f, __) => CustomPaint(
          painter: _ArcPainter(f, color, trilho, stroke),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double f;
  final Color cor;
  final Color trilho;
  final double stroke;
  _ArcPainter(this.f, this.cor, this.trilho, this.stroke);

  static const _inicio = math.pi * 5 / 6; // 150°
  static const _total = math.pi * 4 / 3; // 240°

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trilho;
    canvas.drawArc(rect, _inicio, _total, false, base);
    if (f <= 0) return;
    final arco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: const GradientRotation(_inicio - .2),
        colors: [cor.withOpacity(.55), cor, cor],
        stops: const [0, .45, 1],
      ).createShader(rect);
    canvas.drawArc(rect, _inicio, _total * f, false, arco);
    // ponta brilhante
    final ang = _inicio + _total * f;
    final c = rect.center;
    final r = rect.width / 2;
    final ponta = Offset(c.dx + r * math.cos(ang), c.dy + r * math.sin(ang));
    canvas.drawCircle(ponta, stroke * .75, Paint()..color = cor.withOpacity(.25));
    canvas.drawCircle(ponta, stroke * .38, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.f != f || o.cor != cor || o.trilho != trilho;
}

/// Bloco cinza com brilho passando (lugar de conteúdo carregando).
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 12});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final base = dark ? const Color(0xFF17223A) : const Color(0xFFE9EFF8);
    final brilho = dark ? const Color(0xFF22304F) : const Color(0xFFF7FAFE);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + 3 * _c.value, 0),
            end: Alignment(-0.5 + 3 * _c.value, 0),
            colors: [base, brilho, base],
          ),
        ),
      ),
    );
  }
}

/// Lista de cartões-esqueleto (enquanto a tela carrega).
class SkeletonList extends StatelessWidget {
  final int itens;
  final double altura;
  final EdgeInsetsGeometry padding;
  final Widget? topo;
  const SkeletonList({
    super.key,
    this.itens = 5,
    this.altura = 84,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
    this.topo,
  });

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        children: [
          if (topo != null) topo!,
          for (var i = 0; i < itens; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  height: altura - 28,
                  child: Row(children: [
                    Skeleton(width: altura - 28, height: altura - 28, radius: 16),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 150.0 - i * 12, height: 14),
                          const SizedBox(height: 10),
                          const Skeleton(width: 96, height: 11),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
        ],
      );
}

/// Título grande das abas (estilo do Início): "Alertas" + subtítulo.
class TelaTitulo extends StatelessWidget {
  final String titulo;
  final String? destaque;
  final String? subtitulo;
  final Widget? acao;
  const TelaTitulo({super.key, required this.titulo, this.destaque, this.subtitulo, this.acao});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 0, 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (subtitulo != null)
                Text(subtitulo!,
                    style: TextStyle(color: mutedText(context), fontSize: 13.5, fontWeight: FontWeight.w600)),
              if (subtitulo != null) const SizedBox(height: 4),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: titulo),
                  if (destaque != null) TextSpan(text: destaque, style: const TextStyle(color: AppColors.accent)),
                ]),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.1),
              ),
            ]),
          ),
          if (acao != null) acao!,
        ]),
      );
}

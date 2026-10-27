import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ícones animados de cada grandeza, sempre em movimento:
///  - temperatura: termômetro com o mercúrio subindo e descendo + ondas de calor
///  - umidade: gota balançando com a água ondulando por dentro
///  - qualidade do ar: correntes de vento passando
///  - gases: frasco com bolhas subindo
/// [tipo] aceita 'temperatura', 'umidade', 'qualidadeAr'/'qualidade_ar' e 'gas'.
class LiveSensorIcon extends StatefulWidget {
  final String tipo;
  final double size;
  final Color color;

  /// false = desenho parado (ex.: sensor offline).
  final bool animar;

  const LiveSensorIcon({super.key, required this.tipo, this.size = 22, this.color = Colors.white, this.animar = true});

  @override
  State<LiveSensorIcon> createState() => _LiveSensorIconState();
}

class _LiveSensorIconState extends State<LiveSensorIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.animar) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant LiveSensorIcon old) {
    super.didUpdateWidget(old);
    if (widget.animar && !_c.isAnimating) _c.repeat();
    if (!widget.animar && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(painter: _painterPara(widget.tipo, _c.value, widget.color)),
        ),
      ),
    );
  }
}

CustomPainter _painterPara(String tipo, double t, Color cor) {
  switch (tipo) {
    case 'temperatura':
      return _TermometroPainter(t, cor);
    case 'umidade':
      return _GotaPainter(t, cor);
    case 'qualidadeAr':
    case 'qualidade_ar':
      return _VentoPainter(t, cor);
    case 'gas':
      return _BolhasPainter(t, cor);
    default:
      return _OndaPainter(t, cor);
  }
}

double _onda(double t, [double fase = 0]) => math.sin((t + fase) * 2 * math.pi);

// ------------------------------------------------------------------ temperatura
class _TermometroPainter extends CustomPainter {
  final double t;
  final Color cor;
  _TermometroPainter(this.t, this.cor);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final contorno = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .085
      ..strokeCap = StrokeCap.round;
    final cheio = Paint()..color = cor;

    final cx = w * .40;
    final tuboW = w * .20;
    final topo = h * .08;
    final bulboC = Offset(cx, h * .76);
    final bulboR = w * .17;

    // tubo + bulbo
    final tubo = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - tuboW / 2, topo, cx + tuboW / 2, bulboC.dy),
      Radius.circular(tuboW / 2),
    );
    final forma = Path()
      ..addRRect(tubo)
      ..addOval(Rect.fromCircle(center: bulboC, radius: bulboR));
    canvas.drawPath(forma, contorno);

    // mercúrio sobe e desce
    final nivel = .42 + .28 * (0.5 + 0.5 * _onda(t));
    final yTopo = bulboC.dy - (bulboC.dy - topo - tuboW * .4) * nivel;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - tuboW * .22, yTopo, cx + tuboW * .22, bulboC.dy),
        Radius.circular(tuboW * .22),
      ),
      cheio,
    );
    canvas.drawCircle(bulboC, bulboR * .62, cheio);

    // ondas de calor subindo à direita
    for (var i = 0; i < 2; i++) {
      final p = (t + i * .5) % 1.0;
      final x = w * (.72 + i * .14);
      final y0 = h * .62 - p * h * .45;
      final alfa = (math.sin(p * math.pi)).clamp(0.0, 1.0);
      final ondaPaint = Paint()
        ..color = cor.withOpacity(.85 * alfa)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .06
        ..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(x, y0 + h * .16);
      path.cubicTo(x - w * .06, y0 + h * .11, x + w * .06, y0 + h * .05, x, y0);
      canvas.drawPath(path, ondaPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TermometroPainter o) => o.t != t || o.cor != cor;
}

// ------------------------------------------------------------------ umidade
class _GotaPainter extends CustomPainter {
  final double t;
  final Color cor;
  _GotaPainter(this.t, this.cor);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final dy = _onda(t) * h * .04; // balança
    canvas.save();
    canvas.translate(0, dy);

    final gota = Path()
      ..moveTo(w * .5, h * .08)
      ..cubicTo(w * .5, h * .08, w * .16, h * .46, w * .16, h * .62)
      ..arcToPoint(Offset(w * .84, h * .62), radius: Radius.circular(w * .34), clockwise: false)
      ..cubicTo(w * .84, h * .46, w * .5, h * .08, w * .5, h * .08)
      ..close();

    canvas.drawPath(
      gota,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .08
        ..strokeJoin = StrokeJoin.round,
    );

    // água ondulando dentro
    canvas.save();
    canvas.clipPath(gota);
    final nivel = h * (.52 + .05 * _onda(t, .25));
    final agua = Path()..moveTo(0, h);
    for (double x = 0; x <= w; x += w / 16) {
      agua.lineTo(x, nivel + math.sin((x / w * 2 + t * 2) * math.pi) * h * .05);
    }
    agua
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(agua, Paint()..color = cor.withOpacity(.9));
    canvas.restore();

    // brilho
    canvas.drawCircle(
      Offset(w * .38, h * .52),
      w * .05,
      Paint()..color = cor.withOpacity(.0 + .5 * (0.5 + 0.5 * _onda(t, .5))),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GotaPainter o) => o.t != t || o.cor != cor;
}

// ------------------------------------------------------------------ qualidade do ar
class _VentoPainter extends CustomPainter {
  final double t;
  final Color cor;
  _VentoPainter(this.t, this.cor);

  Path _linha(Size s, double y, double comp, bool curvaCima) {
    final w = s.width, h = s.height;
    final fim = w * .1 + w * comp;
    final r = h * .12;
    final p = Path()..moveTo(w * .08, y);
    p.lineTo(fim, y);
    // cachinho no final
    p.arcToPoint(
      Offset(fim, y + (curvaCima ? -2 * r : 2 * r)),
      radius: Radius.circular(r),
      clockwise: !curvaCima,
    );
    p.arcToPoint(
      Offset(fim - r * .9, y + (curvaCima ? -r : r)),
      radius: Radius.circular(r * .5),
      clockwise: !curvaCima,
    );
    return p;
  }

  @override
  void paint(Canvas canvas, Size s) {
    final h = s.height;
    final linhas = [
      (_linha(s, h * .34, .58, true), 0.0),
      (_linha(s, h * .54, .74, false), .33),
      (_linha(s, h * .74, .44, false), .66),
    ];
    for (final (path, fase) in linhas) {
      // trilho fraquinho
      canvas.drawPath(
        path,
        Paint()
          ..color = cor.withOpacity(.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * .075
          ..strokeCap = StrokeCap.round,
      );
      // rajada percorrendo a linha
      for (final m in path.computeMetrics()) {
        final p = (t + fase) % 1.0;
        final ini = m.length * (p * 1.4 - .4);
        final seg = m.extractPath(ini.clamp(0.0, m.length), (ini + m.length * .55).clamp(0.0, m.length));
        canvas.drawPath(
          seg,
          Paint()
            ..color = cor
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.width * .085
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VentoPainter o) => o.t != t || o.cor != cor;
}

// ------------------------------------------------------------------ gases
class _BolhasPainter extends CustomPainter {
  final double t;
  final Color cor;
  _BolhasPainter(this.t, this.cor);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // frasco (Erlenmeyer)
    final frasco = Path()
      ..moveTo(w * .38, h * .1)
      ..lineTo(w * .38, h * .38)
      ..lineTo(w * .14, h * .84)
      ..quadraticBezierTo(w * .12, h * .92, w * .22, h * .92)
      ..lineTo(w * .78, h * .92)
      ..quadraticBezierTo(w * .88, h * .92, w * .86, h * .84)
      ..lineTo(w * .62, h * .38)
      ..lineTo(w * .62, h * .1);
    canvas.drawPath(
      frasco,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .08
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(w * .32, h * .1),
      Offset(w * .68, h * .1),
      Paint()
        ..color = cor
        ..strokeWidth = w * .08
        ..strokeCap = StrokeCap.round,
    );

    // líquido
    final liquido = Path()
      ..moveTo(w * .25, h * .66)
      ..lineTo(w * .75, h * .66)
      ..lineTo(w * .84, h * .86)
      ..lineTo(w * .16, h * .86)
      ..close();
    canvas.drawPath(liquido, Paint()..color = cor.withOpacity(.55));

    // bolhas subindo e saindo pela boca
    const bolhas = [(.42, 0.0, .07), (.56, .35, .055), (.48, .7, .045)];
    for (final (x, fase, r) in bolhas) {
      final p = (t + fase) % 1.0;
      final y = h * (.82 - p * .9);
      final balanco = math.sin(p * math.pi * 3) * w * .04;
      final alfa = p < .85 ? 1.0 : (1 - (p - .85) / .15);
      canvas.drawCircle(
        Offset(w * x + balanco, y),
        w * r * (.7 + p * .6),
        Paint()..color = cor.withOpacity(alfa.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BolhasPainter o) => o.t != t || o.cor != cor;
}

// ------------------------------------------------------------------ genérico
class _OndaPainter extends CustomPainter {
  final double t;
  final Color cor;
  _OndaPainter(this.t, this.cor);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    canvas.drawCircle(c, s.width * .12, Paint()..color = cor);
    for (var i = 0; i < 2; i++) {
      final p = (t + i * .5) % 1.0;
      canvas.drawCircle(
        c,
        s.width * (.15 + p * .32),
        Paint()
          ..color = cor.withOpacity(1 - p)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * .07,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OndaPainter o) => o.t != t || o.cor != cor;
}

/// Bolinha com o ícone animado e um anel "respirando" em volta (sensor ao vivo).
class LiveSensorBadge extends StatefulWidget {
  final String tipo;
  final double size;
  final Gradient? gradient;
  final Color? fundo;
  final Color iconColor;
  final Color anelColor;
  final bool aoVivo;

  const LiveSensorBadge({
    super.key,
    required this.tipo,
    this.size = 40,
    this.gradient,
    this.fundo,
    this.iconColor = Colors.white,
    required this.anelColor,
    this.aoVivo = true,
  });

  @override
  State<LiveSensorBadge> createState() => _LiveSensorBadgeState();
}

class _LiveSensorBadgeState extends State<LiveSensorBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

  @override
  void initState() {
    super.initState();
    if (widget.aoVivo) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant LiveSensorBadge old) {
    super.didUpdateWidget(old);
    if (widget.aoVivo && !_c.isAnimating) _c.repeat();
    if (!widget.aoVivo && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size;
    return SizedBox.square(
      dimension: d,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        if (widget.aoVivo)
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final p = Curves.easeOut.transform(_c.value);
              return Container(
                width: d * (1 + .45 * p),
                height: d * (1 + .45 * p),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.anelColor.withOpacity(.45 * (1 - p)), width: 2),
                ),
              );
            },
          ),
        Container(
          width: d,
          height: d,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: widget.gradient, color: widget.fundo),
          alignment: Alignment.center,
          child: LiveSensorIcon(tipo: widget.tipo, size: d * .58, color: widget.iconColor, animar: widget.aoVivo),
        ),
      ]),
    );
  }
}

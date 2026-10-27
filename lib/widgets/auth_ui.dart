import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Visual claro das telas de entrada (splash, login e cadastro),
/// no estilo das telas de referência: fundo azul bem clarinho, ondas azuis
/// no rodapé, marca InduSense e campos brancos arredondados.

class AuthColors {
  AuthColors._();
  static const fundoTopo = Color(0xFFF7FAFE);
  static const fundoBase = Color(0xFFEAF2FE);
  static const tinta = Color(0xFF0A1A3F);
  static const texto = Color(0xFF64748B);
  static const textoClaro = Color(0xFF94A3B8);
  static const borda = Color(0xFFDCE6F5);
  static const azul = Color(0xFF1E6BFF);
  static const ciano = Color(0xFF13C8E8);
}

const authGradiente = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF1061FF), Color(0xFF1E8BFF), Color(0xFF14D0EC)],
);

/// Fundo claro com bolha suave no topo e ondas azuis embaixo.
class AuthScaffold extends StatelessWidget {
  final Widget child;
  final bool ondas;
  final double ondasAltura;
  const AuthScaffold({super.key, required this.child, this.ondas = true, this.ondasAltura = 130});

  @override
  Widget build(BuildContext context) {
    return Theme(
      // estas telas são sempre claras, mesmo com o app no modo escuro
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AuthColors.fundoTopo,
        body: Stack(children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AuthColors.fundoTopo, AuthColors.fundoBase],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFFDCEBFF).withOpacity(.9), const Color(0x00DCEBFF)]),
              ),
            ),
          ),
          if (ondas)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: ondasAltura,
              child: const IgnorePointer(child: CustomPaint(painter: OndasPainter())),
            ),
          child,
        ]),
      ),
    );
  }
}

/// Ondas do rodapé (duas camadas de azul).
class OndasPainter extends CustomPainter {
  final double fase;
  const OndasPainter({this.fase = 0});

  @override
  void paint(Canvas canvas, Size s) {
    Path onda(double base, double amp, double desloc) {
      final p = Path()..moveTo(0, s.height);
      p.lineTo(0, s.height * base);
      for (double x = 0; x <= s.width; x += 4) {
        final y = s.height * base + amp * math.sin((x / s.width) * math.pi * 1.4 + desloc + fase);
        p.lineTo(x, y);
      }
      p.lineTo(s.width, s.height);
      p.close();
      return p;
    }

    final r = Offset.zero & s;
    canvas.drawPath(
      onda(.42, 18, 2.2),
      Paint()
        ..shader = const LinearGradient(colors: [Color(0x332F7BFF), Color(0x5522B8F0)]).createShader(r),
    );
    canvas.drawPath(
      onda(.62, 16, 3.6),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFBFD8FF), Color(0xFF4C9BFF), Color(0xFF1366FF)],
        ).createShader(r),
    );
    // fio branco em cima da onda
    canvas.drawPath(
      onda(.40, 18, 2.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withOpacity(.9),
    );
  }

  @override
  bool shouldRepaint(OndasPainter old) => old.fase != fase;
}

/// Símbolo + "InduSense" + "MONITORAMENTO INDUSTRIAL INTELIGENTE".
class BrandWordmark extends StatelessWidget {
  final double logo;
  final double fonte;
  final bool vertical;

  /// false = só a escrita, sem o símbolo.
  final bool simbolo;
  const BrandWordmark({super.key, this.logo = 64, this.fonte = 32, this.vertical = false, this.simbolo = true});

  @override
  Widget build(BuildContext context) {
    final marca = Image.asset(
      'assets/images/logo_mark.png',
      width: logo,
      height: logo,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(Icons.factory_rounded, size: logo * .8, color: AuthColors.azul),
    );
    final nome = Column(
      crossAxisAlignment: vertical ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Indu',
              style: TextStyle(
                  color: AuthColors.tinta, fontSize: fonte, fontWeight: FontWeight.w800, letterSpacing: -fonte * .03, height: 1)),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => authGradiente.createShader(r),
            child: Text('Sense',
                style: TextStyle(
                    color: Colors.white, fontSize: fonte, fontWeight: FontWeight.w800, letterSpacing: -fonte * .03, height: 1)),
          ),
        ]),
        SizedBox(height: fonte * .22),
        Text('MONITORAMENTO INDUSTRIAL INTELIGENTE',
            style: TextStyle(
                color: AuthColors.texto, fontSize: fonte * .2, fontWeight: FontWeight.w700, letterSpacing: fonte * .03)),
      ],
    );
    if (!simbolo) {
      return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: nome);
    }
    if (vertical) {
      return Column(mainAxisSize: MainAxisSize.min, children: [marca, SizedBox(height: logo * .12), nome]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      marca,
      SizedBox(width: logo * .2),
      // encolhe junto se a tela for estreita, sem estourar a linha
      Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: nome)),
    ]);
  }
}

/// Título com a parte final em azul: "Bem-vindo " + "de volta!".
class TituloAzul extends StatelessWidget {
  final String inicio;
  final String destaque;
  final double fonte;
  final TextAlign align;
  const TituloAzul(this.inicio, this.destaque, {super.key, this.fonte = 30, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: inicio),
          TextSpan(text: destaque, style: const TextStyle(color: AuthColors.azul)),
        ]),
        textAlign: align,
        style: TextStyle(
            color: AuthColors.tinta, fontSize: fonte, fontWeight: FontWeight.w800, letterSpacing: -fonte * .025, height: 1.15),
      );
}

/// Campo branco arredondado com ícone azul.
InputDecoration authCampo(String rotulo, IconData icone, {Widget? sufixo}) {
  OutlineInputBorder borda(Color c, [double w = 1.2]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: rotulo,
    hintStyle: const TextStyle(color: AuthColors.textoClaro, fontSize: 15),
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 16, right: 10),
      child: Icon(icone, color: AuthColors.azul, size: 22),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 48),
    suffixIcon: sufixo,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    border: borda(AuthColors.borda),
    enabledBorder: borda(AuthColors.borda),
    focusedBorder: borda(AuthColors.azul, 1.6),
    errorBorder: borda(AppColors.statusCritico),
    focusedErrorBorder: borda(AppColors.statusCritico, 1.6),
    errorStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  );
}

const authTextoCampo = TextStyle(color: AuthColors.tinta, fontSize: 15.5, fontWeight: FontWeight.w600);

/// Botão de olho para mostrar/esconder a senha.
class OlhoSenha extends StatelessWidget {
  final bool visivel;
  final VoidCallback onTap;
  const OlhoSenha({super.key, required this.visivel, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: visivel ? 'Esconder senha' : 'Mostrar senha',
        onPressed: onTap,
        icon: Icon(visivel ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF7C8AA5)),
      );
}

/// Cartão branco translúcido do formulário.
class AuthCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AuthCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(24, 28, 24, 24)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.82),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(color: const Color(0xFF1E4FB8).withOpacity(.08), blurRadius: 40, offset: const Offset(0, 18)),
          ],
        ),
        child: child,
      );
}

/// Botão principal em degradê azul → ciano, com seta.
class GradientButton extends StatelessWidget {
  final String texto;
  final bool carregando;
  final VoidCallback? onPressed;
  const GradientButton({super.key, required this.texto, required this.carregando, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final ativo = onPressed != null && !carregando;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: onPressed == null && !carregando ? .6 : 1,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: authGradiente,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: AuthColors.azul.withOpacity(.32), blurRadius: 22, offset: const Offset(0, 10)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: ativo ? onPressed : null,
            child: Center(
              child: carregando
                  ? const SizedBox(
                      width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(texto,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// "—— ou continue com ——"
class OuDivisor extends StatelessWidget {
  final String texto;
  const OuDivisor({super.key, this.texto = 'ou continue com'});

  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Divider(color: AuthColors.borda, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(texto, style: const TextStyle(color: AuthColors.textoClaro, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        const Expanded(child: Divider(color: AuthColors.borda, thickness: 1)),
      ]);
}

/// Botão do Google ou da Apple.
class BotaoSocial extends StatelessWidget {
  final String rotulo;
  final Widget icone;
  final bool escuro;
  final bool carregando;
  final VoidCallback? onPressed;

  const BotaoSocial({
    super.key,
    required this.rotulo,
    required this.icone,
    this.escuro = false,
    required this.carregando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cor = escuro ? Colors.black : Colors.white;
    final texto = escuro ? Colors.white : AuthColors.tinta;
    return Material(
      color: cor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: carregando ? null : onPressed,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: escuro ? null : Border.all(color: AuthColors.borda, width: 1.2),
          ),
          child: Center(
            child: carregando
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: texto))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    icone,
                    const SizedBox(width: 12),
                    Text(rotulo, style: TextStyle(color: texto, fontWeight: FontWeight.w700, fontSize: 16)),
                  ]),
          ),
        ),
      ),
    );
  }
}

/// "G" colorido do Google desenhado em código (sem precisar de imagem).
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double g(double graus) => graus * math.pi / 180;

    canvas.drawArc(rect, g(-140), g(100), false, p(const Color(0xFFEA4335)));
    canvas.drawArc(rect, g(140), g(80), false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, g(40), g(100), false, p(const Color(0xFF34A853)));
    canvas.drawArc(rect, g(-10), g(50), false, p(const Color(0xFF4285F4)));
    canvas.drawRect(
      Rect.fromLTWH(s * 0.5, s * 0.5 - stroke / 2, s * 0.5 - stroke * 0.05, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Entrada suave (sobe e aparece) com atraso.
class Entrada extends StatelessWidget {
  final Widget child;
  final int atrasoMs;
  final double deslocamento;
  const Entrada({super.key, required this.child, this.atrasoMs = 0, this.deslocamento = 18});

  @override
  Widget build(BuildContext context) {
    final total = 520 + atrasoMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(atrasoMs / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, deslocamento * (1 - v)), child: child),
      ),
    );
  }
}

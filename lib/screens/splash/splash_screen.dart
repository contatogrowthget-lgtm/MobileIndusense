import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';
import '../../services/auth_provider.dart';
import '../../widgets/auth_ui.dart';

/// Abertura clara: marca no topo, fotos da operação no centro (flutuando
/// devagar), frase de efeito e barra de carregamento enquanto a sessão é restaurada.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _duracao = Duration(milliseconds: 2600);

  late final AnimationController _progresso = AnimationController(vsync: this, duration: _duracao)..forward();
  late final AnimationController _flutua =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _bootstrap();
  }

  @override
  void dispose() {
    _progresso.dispose();
    _flutua.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    await Future.wait([auth.restoreSession(), Future.delayed(_duracao)]);
    if (!mounted) return;
    final destino = auth.status == AuthStatus.autenticado ? '/dashboard' : '/login';
    final tela = AppRoutes.routes[destino]!;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      settings: RouteSettings(name: destino),
      transitionDuration: const Duration(milliseconds: 550),
      pageBuilder: (ctx, _, __) => tela(ctx),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.of(context).size.height;
    return AuthScaffold(
      child: SafeArea(
        // em tela baixa (paisagem / tela dividida) rola em vez de estourar a Column
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(
                child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
                SizedBox(height: alto * .05),
                const Entrada(child: BrandWordmark(logo: 74, fonte: 34)),
                const Spacer(),
                // fotos flutuando
                Entrada(
                  atrasoMs: 200,
                  deslocamento: 30,
                  child: AnimatedBuilder(
                    animation: _flutua,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, math.sin(_flutua.value * math.pi) * 8 - 4),
                      child: child,
                    ),
                    child: Image.asset(
                      'assets/images/splash_collage.png',
                      fit: BoxFit.contain,
                      height: alto * .34,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                const Spacer(),
                const Entrada(
                  atrasoMs: 450,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Tecnologia que '),
                      TextSpan(text: 'cuida\ndo que importa', style: TextStyle(color: AuthColors.azul)),
                    ]),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AuthColors.tinta, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.8, height: 1.2),
                  ),
                ),
                const SizedBox(height: 14),
                const Entrada(
                  atrasoMs: 600,
                  child: Text(
                    'Monitoramento em tempo real de sensores, câmeras e ambientes industriais com inteligência e segurança.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AuthColors.texto, fontSize: 15.5, height: 1.5),
                  ),
                ),
                const SizedBox(height: 32),
                // barra de carregamento
                SizedBox(
                  width: 180,
                  height: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(children: [
                      Positioned.fill(child: ColoredBox(color: AuthColors.azul.withOpacity(.12))),
                      AnimatedBuilder(
                        animation: _progresso,
                        builder: (_, __) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          heightFactor: 1,
                          widthFactor: Curves.easeInOutCubic.transform(_progresso.value),
                          child: const DecoratedBox(decoration: BoxDecoration(gradient: authGradiente)),
                        ),
                      ),
                    ]),
                  ),
                ),
                SizedBox(height: alto * .11), // espaço das ondas
              ]),
            ),
          ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

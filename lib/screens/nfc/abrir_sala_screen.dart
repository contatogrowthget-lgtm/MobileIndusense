import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_provider.dart';
import '../home_shell.dart';
import '../sala_detail/sala_detail_screen.dart';

/// Aberta pelo link gravado na tag (indusense://app/sala/IND-001).
/// Confere a sessão e abre a sala; com [inicial] (app estava fechado),
/// coloca o Início por baixo para o "voltar" funcionar.
class AbrirSalaScreen extends StatefulWidget {
  final String codigo;
  final bool inicial;
  const AbrirSalaScreen({super.key, required this.codigo, this.inicial = false});

  @override
  State<AbrirSalaScreen> createState() => _AbrirSalaScreenState();
}

class _AbrirSalaScreenState extends State<AbrirSalaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrir());
  }

  Future<void> _abrir() async {
    final auth = context.read<AuthProvider>();
    if (auth.status == AuthStatus.desconhecido) await auth.restoreSession();
    if (!mounted) return;
    final nav = Navigator.of(context);

    if (auth.status != AuthStatus.autenticado) {
      nav.pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }
    final sala = MaterialPageRoute(builder: (_) => SalaDetailScreen(salaId: widget.codigo));
    if (widget.inicial) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(settings: const RouteSettings(name: '/dashboard'), builder: (_) => const HomeShell()),
        (_) => false,
      );
      nav.push(sala);
    } else {
      nav.pushReplacement(sala);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.night),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.contactless_rounded, color: AppColors.cyan, size: 56),
            SizedBox(height: 18),
            Text('Abrindo a sala…', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 18),
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

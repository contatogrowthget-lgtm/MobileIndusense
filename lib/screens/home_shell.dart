import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/alert_service.dart';
import '../services/alert_watcher.dart';
import '../services/camera_service.dart';
import '../services/nfc_auto_reader.dart';
import 'alertas/alertas_screen.dart';
import 'cameras/cameras_screen.dart';
import 'configuracoes/configuracoes_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'historico/historico_screen.dart';

/// Permite que qualquer tela troque de aba (ex.: "Ver todos" no dashboard abre Alertas).
class HomeShellScope extends InheritedWidget {
  final ValueChanged<int> goTo;
  const HomeShellScope({super.key, required this.goTo, required super.child});

  static HomeShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeShellScope>();

  @override
  bool updateShouldNotify(HomeShellScope oldWidget) => false;
}

class HomeTabs {
  static const inicio = 0;
  static const cameras = 1;
  static const historico = 2;
  static const alertas = 3;
  static const perfil = 4;
}

class HomeShell extends StatefulWidget {
  final int initialIndex;
  const HomeShell({super.key, this.initialIndex = 0});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;
  int _pendentes = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    // Android: encostou na tag da porta -> abre a sala, em qualquer tela
    NfcAutoReader.instance.ligar();
    // aviso grande quando algum sensor sai do limite (em qualquer tela)
    AlertWatcher.instance.ligar();
    _contarPendentes();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _contarPendentes());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() => _index = widget.initialIndex);
    }
  }

  /// Número no ícone de Alertas: alertas de sensor não lidos + ocorrências de EPI abertas.
  Future<void> _contarPendentes() async {
    var total = 0;
    try {
      final alertas = await AlertService().getAlerts();
      total += alertas.where((a) => !a.lido).length;
    } catch (_) {}
    try {
      total += (await CameraService().resumo()).abertas;
    } catch (_) {}
    if (mounted && total != _pendentes) setState(() => _pendentes = total);
  }

  void _goTo(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    if (i == HomeTabs.alertas || i == HomeTabs.inicio) _contarPendentes();
  }

  @override
  Widget build(BuildContext context) {
    return HomeShellScope(
      goTo: _goTo,
      child: Scaffold(
        body: IndexedStack(index: _index, children: [
          // "ativo" pausa o vídeo ao vivo quando a aba não está na tela
          DashboardScreen(ativo: _index == HomeTabs.inicio),
          CamerasScreen(ativo: _index == HomeTabs.cameras),
          const HistoricoScreen(),
          const AlertasScreen(),
          const ConfiguracoesScreen(),
        ]),
        bottomNavigationBar: _NavBar(index: _index, pendentes: _pendentes, onTap: _goTo),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData iconAtivo;
  final String label;
  const _NavItem(this.icon, this.iconAtivo, this.label);
}

class _NavBar extends StatelessWidget {
  final int index;
  final int pendentes;
  final ValueChanged<int> onTap;

  const _NavBar({required this.index, required this.pendentes, required this.onTap});

  static const _itens = [
    _NavItem(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Início'),
    _NavItem(Icons.videocam_outlined, Icons.videocam_rounded, 'Câmeras'),
    _NavItem(Icons.insights_outlined, Icons.insights_rounded, 'Histórico'),
    _NavItem(Icons.notifications_none_rounded, Icons.notifications_rounded, 'Alertas'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: dark ? Border.all(color: AppColors.darkBorder) : null,
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withOpacity(dark ? 0.4 : 0.10), blurRadius: 30, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          children: List.generate(_itens.length, (i) {
            final item = _itens[i];
            final ativo = i == index;
            final badge = i == HomeTabs.alertas && pendentes > 0;
            final icone = Badge(
              isLabelVisible: badge,
              backgroundColor: AppColors.statusCritico,
              label: Text(pendentes > 99 ? '99+' : '$pendentes', style: const TextStyle(fontSize: 10)),
              child: Icon(ativo ? item.iconAtivo : item.icon,
                  color: ativo ? Colors.white : const Color(0xFF94A3B8), size: 22),
            );
            // aba ativa vira uma pílula em degradê (igual ao botão Entrar) com o nome
            return Expanded(
              flex: ativo ? 6 : 3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    height: 46,
                    padding: EdgeInsets.symmetric(horizontal: ativo ? 14 : 0),
                    decoration: BoxDecoration(
                      gradient: ativo ? AppGradients.hero : null,
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: ativo
                          ? [BoxShadow(color: AppColors.accent.withOpacity(.35), blurRadius: 14, offset: const Offset(0, 6))]
                          : null,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      icone,
                      if (ativo) ...[
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(item.label,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

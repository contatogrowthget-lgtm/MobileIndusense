import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/alert_model.dart';
import '../../models/sensor_model.dart';
import '../../services/alert_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/camera_service.dart';
import '../../widgets/anim.dart';
import '../../widgets/live_sensor_icon.dart';
import '../../widgets/settings_ui.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/ui.dart';
import '../sala_detail/sala_detail_screen.dart';
import 'epi_tab.dart';

enum _Aba { sensores, epi }

enum _Filtro { ativos, criticos, resolvidosHoje, resolvidos, todos }

/// Central de alertas: resumo animado, filtros e cartões com deslizar
/// (→ marcar como lido, ← resolver). A aba EPI mostra as fotos das câmeras.
class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  final _service = AlertService();
  List<AlertModel>? _alertas;
  String? _erro;
  _Aba _aba = _Aba.sensores;
  _Filtro _filtro = _Filtro.ativos;
  Timer? _timer;
  int? _epiAbertas;

  @override
  void initState() {
    super.initState();
    final p = context.read<AuthProvider>().user?.perfil;
    _podeResolver = p == 'ADMIN' || p == 'OPERADOR';
    _carregar();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _carregar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  late final bool _podeResolver;

  Future<void> _carregar({bool silencioso = false}) async {
    try {
      final l = await _service.getAlerts(limit: 300);
      if (!mounted) return;
      setState(() {
        _alertas = l;
        _erro = null;
      });
      try {
        final r = await CameraService().resumo();
        if (mounted) setState(() => _epiAbertas = r.abertas);
      } catch (_) {}
    } on ApiException catch (e) {
      if (!mounted || (silencioso && _alertas != null)) return;
      setState(() => _erro = e.message);
    }
  }

  void _aviso(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _lido(AlertModel a) async {
    HapticFeedback.selectionClick();
    setState(() => _alertas = _alertas!.map((x) => x.id == a.id ? x.copyWith(lido: true) : x).toList());
    try {
      await _service.marcarComoLido(a.id);
    } catch (_) {}
  }

  Future<void> _resolver(AlertModel a) async {
    HapticFeedback.mediumImpact();
    setState(() =>
        _alertas = _alertas!.map((x) => x.id == a.id ? x.copyWith(lido: true, resolvido: true) : x).toList());
    try {
      await _service.resolver(a.id);
      if (!mounted) return;
      _aviso('Alerta resolvido. Se o valor continuar fora do limite, um novo alerta é aberto.');
    } on ApiException catch (e) {
      if (!mounted) return;
      _aviso(e.message);
      _carregar(silencioso: true);
    }
  }

  Future<void> _todosLidos() async {
    HapticFeedback.mediumImpact();
    setState(() => _alertas = _alertas!.map((x) => x.copyWith(lido: true)).toList());
    try {
      await _service.marcarTodosLidos();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final todos = _alertas ?? const <AlertModel>[];
    final ativos = todos.where((a) => !a.resolvido).toList();
    final naoLidos = ativos.where((a) => !a.lido).length;
    final hoje = DateTime.now();
    final resolvidosHoje = todos
        .where((a) => a.resolvido && a.resolvidoEm != null && DateUtils.isSameDay(a.resolvidoEm, hoje))
        .length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  TelaTitulo(
                    titulo: 'Alertas',
                    subtitulo: ativos.isEmpty
                        ? 'Tudo dentro dos limites'
                        : '${ativos.length} ${ativos.length == 1 ? 'alerta ativo' : 'alertas ativos'} agora',
                    acao: naoLidos > 0 && _aba == _Aba.sensores
                        ? TextButton.icon(
                            onPressed: _todosLidos,
                            icon: const Icon(Icons.done_all_rounded, size: 18),
                            label: const Text('Ler todos'),
                          )
                        : null,
                  ),
                  SegmentedPicker<_Aba>(
                    value: _aba,
                    onChanged: (v) => setState(() => _aba = v),
                    options: const [
                      (_Aba.sensores, Icons.sensors_rounded, 'Sensores'),
                      (_Aba.epi, Icons.health_and_safety_rounded, 'EPI'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_aba == _Aba.sensores) ...[
                    FadeSlideIn(
                      child: Column(children: [
                        Row(children: [
                          _resumo('${ativos.length}', 'ativos',
                              ativos.isEmpty ? AppColors.statusNormal : AppColors.statusCritico, Icons.bolt_rounded,
                              selecionado: _filtro == _Filtro.ativos, onTap: () => _irPara(_Filtro.ativos)),
                          const SizedBox(width: 10),
                          _resumo(
                              '${ativos.where((a) => a.severidade == SensorStatus.critico).length}',
                              'críticos',
                              AppColors.statusCritico,
                              Icons.local_fire_department_rounded,
                              selecionado: _filtro == _Filtro.criticos,
                              onTap: () => _irPara(_Filtro.criticos)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          _resumo('$resolvidosHoje', 'resolvidos hoje', AppColors.statusNormal, Icons.verified_rounded,
                              selecionado: _filtro == _Filtro.resolvidosHoje,
                              onTap: () => _irPara(_Filtro.resolvidosHoje)),
                          const SizedBox(width: 10),
                          _resumo(_epiAbertas == null ? '—' : '$_epiAbertas', 'EPI em aberto',
                              (_epiAbertas ?? 0) > 0 ? AppColors.statusAtencao : AppColors.statusNormal,
                              Icons.health_and_safety_rounded,
                              onTap: () => setState(() => _aba = _Aba.epi)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    _filtros(),
                    const SizedBox(height: 6),
                  ],
                ]),
              ),
            ),
          ],
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _aba == _Aba.epi
                ? const EpiOcorrenciasTab(key: ValueKey('epi'))
                : KeyedSubtree(key: ValueKey('s$_filtro'), child: _lista(todos)),
          ),
        ),
      ),
    );
  }

  void _irPara(_Filtro f) {
    HapticFeedback.selectionClick();
    setState(() {
      _aba = _Aba.sensores;
      _filtro = f;
    });
  }

  /// Cartão do resumo: tocar abre a lista filtrada.
  Widget _resumo(String n, String rotulo, Color cor, IconData icon, {bool selecionado = false, VoidCallback? onTap}) =>
      Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selecionado ? cor : Colors.transparent, width: 2),
            boxShadow: selecionado ? [BoxShadow(color: cor.withOpacity(.25), blurRadius: 14, offset: const Offset(0, 4))] : null,
          ),
          child: AppCard(
            radius: 20,
            onTap: onTap,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, color: cor, size: 20),
                  const SizedBox(height: 8),
                  n == '—'
                      ? const Text('—', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1))
                      : CountUp(
                          value: double.tryParse(n) ?? 0,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1),
                        ),
                  const SizedBox(height: 2),
                  Text(rotulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: mutedText(context), fontSize: 12)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: mutedText(context).withOpacity(.6), size: 20),
            ]),
          ),
        ),
      );

  Widget _filtros() {
    Widget chip(_Filtro f, String texto) {
      final sel = _filtro == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _filtro = f);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: sel ? AppGradients.hero : null,
              color: sel ? null : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: sel ? null : Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(texto,
                style: TextStyle(
                    color: sel ? Colors.white : mutedText(context), fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(children: [
        chip(_Filtro.ativos, 'Ativos'),
        chip(_Filtro.criticos, 'Críticos'),
        chip(_Filtro.resolvidosHoje, 'Resolvidos hoje'),
        chip(_Filtro.resolvidos, 'Resolvidos'),
        chip(_Filtro.todos, 'Todos'),
      ]),
    );
  }

  Widget _lista(List<AlertModel> todos) {
    if (_alertas == null && _erro != null) return AppErrorWidget(mensagem: _erro!, onRetry: _carregar);
    if (_alertas == null) return const SkeletonList(itens: 5);

    final lista = todos
        .where((a) => switch (_filtro) {
              _Filtro.ativos => !a.resolvido,
              _Filtro.criticos => !a.resolvido && a.severidade == SensorStatus.critico,
              _Filtro.resolvidosHoje =>
                a.resolvido && a.resolvidoEm != null && DateUtils.isSameDay(a.resolvidoEm, DateTime.now()),
              _Filtro.resolvidos => a.resolvido,
              _Filtro.todos => true,
            })
        .toList()
      ..sort((a, b) {
        final r = (a.resolvido ? 1 : 0).compareTo(b.resolvido ? 1 : 0);
        if (r != 0) return r;
        return b.dataHora.compareTo(a.dataHora);
      });

    if (lista.isEmpty) {
      return RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(children: [
          const SizedBox(height: 40),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.hero),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(_filtro == _Filtro.ativos ? 'Tudo em ordem' : 'Nada por aqui',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            _filtro == _Filtro.ativos ? 'Nenhum sensor fora do limite agora.' : 'Nenhum alerta com esse filtro.',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedText(context)),
          ),
        ]),
      );
    }

    // agrupa por dia
    final itens = <Widget>[];
    String? diaAtual;
    var i = 0;
    for (final a in lista) {
      final dia = _rotuloDia(a.dataHora);
      if (dia != diaAtual) {
        diaAtual = dia;
        itens.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Text(dia.toUpperCase(),
              style: TextStyle(color: mutedText(context), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        ));
      }
      itens.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FadeSlideIn(index: i++, child: _cartao(a)),
      ));
    }
    if (lista.any((a) => !a.resolvido)) {
      itens.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.swipe_rounded, size: 16, color: mutedText(context)),
          const SizedBox(width: 6),
          Text(_podeResolver ? 'Arraste → para marcar como lido, ← para resolver' : 'Arraste → para marcar como lido',
              style: TextStyle(color: mutedText(context), fontSize: 12)),
        ]),
      ));
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 110), children: itens),
    );
  }

  static String _rotuloDia(DateTime d) {
    final hoje = DateTime.now();
    if (DateUtils.isSameDay(d, hoje)) return 'Hoje';
    if (DateUtils.isSameDay(d, hoje.subtract(const Duration(days: 1)))) return 'Ontem';
    return DateFormat("EEEE, d 'de' MMM", 'pt_BR').format(d);
  }

  static String _fmt(double v) => CountUp.fmt(v, v.abs() >= 100 ? 0 : 1);

  Widget _cartao(AlertModel a) {
    final ativo = !a.resolvido;
    final cor = ativo ? statusColor(a.severidade.name) : AppColors.statusNormal;
    final un = a.tipo.unidade;
    final quando = DateFormat('HH:mm').format(a.dataHora);

    final cartao = AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      onTap: a.salaId == null && a.salaCodigo == null
          ? null
          : () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => SalaDetailScreen(salaId: a.salaId ?? a.salaCodigo!))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: ativo
                  ? LinearGradient(colors: [cor, Color.lerp(cor, Colors.white, .25)!])
                  : null,
              color: ativo ? null : cor.withOpacity(.12),
            ),
            alignment: Alignment.center,
            child: ativo
                ? LiveSensorIcon(tipo: a.tipo.name, color: Colors.white, size: 28)
                : Icon(Icons.check_rounded, color: cor, size: 24),
          ),
          if (ativo && !a.lido)
            Positioned(right: -6, top: -6, child: PulseDot(color: cor, size: 8)),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(a.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: a.lido ? FontWeight.w600 : FontWeight.w800, fontSize: 15)),
              ),
              Text(quando, style: TextStyle(color: mutedText(context), fontSize: 12)),
            ]),
            const SizedBox(height: 3),
            Text([a.salaNome, a.sensorNome].whereType<String>().join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: mutedText(context), fontSize: 12.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _pilula(
                '${_fmt(a.valorMedido)} $un ${a.acima ? '>' : '<'} ${_fmt(a.limite)}',
                cor,
                forte: ativo,
              ),
              _pilula(
                ativo
                    ? (a.severidade == SensorStatus.critico ? 'Crítico' : 'Atenção')
                    : (a.resolvidoAutomaticamente ? 'Normalizado ⚡' : 'Resolvido'),
                cor,
              ),
              if (ativo && a.sensorValorAtual != null)
                Text('agora ${_fmt(a.sensorValorAtual!)} $un',
                    style: TextStyle(color: mutedText(context), fontSize: 11.5, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ]),
    );

    if (!ativo) return cartao;
    return Dismissible(
      key: ValueKey('al-${a.id}-${a.lido}'),
      direction: _podeResolver ? DismissDirection.horizontal : DismissDirection.startToEnd,
      background: _fundoArraste(Alignment.centerLeft, AppColors.accent, Icons.mark_email_read_rounded, 'Lido'),
      secondaryBackground:
          _fundoArraste(Alignment.centerRight, AppColors.statusNormal, Icons.task_alt_rounded, 'Resolver'),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          if (!a.lido) _lido(a);
          return false; // o cartão continua, só muda para lido
        }
        _resolver(a);
        return _filtro == _Filtro.ativos || _filtro == _Filtro.criticos;
      },
      child: cartao,
    );
  }

  Widget _pilula(String texto, Color cor, {bool forte = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: cor.withOpacity(forte ? .14 : .08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(texto, style: TextStyle(color: cor, fontSize: 11.5, fontWeight: FontWeight.w800)),
      );

  Widget _fundoArraste(Alignment lado, Color cor, IconData icon, String texto) => Container(
        alignment: lado,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      );
}

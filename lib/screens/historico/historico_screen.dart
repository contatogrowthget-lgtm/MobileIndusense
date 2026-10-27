import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/reading_model.dart';
import '../../models/sensor_model.dart';
import '../../services/sensor_service.dart';
import '../../widgets/anim.dart';
import '../../widgets/live_sensor_icon.dart';
import '../../widgets/settings_ui.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/ui.dart';

enum _Periodo { horas24, dias7, dias30 }

extension on _Periodo {
  Duration get duracao => switch (this) {
        _Periodo.horas24 => const Duration(hours: 24),
        _Periodo.dias7 => const Duration(days: 7),
        _Periodo.dias30 => const Duration(days: 30),
      };
}

/// Cores das linhas quando há mais de um sensor do mesmo tipo.
const _paleta = [
  Color(0xFF1E6BFF),
  Color(0xFF14C8E6),
  Color(0xFF8B5CF6),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFFEF4444),
];

/// Histórico: escolhe o período; em "Tudo" mostra um cartão por grandeza com
/// mini-gráfico; tocando num deles abre o gráfico grande (uma linha por sensor).
class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final _service = SensorService();

  List<ReadingModel>? _leituras;
  bool _carregando = true;
  String? _erro;
  SensorType? _tipo;
  _Periodo _periodo = _Periodo.horas24;
  bool _subir = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = _leituras == null;
      _erro = null;
    });
    try {
      final l = await _service.getReadings(inicio: DateTime.now().subtract(_periodo.duracao));
      if (!mounted) return;
      setState(() {
        _leituras = l..sort((a, b) => a.dataHora.compareTo(b.dataHora));
        _carregando = false;
        _subir = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _subir = true);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar o histórico.';
        _carregando = false;
      });
    }
  }

  void _escolherTipo(SensorType? t) {
    HapticFeedback.selectionClick();
    setState(() {
      _tipo = t;
      _subir = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _subir = true);
    });
  }

  static String _fmt(double v) => CountUp.fmt(v, v.abs() >= 100 ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _carregar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
            children: [
              TelaTitulo(
                titulo: 'Histórico',
                subtitulo: 'Leituras enviadas pelos ESP32',
                acao: _tipo == null
                    ? null
                    : TextButton.icon(
                        onPressed: () => _escolherTipo(null),
                        icon: const Icon(Icons.grid_view_rounded, size: 18),
                        label: const Text('Tudo'),
                      ),
              ),
              SegmentedPicker<_Periodo>(
                compacto: true,
                value: _periodo,
                onChanged: (p) {
                  setState(() => _periodo = p);
                  _carregar();
                },
                options: const [
                  (_Periodo.horas24, Icons.schedule_rounded, '24 h'),
                  (_Periodo.dias7, Icons.date_range_rounded, '7 dias'),
                  (_Periodo.dias30, Icons.calendar_month_rounded, '30 dias'),
                ],
              ),
              const SizedBox(height: 14),
              _chipsTipo(),
              const SizedBox(height: 16),
              ..._corpo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipsTipo() {
    Widget chip(SensorType? t, String texto, IconData icon) {
      final sel = _tipo == t;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => _escolherTipo(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: sel ? AppGradients.hero : null,
              color: sel ? null : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: sel ? null : Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              t == null
                  ? Icon(icon, size: 16, color: sel ? Colors.white : AppColors.accent)
                  : LiveSensorIcon(tipo: t.name, size: 16, color: sel ? Colors.white : AppColors.accent, animar: sel),
              const SizedBox(width: 6),
              Text(texto,
                  style: TextStyle(
                      color: sel ? Colors.white : mutedText(context), fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(children: [
        chip(null, 'Tudo', Icons.grid_view_rounded),
        for (final t in SensorType.values) chip(t, t.label, sensorIcon(t.name)),
      ]),
    );
  }

  List<Widget> _corpo() {
    if (_carregando) {
      return [
        for (var i = 0; i < 3; i++)
          const Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 150, radius: 26)),
      ];
    }
    if (_erro != null) return [AppErrorWidget(mensagem: _erro!, onRetry: _carregar)];

    final todas = _leituras ?? [];
    if (todas.isEmpty) {
      return const [
        SizedBox(height: 30),
        EmptyStateWidget(
          icon: Icons.show_chart_rounded,
          titulo: 'Sem leituras no período',
          mensagem: 'Ligue o ESP32 ou escolha um período maior.',
        ),
      ];
    }

    if (_tipo == null) {
      final tipos = SensorType.values.where((t) => todas.any((l) => l.tipo == t)).toList();
      return [
        for (var i = 0; i < tipos.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FadeSlideIn(index: i, child: _cartaoTipo(tipos[i], todas.where((l) => l.tipo == tipos[i]).toList())),
          ),
      ];
    }

    final doTipo = todas.where((l) => l.tipo == _tipo).toList();
    if (doTipo.isEmpty) {
      return const [
        SizedBox(height: 30),
        EmptyStateWidget(
          icon: Icons.sensors_off_rounded,
          titulo: 'Nenhuma leitura deste tipo',
          mensagem: 'Nenhum sensor deste tipo enviou dados no período.',
        ),
      ];
    }
    final vals = doTipo.map((l) => l.valor).toList();
    final un = _tipo!.unidade;
    return [
      FadeSlideIn(child: _graficoGrande(doTipo)),
      const SizedBox(height: 12),
      FadeSlideIn(
        index: 1,
        child: Row(children: [
          _stat('Menor', vals.reduce((a, b) => a < b ? a : b), un, const Color(0xFF0EA5E9)),
          const SizedBox(width: 10),
          _stat('Média', vals.reduce((a, b) => a + b) / vals.length, un, AppColors.accent),
          const SizedBox(width: 10),
          _stat('Maior', vals.reduce((a, b) => a > b ? a : b), un, AppColors.statusAtencao),
        ]),
      ),
      const SizedBox(height: 22),
      Row(children: [
        const Text('Registros', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const Spacer(),
        Text('${doTipo.length}', style: TextStyle(color: mutedText(context), fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 10),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          for (final r in doTipo.reversed.take(60))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: statusColor(r.status.value), shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.sensorNome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text(DateFormat("dd/MM 'às' HH:mm").format(r.dataHora.toLocal()),
                        style: TextStyle(color: mutedText(context), fontSize: 11.5)),
                  ]),
                ),
                Text('${_fmt(r.valor)} $un', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ]),
            ),
        ]),
      ),
    ];
  }

  Widget _stat(String rotulo, double v, String un, Color cor) => Expanded(
        child: AppCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rotulo, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                CountUp(
                    value: v,
                    decimals: v.abs() >= 100 ? 0 : 1,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.8)),
                const SizedBox(width: 3),
                Text(un, style: TextStyle(color: mutedText(context), fontSize: 11.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      );

  // ------------------------------------------------------------ cartão por grandeza
  Widget _cartaoTipo(SensorType t, List<ReadingModel> l) {
    final vals = l.map((x) => x.valor).toList();
    final ultimo = l.last;
    final media = vals.reduce((a, b) => a + b) / vals.length;
    final minimo = vals.reduce((a, b) => a < b ? a : b);
    final maximo = vals.reduce((a, b) => a > b ? a : b);
    final cor = statusColor(ultimo.status.value);
    // mini-gráfico com no máx. 60 pontos
    final passo = (l.length / 60).ceil().clamp(1, 1 << 30);
    final pontos = <FlSpot>[
      for (var i = 0; i < l.length; i += passo) FlSpot(i.toDouble(), _subir ? l[i].valor : minimo),
    ];

    return AppCard(
      radius: 26,
      onTap: () => _escolherTipo(t),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          LiveSensorBadge(tipo: t.name, size: 40, gradient: AppGradients.hero, anelColor: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              Text('${l.length} leituras · média ${_fmt(media)} ${t.unidade}',
                  style: TextStyle(color: mutedText(context), fontSize: 12)),
            ]),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            CountUp(
              value: ultimo.valor,
              decimals: ultimo.valor.abs() >= 100 ? 0 : 1,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -1, color: cor),
            ),
            const SizedBox(width: 2),
            Text(t.unidade, style: TextStyle(color: mutedText(context), fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 70,
          child: LineChart(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            LineChartData(
              minY: minimo - (maximo - minimo).abs() * .15 - .5,
              maxY: maximo + (maximo - minimo).abs() * .15 + .5,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: pontos,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  gradient: const LinearGradient(colors: [AppColors.accent, AppColors.cyan]),
                  barWidth: 2.6,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.accent.withOpacity(.22), AppColors.accent.withOpacity(0)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(children: [
          Text('mín ${_fmt(minimo)}', style: TextStyle(color: mutedText(context), fontSize: 11)),
          const Spacer(),
          Text('Ver gráfico', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w800)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.accent, size: 18),
          const Spacer(),
          Text('máx ${_fmt(maximo)}', style: TextStyle(color: mutedText(context), fontSize: 11)),
        ]),
      ]),
    );
  }

  // ------------------------------------------------------------ gráfico grande
  Widget _graficoGrande(List<ReadingModel> l) {
    final t0 = l.first.dataHora;
    double x(DateTime d) => d.difference(t0).inSeconds / 60.0;
    final spanX = x(l.last.dataHora).clamp(1.0, double.infinity);
    final vals = l.map((r) => r.valor);
    final minimo = vals.reduce((a, b) => a < b ? a : b);
    final maximo = vals.reduce((a, b) => a > b ? a : b);
    final folga = ((maximo - minimo).abs() * .15).clamp(.5, double.infinity);
    final minY = minimo - folga;
    final maxY = maximo + folga;
    final muted = mutedText(context);
    final formatoX = _periodo == _Periodo.horas24 ? DateFormat('HH:mm') : DateFormat('dd/MM');

    // uma linha por sensor
    final porSensor = <String, List<ReadingModel>>{};
    for (final r in l) {
      porSensor.putIfAbsent(r.sensorId, () => []).add(r);
    }
    final sensores = porSensor.entries.toList();

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 10),
      child: Column(children: [
        if (sensores.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 0, 10),
            child: Wrap(spacing: 12, runSpacing: 6, children: [
              for (var i = 0; i < sensores.length; i++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: _paleta[i % _paleta.length], shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(sensores[i].value.first.sensorNome,
                      style: TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ]),
            ]),
          ),
        SizedBox(
          height: 250,
          child: LineChart(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            LineChartData(
              minY: minY,
              maxY: maxY,
              minX: 0,
              maxX: spanX,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: muted.withOpacity(.15), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(v.toStringAsFixed(0),
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: spanX / 4,
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(formatoX.format(t0.add(Duration(seconds: (v * 60).round())).toLocal()),
                          style: TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.primary,
                  tooltipRoundedRadius: 12,
                  getTooltipItems: (spots) => spots
                      .map((sp) => LineTooltipItem(
                            '${_fmt(sp.y)} ${_tipo!.unidade}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                          ))
                      .toList(),
                ),
              ),
              lineBarsData: [
                for (var i = 0; i < sensores.length; i++)
                  LineChartBarData(
                    spots: [for (final r in sensores[i].value) FlSpot(x(r.dataHora), _subir ? r.valor : minY)],
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: sensores.length > 1 ? _paleta[i % _paleta.length] : null,
                    gradient:
                        sensores.length > 1 ? null : const LinearGradient(colors: [AppColors.accent, AppColors.cyan]),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: sensores.length == 1,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.accent.withOpacity(.25), AppColors.accent.withOpacity(0)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

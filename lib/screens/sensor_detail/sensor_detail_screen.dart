import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/reading_model.dart';
import '../../models/sensor_model.dart';
import '../../services/api_client.dart';
import '../../services/sensor_service.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/anim.dart';
import '../../widgets/live_sensor_icon.dart';
import '../../widgets/ui.dart';

class SensorDetailScreen extends StatefulWidget {
  final String sensorId;
  const SensorDetailScreen({super.key, required this.sensorId});

  @override
  State<SensorDetailScreen> createState() => _SensorDetailScreenState();
}

class _SensorDetailScreenState extends State<SensorDetailScreen> {
  final SensorService _sensorService = SensorService();

  SensorModel? _sensor;
  List<ReadingModel>? _leituras;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      // Dispara as duas chamadas ao NestJS em paralelo
      final resultados = await Future.wait([
        _sensorService.getSensorById(widget.sensorId),
        _sensorService.getReadings(sensorId: widget.sensorId),
      ]);

      if (!mounted) return;

      setState(() {
        _sensor = resultados[0] as SensorModel;
        _leituras = resultados[1] as List<ReadingModel>;
        _carregando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.message;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar os dados do sensor.';
        _carregando = false;
      });
    }
  }

  bool _grafico = false; // liga depois do 1º quadro para o gráfico "subir"

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_sensor?.nome ?? 'Sensor', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      ),
      body: _buildBody(),
    );
  }

  static String _fmt(double v) => CountUp.fmt(v, v.abs() >= 100 ? 0 : 1);

  Widget _buildBody() {
    if (_carregando) {
      return const SkeletonList(
        itens: 3,
        topo: Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Center(child: Skeleton(width: 220, height: 220, radius: 110)),
        ),
      );
    }
    if (_erro != null) return AppErrorWidget(mensagem: _erro!, onRetry: _carregar);

    final sensor = _sensor!;
    final leituras = List<ReadingModel>.of(_leituras ?? const <ReadingModel>[])..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    final cor = sensor.online ? statusColor(sensor.status.value) : AppColors.statusOffline;
    final un = sensor.tipo.unidade;
    final faixa = (sensor.limiteMax - sensor.limiteMin).abs() < .001 ? 1.0 : sensor.limiteMax - sensor.limiteMin;
    final frac = sensor.online ? ((sensor.valorAtual - sensor.limiteMin) / faixa).clamp(0.0, 1.0) : 0.0;
    final rotulo = !sensor.online
        ? 'Sem sinal'
        : switch (sensor.status) {
            SensorStatus.critico => 'Nível crítico',
            SensorStatus.atencao => 'Atenção',
            SensorStatus.offline => 'Sem sinal',
            SensorStatus.normal => 'Dentro do limite',
          };

    if (!_grafico && leituras.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _grafico = true);
      });
    }

    final valores = leituras.map((l) => l.valor).toList();
    final minimo = valores.isEmpty ? null : valores.reduce((a, b) => a < b ? a : b);
    final maximo = valores.isEmpty ? null : valores.reduce((a, b) => a > b ? a : b);
    final media = valores.isEmpty ? null : valores.reduce((a, b) => a + b) / valores.length;

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          // ---------- medidor
          FadeSlideIn(
            child: AppCard(
              radius: 32,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: Text(sensor.localizacao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: mutedText(context), fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  if (sensor.online) PulseDot(color: cor, size: 7),
                  Text(sensor.online ? 'ao vivo' : 'offline',
                      style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 8),
                ArcGauge(
                  fraction: frac,
                  color: cor,
                  size: 220,
                  stroke: 16,
                  center: Column(mainAxisSize: MainAxisSize.min, children: [
                    LiveSensorIcon(tipo: sensor.tipo.name, color: cor, size: 34, animar: sensor.online),
                    const SizedBox(height: 4),
                    if (sensor.qualidadeTexto != null) ...[
                      Text('Qualidade ${sensor.qualidadeTexto!.toLowerCase()}',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.8, color: cor)),
                      const SizedBox(height: 2),
                      Text('índice ${_fmt(sensor.valorAtual)} $un',
                          style: TextStyle(color: mutedText(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ] else
                    Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic, children: [
                      sensor.online
                          ? CountUp(
                              value: sensor.valorAtual,
                              decimals: sensor.valorAtual.abs() >= 100 ? 0 : 1,
                              style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w800, letterSpacing: -2, height: 1),
                            )
                          : const Text('—', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      Text(un, style: TextStyle(color: mutedText(context), fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: cor.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                      child: Text(rotulo, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Row(children: [
                    Text('mín ${_fmt(sensor.limiteMin)}', style: TextStyle(color: mutedText(context), fontSize: 12)),
                    const Spacer(),
                    Text('máx ${_fmt(sensor.limiteMax)}', style: TextStyle(color: mutedText(context), fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 8),
                Text('Última leitura às ${DateFormat('HH:mm:ss').format(sensor.ultimaLeitura.toLocal())}',
                    style: TextStyle(color: mutedText(context), fontSize: 12)),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          // ---------- mínimo / média / máximo
          if (media != null)
            FadeSlideIn(
              index: 1,
              child: Row(children: [
                _stat('Menor', minimo!, un, Icons.south_rounded, const Color(0xFF0EA5E9)),
                const SizedBox(width: 10),
                _stat('Média', media, un, Icons.horizontal_rule_rounded, AppColors.accent),
                const SizedBox(width: 10),
                _stat('Maior', maximo!, un, Icons.north_rounded, AppColors.statusAtencao),
              ]),
            ),
          const SizedBox(height: 26),
          Row(children: [
            const Text('Últimas 24 horas', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.4)),
            const Spacer(),
            Text('${leituras.length} leituras', style: TextStyle(color: mutedText(context), fontSize: 12.5)),
          ]),
          const SizedBox(height: 12),
          if (leituras.isEmpty)
            const EmptyStateWidget(
              icon: Icons.show_chart_rounded,
              titulo: 'Sem dados no histórico',
              mensagem: 'Aguardando o ESP32 enviar as leituras.',
            )
          else
            FadeSlideIn(index: 2, child: _grafico24h(sensor, leituras, cor)),
          if (leituras.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text('Leituras recentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                for (final l in leituras.reversed.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: statusColor(l.status.value), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Text(DateFormat('dd/MM HH:mm').format(l.dataHora.toLocal()),
                          style: TextStyle(color: mutedText(context), fontSize: 13)),
                      const Spacer(),
                      Text('${_fmt(l.valor)} $un', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ]),
                  ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String rotulo, double v, String un, IconData icon, Color cor) => Expanded(
        child: AppCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: cor, size: 16),
              const SizedBox(width: 4),
              Text(rotulo, style: TextStyle(color: mutedText(context), fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                CountUp(
                  value: v,
                  decimals: v.abs() >= 100 ? 0 : 1,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.8),
                ),
                const SizedBox(width: 3),
                Text(un, style: TextStyle(color: mutedText(context), fontSize: 11.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      );

  Widget _grafico24h(SensorModel sensor, List<ReadingModel> leituras, Color cor) {
    final t0 = leituras.first.dataHora;
    double x(DateTime d) => d.difference(t0).inSeconds / 60.0;
    final vals = leituras.map((l) => l.valor);
    var minY = [sensor.limiteMin, ...vals].reduce((a, b) => a < b ? a : b);
    var maxY = [sensor.limiteMax, ...vals].reduce((a, b) => a > b ? a : b);
    final folga = ((maxY - minY).abs() * .12).clamp(1.0, double.infinity);
    minY -= folga;
    maxY += folga;
    final spanX = x(leituras.last.dataHora).clamp(1.0, double.infinity);
    final muted = mutedText(context);

    HorizontalLine limite(double y, String nome) => HorizontalLine(
          y: y,
          color: AppColors.statusCritico.withOpacity(.55),
          strokeWidth: 1.4,
          dashArray: [6, 5],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 4, bottom: 2),
            style: const TextStyle(color: AppColors.statusCritico, fontSize: 10, fontWeight: FontWeight.w800),
            labelResolver: (_) => '$nome ${_fmt(y)}',
          ),
        );

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(8, 18, 16, 8),
      child: SizedBox(
        height: 240,
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
            extraLinesData: ExtraLinesData(horizontalLines: [
              limite(sensor.limiteMax, 'máx'),
              if (sensor.limiteMin > minY) limite(sensor.limiteMin, 'mín'),
            ]),
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
                    child: Text(DateFormat('HH:mm').format(t0.add(Duration(seconds: (v * 60).round())).toLocal()),
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
                          '${_fmt(sp.y)} ${sensor.tipo.unidade}\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          children: [
                            TextSpan(
                              text: DateFormat('HH:mm').format(t0.add(Duration(seconds: (sp.x * 60).round())).toLocal()),
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ))
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final l in leituras) FlSpot(x(l.dataHora), _grafico ? l.valor : minY),
                ],
                isCurved: true,
                preventCurveOverShooting: true,
                gradient: LinearGradient(colors: [AppColors.accent, cor == AppColors.statusNormal ? AppColors.cyan : cor]),
                barWidth: 3.2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.accent.withOpacity(.28), AppColors.accent.withOpacity(0)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

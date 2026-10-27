import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/sala_model.dart';
import '../models/sensor_model.dart';
import 'live_sensor_icon.dart';
import 'status_indicator.dart';
import 'ui.dart';

/// Cartão de sala: status geral, faixa colorida e as leituras atuais de cada sensor.
class SalaCard extends StatelessWidget {
  final SalaComSensores salaComSensores;
  final VoidCallback? onTap;

  const SalaCard({super.key, required this.salaComSensores, this.onTap});

  @override
  Widget build(BuildContext context) {
    final sala = salaComSensores.sala;
    final status = salaComSensores.statusGeral;
    final cor = statusColor(status.name);
    final sensores = salaComSensores.sensores;
    final alertas = salaComSensores.totalAlertas;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, color: cor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cor.withOpacity(0.22), cor.withOpacity(0.08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.factory_rounded, color: cor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(sala.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (sala.setor.isNotEmpty) sala.setor,
                          '${sensores.length} sensor${sensores.length == 1 ? '' : 'es'}',
                          if (alertas > 0) '$alertas alerta${alertas == 1 ? '' : 's'}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: mutedText(context), fontSize: 12.5),
                      ),
                    ]),
                  ),
                  StatusIndicator(status: status, compact: true),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                ]),
                if (sensores.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sensores.take(6).map((s) => _Leitura(sensor: s)).toList(),
                  ),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Leitura extends StatelessWidget {
  final SensorModel sensor;
  const _Leitura({required this.sensor});

  @override
  Widget build(BuildContext context) {
    final cor = sensor.online ? statusColor(sensor.status.name) : AppColors.statusOffline;
    final dark = isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sensor.status == SensorStatus.normal || !sensor.online
            ? (dark ? AppColors.darkBorder : const Color(0xFFE2E8F0))
            : cor.withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        LiveSensorIcon(tipo: sensor.tipo.name, size: 15, color: cor, animar: sensor.online),
        const SizedBox(width: 6),
        Text(
          sensor.online ? '${_fmt(sensor.valorAtual)} ${sensor.tipo.unidade}' : 'offline',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: sensor.online ? null : cor),
        ),
      ]),
    );
  }

  static String _fmt(double v) => v.abs() >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

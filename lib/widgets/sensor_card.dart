import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../models/sensor_model.dart';
import 'live_sensor_icon.dart';
import 'status_indicator.dart';
import 'ui.dart';

/// Cartão de sensor: valor grande, posição dentro dos limites e status.
class SensorCard extends StatelessWidget {
  final SensorModel sensor;
  final VoidCallback? onTap;

  const SensorCard({super.key, required this.sensor, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cor = sensor.online ? statusColor(sensor.status.name) : AppColors.statusOffline;
    final faixa = sensor.limiteMax - sensor.limiteMin;
    final pos = faixa <= 0 ? null : ((sensor.valorAtual - sensor.limiteMin) / faixa).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: cor.withOpacity(0.13), borderRadius: BorderRadius.circular(11)),
            child: LiveSensorIcon(tipo: sensor.tipo.name, size: 17, color: cor, animar: sensor.online),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sensor.tipo.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text(sensor.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: mutedText(context), fontSize: 11)),
            ]),
          ),
        ]),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: sensor.online ? sensor.valorAtual.toStringAsFixed(1) : '—',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1, color: sensor.online ? null : cor),
              ),
              if (sensor.online)
                TextSpan(
                  text: ' ${sensor.tipo.unidade}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: mutedText(context)),
                ),
            ]),
          ),
        ),
        if (pos != null && sensor.online)
          LayoutBuilder(builder: (context, c) {
            return SizedBox(
              height: 14,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(colors: [
                      AppColors.statusNormal,
                      AppColors.statusAtencao,
                      AppColors.statusCritico,
                    ]),
                  ),
                ),
                Positioned(
                  left: (c.maxWidth - 12) * pos,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: cor, width: 3),
                    ),
                  ),
                ),
              ]),
            );
          }),
        Row(children: [
          StatusIndicator(status: sensor.status, compact: true),
          const Spacer(),
          Text(DateFormat('HH:mm').format(sensor.ultimaLeitura),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

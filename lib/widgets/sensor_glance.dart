import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/sensor_model.dart';
import 'live_sensor_icon.dart';
import 'ui.dart';

/// Cartão de leitura "agora" (carrossel do Início): valor grande e uma régua
/// mostrando onde a leitura está entre o mínimo e o máximo permitidos.
class SensorGlanceCard extends StatelessWidget {
  final SensorModel sensor;
  final String? salaNome;
  final VoidCallback? onTap;

  const SensorGlanceCard({super.key, required this.sensor, this.salaNome, this.onTap});

  static String _fmt(double v) => v.abs() >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final s = sensor;
    final cor = s.online ? statusColor(s.status.name) : AppColors.statusOffline;
    final normal = s.online && s.status == SensorStatus.normal;
    final faixa = (s.limiteMax - s.limiteMin).abs() < 0.001 ? 1.0 : (s.limiteMax - s.limiteMin);
    final pos = ((s.valorAtual - s.limiteMin) / faixa).clamp(0.0, 1.0);
    final rotuloStatus = !s.online
        ? 'offline'
        : switch (s.status) {
            SensorStatus.critico => 'crítico',
            SensorStatus.atencao => 'atenção',
            SensorStatus.offline => 'offline',
            SensorStatus.normal => 'normal',
          };

    return AppCard(
      radius: 26,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          LiveSensorBadge(
            tipo: s.tipo.name,
            size: 40,
            gradient: normal ? AppGradients.hero : null,
            fundo: normal ? null : cor.withOpacity(.14),
            iconColor: normal ? Colors.white : cor,
            anelColor: normal ? AppColors.accent : cor,
            aoVivo: s.online,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: cor.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
            child: Text(rotuloStatus, style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ]),
        const Spacer(),
        if (s.qualidadeTexto != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(s.qualidadeTexto!,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1, color: cor)),
          )
        else
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: s.online ? s.valorAtual : 0),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text(s.online ? _fmt(v) : '—',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(s.tipo.unidade, style: TextStyle(color: mutedText(context), fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        Text(s.tipo.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        if (salaNome != null)
          Text(salaNome!,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mutedText(context), fontSize: 11.5)),
        const SizedBox(height: 12),
        // régua mínimo → máximo
        LayoutBuilder(builder: (context, c) {
          return SizedBox(
            height: 12,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(colors: [
                    AppColors.statusNormal.withOpacity(.35),
                    AppColors.statusNormal.withOpacity(.35),
                    AppColors.statusAtencao.withOpacity(.45),
                  ], stops: const [0, .8, 1]),
                ),
              ),
              if (s.online)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pos),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, p, __) => Positioned(
                    left: (c.maxWidth - 12) * p,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: cor, width: 3),
                        boxShadow: [BoxShadow(color: cor.withOpacity(.4), blurRadius: 6)],
                      ),
                    ),
                  ),
                ),
            ]),
          );
        }),
        const SizedBox(height: 4),
        Row(children: [
          Text(_fmt(s.limiteMin), style: TextStyle(color: mutedText(context), fontSize: 10.5)),
          const Spacer(),
          Text(_fmt(s.limiteMax), style: TextStyle(color: mutedText(context), fontSize: 10.5)),
        ]),
      ]),
    );
  }
}

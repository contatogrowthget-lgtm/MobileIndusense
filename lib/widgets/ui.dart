import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Kit visual do InduSense: cartões, títulos de seção, indicador "ao vivo"
/// e animação de entrada. Use estes componentes para manter tudo coerente.

bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

Color mutedText(BuildContext context) => isDark(context) ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

/// Cartão padrão: cantos de 24, sombra suave no claro e borda fina no escuro.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.radius = 24,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Theme.of(context).cardColor) : null,
        gradient: gradient,
        borderRadius: shape,
        border: dark && gradient == null ? Border.all(color: AppColors.darkBorder) : null,
        boxShadow: dark
            ? null
            : [
                BoxShadow(color: const Color(0xFF1E4FB8).withOpacity(0.07), blurRadius: 26, offset: const Offset(0, 10)),
              ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      ),
    );
  }
}

/// Título de seção com ação opcional à direita ("Ver todos").
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.subtitle, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(color: mutedText(context), fontSize: 12.5)),
            ],
          ]),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(action!, style: const TextStyle(fontSize: 13)),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ]),
          ),
      ]),
    );
  }
}

/// Bolinha pulsando (indicador de "ao vivo").
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulseDot({super.key, this.color = AppColors.statusNormal, this.size = 8});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          Container(
            width: s + s * 1.4 * _c.value,
            height: s + s * 1.4 * _c.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withOpacity(0.35 * (1 - _c.value)),
            ),
          ),
          Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
        ]),
      ),
    );
  }
}

/// Entrada suave (sobe e aparece). [index] escalona a animação em listas.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + (index.clamp(0, 8) * 70)),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
      ),
    );
  }
}

/// Anel de progresso com o número no meio (conformidade, saúde dos sensores).
class ScoreRing extends StatelessWidget {
  final int? value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? track;
  final TextStyle? style;
  final String? caption;

  const ScoreRing({
    super.key,
    required this.value,
    this.size = 72,
    this.stroke = 7,
    this.color,
    this.track,
    this.style,
    this.caption,
  });

  static Color colorFor(int? v) => v == null
      ? AppColors.statusOffline
      : v >= 95
          ? AppColors.statusNormal
          : v >= 80
              ? AppColors.statusAtencao
              : AppColors.statusCritico;

  @override
  Widget build(BuildContext context) {
    final c = color ?? colorFor(value);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (value ?? 0) / 100),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: stroke,
              color: c,
              backgroundColor: track ?? c.withOpacity(0.14),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(value == null ? '—' : '$value%',
                style: style ?? TextStyle(fontSize: size * 0.24, fontWeight: FontWeight.w800)),
            if (caption != null)
              Text(caption!, style: TextStyle(fontSize: size * 0.11, color: (style?.color ?? mutedText(context)).withOpacity(.8))),
          ]),
        ]),
      ),
    );
  }
}

/// Cartão pequeno de indicador (KPI).
class MetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final String? hint;
  final VoidCallback? onTap;

  const MetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          if (hint != null)
            Flexible(
              child: Text(hint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        ),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mutedText(context), fontSize: 12.5)),
      ]),
    );
  }
}

/// Ícone por tipo de sensor (mantém o mesmo em todas as telas).
IconData sensorIcon(String tipo) {
  switch (tipo) {
    case 'temperatura':
      return Icons.thermostat_rounded;
    case 'umidade':
      return Icons.water_drop_rounded;
    case 'qualidadeAr':
      return Icons.air_rounded;
    default:
      return Icons.sensors_rounded;
  }
}

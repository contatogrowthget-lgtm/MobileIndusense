import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/sensor_model.dart';

String statusLabel(SensorStatus status) {
  switch (status) {
    case SensorStatus.normal:
      return 'Normal';
    case SensorStatus.atencao:
      return 'Atenção';
    case SensorStatus.critico:
      return 'Crítico';
    case SensorStatus.offline:
      return 'Offline';
  }
}

/// Pílula/Badge estruturado indicando o status de um sensor ou ambiente.
class StatusIndicator extends StatelessWidget {
  final SensorStatus status;
  final bool compact;

  const StatusIndicator({super.key, required this.status, this.compact = false});

  IconData _getStatusIcon(SensorStatus status) {
    switch (status) {
      case SensorStatus.normal:
        return Icons.check_circle_rounded;
      case SensorStatus.atencao:
        return Icons.error_rounded;
      case SensorStatus.critico:
        return Icons.warning_rounded;
      case SensorStatus.offline:
        return Icons.wifi_off_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status.value);
    final icon = _getStatusIcon(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 12 : 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            statusLabel(status).toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 10 : 11,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
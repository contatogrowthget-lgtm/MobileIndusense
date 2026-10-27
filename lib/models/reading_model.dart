import 'sensor_model.dart';

/// Um registro histórico de leitura de um sensor.
class ReadingModel {
  final String id;
  final String sensorId;
  final String sensorNome;
  final SensorType tipo;
  final double valor;
  final DateTime dataHora;
  final SensorStatus status;

  ReadingModel({
    required this.id,
    required this.sensorId,
    required this.sensorNome,
    required this.tipo,
    required this.valor,
    required this.dataHora,
    required this.status,
  });

  factory ReadingModel.fromJson(Map<String, dynamic> json) {
    // Resolve sensorId e sensorNome aceitando chave direta ou objeto aninhado do NestJS
    String resolvedSensorId = '';
    String resolvedSensorNome = '';

    if (json['sensorId'] != null) {
      resolvedSensorId = json['sensorId'].toString();
    } else if (json['sensor_id'] != null) {
      resolvedSensorId = json['sensor_id'].toString();
    } else if (json['sensor'] != null && json['sensor'] is Map) {
      resolvedSensorId = json['sensor']['id']?.toString() ?? '';
      resolvedSensorNome = json['sensor']['nome']?.toString() ?? '';
    }

    if (resolvedSensorNome.isEmpty) {
      resolvedSensorNome = json['sensorNome']?.toString() ?? json['sensor_nome']?.toString() ?? '';
    }

    // Resolve parsing de data aceitando dataHora, timestamp ou createdAt
    DateTime parsedDate;
    final rawDate = json['dataHora'] ?? json['timestamp'] ?? json['createdAt'];
    try {
      parsedDate = rawDate != null ? DateTime.parse(rawDate.toString()) : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return ReadingModel(
      id: json['id']?.toString() ?? '',
      sensorId: resolvedSensorId,
      sensorNome: resolvedSensorNome,
      tipo: SensorTypeX.fromString(json['tipo']?.toString() ?? 'temperatura'),
      valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
      dataHora: parsedDate,
      status: SensorStatusX.fromString(json['status']?.toString() ?? 'normal'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sensorId': sensorId,
        'sensorNome': sensorNome,
        'tipo': tipo.name,
        'valor': valor,
        'dataHora': dataHora.toIso8601String(),
        'status': status.value,
      };
}
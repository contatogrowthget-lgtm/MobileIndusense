/// Tipos de grandeza monitorados pelos sensores ESP32/IoT.
enum SensorType { temperatura, umidade, qualidadeAr, gas }

extension SensorTypeX on SensorType {
  String get label {
    switch (this) {
      case SensorType.temperatura:
        return 'Temperatura';
      case SensorType.umidade:
        return 'Umidade';
      case SensorType.qualidadeAr:
        return 'Qualidade do Ar';
      case SensorType.gas:
        return 'Gases';
    }
  }

  String get unidade {
    switch (this) {
      case SensorType.temperatura:
        return '°C';
      case SensorType.umidade:
        return '%';
      case SensorType.qualidadeAr:
        return 'IQA';
      case SensorType.gas:
        return 'ppm';
    }
  }

  static SensorType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'temperatura':
        return SensorType.temperatura;
      case 'umidade':
        return SensorType.umidade;
      case 'qualidade_ar':
      case 'qualidadear':
        return SensorType.qualidadeAr;
      case 'gas':
      case 'gases':
        return SensorType.gas;
      default:
        return SensorType.temperatura;
    }
  }
}

/// Status atual do sensor.
enum SensorStatus { normal, atencao, critico, offline }

extension SensorStatusX on SensorStatus {
  String get value => toString().split('.').last;

  static SensorStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'normal':
        return SensorStatus.normal;
      case 'atencao':
      case 'atenção':
        return SensorStatus.atencao;
      case 'critico':
      case 'crítico':
        return SensorStatus.critico;
      default:
        return SensorStatus.offline;
    }
  }
}

class SensorModel {
  final String id;
  final String nome;
  final String localizacao;
  final String salaId;
  final SensorType tipo;
  final SensorStatus status;
  final double valorAtual;
  final double limiteMin;
  final double limiteMax;
  final DateTime ultimaLeitura;
  final bool online;

  SensorModel({
    required this.id,
    required this.nome,
    required this.localizacao,
    required this.salaId,
    required this.tipo,
    required this.status,
    required this.valorAtual,
    required this.limiteMin,
    required this.limiteMax,
    required this.ultimaLeitura,
    required this.online,
  });

  factory SensorModel.fromJson(Map<String, dynamic> json) {
    // Resolve o salaId permitindo chave direta ou objeto aninhado vindo do NestJS
    String resolvedSalaId = '';
    if (json['salaId'] != null) {
      resolvedSalaId = json['salaId'].toString();
    } else if (json['sala_id'] != null) {
      resolvedSalaId = json['sala_id'].toString();
    } else if (json['sala'] != null && json['sala'] is Map) {
      resolvedSalaId = json['sala']['id']?.toString() ?? '';
    }

    // Resolve parsing de data seguro
    DateTime parsedDate;
    try {
      parsedDate = json['ultimaLeitura'] != null
          ? DateTime.parse(json['ultimaLeitura'].toString())
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return SensorModel(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      localizacao: json['localizacao']?.toString() ?? '',
      salaId: resolvedSalaId,
      tipo: SensorTypeX.fromString(json['tipo']?.toString() ?? 'temperatura'),
      status: SensorStatusX.fromString(json['status']?.toString() ?? 'offline'),
      valorAtual: (json['valorAtual'] as num?)?.toDouble() ?? 0.0,
      limiteMin: (json['limiteMin'] as num?)?.toDouble() ?? 0.0,
      limiteMax: (json['limiteMax'] as num?)?.toDouble() ?? 0.0,
      ultimaLeitura: parsedDate,
      online: json['online'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'localizacao': localizacao,
        'salaId': salaId,
        'tipo': tipo.name,
        'status': status.value,
        'valorAtual': valorAtual,
        'limiteMin': limiteMin,
        'limiteMax': limiteMax,
        'ultimaLeitura': ultimaLeitura.toIso8601String(),
        'online': online,
      };
}

/// Qualidade do ar em palavras: "Boa", "Moderada" ou "Ruim" (pelo status do sensor).
/// Para os outros tipos devolve null e as telas mostram o número.
extension QualidadeArX on SensorModel {
  String? get qualidadeTexto {
    if (tipo != SensorType.qualidadeAr) return null;
    if (!online) return null;
    switch (status) {
      case SensorStatus.normal:
        return 'Boa';
      case SensorStatus.atencao:
        return 'Moderada';
      case SensorStatus.critico:
        return 'Ruim';
      case SensorStatus.offline:
        return null;
    }
  }
}

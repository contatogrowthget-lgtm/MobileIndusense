import 'sensor_model.dart';

class AlertModel {
  final String id;
  final String sensorId;
  final String sensorNome;
  final SensorType tipo;
  final double valorMedido;
  final double limite;
  final DateTime dataHora;
  final bool lido;
  final SensorStatus severidade;

  // Campos extras da API (podem faltar em versões antigas)
  final String? salaId;
  final String? salaNome;
  final String? salaCodigo;
  final bool resolvido;
  final DateTime? resolvidoEm;
  final bool resolvidoAutomaticamente;
  final double? sensorValorAtual;

  AlertModel({
    required this.id,
    required this.sensorId,
    required this.sensorNome,
    required this.tipo,
    required this.valorMedido,
    required this.limite,
    required this.dataHora,
    required this.lido,
    required this.severidade,
    this.salaId,
    this.salaNome,
    this.salaCodigo,
    this.resolvido = false,
    this.resolvidoEm,
    this.resolvidoAutomaticamente = false,
    this.sensorValorAtual,
  });

  bool get acima => valorMedido > limite;

  /// "Temperatura elevada", "Umidade baixa", "Gases acima do limite"...
  String get titulo {
    switch (tipo) {
      case SensorType.temperatura:
        return acima ? 'Temperatura elevada' : 'Temperatura baixa';
      case SensorType.umidade:
        return acima ? 'Umidade elevada' : 'Umidade baixa';
      case SensorType.qualidadeAr:
        return acima ? 'Qualidade do ar ruim' : 'Qualidade do ar abaixo do esperado';
      case SensorType.gas:
        return acima ? 'Gases acima do limite' : 'Gases abaixo do esperado';
    }
  }

  /// Leitura atual do sensor (ou a do momento do alerta).
  double get valorAgora => sensorValorAtual ?? valorMedido;

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'].toString(),
      sensorId: json['sensorId'].toString(),
      sensorNome: json['sensorNome'] ?? '',
      tipo: SensorTypeX.fromString(json['tipo'] ?? 'temperatura'),
      valorMedido: (json['valorMedido'] as num).toDouble(),
      limite: (json['limite'] as num).toDouble(),
      dataHora: DateTime.parse(json['dataHora']).toLocal(),
      lido: json['lido'] ?? false,
      severidade: SensorStatusX.fromString(json['severidade'] ?? 'atencao'),
      salaId: json['salaId']?.toString(),
      salaNome: json['salaNome']?.toString(),
      salaCodigo: json['salaCodigo']?.toString(),
      resolvido: json['resolvido'] == true,
      resolvidoEm: json['resolvidoEm'] == null ? null : DateTime.tryParse(json['resolvidoEm'].toString())?.toLocal(),
      resolvidoAutomaticamente: json['resolvidoAutomaticamente'] == true,
      sensorValorAtual: (json['sensorValorAtual'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sensorId': sensorId,
        'sensorNome': sensorNome,
        'tipo': tipo.name,
        'valorMedido': valorMedido,
        'limite': limite,
        'dataHora': dataHora.toIso8601String(),
        'lido': lido,
        'severidade': severidade.value,
      };

  AlertModel copyWith({bool? lido, bool? resolvido}) {
    return AlertModel(
      id: id,
      sensorId: sensorId,
      sensorNome: sensorNome,
      tipo: tipo,
      valorMedido: valorMedido,
      limite: limite,
      dataHora: dataHora,
      lido: lido ?? this.lido,
      severidade: severidade,
      salaId: salaId,
      salaNome: salaNome,
      salaCodigo: salaCodigo,
      resolvido: resolvido ?? this.resolvido,
      resolvidoEm: (resolvido ?? false) ? DateTime.now() : resolvidoEm,
      resolvidoAutomaticamente: resolvidoAutomaticamente,
      sensorValorAtual: sensorValorAtual,
    );
  }
}

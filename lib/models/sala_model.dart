import 'sensor_model.dart';

/// Representa uma sala/setor da fábrica (ex: "Galpão 1 · Linha de
/// Produção A"). Cada sala tem uma tag NFC fixada na porta; ao
/// aproximar o celular, o app abre direto os sensores dessa sala.
class SalaModel {
  final String id;

  /// Código legível, ex.: IND-001 (vazio em dados antigos).
  final String codigo;
  final String nome;
  final String setor;
  final String nfcTagId;

  SalaModel({
    required this.id,
    this.codigo = '',
    required this.nome,
    required this.setor,
    required this.nfcTagId,
  });

  factory SalaModel.fromJson(Map<String, dynamic> json) {
    return SalaModel(
      id: json['id']?.toString() ?? '',
      codigo: json['codigo']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      setor: json['setor']?.toString() ?? '',
      nfcTagId: json['nfcTagId']?.toString() ?? json['nfc_tag_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'codigo': codigo,
        'nome': nome,
        'setor': setor,
        'nfcTagId': nfcTagId,
      };
}

/// Agrega uma sala com os sensores nela instalados e o pior status
/// entre eles (usado para exibir o "estado geral" da sala no dashboard).
class SalaComSensores {
  final SalaModel sala;
  final List<SensorModel> sensores;

  SalaComSensores({required this.sala, required this.sensores});

  /// Prioridade: crítico > atenção > offline > normal.
  SensorStatus get statusGeral {
    if (sensores.isEmpty) return SensorStatus.offline;
    if (sensores.any((s) => s.status == SensorStatus.critico)) {
      return SensorStatus.critico;
    }
    if (sensores.any((s) => s.status == SensorStatus.atencao)) {
      return SensorStatus.atencao;
    }
    if (sensores.every((s) => !s.online)) return SensorStatus.offline;
    return SensorStatus.normal;
  }

  int get totalAlertas => sensores
      .where((s) =>
          s.status == SensorStatus.critico || s.status == SensorStatus.atencao)
      .length;
}
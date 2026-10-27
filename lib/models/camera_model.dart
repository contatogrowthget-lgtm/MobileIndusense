import '../core/config/server_config.dart';

/// Rótulos dos EPIs enviados pelo sistema de câmera.
const Map<String, String> kEpiLabels = {
  'capacete': 'Capacete',
  'oculos': 'Óculos',
  'colete': 'Colete',
  'luvas': 'Luvas',
  'botas': 'Botas',
  'mascara': 'Máscara',
  'protetor_auricular': 'Protetor auricular',
};

String epiLabel(String key) => kEpiLabels[key] ?? key;

/// "capacete e luvas" / "capacete, óculos e luvas"
String juntarEpis(List<String> itens) {
  final nomes = itens.map((k) => epiLabel(k).toLowerCase()).toList();
  if (nomes.length <= 1) return nomes.join();
  return '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last}';
}

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class CameraModel {
  final String id;
  final String? codigo;
  final String salaId;
  final String? salaNome;
  final String nome;
  final bool online;
  final int pessoas;
  final int epiConformidade;
  final String? ocorrencia;
  final String? streamUrl;
  final DateTime? ultimoContato;
  final String? ultimoContatoRelativo;

  CameraModel({
    required this.id,
    required this.codigo,
    required this.salaId,
    required this.salaNome,
    required this.nome,
    required this.online,
    required this.pessoas,
    required this.epiConformidade,
    required this.ocorrencia,
    required this.streamUrl,
    required this.ultimoContato,
    required this.ultimoContatoRelativo,
  });

  factory CameraModel.fromJson(Map<String, dynamic> j) => CameraModel(
        id: j['id']?.toString() ?? '',
        codigo: j['codigo']?.toString(),
        salaId: j['salaId']?.toString() ?? '',
        salaNome: j['salaNome']?.toString(),
        nome: j['nome']?.toString() ?? j['name']?.toString() ?? 'Câmera',
        online: j['online'] == true,
        pessoas: _int(j['pessoas'] ?? j['people']),
        epiConformidade: _int(j['epiConformidade'] ?? j['epi']),
        ocorrencia: j['ocorrencia']?.toString(),
        streamUrl: (j['streamUrl'] as String?)?.isNotEmpty == true ? j['streamUrl'] as String : null,
        ultimoContato: _date(j['ultimoContato']),
        ultimoContatoRelativo: j['ultimoContatoRelativo']?.toString(),
      );

  /// Câmera ligada ao sistema de visão (as de demonstração não têm isso).
  bool get real => streamUrl != null || ultimoContato != null;

  /// Endereço do vídeo, já ajustado para o aparelho (troca "localhost" pelo IP do servidor).
  String? get videoUrl => streamUrl == null ? null : ServerConfig.resolveLocal(streamUrl!);

  /// Endereço do sistema de câmera, ex.: http://192.168.1.20:8000
  String? get visionOrigin {
    final url = videoUrl;
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    return uri.hasPort ? '${uri.scheme}://${uri.host}:${uri.port}' : '${uri.scheme}://${uri.host}';
  }
}

class EpiOcorrenciaModel {
  final String id;
  final String cameraNome;
  final String? cameraCodigo;
  final String? salaNome;
  final int pessoa;
  final List<String> faltando;
  final String mensagem;
  final String? fotoUrl;
  final DateTime dataHora;
  final String tempoRelativo;
  final bool lido;
  final bool resolvido;

  EpiOcorrenciaModel({
    required this.id,
    required this.cameraNome,
    required this.cameraCodigo,
    required this.salaNome,
    required this.pessoa,
    required this.faltando,
    required this.mensagem,
    required this.fotoUrl,
    required this.dataHora,
    required this.tempoRelativo,
    required this.lido,
    required this.resolvido,
  });

  factory EpiOcorrenciaModel.fromJson(Map<String, dynamic> j) {
    final faltando = (j['faltando'] as List? ?? []).map((e) => e.toString()).toList();
    return EpiOcorrenciaModel(
      id: j['id']?.toString() ?? '',
      cameraNome: j['cameraNome']?.toString() ?? 'Câmera',
      cameraCodigo: j['cameraCodigo']?.toString(),
      salaNome: j['salaNome']?.toString(),
      pessoa: _int(j['pessoa']),
      faltando: faltando,
      mensagem: j['mensagem']?.toString() ??
          (faltando.isEmpty ? 'EPI incompleto' : 'Pessoa ${_int(j['pessoa'])} sem ${juntarEpis(faltando)}'),
      fotoUrl: j['fotoUrl']?.toString(),
      dataHora: _date(j['dataHora']) ?? DateTime.now(),
      tempoRelativo: j['tempoRelativo']?.toString() ?? '',
      lido: j['lido'] == true,
      resolvido: j['resolvido'] == true,
    );
  }

  EpiOcorrenciaModel copyWith({bool? lido, bool? resolvido}) => EpiOcorrenciaModel(
        id: id,
        cameraNome: cameraNome,
        cameraCodigo: cameraCodigo,
        salaNome: salaNome,
        pessoa: pessoa,
        faltando: faltando,
        mensagem: mensagem,
        fotoUrl: fotoUrl,
        dataHora: dataHora,
        tempoRelativo: tempoRelativo,
        lido: lido ?? this.lido,
        resolvido: resolvido ?? this.resolvido,
      );
}

/// Resumo de uma sala: GET /salas/:id/monitoramento
class MonitoramentoModel {
  final String risco;
  final String riscoDescricao;
  final int pessoasDetectadas;
  final int? epiConformidade;
  final List<CameraModel> cameras;
  final List<EpiOcorrenciaModel> ocorrencias;

  MonitoramentoModel({
    required this.risco,
    required this.riscoDescricao,
    required this.pessoasDetectadas,
    required this.epiConformidade,
    required this.cameras,
    required this.ocorrencias,
  });

  factory MonitoramentoModel.fromJson(Map<String, dynamic> j) => MonitoramentoModel(
        risco: j['risco']?.toString() ?? '',
        riscoDescricao: j['riscoDescricao']?.toString() ?? '',
        pessoasDetectadas: _int(j['pessoasDetectadas']),
        epiConformidade: j['epiConformidade'] == null ? null : _int(j['epiConformidade']),
        cameras: (j['cameras'] as List? ?? [])
            .map((e) => CameraModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        ocorrencias: (j['ocorrenciasEpi'] as List? ?? [])
            .map((e) => EpiOcorrenciaModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Só as câmeras reais; se não houver nenhuma, mostra as de demonstração.
  List<CameraModel> get camerasVisiveis {
    final reais = cameras.where((c) => c.real).toList();
    return reais.isNotEmpty ? reais : cameras;
  }
}

/// GET /epi/ocorrencias/resumo
class EpiResumoModel {
  final int ocorrenciasHoje;
  final int abertas;
  final int naoLidas;
  final int camerasTotal;
  final int camerasOnline;
  final int pessoasDetectadas;
  final int? conformidadeMedia;

  EpiResumoModel({
    required this.ocorrenciasHoje,
    required this.abertas,
    required this.naoLidas,
    required this.camerasTotal,
    required this.camerasOnline,
    required this.pessoasDetectadas,
    required this.conformidadeMedia,
  });

  factory EpiResumoModel.fromJson(Map<String, dynamic> j) => EpiResumoModel(
        ocorrenciasHoje: _int(j['ocorrenciasHoje']),
        abertas: _int(j['abertas']),
        naoLidas: _int(j['naoLidas']),
        camerasTotal: _int(j['camerasTotal']),
        camerasOnline: _int(j['camerasOnline']),
        pessoasDetectadas: _int(j['pessoasDetectadas']),
        conformidadeMedia: j['conformidadeMedia'] == null ? null : _int(j['conformidadeMedia']),
      );
}

// ------------------------------------------------------------------------
// Dados ao vivo lidos direto do sistema de câmera (Python, porta 8000)
// ------------------------------------------------------------------------

class VisionPerson {
  final int id;
  final String status;
  final Map<String, bool?> itens;
  final Map<String, double?> confs;
  final List<String> faltando;
  final double vistoHa;

  VisionPerson(this.id, this.status, this.itens, this.confs, this.faltando, this.vistoHa);

  factory VisionPerson.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as Map? ?? {}).cast<String, dynamic>();
    return VisionPerson(
      _int(j['id']),
      j['status']?.toString() ?? 'ANALISANDO',
      items.map((k, v) => MapEntry(k, (v as Map)['present'] as bool?)),
      items.map((k, v) => MapEntry(k, ((v as Map)['conf'] as num?)?.toDouble())),
      (j['missing'] as List? ?? []).map((e) => e.toString()).toList(),
      ((j['seen_for'] as num?) ?? 0).toDouble(),
    );
  }
}

class VisionEvent {
  final int id;
  final int pessoa;
  final String dataHora;
  final List<String> faltando;
  final String? foto;

  VisionEvent(this.id, this.pessoa, this.dataHora, this.faltando, this.foto);

  factory VisionEvent.fromJson(Map<String, dynamic> j) => VisionEvent(
        _int(j['id']),
        _int(j['person_id']),
        j['datetime']?.toString() ?? '',
        (j['missing'] as List? ?? []).map((e) => e.toString()).toList(),
        j['snapshot']?.toString(),
      );
}

class VisionStatus {
  final bool cameraOnline;
  final double fps;
  final int largura;
  final int altura;
  final String? erroCamera;
  final bool detectorPronto;
  final String? erroDetector;
  final int? latenciaMs;
  final List<String> exigidos;
  final int pessoas;
  final int conformes;
  final int naoConformes;
  final int inconclusivos;
  final List<VisionPerson> lista;
  final int ocorrenciasHoje;
  final int ultimoEvento;

  VisionStatus({
    required this.cameraOnline,
    required this.fps,
    required this.largura,
    required this.altura,
    required this.erroCamera,
    required this.detectorPronto,
    required this.erroDetector,
    required this.latenciaMs,
    required this.exigidos,
    required this.pessoas,
    required this.conformes,
    required this.naoConformes,
    required this.inconclusivos,
    required this.lista,
    required this.ocorrenciasHoje,
    required this.ultimoEvento,
  });

  factory VisionStatus.fromJson(Map<String, dynamic> j) {
    final cam = (j['camera'] as Map? ?? {}).cast<String, dynamic>();
    final det = (j['detector'] as Map? ?? {}).cast<String, dynamic>();
    final sum = (j['summary'] as Map? ?? {}).cast<String, dynamic>();
    return VisionStatus(
      cameraOnline: cam['online'] == true,
      fps: ((cam['fps'] as num?) ?? 0).toDouble(),
      largura: _int(cam['width']),
      altura: _int(cam['height']),
      erroCamera: cam['error']?.toString(),
      detectorPronto: j['model_ready'] == true,
      erroDetector: det['error']?.toString(),
      latenciaMs: det['latency_ms'] == null ? null : _int(det['latency_ms']),
      exigidos: (j['required_ppe'] as List? ?? []).map((e) => e.toString()).toList(),
      pessoas: _int(j['people_count']),
      conformes: _int(sum['conforme']),
      naoConformes: _int(sum['nao_conforme']),
      inconclusivos: _int(sum['inconclusivo']) + _int(sum['analisando']),
      lista: (j['people'] as List? ?? [])
          .map((e) => VisionPerson.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      ocorrenciasHoje: _int(j['events_today']),
      ultimoEvento: _int(j['last_event_id']),
    );
  }

  /// Mesma conta do painel da câmera: conformes ÷ (conformes + não conformes).
  int? get conformidade {
    final avaliados = conformes + naoConformes;
    if (!cameraOnline || avaliados == 0) return null;
    return (conformes * 100 / avaliados).round();
  }

  /// % de pessoas usando cada EPI exigido.
  Map<String, int?> get porItem {
    final out = <String, int?>{};
    for (final k in exigidos) {
      final avaliados = lista.where((p) => p.itens[k] != null).toList();
      final ok = avaliados.where((p) => p.itens[k] == true).length;
      out[k] = avaliados.isEmpty ? null : (ok * 100 / avaliados.length).round();
    }
    return out;
  }
}

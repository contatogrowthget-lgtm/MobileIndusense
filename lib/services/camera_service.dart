import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/camera_model.dart';
import 'api_client.dart';

/// Câmeras e ocorrências de EPI, pela InduSense API.
class CameraService {
  final ApiClient _client = ApiClient();

  Future<MonitoramentoModel> monitoramento(String salaId) async {
    final res = await _client.get(ApiConstants.salaMonitoramento(salaId));
    return MonitoramentoModel.fromJson(res as Map<String, dynamic>);
  }

  Future<List<CameraModel>> cameras() async {
    final res = await _client.get(ApiConstants.cameras);
    return (res as List).map((e) => CameraModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<EpiOcorrenciaModel>> ocorrencias({String? salaId, bool? resolvido, int limit = 100}) async {
    final query = <String, String>{
      if (salaId != null) 'salaId': salaId,
      if (resolvido != null) 'resolvido': '$resolvido',
      'limit': '$limit',
    };
    final res = await _client.get('${ApiConstants.epiOcorrencias}?${Uri(queryParameters: query).query}');
    return (res as List).map((e) => EpiOcorrenciaModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<EpiResumoModel> resumo() async {
    final res = await _client.get(ApiConstants.epiResumo);
    return EpiResumoModel.fromJson(res as Map<String, dynamic>);
  }

  Future<void> resolver(String id) => _client.patch(ApiConstants.epiResolver(id));

  Future<void> marcarLida(String id) => _client.patch(ApiConstants.epiLer(id));
}

/// Dados ao vivo direto do sistema de câmera (Python, porta 8000):
/// as mesmas informações do painel em http://localhost:8000.
class VisionService {
  static Future<Map<String, dynamic>> _get(String url) async {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
    if (res.statusCode != 200) throw ApiException('HTTP ${res.statusCode}', statusCode: res.statusCode);
    return (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
  }

  static Future<VisionStatus> status(String origin) async =>
      VisionStatus.fromJson(await _get('$origin/status'));

  static Future<List<VisionEvent>> eventos(String origin, {int limit = 30}) async {
    final data = await _get('$origin/events?limit=$limit');
    return (data['events'] as List? ?? [])
        .map((e) => VisionEvent.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

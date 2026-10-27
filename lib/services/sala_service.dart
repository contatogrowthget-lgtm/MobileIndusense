import '../core/constants/api_constants.dart';
import '../models/sala_model.dart';
import '../models/sensor_model.dart';
import 'api_client.dart';
import 'mock_data_service.dart';
import 'nfc_service.dart';
import 'sensor_service.dart';

/// Agrupa sensores por sala/setor físico da fábrica. Também resolve
/// a sala a partir da tag NFC lida na porta.
class SalaService {
  final ApiClient _client = ApiClient();
  final SensorService _sensorService = SensorService();

  Future<List<SalaModel>> getSalas() async {
    if (ApiConstants.useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return MockDataService.salas;
    }
    final res = await _client.get(ApiConstants.salas);
    return (res as List).map((e) => SalaModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Retorna todas as salas já com seus sensores e status agregado,
  /// pronto para exibir no Dashboard.
  /// Executa a busca de salas e sensores em paralelo para melhor performance.
  Future<List<SalaComSensores>> getSalasComSensores() async {
    final resultados = await Future.wait([
      getSalas(),
      _sensorService.getSensors(),
    ]);

    final salas = resultados[0] as List<SalaModel>;
    final sensores = resultados[1] as List<SensorModel>;

    return salas.map((sala) {
      final doSala = sensores.where((s) => s.salaId == sala.id).toList();
      return SalaComSensores(sala: sala, sensores: doSala);
    }).toList();
  }

  Future<List<SensorModel>> getSensoresPorSala(String salaId) async {
    if (ApiConstants.useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return MockDataService.sensors.where((s) => s.salaId == salaId).toList();
    }
    final res = await _client.get(ApiConstants.salaSensors(salaId));
    return (res as List).map((e) => SensorModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SalaModel> getSalaById(String id) async {
    if (ApiConstants.useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        return MockDataService.salas.firstWhere((s) => s.id == id);
      } catch (_) {
        throw ApiException('Sala não encontrada.', statusCode: 404);
      }
    }
    final res = await _client.get(ApiConstants.salaById(id));
    return SalaModel.fromJson(res as Map<String, dynamic>);
  }

  /// Resolve a sala a partir do id gravado na tag NFC fixada na porta.
  /// Lança [ApiException] se nenhuma sala estiver associada à tag.
  Future<SalaModel> getSalaPorTagNfc(String tagId) async {
    if (ApiConstants.useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      final sala = MockDataService.salas
          .where((s) => s.nfcTagId.toLowerCase() == tagId.toLowerCase())
          .toList();
      if (sala.isEmpty) {
        throw ApiException('Nenhuma sala cadastrada para esta tag NFC.', statusCode: 404);
      }
      return sala.first;
    }
    final res = await _client.get(ApiConstants.salaByNfcTag(tagId));
    return SalaModel.fromJson(res as Map<String, dynamic>);
  }

  /// Descobre a sala de uma tag física: primeiro pelo link gravado pelo app,
  /// depois pelo texto da tag e por fim pelo número de série (UID).
  /// Lança [ApiException] com statusCode 404 se a tag não estiver vinculada.
  Future<SalaModel> resolverTag(TagLida tag) async {
    if (tag.salaCodigo != null) {
      try {
        return await getSalaById(tag.salaCodigo!);
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
    }
    for (final id in tag.candidatos) {
      try {
        return await getSalaPorTagNfc(id);
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
    }
    throw ApiException('Esta tag ainda não está vinculada a nenhuma sala.', statusCode: 404);
  }

  /// Vincula a tag (pelo UID) à sala. Se a tag estava em outra sala, libera de lá.
  /// Retorna o nome da sala anterior, se havia.
  Future<String?> vincularTag({required SalaModel sala, required String uid}) async {
    String? anterior;
    try {
      final outra = await getSalaPorTagNfc(uid);
      if (outra.id == sala.id) return null;
      anterior = outra.nome;
      final codigoOutra = outra.codigo.isNotEmpty ? outra.codigo : (outra.id.length > 8 ? outra.id.substring(0, 8) : outra.id);
      await _client.patch(ApiConstants.salaById(outra.id), {'nfcTagId': 'NFC-$codigoOutra'});
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
    }
    await _client.patch(ApiConstants.salaById(sala.id), {'nfcTagId': uid});
    return anterior;
  }
}

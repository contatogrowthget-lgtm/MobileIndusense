import '../core/constants/api_constants.dart';
import '../models/reading_model.dart';
import '../models/sensor_model.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

/// Dados dos sensores IoT/ESP32: status atual (dashboard) e
/// histórico de leituras (com filtros por período/sensor/tipo).
class SensorService {
  final ApiClient _client = ApiClient();

  Future<List<SensorModel>> getSensors() async {
    if (ApiConstants.useMock) {
      await Future.delayed(const Duration(milliseconds: 700));
      return MockDataService.sensors;
    }
    final res = await _client.get(ApiConstants.sensors);
    return (res as List)
        .map((e) => SensorModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SensorModel> getSensorById(String id) async {
    if (ApiConstants.useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        return MockDataService.sensors.firstWhere((s) => s.id == id);
      } catch (_) {
        throw ApiException('Sensor não encontrado.');
      }
    }
    final res = await _client.get(ApiConstants.sensorById(id));
    return SensorModel.fromJson(res as Map<String, dynamic>);
  }

  /// Retorna leituras históricas com filtros opcionais.
  Future<List<ReadingModel>> getReadings({
    String? sensorId,
    SensorType? tipo,
    DateTime? inicio,
    DateTime? fim,
  }) async {
    if (ApiConstants.useMock) {
      await Future.delayed(const Duration(milliseconds: 700));
      var result = MockDataService.readings(sensorId: sensorId, tipo: tipo);
      if (inicio != null) {
        result = result.where((r) => r.dataHora.isAfter(inicio)).toList();
      }
      if (fim != null) {
        result = result.where((r) => r.dataHora.isBefore(fim)).toList();
      }
      return result;
    }

    final query = <String, String>{
      if (sensorId != null) 'sensorId': sensorId,
      if (tipo != null) 'tipo': tipo.name,
      if (inicio != null) 'inicio': inicio.toIso8601String(),
      if (fim != null) 'fim': fim.toIso8601String(),
    };

    final queryString = query.isNotEmpty
        ? '?${Uri(queryParameters: query).query}'
        : '';
        
    final res = await _client.get('${ApiConstants.readings}$queryString');
    return (res as List)
        .map((e) => ReadingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
import '../core/constants/api_constants.dart';
import '../models/alert_model.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

/// Alertas: parâmetro excedido, valor medido, limite, data/hora e
/// status lido/não lido.
class AlertService {
  final ApiClient _client = ApiClient();

  Future<List<AlertModel>> getAlerts({bool? resolvido, int? limit}) async {
    if (ApiConstants.useMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      return List.of(MockDataService.alerts);
    }
    final q = <String>[
      if (resolvido != null) 'resolvido=$resolvido',
      if (limit != null) 'limit=$limit',
    ];
    final res = await _client.get(q.isEmpty ? ApiConstants.alerts : '${ApiConstants.alerts}?${q.join('&')}');
    final lista = res is Map ? (res['data'] ?? const []) : res;
    return (lista as List).map((e) => AlertModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Encerra o alerta (ADMIN/OPERADOR). Se o valor continuar fora, a API abre outro.
  Future<void> resolver(String alertId) => _client.patch('${ApiConstants.alerts}/$alertId/resolve');

  Future<void> marcarTodosLidos() => _client.patch('${ApiConstants.alerts}/read-all');

  Future<void> marcarComoLido(String alertId) async {
    if (ApiConstants.useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    await _client.patch(ApiConstants.alertRead(alertId));
  }
}

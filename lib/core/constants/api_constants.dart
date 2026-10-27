import '../config/server_config.dart';

/// Rotas da InduSense API (NestJS).
///
/// O endereço do servidor é configurado DENTRO do app (Perfil > Servidor),
/// então não precisa recompilar para trocar entre emulador e celular.
class ApiConstants {
  ApiConstants._();

  static String get baseUrl => ServerConfig.apiUrl;

  /// true = usa dados fictícios, sem servidor.
  static const bool useMock = false;

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String loginGoogle = '/auth/google';
  static const String loginApple = '/auth/apple';

  // Sensores / Dashboard
  static const String sensors = '/sensors';
  static String sensorById(String id) => '/sensors/$id';
  static String sensorReadings(String id) => '/sensors/$id/readings';

  // Salas / Setores (agrupamento físico dos sensores)
  static const String salas = '/salas';
  static String salaById(String id) => '/salas/$id';
  static String salaSensors(String id) => '/salas/$id/sensors';
  static String salaByNfcTag(String tagId) => '/salas/nfc/$tagId';

  // Histórico
  static const String readings = '/readings';

  // Alertas
  static const String alerts = '/alerts';
  static String alertRead(String id) => '/alerts/$id/read';

  // Perfil
  static const String profile = '/users/profile';
  static const String profilePassword = '/users/profile/password';
  static const String profileSessions = '/users/profile/sessions';
  static const String profileSessionsRevokeOthers = '/users/profile/sessions/revoke-others';
  static String profileSession(String id) => '/users/profile/sessions/${Uri.encodeComponent(id)}';

  // Dashboard
  static const String dashboardSummary = '/dashboard/summary';

  // Câmeras e EPI (sistema de visão)
  static const String cameras = '/cameras';
  static String salaMonitoramento(String id) => '/salas/${Uri.encodeComponent(id)}/monitoramento';
  static const String epiOcorrencias = '/epi/ocorrencias';
  static const String epiResumo = '/epi/ocorrencias/resumo';
  static String epiResolver(String id) => '/epi/ocorrencias/$id/resolve';
  static String epiLer(String id) => '/epi/ocorrencias/$id/read';

  static const String health = '/health';

  /// O Render gratuito "dorme" e leva até ~50 s para acordar na primeira chamada.
  static const Duration timeout = Duration(seconds: 45);
}
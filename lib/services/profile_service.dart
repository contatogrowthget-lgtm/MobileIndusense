import 'dart:convert';
import 'dart:typed_data';

import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_client.dart';

/// Perfil do próprio usuário: dados, foto, senha e sessões.
/// Mesmas rotas que o painel web usa em Configurações.
class ProfileService {
  final ApiClient _client = ApiClient();

  static Map<String, dynamic> _map(dynamic res) {
    if (res is Map<String, dynamic>) {
      final d = res['data'];
      return d is Map<String, dynamic> ? d : res;
    }
    throw ApiException('Resposta inesperada do servidor.');
  }

  Future<UserModel> carregar() async => UserModel.fromJson(_map(await _client.get(ApiConstants.profile)));

  /// Envia só os campos informados. [avatar] = "" remove a foto.
  Future<UserModel> atualizar({String? nome, String? email, String? cargo, String? empresa, String? avatar}) async {
    final body = <String, dynamic>{
      if (nome != null) 'nome': nome.trim(),
      if (email != null) 'email': email.trim().toLowerCase(),
      if (cargo != null) 'cargo': cargo.trim(),
      if (empresa != null) 'empresa': empresa.trim(),
      if (avatar != null) 'avatar': avatar,
    };
    return UserModel.fromJson(_map(await _client.patch(ApiConstants.profile, body)));
  }

  static String dataUrlJpeg(Uint8List jpeg) => 'data:image/jpeg;base64,${base64Encode(jpeg)}';

  /// Retorna quantos outros aparelhos foram desconectados.
  Future<int> alterarSenha({required String atual, required String nova}) async {
    final res = _map(await _client.patch(ApiConstants.profilePassword, {'senhaAtual': atual, 'novaSenha': nova}));
    final n = res['sessoesEncerradas'];
    return n is num ? n.toInt() : 0;
  }

  Future<List<SessaoModel>> sessoes() async {
    final res = await _client.get(ApiConstants.profileSessions);
    final lista = res is Map ? (res['data'] ?? res['items'] ?? const []) : res;
    return (lista as List).map((e) => SessaoModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> encerrar(String id) => _client.delete(ApiConstants.profileSession(id));

  Future<int> encerrarOutras() async {
    final res = _map(await _client.post(ApiConstants.profileSessionsRevokeOthers, {}));
    final n = res['encerradas'];
    return n is num ? n.toInt() : 0;
  }
}

class UserModel {
  final String id;
  final String nome;
  final String email;
  final String? cargo;
  final String? empresa;

  /// ADMIN | OPERADOR | VISUALIZADOR
  final String? perfil;

  /// Foto em data URL (data:image/jpeg;base64,...). null = sem foto.
  final String? avatar;
  final DateTime? ultimoAcesso;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.nome,
    required this.email,
    this.cargo,
    this.empresa,
    this.perfil,
    this.avatar,
    this.ultimoAcesso,
    this.createdAt,
  });

  static String? _str(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      nome: json['nome'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      cargo: _str(json['cargo']),
      empresa: _str(json['empresa']),
      perfil: _str(json['perfil']),
      avatar: _str(json['avatar']),
      ultimoAcesso: _date(json['ultimoAcesso']),
      createdAt: _date(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'cargo': cargo,
        'empresa': empresa,
        'perfil': perfil,
        'avatar': avatar,
        'ultimoAcesso': ultimoAcesso?.toUtc().toIso8601String(),
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };

  /// "Administrador", "Operador" ou "Visualizador".
  String get perfilLabel {
    switch (perfil) {
      case 'ADMIN':
        return 'Administrador';
      case 'OPERADOR':
        return 'Operador';
      case 'VISUALIZADOR':
        return 'Visualizador';
      default:
        return 'Usuário';
    }
  }

  /// Até duas iniciais: "Cauã Gomes" -> "CG".
  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return email.isNotEmpty ? email[0].toUpperCase() : '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  String get primeiroNome {
    final p = nome.trim().split(RegExp(r'\s+'));
    return p.isEmpty ? '' : p.first;
  }

  /// 0 a 1: quanto do perfil está preenchido (nome, e-mail, foto, cargo, empresa).
  double get completude {
    var n = 0;
    if (nome.trim().isNotEmpty) n++;
    if (email.trim().isNotEmpty) n++;
    if (avatar != null) n++;
    if (cargo != null) n++;
    if (empresa != null) n++;
    return n / 5;
  }

  List<String> get faltando => [
        if (avatar == null) 'foto',
        if (cargo == null) 'cargo',
        if (empresa == null) 'empresa',
      ];
}

/// Resposta de autenticação (login/cadastro): usuário + token de sessão.
class AuthResponse {
  final String token;
  final UserModel user;

  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] ?? json['accessToken'] ?? '',
      user: UserModel.fromJson(json['user']),
    );
  }
}

/// Aparelho/navegador conectado na conta (GET /users/profile/sessions).
class SessaoModel {
  final String id;
  final bool atual;
  final String? dispositivo;
  final String? ip;
  final DateTime criadaEm;
  final DateTime ultimoUso;

  SessaoModel({
    required this.id,
    required this.atual,
    this.dispositivo,
    this.ip,
    required this.criadaEm,
    required this.ultimoUso,
  });

  factory SessaoModel.fromJson(Map<String, dynamic> j) => SessaoModel(
        id: j['id'].toString(),
        atual: j['atual'] == true,
        dispositivo: j['dispositivo']?.toString(),
        ip: j['ip']?.toString(),
        criadaEm: DateTime.tryParse(j['criadaEm']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        ultimoUso: DateTime.tryParse(j['ultimoUso']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      );

  /// O que é: app, navegador e sistema, a partir do user-agent.
  ({String titulo, String tipo}) get descricao {
    final u = dispositivo ?? '';
    final app = RegExp(r'InduSenseApp|Dart|okhttp|CFNetwork', caseSensitive: false).hasMatch(u);
    final nav = app
        ? 'App InduSense'
        : u.contains('Edg/')
            ? 'Edge'
            : u.contains('OPR/')
                ? 'Opera'
                : u.contains('Chrome/')
                    ? 'Chrome'
                    : u.contains('Firefox/')
                        ? 'Firefox'
                        : u.contains('Safari/')
                            ? 'Safari'
                            : 'Navegador';
    final so = RegExp(r'iPhone|iPad').hasMatch(u)
        ? 'iPhone'
        : u.contains('Android')
            ? 'Android'
            : RegExp(r'Mac OS X|Macintosh').hasMatch(u)
                ? 'Mac'
                : u.contains('Windows')
                    ? 'Windows'
                    : u.contains('Linux')
                        ? 'Linux'
                        : '';
    final tipo = RegExp(r'iPhone|Android|Mobile').hasMatch(u)
        ? 'celular'
        : RegExp(r'iPad|Tablet').hasMatch(u)
            ? 'tablet'
            : 'computador';
    return (titulo: so.isEmpty ? nav : '$nav · $so', tipo: tipo);
  }
}

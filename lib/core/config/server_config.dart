import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Endereço da InduSense API, configurável dentro do app
/// (Perfil > Servidor, ou no link "Servidor" da tela de login).
///
/// Assim dá para usar o mesmo app no emulador, no simulador e no celular
/// de verdade sem recompilar: no celular use o IP do Mac, ex.:
/// http://192.168.1.20:3333/v1
class ServerConfig {
  ServerConfig._();

  // chave nova: endereços antigos salvos (IP da rede local) são ignorados e o app usa a nuvem
  static const _key = 'indusense_api_url_v2';
  static String _apiUrl = defaultUrl;

  /// API na nuvem (Render). Para testar com a API local, troque em Perfil > Servidor.
  static const String cloudUrl = 'https://indusense-api.onrender.com/v1';

  static String get defaultUrl => cloudUrl;

  /// URL da API com o prefixo de versão, ex.: http://192.168.1.20:3333/v1
  static String get apiUrl => _apiUrl;

  /// Só o esquema + host + porta, ex.: http://192.168.1.20:3333
  static String get apiOrigin {
    final uri = Uri.tryParse(_apiUrl);
    if (uri == null || uri.host.isEmpty) return _apiUrl;
    return uri.hasPort ? '${uri.scheme}://${uri.host}:${uri.port}' : '${uri.scheme}://${uri.host}';
  }

  static String get apiHost => Uri.tryParse(_apiUrl)?.host ?? 'localhost';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.trim().isNotEmpty) _apiUrl = saved.trim();
  }

  static Future<void> save(String url) async {
    _apiUrl = normalize(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _apiUrl);
  }

  static Future<void> reset() async {
    _apiUrl = defaultUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Aceita "192.168.1.20", "192.168.1.20:3333" ou a URL completa.
  static String normalize(String input) {
    var url = input.trim();
    if (url.isEmpty) return defaultUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'http://$url';
    var uri = Uri.parse(url);
    if (!uri.hasPort && uri.scheme == 'http') uri = uri.replace(port: 3333);
    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (path.isEmpty) path = '/v1';
    return uri.replace(path: path).toString();
  }

  /// O sistema de câmera costuma informar "localhost". No emulador ou no
  /// celular, "localhost" é o próprio aparelho; então trocamos pelo host da API,
  /// que é o computador onde tudo está rodando.
  static String resolveLocal(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    const locais = {'localhost', '127.0.0.1', '0.0.0.0'};
    if (locais.contains(uri.host) && !locais.contains(apiHost)) {
      return uri.replace(host: apiHost).toString();
    }
    return url;
  }

  /// Testa GET /health. Retorna null se deu certo, ou a mensagem do problema.
  static Future<String?> test(String url) async {
    final base = normalize(url);
    try {
      final res = await http.get(Uri.parse('$base/health')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) return null;
      if (res.statusCode == 404) return 'O servidor respondeu, mas não é a InduSense API (confira o /v1).';
      return 'O servidor respondeu com erro ${res.statusCode}. O banco de dados está ligado?';
    } catch (_) {
      return 'Não foi possível conectar em $base. Confira o IP, a porta e se a API está rodando.';
    }
  }
}

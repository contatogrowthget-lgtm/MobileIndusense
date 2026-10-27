import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'alert_watcher.dart';
import 'auth_service.dart';
import 'nfc_auto_reader.dart';
import 'profile_service.dart';
import 'social_auth_service.dart';

enum AuthStatus { desconhecido, autenticado, naoAutenticado }

/// Estado global de sessão, consumido pelas telas via Provider.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SocialAuthService _social = SocialAuthService();

  /// Qual botão está carregando: 'email', 'google' ou 'apple'.
  String? _carregandoVia;
  String? get carregandoVia => _carregandoVia;

  UserModel? _user;
  AuthStatus _status = AuthStatus.desconhecido;
  String? _errorMessage;
  bool _loading = false;
  bool _disposed = false;

  UserModel? get user => _user;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get loading => _loading;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  Future<void> restoreSession() async {
    try {
      final user = await _authService.restoreSession();
      _user = user;
      _status = user != null ? AuthStatus.autenticado : AuthStatus.naoAutenticado;
    } catch (_) {
      _status = AuthStatus.naoAutenticado;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String senha) async {
    _loading = true;
    _carregandoVia = 'email';
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.login(email: email, senha: senha);
      _user = user;
      _status = AuthStatus.autenticado;
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Não foi possível entrar. Tente novamente.';
      return false;
    } finally {
      _carregandoVia = null;
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> cadastrar({
    required String nome,
    required String email,
    required String senha,
    String? empresa,
  }) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.cadastrar(
        nome: nome,
        email: email,
        senha: senha,
        empresa: empresa,
      );
      _user = user;
      _status = AuthStatus.autenticado;
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Não foi possível concluir o cadastro.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> loginGoogle() => _loginSocial('google');
  Future<bool> loginApple() => _loginSocial('apple');

  Future<bool> _loginSocial(String provedor) async {
    _loading = true;
    _carregandoVia = provedor;
    _errorMessage = null;
    notifyListeners();
    try {
      final t = provedor == 'apple' ? await _social.apple() : await _social.google();
      _user = await _authService.loginSocial(provedor: provedor, token: t.token, nome: t.nome);
      _status = AuthStatus.autenticado;
      return true;
    } on SocialCancelado {
      return false;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Não foi possível entrar com ${provedor == 'apple' ? 'a Apple' : 'o Google'}.';
      return false;
    } finally {
      _loading = false;
      _carregandoVia = null;
      notifyListeners();
    }
  }

  /// Troca o usuário em memória e no aparelho (depois de editar o perfil).
  Future<void> atualizarUsuario(UserModel user) async {
    _user = user;
    notifyListeners();
    await _authService.persistUser(user);
  }

  /// Busca o perfil de novo na API (ex.: foto trocada pelo painel web).
  Future<void> recarregarPerfil() async {
    try {
      final u = await ProfileService().carregar();
      await atualizarUsuario(u);
    } catch (_) {}
  }

  Future<void> logout() async {
    NfcAutoReader.instance.desligar();
    AlertWatcher.instance.desligar();
    _loading = true;
    notifyListeners();

    try {
      await _authService.logout();
    } finally {
      _user = null;
      _errorMessage = null;
      _loading = false;
      _status = AuthStatus.naoAutenticado;
      notifyListeners();
    }
  }
}
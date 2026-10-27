import 'package:flutter/material.dart';
import '../screens/auth/cadastro_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home_shell.dart';
import '../screens/nfc/abrir_sala_screen.dart';
import '../screens/nfc/nfc_scan_screen.dart';
import '../screens/sala_detail/sala_detail_screen.dart';
import '../screens/sensor_detail/sensor_detail_screen.dart';
import '../screens/splash/splash_screen.dart';

/// Tabela de rotas nomeadas do InduSense.
///
/// '/sensor-detalhe' e '/sala-detalhe' recebem o id correspondente via
/// `arguments` (String).
class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const cadastro = '/cadastro';
  static const dashboard = '/dashboard';
  static const cameras = '/cameras';
  static const historico = '/historico';
  static const alertas = '/alertas';
  static const configuracoes = '/configuracoes';
  static const sensorDetalhe = '/sensor-detalhe';
  static const salaDetalhe = '/sala-detalhe';
  static const nfcScan = '/nfc-scan';

  /// Para abrir telas fora de um BuildContext (leitura NFC automática, link da tag).
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Link gravado na tag: indusense://app/sala/IND-001 -> rota "/sala/IND-001".
  static String? codigoDaRota(String? nome) {
    if (nome == null) return null;
    final m = RegExp(r'^/sala/([^/?#]+)').firstMatch(nome);
    return m == null ? null : Uri.decodeComponent(m.group(1)!);
  }

  /// Primeira tela do app. Se ele foi aberto encostando numa tag (Android),
  /// vai direto para a sala; senão começa pela splash.
  static List<Route<dynamic>> rotasIniciais(String inicial) {
    final codigo = codigoDaRota(inicial);
    if (codigo != null) {
      return [MaterialPageRoute(builder: (_) => AbrirSalaScreen(codigo: codigo, inicial: true))];
    }
    return [MaterialPageRoute(settings: const RouteSettings(name: splash), builder: (_) => const SplashScreen())];
  }

  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        login: (_) => const LoginScreen(),
        cadastro: (_) => const CadastroScreen(),
        dashboard: (_) => const HomeShell(initialIndex: HomeTabs.inicio),
        cameras: (_) => const HomeShell(initialIndex: HomeTabs.cameras),
        historico: (_) => const HomeShell(initialIndex: HomeTabs.historico),
        alertas: (_) => const HomeShell(initialIndex: HomeTabs.alertas),
        configuracoes: (_) => const HomeShell(initialIndex: HomeTabs.perfil),
        nfcScan: (_) => const NfcScanScreen(),
      };

  /// Rotas que exigem argumento dinâmico ficam fora do mapa estático.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    // app já aberto e a pessoa encostou numa tag gravada (Android)
    final codigo = codigoDaRota(settings.name);
    if (codigo != null) {
      return MaterialPageRoute(settings: settings, builder: (_) => AbrirSalaScreen(codigo: codigo));
    }

    if (settings.name == sensorDetalhe) {
      final sensorId = settings.arguments as String?;
      if (sensorId == null) return null;

      return MaterialPageRoute(
        builder: (_) => SensorDetailScreen(sensorId: sensorId),
      );
    }

    if (settings.name == salaDetalhe) {
      final salaId = settings.arguments as String?;
      if (salaId == null) return null;

      return MaterialPageRoute(
        builder: (_) => SalaDetailScreen(salaId: salaId),
      );
    }

    return null;
  }
}
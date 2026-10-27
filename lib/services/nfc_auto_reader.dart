import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../routes/app_routes.dart';
import '../screens/nfc/nfc_scan_screen.dart';
import '../screens/sala_detail/sala_detail_screen.dart';
import 'api_client.dart';
import 'nfc_service.dart';
import 'sala_service.dart';

/// Leitura automática no Android: com o app aberto (em qualquer tela),
/// encostou na tag da porta → abre a sala, sem apertar nada.
///
/// No iPhone a Apple não permite ler sem a janela do sistema, então lá
/// a leitura é pelo botão de NFC do início.
class NfcAutoReader with WidgetsBindingObserver {
  NfcAutoReader._();
  static final NfcAutoReader instance = NfcAutoReader._();

  final _nfc = NfcService.instance;
  final _salas = SalaService();

  bool _ligado = false;
  int _pausas = 0;
  bool _ocupado = false;
  String? _ultimoUid;
  DateTime _ultimaVez = DateTime(2000);

  bool get _suportado => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Chamado quando o usuário entra no app (HomeShell).
  void ligar() {
    if (!_suportado || _ligado) return;
    _ligado = true;
    WidgetsBinding.instance.addObserver(this);
    _abrirSessao();
  }

  /// Chamado ao sair da conta.
  void desligar() {
    if (!_ligado) return;
    _ligado = false;
    WidgetsBinding.instance.removeObserver(this);
    _nfc.parar();
  }

  /// A tela de escanear/configurar tag usa o NFC sozinha enquanto está aberta.
  void pausar() {
    _pausas++;
    if (_ligado && _pausas == 1) _nfc.parar();
  }

  void retomar() {
    if (_pausas > 0) _pausas--;
    if (_ligado && _pausas == 0) {
      // espera a tela fechar a sessão dela
      Future.delayed(const Duration(milliseconds: 300), _abrirSessao);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ligado && _pausas == 0) _abrirSessao();
  }

  Future<void> _abrirSessao() async {
    if (!_ligado || _pausas > 0) return;
    if (await _nfc.estado() != NfcEstadoAparelho.pronto) return;
    await _nfc.iniciar(aoDescobrir: _aoDescobrir);
  }

  Future<void> _aoDescobrir(NfcTag tagCrua) async {
    if (_ocupado || _pausas > 0) return;
    final TagLida tag;
    try {
      tag = _nfc.ler(tagCrua);
    } catch (_) {
      return;
    }
    // a mesma tag encostada por mais tempo não abre a sala duas vezes
    final agora = DateTime.now();
    if (tag.uid == _ultimoUid && agora.difference(_ultimaVez) < const Duration(seconds: 4)) return;
    _ultimoUid = tag.uid;
    _ultimaVez = agora;

    final nav = AppRoutes.navigatorKey.currentState;
    final msg = AppRoutes.messengerKey.currentState;
    if (nav == null) return;

    _ocupado = true;
    HapticFeedback.mediumImpact();
    msg?.hideCurrentSnackBar();
    msg?.showSnackBar(const SnackBar(
      duration: Duration(seconds: 2),
      content: Row(children: [
        Icon(Icons.contactless_rounded, color: Color(0xFF22D3C5), size: 20),
        SizedBox(width: 10),
        Text('Tag lida, abrindo a sala…'),
      ]),
    ));
    try {
      final sala = await _salas.resolverTag(tag);
      HapticFeedback.heavyImpact();
      msg?.hideCurrentSnackBar();
      nav.push(MaterialPageRoute(builder: (_) => SalaDetailScreen(salaId: sala.id)));
    } on ApiException catch (e) {
      msg?.hideCurrentSnackBar();
      if (e.statusCode == 404) {
        nav.push(MaterialPageRoute(builder: (_) => NfcScanScreen(tagInicial: tag)));
      } else {
        msg?.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      _ocupado = false;
    }
  }
}

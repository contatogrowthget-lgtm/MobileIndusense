import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_model.dart';
import '../models/sensor_model.dart';
import '../routes/app_routes.dart';
import '../screens/sala_detail/sala_detail_screen.dart';
import '../widgets/alert_overlay.dart';
import 'alert_service.dart';

/// Fica ligado enquanto o usuário está no app. A cada 15 s busca os alertas
/// abertos e, quando algum sensor sai do limite, mostra o aviso grande por
/// cima de qualquer tela (igual ao painel web):
///   "OK, estou ciente"    -> não mostra mais esse alerta (até piorar)
///   "Me lembre em 15 min" -> silencia TODOS os avisos por 15 min; depois volta
///                           a mostrar o que continuar fora do limite
/// Quando a leitura volta ao normal, a API encerra o alerta e o aviso fecha.
class AlertWatcher with WidgetsBindingObserver {
  AlertWatcher._();
  static final AlertWatcher instance = AlertWatcher._();

  static const _kVistos = 'alert_vistos';
  static const _kSoneca = 'alert_soneca';
  static const sonecaMin = 15;

  /// chave da soneca geral (vale para todos os alertas)
  static const _todos = '*';

  final _service = AlertService();
  Timer? _timer;
  bool _ligado = false;
  bool _verificando = false;

  OverlayEntry? _entry;
  final ValueNotifier<AlertModel?> _atual = ValueNotifier(null);
  final ValueNotifier<int> _fila = ValueNotifier(0);
  String? _chaveNaTela;
  final Map<String, AlertModel> _abertosAntes = {};

  static String _chave(AlertModel a) => '${a.id}:${a.severidade.name}';

  void ligar() {
    if (_ligado) return;
    _ligado = true;
    WidgetsBinding.instance.addObserver(this);
    verificar();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => verificar());
  }

  void desligar() {
    _ligado = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    _fechar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ligado) verificar();
  }

  Future<Set<String>> _vistos() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_kVistos) ?? const []).toSet();
  }

  Future<Map<String, int>> _soneca() async {
    final p = await SharedPreferences.getInstance();
    try {
      return Map<String, int>.from(jsonDecode(p.getString(_kSoneca) ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> verificar() async {
    if (!_ligado || _verificando) return;
    _verificando = true;
    try {
      final todos = await _service.getAlerts(resolvido: false, limit: 100);
      if (!_ligado) return; // saiu (logout) enquanto buscava
      final abertos = todos
          .where((a) => !a.resolvido && (a.severidade == SensorStatus.atencao || a.severidade == SensorStatus.critico))
          .toList();
      final ids = abertos.map((a) => a.id).toSet();

      // os que estavam na tela e sumiram = voltaram ao normal
      final naTela = _atual.value;
      if (naTela != null && !ids.contains(naTela.id)) {
        _fechar();
        _avisar('${naTela.salaNome ?? 'Sala'}: ${naTela.tipo.label.toLowerCase()} voltou ao normal.', ok: true);
      }
      _abertosAntes
        ..clear()
        ..addEntries(abertos.map((a) => MapEntry(a.id, a)));

      final agora = DateTime.now().millisecondsSinceEpoch;
      final vistos = await _vistos();
      final soneca = await _soneca();
      // limpeza do que já não existe
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kVistos, vistos.where((k) => ids.contains(k.split(':').first)).toList());
      soneca.removeWhere((id, ate) => (id != _todos && !ids.contains(id)) || ate <= agora);
      final silenciado = (soneca[_todos] ?? 0) > agora;
      await p.setString(_kSoneca, jsonEncode(soneca));

      final pendentes = abertos
          .where((a) => !silenciado && !vistos.contains(_chave(a)) && (soneca[a.id] ?? 0) <= agora)
          .toList()
        ..sort((a, b) {
          final s = (a.severidade == SensorStatus.critico ? 0 : 1).compareTo(b.severidade == SensorStatus.critico ? 0 : 1);
          return s != 0 ? s : b.dataHora.compareTo(a.dataHora);
        });
      _fila.value = pendentes.length;

      if (!_ligado) return;
      if (pendentes.isEmpty) {
        _fechar();
        return;
      }
      // mantém o que já está na tela (atualizado); troca só se ele saiu da fila
      final mesmo = pendentes.where((a) => _chave(a) == _chaveNaTela);
      final mostrar = mesmo.isNotEmpty ? mesmo.first : pendentes.first;
      _mostrar(mostrar);
    } catch (_) {
      // sem rede ou API acordando: tenta de novo no próximo ciclo
    } finally {
      _verificando = false;
    }
  }

  void _mostrar(AlertModel a) {
    final novo = _chave(a) != _chaveNaTela;
    _chaveNaTela = _chave(a);
    _atual.value = a;
    if (_entry == null) {
      final overlay = AppRoutes.navigatorKey.currentState?.overlay;
      if (overlay == null) return;
      _entry = OverlayEntry(
        builder: (_) => AlertOverlay(
          alerta: _atual,
          fila: _fila,
          sonecaMin: sonecaMin,
          onCiente: ciente,
          onLembrar: lembrarDepois,
          onVerSala: verSala,
        ),
      );
      overlay.insert(_entry!);
    }
    if (novo) {
      final critico = a.severidade == SensorStatus.critico;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      if (critico) {
        Future.delayed(const Duration(milliseconds: 350), HapticFeedback.heavyImpact);
        Future.delayed(const Duration(milliseconds: 700), HapticFeedback.heavyImpact);
      }
    }
  }

  void _fechar() {
    _entry?.remove();
    _entry = null;
    _chaveNaTela = null;
    _atual.value = null;
  }

  void _avisar(String msg, {bool ok = false}) {
    AppRoutes.messengerKey.currentState?.showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: ok ? const Color(0xFF4ADE80) : Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
    ));
  }

  Future<void> ciente() async {
    final a = _atual.value;
    if (a == null) return;
    final p = await SharedPreferences.getInstance();
    final vistos = (p.getStringList(_kVistos) ?? <String>[])..add(_chave(a));
    await p.setStringList(_kVistos, vistos);
    _fechar();
    try {
      await _service.marcarComoLido(a.id);
    } catch (_) {}
    verificar();
  }

  Future<void> lembrarDepois() async {
    if (_atual.value == null) return;
    final s = await _soneca();
    // silencia todos os avisos (os atuais e os que surgirem) por 15 min
    s[_todos] = DateTime.now().add(const Duration(minutes: sonecaMin)).millisecondsSinceEpoch;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSoneca, jsonEncode(s));
    _fechar();
    _avisar('Certo, todos os avisos ficam em silêncio por $sonecaMin minutos.');
    verificar();
  }

  Future<void> verSala() async {
    final a = _atual.value;
    final sala = a?.salaId ?? a?.salaCodigo;
    await lembrarDepois();
    if (sala != null) {
      AppRoutes.navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => SalaDetailScreen(salaId: sala)));
    }
  }
}

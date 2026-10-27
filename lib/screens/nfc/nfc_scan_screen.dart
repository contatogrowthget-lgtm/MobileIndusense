import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/sala_model.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/nfc_auto_reader.dart';
import '../../services/nfc_service.dart';
import '../../services/sala_service.dart';
import '../../widgets/ui.dart';
import '../sala_detail/sala_detail_screen.dart';

enum _Etapa { preparando, aguardando, lendo, sucesso, naoVinculada, erro }

/// Lê a tag NFC da porta e abre a sala na hora.
///
/// Com [gravarEm], configura uma tag nova para essa sala: grava o link do app
/// na tag e vincula o número de série dela à sala na API.
/// Com [tagInicial], já começa com uma tag lida (vinda da leitura automática).
class NfcScanScreen extends StatefulWidget {
  final SalaModel? gravarEm;
  final TagLida? tagInicial;
  const NfcScanScreen({super.key, this.gravarEm, this.tagInicial});

  @override
  State<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends State<NfcScanScreen> with SingleTickerProviderStateMixin {
  final _nfc = NfcService.instance;
  final _salas = SalaService();
  late final AnimationController _radar =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  _Etapa _etapa = _Etapa.preparando;
  String _mensagem = '';
  TagLida? _tag;
  SalaModel? _sala;
  bool _ocupado = false;
  bool _gravouLink = true;

  bool get _gravando => widget.gravarEm != null;
  late final bool _admin;

  @override
  void initState() {
    super.initState();
    _admin = context.read<AuthProvider>().user?.perfil == 'ADMIN';
    NfcAutoReader.instance.pausar();
    if (widget.tagInicial != null) {
      _tag = widget.tagInicial;
      _etapa = _Etapa.naoVinculada;
    } else {
      _iniciar();
    }
  }

  @override
  void dispose() {
    _radar.dispose();
    _nfc.parar();
    NfcAutoReader.instance.retomar();
    super.dispose();
  }

  void _set(_Etapa e, [String msg = '']) {
    if (!mounted) return;
    setState(() {
      _etapa = e;
      _mensagem = msg;
    });
  }

  Future<void> _iniciar() async {
    _ocupado = false;
    _etapaVeioDeVinculo = false;
    _set(_Etapa.preparando);
    final estado = await _nfc.estado();
    if (estado != NfcEstadoAparelho.pronto) {
      _set(_Etapa.erro, NfcService.mensagemEstado(estado));
      return;
    }
    _set(_Etapa.aguardando);
    await _nfc.iniciar(
      mensagemIos: _gravando
          ? 'Encoste o topo do iPhone na tag nova de ${widget.gravarEm!.nome}'
          : 'Encoste o topo do iPhone na tag da porta',
      aoDescobrir: _gravando ? _gravar : _ler,
      aoErro: (m) {
        // só interessa enquanto ainda esperamos a tag
        if (!mounted || _ocupado || _etapa != _Etapa.aguardando) return;
        // m vazio = a pessoa fechou a janela do iPhone
        _set(_Etapa.erro, m.isEmpty ? 'Leitura cancelada.' : m);
      },
    );
  }

  // ------------------------------------------------------------ ler e abrir
  Future<void> _ler(NfcTag tagCrua) async {
    if (_ocupado) return;
    _ocupado = true;
    HapticFeedback.mediumImpact();
    _set(_Etapa.lendo);
    try {
      final tag = _nfc.ler(tagCrua);
      _tag = tag;
      final sala = await _salas.resolverTag(tag);
      await _nfc.parar(sucessoIos: sala.nome);
      _sala = sala;
      _set(_Etapa.sucesso);
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 650));
      _abrirSala(sala);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        await _nfc.parar(erroIos: 'Tag não vinculada');
        _set(_Etapa.naoVinculada);
      } else {
        await _nfc.parar(erroIos: 'Sem conexão');
        _set(_Etapa.erro, e.message);
      }
    } on NfcException catch (e) {
      await _nfc.parar(erroIos: e.message);
      _set(_Etapa.erro, e.message);
    }
  }

  void _abrirSala(SalaModel sala) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SalaDetailScreen(salaId: sala.id)),
    );
  }

  // ------------------------------------------------------------ gravar tag
  Future<void> _gravar(NfcTag tagCrua) async {
    if (_ocupado) return;
    _ocupado = true;
    HapticFeedback.mediumImpact();
    final sala = widget.gravarEm!;
    _set(_Etapa.lendo);
    try {
      final tag = _nfc.ler(tagCrua);
      _tag = tag;
      try {
        _gravouLink = sala.codigo.isNotEmpty && await _nfc.gravarSala(tagCrua, sala.codigo);
      } catch (e) {
        if (kDebugMode) debugPrint('[nfc] gravação falhou: $e');
        _gravouLink = false;
      }
      await _nfc.parar(sucessoIos: 'Tag configurada');
      final anterior = await _salas.vincularTag(sala: sala, uid: tag.uid);
      _sala = sala;
      HapticFeedback.heavyImpact();
      _set(_Etapa.sucesso, anterior == null ? '' : 'Ela estava vinculada a "$anterior" e foi transferida.');
    } on ApiException catch (e) {
      await _nfc.parar(erroIos: 'Falhou');
      _set(_Etapa.erro, e.message);
    } on NfcException catch (e) {
      await _nfc.parar(erroIos: 'Falhou');
      _set(_Etapa.erro, e.message);
    }
  }

  // ------------------------------------------------------------ vincular tag lida
  Future<void> _escolherSalaParaVincular() async {
    final tag = _tag;
    if (tag == null) return;
    final sala = await showModalBottomSheet<SalaModel>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _EscolherSala(service: _salas),
    );
    if (sala == null || !mounted) return;
    setState(() => _ocupado = true);
    try {
      final anterior = await _salas.vincularTag(sala: sala, uid: tag.uid);
      HapticFeedback.heavyImpact();
      _sala = sala;
      _gravouLink = true;
      _etapaVeioDeVinculo = true;
      _set(_Etapa.sucesso, anterior == null ? '' : 'Ela estava vinculada a "$anterior" e foi transferida.');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  // ------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text(_gravando ? 'Configurar tag NFC' : 'Escanear sala',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: dark ? AppGradients.night : AppGradients.hero),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(children: [
              const Spacer(flex: 2),
              _ilustracao(),
              const SizedBox(height: 40),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey('$_etapa$_mensagem'),
                  children: [
                    Text(_titulo(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                    const SizedBox(height: 10),
                    Text(_texto(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 14.5, height: 1.45)),
                    if (_tag != null && (_etapa == _Etapa.naoVinculada || (_gravando && _etapa == _Etapa.sucesso))) ...[
                      const SizedBox(height: 14),
                      _chip(Icons.memory_rounded, 'Tag ${_tag!.uid}'),
                    ],
                  ],
                ),
              ),
              const Spacer(flex: 3),
              ..._acoes(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String texto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(.14)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: AppColors.cyan),
          const SizedBox(width: 6),
          Text(texto,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        ]),
      );

  String _titulo() {
    switch (_etapa) {
      case _Etapa.preparando:
        return 'Preparando o NFC…';
      case _Etapa.aguardando:
        return _gravando ? 'Encoste a tag nova' : 'Encoste o celular na tag';
      case _Etapa.lendo:
        return _gravando ? 'Configurando a tag…' : 'Tag lida! Procurando a sala…';
      case _Etapa.sucesso:
        return (_gravando || _etapaVeioDeVinculo) ? 'Tag pronta!' : (_sala?.nome ?? 'Sala encontrada');
      case _Etapa.naoVinculada:
        return 'Tag sem sala';
      case _Etapa.erro:
        return 'Não deu certo';
    }
  }

  bool _etapaVeioDeVinculo = false;

  String _texto() {
    switch (_etapa) {
      case _Etapa.preparando:
        return '';
      case _Etapa.aguardando:
        if (_gravando) {
          return 'Segure o celular encostado na tag que vai ficar na porta de "${widget.gravarEm!.nome}" até vibrar.';
        }
        return _nfc.isIOS
            ? 'Encoste o topo do iPhone na tag fixada na porta da sala.'
            : 'Encoste a parte de trás do celular na tag fixada na porta. A sala abre sozinha.';
      case _Etapa.lendo:
        return 'Só um instante.';
      case _Etapa.sucesso:
        if (_gravando || _etapaVeioDeVinculo) {
          final base = _gravouLink
              ? 'Agora é só encostar o celular nesta tag para abrir "${_sala?.nome}".'
              : 'Tag vinculada a "${_sala?.nome}". Esta tag não aceita gravação, então abra o app antes de encostar.';
          return _mensagem.isEmpty ? base : '$base\n$_mensagem';
        }
        return 'Abrindo os sensores e a câmera…';
      case _Etapa.naoVinculada:
        return _admin
            ? 'Esta tag ainda não está ligada a nenhuma sala. Escolha a sala da porta onde ela está.'
            : 'Esta tag ainda não está ligada a nenhuma sala. Peça a um administrador para configurar.';
      case _Etapa.erro:
        return _mensagem.isEmpty ? 'Tente encostar de novo, segurando por um segundo.' : _mensagem;
    }
  }

  List<Widget> _acoes() {
    Widget principal(String texto, IconData icon, VoidCallback? onTap) => SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
            onPressed: onTap,
            icon: _ocupado
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(icon),
            label: Text(texto),
          ),
        );
    Widget secundario(String texto, VoidCallback onTap) => TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          child: Text(texto),
        );

    switch (_etapa) {
      case _Etapa.naoVinculada:
        return [
          if (_admin) principal('Vincular a uma sala', Icons.link_rounded, _ocupado ? null : _escolherSalaParaVincular),
          const SizedBox(height: 8),
          secundario('Ler outra tag', _iniciar),
        ];
      case _Etapa.erro:
        return [
          principal('Tentar de novo', Icons.refresh_rounded, _iniciar),
          if (kDebugMode && !_gravando) secundario('Simular leitura (teste)', _simular),
        ];
      case _Etapa.sucesso:
        if (_gravando || _etapaVeioDeVinculo) {
          return [
            principal('Abrir ${_sala?.nome ?? 'sala'}', Icons.arrow_forward_rounded, () => _abrirSala(_sala!)),
            const SizedBox(height: 8),
            secundario(_gravando ? 'Configurar outra tag' : 'Ler outra tag', _iniciar),
          ];
        }
        return const [SizedBox(height: 52)];
      case _Etapa.aguardando:
        return [
          if (_nfc.isIOS) principal('Escanear de novo', Icons.nfc_rounded, _iniciar),
          if (kDebugMode && !_gravando) secundario('Simular leitura (teste)', _simular),
          if (!_nfc.isIOS && !kDebugMode) const SizedBox(height: 52),
        ];
      default:
        return const [SizedBox(height: 52)];
    }
  }

  Future<void> _simular() async {
    _set(_Etapa.lendo);
    try {
      final sala = await _salas.resolverTag(const TagLida(uid: 'SIMULADA', conteudo: 'NFC-GALPAO1-LINHA-A'));
      _sala = sala;
      _set(_Etapa.sucesso);
      await Future.delayed(const Duration(milliseconds: 500));
      _abrirSala(sala);
    } on ApiException catch (e) {
      _set(_Etapa.erro, e.message);
    }
  }

  // ------------------------------------------------------------ ilustração
  Widget _ilustracao() {
    final sucesso = _etapa == _Etapa.sucesso;
    final erro = _etapa == _Etapa.erro || _etapa == _Etapa.naoVinculada;
    final cor = sucesso ? AppColors.statusNormal : (erro ? AppColors.statusAtencao : AppColors.cyan);
    final icone = sucesso
        ? Icons.check_rounded
        : _etapa == _Etapa.naoVinculada
            ? Icons.link_off_rounded
            : erro
                ? Icons.priority_high_rounded
                : Icons.contactless_rounded;
    final pulsando = _etapa == _Etapa.aguardando || _etapa == _Etapa.lendo || _etapa == _Etapa.preparando;

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(alignment: Alignment.center, children: [
        if (pulsando)
          AnimatedBuilder(
            animation: _radar,
            builder: (_, __) => CustomPaint(size: const Size(240, 240), painter: _RadarPainter(_radar.value, cor)),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          width: sucesso ? 132 : 116,
          height: sucesso ? 132 : 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cor.withOpacity(.16),
            border: Border.all(color: cor.withOpacity(.55), width: 2),
            boxShadow: [BoxShadow(color: cor.withOpacity(.35), blurRadius: 40)],
          ),
          child: _etapa == _Etapa.lendo
              ? const Padding(
                  padding: EdgeInsets.all(38),
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                )
              : TweenAnimationBuilder<double>(
                  key: ValueKey(icone),
                  tween: Tween(begin: .4, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Icon(icone, color: Colors.white, size: 54),
                ),
        ),
      ]),
    );
  }
}

/// Ondas saindo do centro (sensação de "procurando a tag").
class _RadarPainter extends CustomPainter {
  final double t;
  final Color cor;
  _RadarPainter(this.t, this.cor);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final f = (t + i / 3) % 1.0;
      final r = 58 + (maxR - 58) * f;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = cor.withOpacity((1 - f) * .55);
      canvas.drawCircle(c, r, p);
    }
    // arco girando
    final arco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(.5);
    canvas.drawArc(Rect.fromCircle(center: c, radius: 66), t * 2 * math.pi, math.pi / 3, false, arco);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.cor != cor;
}

/// Lista de salas para vincular a tag.
class _EscolherSala extends StatefulWidget {
  final SalaService service;
  const _EscolherSala({required this.service});

  @override
  State<_EscolherSala> createState() => _EscolherSalaState();
}

class _EscolherSalaState extends State<_EscolherSala> {
  List<SalaModel>? _lista;
  String? _erro;
  String _busca = '';

  @override
  void initState() {
    super.initState();
    widget.service.getSalas().then((l) {
      if (mounted) setState(() => _lista = l);
    }).catchError((e) {
      if (mounted) setState(() => _erro = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _busca.trim().toLowerCase();
    final lista = (_lista ?? const <SalaModel>[])
        .where((s) => q.isEmpty || '${s.nome} ${s.codigo} ${s.setor}'.toLowerCase().contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * .72,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 4),
          child: Text('Em qual sala está esta tag?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Text('Ao encostar o celular nela, o app vai abrir a sala escolhida.',
              style: TextStyle(color: mutedText(context), fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (v) => setState(() => _busca = v),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar sala'),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _erro != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_erro!, textAlign: TextAlign.center)))
              : _lista == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: lista.length,
                      itemBuilder: (_, i) {
                        final s = lista[i];
                        return Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.pop(context, s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Row(children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                      color: AppColors.electric.withOpacity(.13), borderRadius: BorderRadius.circular(13)),
                                  child: const Icon(Icons.meeting_room_rounded, color: AppColors.electric),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(s.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    Text([s.codigo, s.setor].where((x) => x.isNotEmpty).join(' · '),
                                        style: TextStyle(color: mutedText(context), fontSize: 12.5)),
                                  ]),
                                ),
                                Icon(Icons.chevron_right_rounded, color: mutedText(context)),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

/// Erros de NFC com mensagem amigável para exibir na UI.
class NfcException implements Exception {
  final String message;
  NfcException(this.message);
  @override
  String toString() => message;
}

enum NfcEstadoAparelho { pronto, desligado, semNfc }

/// O que foi lido de uma tag física.
class TagLida {
  /// Número de série gravado de fábrica (ex.: 04A2B3C4D5E680). Sempre existe.
  final String uid;

  /// Código da sala quando a tag foi gravada pelo app (indusense://app/sala/IND-001).
  final String? salaCodigo;

  /// Texto/URL gravado na tag por outro programa (ex.: "NFC-GALPAO1-LINHA-A").
  final String? conteudo;

  const TagLida({required this.uid, this.salaCodigo, this.conteudo});

  /// Ids para procurar a sala, do mais específico ao mais genérico.
  List<String> get candidatos => [if (conteudo != null && conteudo!.isNotEmpty) conteudo!, uid];

  @override
  String toString() => 'TagLida(uid: $uid, sala: $salaCodigo, conteudo: $conteudo)';
}

/// Leitura e gravação das tags NFC fixadas na porta das salas (nfc_manager 4.x).
///
/// Gravamos na tag um link `indusense://app/sala/<codigo>` e o registro de app
/// do Android: assim, no Android, encostar o celular abre o InduSense direto
/// na sala mesmo com o app fechado.
class NfcService {
  NfcService._();
  static final NfcService instance = NfcService._();
  factory NfcService() => instance;

  static const esquema = 'indusense';
  static const pacoteAndroid = 'com.example.indusense';

  static Uri linkDaSala(String codigo) => Uri(scheme: esquema, host: 'app', path: '/sala/$codigo');

  /// Extrai o código de "indusense://app/sala/IND-001" (ou null).
  static String? codigoDoLink(String? link) {
    if (link == null) return null;
    final uri = Uri.tryParse(link.trim());
    if (uri == null || uri.scheme != esquema) return null;
    final seg = uri.pathSegments;
    final i = seg.indexOf('sala');
    if (i >= 0 && i + 1 < seg.length && seg[i + 1].isNotEmpty) return Uri.decodeComponent(seg[i + 1]);
    return null;
  }

  bool get plataformaSuportada =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<NfcEstadoAparelho> estado() async {
    if (!plataformaSuportada) return NfcEstadoAparelho.semNfc;
    try {
      switch (await NfcManager.instance.checkAvailability()) {
        case NfcAvailability.enabled:
          return NfcEstadoAparelho.pronto;
        case NfcAvailability.disabled:
          return NfcEstadoAparelho.desligado;
        case NfcAvailability.unsupported:
          return NfcEstadoAparelho.semNfc;
      }
    } catch (_) {
      return NfcEstadoAparelho.semNfc;
    }
  }

  static String mensagemEstado(NfcEstadoAparelho e) {
    switch (e) {
      case NfcEstadoAparelho.pronto:
        return '';
      case NfcEstadoAparelho.desligado:
        return 'O NFC está desligado. Ative em Configurações do celular > Conexões > NFC.';
      case NfcEstadoAparelho.semNfc:
        return kIsWeb || defaultTargetPlatform == TargetPlatform.macOS
            ? 'Este aparelho não lê NFC. Use o app no celular (Android ou iPhone).'
            : 'Este celular não tem NFC.';
    }
  }

  bool _sessaoAberta = false;
  bool get sessaoAberta => _sessaoAberta;

  /// Abre a leitura. No Android fica ativa até [parar]; no iPhone abre a
  /// janela do sistema e fecha depois da primeira tag.
  ///
  /// [aoDescobrir] recebe a tag crua: use [ler] para extrair os dados e
  /// [gravarSala] para gravar (enquanto a tag ainda está encostada).
  Future<void> iniciar({
    required Future<void> Function(NfcTag tag) aoDescobrir,
    void Function(String mensagem)? aoErro,
    String mensagemIos = 'Aproxime o topo do iPhone da tag NFC da sala',
  }) async {
    final e = await estado();
    if (e != NfcEstadoAparelho.pronto) {
      aoErro?.call(mensagemEstado(e));
      return;
    }
    await parar();
    try {
      _sessaoAberta = true;
      await NfcManager.instance.startSession(
        // iso18092 (FeliCa) fica de fora: no iPhone exigiria configuração extra e as tags comuns não usam.
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        alertMessageIos: mensagemIos,
        // a sessão fica aberta até chamarmos parar(): dá tempo de gravar a tag no iPhone
        invalidateAfterFirstReadIos: false,
        noPlatformSoundsAndroid: false,
        onSessionErrorIos: (err) {
          _sessaoAberta = false;
          if (err.code == NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled ||
              err.code == NfcReaderErrorCodeIos.readerSessionInvalidationErrorFirstNDEFTagRead) {
            aoErro?.call('');
          } else {
            aoErro?.call('Leitura NFC encerrada: ${err.message}');
          }
        },
        onDiscovered: (tag) async {
          try {
            await aoDescobrir(tag);
          } catch (e) {
            if (kDebugMode) debugPrint('[nfc] erro ao tratar tag: $e');
            aoErro?.call(e is NfcException ? e.message : 'Não foi possível ler esta tag. Tente de novo.');
          }
        },
      );
    } catch (e) {
      _sessaoAberta = false;
      if (kDebugMode) debugPrint('[nfc] startSession falhou: $e');
      aoErro?.call('Não foi possível iniciar a leitura NFC.');
    }
  }

  Future<void> parar({String? sucessoIos, String? erroIos}) async {
    if (!_sessaoAberta) return;
    _sessaoAberta = false;
    try {
      await NfcManager.instance.stopSession(alertMessageIos: sucessoIos, errorMessageIos: erroIos);
    } catch (_) {
      // a sessão pode já ter sido encerrada pelo sistema
    }
  }

  // ------------------------------------------------------------------ leitura

  /// UID + conteúdo NDEF da tag.
  TagLida ler(NfcTag tag) {
    final uid = _uid(tag);
    if (uid == null) throw NfcException('Tag NFC não reconhecida. Tente de novo.');

    String? conteudo;
    String? codigo;
    try {
      final ndef = Ndef.from(tag);
      final msg = ndef?.cachedMessage;
      if (msg != null) {
        for (final r in msg.records) {
          final texto = _textoDoRegistro(r);
          if (texto == null || texto.isEmpty) continue;
          codigo ??= codigoDoLink(texto);
          conteudo ??= texto;
        }
      }
    } catch (_) {
      // tag sem NDEF: usamos só o UID
    }
    return TagLida(uid: uid, salaCodigo: codigo, conteudo: codigo != null ? null : conteudo);
  }

  String? _uid(NfcTag tag) {
    Uint8List? id;
    if (defaultTargetPlatform == TargetPlatform.android) {
      id = NfcTagAndroid.from(tag)?.id;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      id = MiFareIos.from(tag)?.identifier ??
          Iso15693Ios.from(tag)?.identifier ??
          Iso7816Ios.from(tag)?.identifier ??
          FeliCaIos.from(tag)?.currentIDm;
    }
    if (id == null || id.isEmpty) return null;
    return id.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  static const _prefixosUri = [
    '', 'http://www.', 'https://www.', 'http://', 'https://', 'tel:', 'mailto:', 'ftp://anonymous:anonymous@',
    'ftp://ftp.', 'ftps://', 'sftp://', 'smb://', 'nfs://', 'ftp://', 'dav://', 'news:', 'telnet://', 'imap:',
    'rtsp://', 'urn:', 'pop:', 'sip:', 'sips:', 'tftp:', 'btspp://', 'btl2cap://', 'btgoep://', 'tcpobex://',
    'irdaobex://', 'file://', 'urn:epc:id:', 'urn:epc:tag:', 'urn:epc:pat:', 'urn:epc:raw:', 'urn:epc:', 'urn:nfc:',
  ];

  /// Texto de um registro "T" (texto) ou "U" (link). Outros tipos: null.
  static String? _textoDoRegistro(NdefRecord r) {
    final p = r.payload;
    if (p.isEmpty) return null;
    if (r.typeNameFormat == TypeNameFormat.wellKnown && r.type.length == 1) {
      if (r.type[0] == 0x55) {
        // 'U' — 1º byte é o prefixo abreviado
        final prefixo = p[0] < _prefixosUri.length ? _prefixosUri[p[0]] : '';
        return prefixo + utf8.decode(p.sublist(1), allowMalformed: true);
      }
      if (r.type[0] == 0x54) {
        // 'T' — status byte + código do idioma + texto
        final langLen = p[0] & 0x3F;
        if (1 + langLen > p.length) return null;
        return utf8.decode(p.sublist(1 + langLen), allowMalformed: true).trim();
      }
    }
    if (r.typeNameFormat == TypeNameFormat.absoluteUri) {
      return utf8.decode(r.type, allowMalformed: true);
    }
    return null;
  }

  // ------------------------------------------------------------------ gravação

  /// Grava na tag o link da sala (+ registro do app no Android).
  /// Retorna false se a tag não aceita gravação (ex.: protegida) — o vínculo
  /// pelo número de série continua funcionando.
  Future<bool> gravarSala(NfcTag tag, String codigo) async {
    final uri = utf8.encode(linkDaSala(codigo).toString());
    final registros = <NdefRecord>[
      NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList([0x55]), // 'U'
        identifier: Uint8List(0),
        payload: Uint8List.fromList([0x00, ...uri]),
      ),
      // Android Application Record: garante que o InduSense abra (e não o navegador)
      NdefRecord(
        typeNameFormat: TypeNameFormat.external,
        type: Uint8List.fromList(utf8.encode('android.com:pkg')),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(utf8.encode(pacoteAndroid)),
      ),
    ];
    final mensagem = NdefMessage(records: registros);

    final ndef = Ndef.from(tag);
    if (ndef != null) {
      if (!ndef.isWritable) return false;
      if (ndef.maxSize > 0 && mensagem.byteLength > ndef.maxSize) {
        // tag pequena demais: grava só o link
        await ndef.write(message: NdefMessage(records: [registros.first]));
        return true;
      }
      await ndef.write(message: mensagem);
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final formatavel = NdefFormatableAndroid.from(tag);
      if (formatavel != null) {
        await formatavel.format(mensagem);
        return true;
      }
    }
    return false;
  }
}

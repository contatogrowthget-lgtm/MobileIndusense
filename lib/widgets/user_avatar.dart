import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/user_model.dart';

/// Foto do usuário (data URL vinda da API) ou as iniciais num degradê da marca.
/// [ring] desenha o anel colorido em volta, como no cabeçalho do perfil.
class UserAvatar extends StatelessWidget {
  final UserModel? user;
  final double size;
  final bool ring;

  /// Mostra esta imagem no lugar da foto salva (prévia antes de salvar).
  final Uint8List? preview;

  /// true = força as iniciais (prévia de "remover foto").
  final bool semFoto;

  /// Cor do vão entre o anel e a foto (padrão: fundo da tela).
  final Color? gapColor;

  const UserAvatar({
    super.key,
    required this.user,
    this.size = 44,
    this.ring = false,
    this.preview,
    this.semFoto = false,
    this.gapColor,
  });

  static String? _ultimoDataUrl;
  static Uint8List? _ultimoBytes;

  /// Decodifica o base64 uma vez só (a foto é desenhada em várias telas).
  static Uint8List? bytesDe(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    if (dataUrl == _ultimoDataUrl) return _ultimoBytes;
    try {
      final i = dataUrl.indexOf('base64,');
      final b = base64Decode(i >= 0 ? dataUrl.substring(i + 7) : dataUrl);
      _ultimoDataUrl = dataUrl;
      _ultimoBytes = b;
      return b;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = semFoto ? null : (preview ?? bytesDe(user?.avatar));
    final iniciais = user?.iniciais ?? '?';

    // Material dá o estilo de texto certo também durante a animação Hero.
    final Widget miolo = Material(
      type: MaterialType.transparency,
      child: ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: bytes != null
              ? Image.memory(bytes,
                  key: ValueKey(bytes.length ^ bytes.hashCode),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  width: size,
                  height: size)
              : DecoratedBox(
                  key: const ValueKey('iniciais'),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF123A8C), AppColors.electric, Color(0xFF0E7C86)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      iniciais,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: size * 0.36,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    ),
    );

    if (!ring) return miolo;

    final borda = size * 0.045;
    return Container(
      padding: EdgeInsets.all(borda),
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.brand),
      child: Container(
        padding: EdgeInsets.all(borda),
        decoration: BoxDecoration(shape: BoxShape.circle, color: gapColor ?? Theme.of(context).scaffoldBackgroundColor),
        child: miolo,
      ),
    );
  }
}

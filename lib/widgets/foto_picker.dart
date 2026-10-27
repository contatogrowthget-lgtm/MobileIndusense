import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import 'ui.dart';

/// Resultado da escolha: nova foto (JPEG quadrado já reduzido) ou "remover".
class FotoEscolha {
  final Uint8List? jpeg;
  final bool remover;
  const FotoEscolha.nova(Uint8List this.jpeg) : remover = false;
  const FotoEscolha.remover()
      : jpeg = null,
        remover = true;
}

/// Câmera só existe no celular; no Mac/Windows/Web abre o seletor de arquivos.
bool get cameraDisponivel =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

/// Mostra "Tirar foto / Escolher da galeria / Remover" e devolve a foto pronta para enviar.
Future<FotoEscolha?> escolherFoto(BuildContext context, {required bool temFoto}) async {
  final origem = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => _FotoSheet(temFoto: temFoto),
  );
  if (origem == null || !context.mounted) return null;
  if (origem == 'remover') return const FotoEscolha.remover();

  XFile? arquivo;
  try {
    arquivo = await ImagePicker().pickImage(
      source: origem == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.front,
    );
  } on PlatformException catch (e) {
    if (context.mounted) {
      final negado = e.code.contains('denied') || e.code.contains('access');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(negado
            ? 'Sem permissão para ${origem == 'camera' ? 'a câmera' : 'as fotos'}. Libere nos Ajustes do aparelho.'
            : 'Não foi possível abrir ${origem == 'camera' ? 'a câmera' : 'a galeria'}.'),
      ));
    }
    return null;
  }
  if (arquivo == null) return null;

  final bytes = await arquivo.readAsBytes();
  final jpeg = await compute(prepararAvatar, bytes);
  if (jpeg == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato de imagem não suportado. Use JPG ou PNG.')),
      );
    }
    return null;
  }
  return FotoEscolha.nova(jpeg);
}

/// Corta no centro em 512×512, corrige a rotação da câmera e comprime em JPEG
/// (a API aceita fotos de até ~300 KB).
Uint8List? prepararAvatar(Uint8List bytes) {
  final original = img.decodeImage(bytes);
  if (original == null) return null;
  final girada = img.bakeOrientation(original);
  final quadrada = img.copyResizeCropSquare(girada, size: 512, interpolation: img.Interpolation.average);
  var qualidade = 86;
  var saida = img.encodeJpg(quadrada, quality: qualidade);
  while (saida.length > 220 * 1024 && qualidade > 40) {
    qualidade -= 12;
    saida = img.encodeJpg(quadrada, quality: qualidade);
  }
  return saida;
}

class _FotoSheet extends StatelessWidget {
  final bool temFoto;
  const _FotoSheet({required this.temFoto});

  @override
  Widget build(BuildContext context) {
    Widget opcao(IconData icon, Color cor, String titulo, String sub, String valor) => Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context, valor);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: cor.withOpacity(.14), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: cor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(titulo,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: valor == 'remover' ? AppColors.statusCritico : null)),
                    const SizedBox(height: 2),
                    Text(sub, style: TextStyle(color: mutedText(context), fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Text('Foto do perfil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.3)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Text('Aparece no app, no painel web e para a sua equipe.',
              style: TextStyle(color: mutedText(context), fontSize: 13)),
        ),
        if (cameraDisponivel)
          opcao(Icons.photo_camera_rounded, AppColors.electric, 'Tirar foto', 'Usar a câmera agora', 'camera'),
        opcao(
          Icons.photo_library_rounded,
          AppColors.cyan,
          cameraDisponivel ? 'Escolher da galeria' : 'Escolher imagem',
          cameraDisponivel ? 'Uma foto que já está no aparelho' : 'JPG ou PNG do computador',
          'galeria',
        ),
        if (temFoto)
          opcao(Icons.delete_outline_rounded, AppColors.statusCritico, 'Remover foto', 'Volta a mostrar as suas iniciais',
              'remover'),
      ]),
    );
  }
}

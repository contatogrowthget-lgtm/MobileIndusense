import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/camera_model.dart';
import 'glass.dart';
import 'mjpeg_view.dart';

/// Cartão grande da câmera no Início: vídeo ao vivo ocupando o cartão,
/// nome da sala por cima, botão de abrir e botões de vidro embaixo.
class CameraHeroCard extends StatefulWidget {
  final CameraModel camera;
  final bool ativo;
  final VoidCallback onAbrir;
  final VoidCallback? onAlertas;
  final int alertas;

  const CameraHeroCard({
    super.key,
    required this.camera,
    required this.onAbrir,
    this.ativo = true,
    this.onAlertas,
    this.alertas = 0,
  });

  @override
  State<CameraHeroCard> createState() => _CameraHeroCardState();
}

class _CameraHeroCardState extends State<CameraHeroCard> {
  bool _videoOk = false;

  @override
  Widget build(BuildContext context) {
    final cam = widget.camera;
    final url = cam.videoUrl;
    final temVideo = url != null && widget.ativo;
    final aoVivo = temVideo && _videoOk;
    final titulo = (cam.salaNome ?? cam.nome).replaceFirst(' de ', ' de\n');

    return AspectRatio(
      aspectRatio: 1.05,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(fit: StackFit.expand, children: [
          // fundo: vídeo ou degradê
          const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.hero)),
          if (temVideo)
            MjpegView(
              url: url,
              fit: BoxFit.cover,
              onStateChanged: (ok) {
                if (mounted) setState(() => _videoOk = ok);
              },
              placeholder: const SizedBox.shrink(),
              errorWidget: const SizedBox.shrink(),
            ),
          if (!aoVivo)
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(temVideo ? Icons.videocam_rounded : Icons.videocam_off_rounded, color: Colors.white38, size: 46),
                const SizedBox(height: 8),
                Text(temVideo ? 'Conectando ao vídeo…' : 'Câmera sem vídeo',
                    style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600)),
              ]),
            ),
          // escurece topo e base para o texto aparecer
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .35, .65, 1],
                colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xAA000000)],
              ),
            ),
          ),
          // título + abrir
          Positioned(
            left: 22,
            top: 20,
            right: 90,
            child: Text(
              titulo,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: -.6, height: 1.12),
            ),
          ),
          Positioned(
            right: 18,
            top: 18,
            child: GlassCircle(
              claro: true,
              size: 58,
              tooltip: 'Abrir câmera',
              onTap: widget.onAbrir,
              child: const Icon(Icons.north_east_rounded, color: Colors.black87, size: 24),
            ),
          ),
          // base: ao vivo + números + alertas
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(children: [
              GlassCircle(
                tooltip: 'Pessoas na cena',
                onTap: widget.onAbrir,
                child: _numero(Icons.groups_rounded, cam.online ? '${cam.pessoas}' : '–'),
              ),
              const SizedBox(width: 10),
              GlassCircle(
                tooltip: 'Conformidade de EPI',
                onTap: widget.onAbrir,
                child: _numero(Icons.health_and_safety_rounded, cam.online ? '${cam.epiConformidade}%' : '–'),
              ),
              const Spacer(),
              GlassCircle(
                tooltip: aoVivo ? 'Ao vivo' : 'Sem sinal',
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: aoVivo ? const Color(0xFF4ADE80) : Colors.white38,
                    boxShadow: aoVivo ? [const BoxShadow(color: Color(0xAA4ADE80), blurRadius: 10)] : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GlassCircle(
                tooltip: 'Alertas',
                onTap: widget.onAlertas,
                child: Stack(clipBehavior: Clip.none, children: [
                  const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                  if (widget.alertas > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.statusCritico, borderRadius: BorderRadius.circular(8)),
                        child: Text('${widget.alertas}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 10),
              GlassCircle(
                tooltip: 'Tela cheia',
                onTap: widget.onAbrir,
                child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 20),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _numero(IconData icon, String valor) => Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 16),
        Text(valor, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, height: 1.1)),
      ]);
}

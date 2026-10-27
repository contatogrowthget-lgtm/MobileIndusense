import 'package:flutter/material.dart';

import '../models/camera_model.dart';
import 'mjpeg_view.dart';

/// Quadro da câmera com vídeo ao vivo, usado na tela da sala.
/// Toque (ou o botão de expandir) abre a câmera em tela cheia.
class CameraLiveCard extends StatefulWidget {
  final CameraModel camera;
  final VoidCallback? onExpand;

  /// false = não abre o vídeo (aba fora da tela), economiza rede e bateria.
  final bool ativo;

  const CameraLiveCard({super.key, required this.camera, this.onExpand, this.ativo = true});

  @override
  State<CameraLiveCard> createState() => _CameraLiveCardState();
}

class _CameraLiveCardState extends State<CameraLiveCard> {
  bool _videoOk = false;

  @override
  Widget build(BuildContext context) {
    final cam = widget.camera;
    final url = cam.videoUrl;
    // Tenta o vídeo sempre que houver endereço, igual à tela cheia.
    // O "online" da API pode atrasar alguns segundos; se o vídeo não vier,
    // o MjpegView mostra "Sem sinal" e fica tentando reconectar sozinho.
    final temVideo = url != null && widget.ativo;
    final aoVivo = temVideo && _videoOk;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Material(
          color: const Color(0xFF0B1118),
          child: InkWell(
            onTap: url != null ? widget.onExpand : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (temVideo)
                  MjpegView(
                    url: url,
                    onStateChanged: (ok) {
                      if (mounted) setState(() => _videoOk = ok);
                    },
                    errorWidget: _Offline(
                      icon: Icons.videocam_off_rounded,
                      titulo: 'Sem sinal do vídeo',
                      detalhe: 'Tentando reconectar em ${cam.visionOrigin ?? url}',
                    ),
                  )
                else
                  _Offline(
                    icon: url == null ? Icons.videocam_outlined : Icons.wifi_off_rounded,
                    titulo: url == null ? 'Sem vídeo ao vivo' : 'Câmera sem conexão',
                    detalhe: url == null
                        ? 'Câmera de demonstração, sem sistema de visão ligado.'
                        : (cam.ultimoContatoRelativo != null
                            ? 'Última comunicação: ${cam.ultimoContatoRelativo!.toLowerCase()}'
                            : 'Ligue o sistema de câmera no computador.'),
                  ),
                // topo
                Positioned(
                  left: 12,
                  top: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _Pill(
                        cor: aoVivo ? const Color(0xFFE5484D) : Colors.white24,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (aoVivo) ...[
                            Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                          ],
                          Text(aoVivo ? 'AO VIVO' : 'SEM VÍDEO',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .5)),
                        ]),
                      ),
                      const Spacer(),
                      Flexible(
                        child: _Pill(
                          cor: Colors.black54,
                          child: Text(cam.nome,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
                // rodapé
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 22, 6, 6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC000000)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cam.online || aoVivo
                                ? '${cam.pessoas} ${cam.pessoas == 1 ? 'pessoa detectada' : 'pessoas detectadas'}'
                                : 'Sem conexão',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (url != null)
                          IconButton(
                            tooltip: 'Abrir em tela cheia',
                            onPressed: widget.onExpand,
                            icon: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 20),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Color cor;
  final Widget child;
  const _Pill({required this.cor, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(8)),
        child: child,
      );
}

class _Offline extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String detalhe;
  const _Offline({required this.icon, required this.titulo, required this.detalhe});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white54, size: 30),
            const SizedBox(height: 8),
            Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Text(detalhe,
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
          ]),
        ),
      );
}

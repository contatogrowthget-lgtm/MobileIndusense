import 'dart:ui';

import 'package:flutter/material.dart';

/// Botão redondo de "vidro" (fundo desfocado) para usar por cima de fotos e vídeo.
class GlassCircle extends StatelessWidget {
  final Widget child;
  final double size;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool claro;

  const GlassCircle({super.key, required this.child, this.size = 48, this.onTap, this.tooltip, this.claro = false});

  @override
  Widget build(BuildContext context) {
    Widget w = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: claro ? Colors.white : Colors.white.withOpacity(.16),
          shape: CircleBorder(side: BorderSide(color: Colors.white.withOpacity(claro ? 1 : .22))),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: size, height: size, child: Center(child: child)),
          ),
        ),
      ),
    );
    if (tooltip != null) w = Tooltip(message: tooltip!, child: w);
    return w;
  }
}

/// Pílula de vidro com texto (ex.: "● AO VIVO").
class GlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GlassPill({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8)});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.28),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: child,
          ),
        ),
      );
}

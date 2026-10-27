import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Imagem protegida da API (foto da ocorrência): envia o token junto.
class AuthImage extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const AuthImage({super.key, required this.path, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: ApiClient.authHeaders(),
      builder: (context, snap) {
        if (!snap.hasData) return const ColoredBox(color: Colors.black12);
        return Image.network(
          ApiClient.absoluteUrl(path),
          headers: snap.data,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Colors.black12,
            child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.black38)),
          ),
        );
      },
    );
  }
}

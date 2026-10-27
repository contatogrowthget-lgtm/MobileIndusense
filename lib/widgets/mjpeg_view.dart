import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Vídeo ao vivo MJPEG (o /video_feed do sistema de câmera).
///
/// Lê o stream e separa cada quadro JPEG (marcadores FF D8 ... FF D9).
/// Reconecta sozinho se a câmera cair. No Flutter Web, onde o navegador
/// não entrega o stream aos poucos, usa fotos seguidas de /snapshot.jpg.
class MjpegView extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final ValueChanged<bool>? onStateChanged;
  final Widget? placeholder;
  final Widget? errorWidget;

  const MjpegView({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.onStateChanged,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<MjpegView> createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  http.Client? _client;
  StreamSubscription<List<int>>? _sub;
  Timer? _retry;
  Timer? _webTimer;
  Uint8List? _frame;
  Uint8List _pending = Uint8List(0);
  bool _ok = false;
  bool _failed = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant MjpegView old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _stop();
      _start();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stop();
    super.dispose();
  }

  void _setOk(bool ok) {
    if (_ok == ok) return;
    _ok = ok;
    widget.onStateChanged?.call(ok);
  }

  void _start() {
    if (kIsWeb) {
      _startWebPolling();
    } else {
      _connect();
    }
  }

  void _stop() {
    _retry?.cancel();
    _webTimer?.cancel();
    _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
    _pending = Uint8List(0);
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _sub?.cancel();
    _client?.close();
    _client = null;
    _setOk(false);
    if (mounted) setState(() => _failed = true);
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 3), () {
      if (!_disposed) _connect();
    });
  }

  Future<void> _connect() async {
    try {
      final client = http.Client();
      _client = client;
      final res = await client
          .send(http.Request('GET', Uri.parse(widget.url)))
          .timeout(const Duration(seconds: 8));
      if (_disposed) return;
      if (res.statusCode != 200) {
        _scheduleRetry();
        return;
      }
      _sub = res.stream.listen(
        _onData,
        onError: (_) => _scheduleRetry(),
        onDone: _scheduleRetry,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _onData(List<int> chunk) {
    final data = Uint8List(_pending.length + chunk.length)
      ..setRange(0, _pending.length, _pending)
      ..setRange(_pending.length, _pending.length + chunk.length, chunk);

    Uint8List? latest;
    var pos = 0;
    while (true) {
      final soi = _find(data, 0xD8, pos);
      if (soi < 0) {
        // guarda só o último byte (pode ser o 0xFF de um marcador cortado ao meio)
        pos = data.isEmpty ? 0 : data.length - 1;
        break;
      }
      final eoi = _find(data, 0xD9, soi + 2);
      if (eoi < 0) {
        pos = soi;
        break;
      }
      latest = Uint8List.sublistView(data, soi, eoi + 2);
      pos = eoi + 2;
    }

    _pending = pos < data.length ? Uint8List.fromList(Uint8List.sublistView(data, pos)) : Uint8List(0);
    if (_pending.length > 8 * 1024 * 1024) _pending = Uint8List(0); // proteção: stream inválido

    if (latest != null && mounted) {
      final frame = Uint8List.fromList(latest);
      setState(() {
        _frame = frame;
        _failed = false;
      });
      _setOk(true);
    }
  }

  /// Posição de 0xFF seguido de [marker], a partir de [from]; -1 se não houver.
  static int _find(Uint8List d, int marker, int from) {
    for (var i = from; i < d.length - 1; i++) {
      if (d[i] == 0xFF && d[i + 1] == marker) return i;
    }
    return -1;
  }

  // -------- Flutter Web: fotos seguidas --------
  void _startWebPolling() {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    final snap = uri.replace(path: '/snapshot.jpg');
    Future<void> tick() async {
      try {
        final res = await http
            .get(snap.replace(queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'}))
            .timeout(const Duration(seconds: 4));
        if (_disposed) return;
        if (res.statusCode == 200 && mounted) {
          setState(() {
            _frame = res.bodyBytes;
            _failed = false;
          });
          _setOk(true);
        } else {
          _setOk(false);
          if (mounted) setState(() => _failed = true);
        }
      } catch (_) {
        _setOk(false);
        if (mounted) setState(() => _failed = true);
      }
    }

    tick();
    _webTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => tick());
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    if (_failed && widget.errorWidget != null) return widget.errorWidget!;
    if (frame == null) {
      return widget.placeholder ??
          const Center(child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2));
    }
    return Image.memory(frame, fit: widget.fit, gaplessPlayback: true, filterQuality: FilterQuality.medium);
  }
}

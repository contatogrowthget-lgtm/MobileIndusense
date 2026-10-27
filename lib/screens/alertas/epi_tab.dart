import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/camera_model.dart';
import '../../services/api_client.dart';
import '../../services/camera_service.dart';
import '../../widgets/auth_image.dart';
import '../../widgets/state_widgets.dart';

/// Ocorrências de EPI registradas pelas câmeras (GET /epi/ocorrencias).
class EpiOcorrenciasTab extends StatefulWidget {
  final bool apenasAbertas;
  const EpiOcorrenciasTab({super.key, this.apenasAbertas = false});

  @override
  State<EpiOcorrenciasTab> createState() => _EpiOcorrenciasTabState();
}

class _EpiOcorrenciasTabState extends State<EpiOcorrenciasTab> with AutomaticKeepAliveClientMixin {
  final CameraService _service = CameraService();
  List<EpiOcorrenciaModel>? _lista;
  bool _carregando = true;
  String? _erro;
  Timer? _timer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _carregar();
    // novas ocorrências das câmeras aparecem sozinhas
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _carregar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (silencioso && _lista == null) return;
    if (silencioso) {
      try {
        final lista = await _service.ocorrencias(limit: 150);
        if (mounted) setState(() => _lista = lista);
      } catch (_) {}
      return;
    }
    setState(() {
      _carregando = _lista == null;
      _erro = null;
    });
    try {
      final lista = await _service.ocorrencias(limit: 150);
      if (!mounted) return;
      setState(() {
        _lista = lista;
        _carregando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.statusCode == 404
            ? 'A API ainda não tem as rotas de EPI. Atualize a pasta indusense-api.'
            : e.message;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar as ocorrências de EPI.';
        _carregando = false;
      });
    }
  }

  Future<void> _resolver(EpiOcorrenciaModel o) async {
    final antes = _lista;
    setState(() => _lista = _lista!.map((x) => x.id == o.id ? x.copyWith(resolvido: true, lido: true) : x).toList());
    try {
      await _service.resolver(o.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ocorrência marcada como resolvida.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _lista = antes);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _detalhes(EpiOcorrenciaModel o) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (o.fotoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: InteractiveViewer(child: AuthImage(path: o.fotoUrl!, fit: BoxFit.contain)),
                ),
              ),
            const SizedBox(height: 16),
            Text(o.mensagem, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              '${o.cameraCodigo ?? o.cameraNome}${o.salaNome != null ? ' · ${o.salaNome}' : ''}\n'
              '${DateFormat("dd/MM/yyyy 'às' HH:mm:ss").format(o.dataHora)}',
              style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: o.faltando
                  .map((f) => Chip(
                        avatar: const Icon(Icons.close_rounded, size: 16, color: AppColors.statusCritico),
                        label: Text('Sem ${epiLabel(f).toLowerCase()}'),
                        side: BorderSide(color: AppColors.statusCritico.withOpacity(.3)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),
            if (!o.resolvido)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _resolver(o);
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Marcar como resolvida'),
              )
            else
              const Row(children: [
                Icon(Icons.check_circle_rounded, color: AppColors.statusNormal),
                SizedBox(width: 8),
                Text('Resolvida', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusNormal)),
              ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_carregando) return const LoadingWidget(mensagem: 'Carregando ocorrências de EPI...');
    if (_erro != null) return AppErrorWidget(mensagem: _erro!, onRetry: _carregar);

    var lista = _lista ?? [];
    if (widget.apenasAbertas) lista = lista.where((o) => !o.resolvido).toList();

    if (lista.isEmpty) {
      return RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(children: const [
          SizedBox(height: 80),
          EmptyStateWidget(
            icon: Icons.verified_user_outlined,
            titulo: 'Nenhuma ocorrência de EPI',
            mensagem: 'Quando a câmera flagrar alguém sem EPI, aparece aqui com a foto.',
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      color: AppColors.accent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: lista.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _card(lista[i]),
      ),
    );
  }

  Widget _card(EpiOcorrenciaModel o) {
    final cor = o.resolvido ? AppColors.statusNormal : AppColors.statusCritico;
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _detalhes(o),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: o.resolvido ? Colors.transparent : cor.withOpacity(.45), width: 1.5),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 104,
                height: 66,
                child: o.fotoUrl != null
                    ? AuthImage(path: o.fotoUrl!)
                    : const ColoredBox(color: Colors.black12, child: Icon(Icons.videocam_outlined)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(o.mensagem,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('${o.cameraCodigo ?? o.cameraNome} · ${DateFormat('dd/MM HH:mm').format(o.dataHora)}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: cor.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(o.resolvido ? 'RESOLVIDA' : 'ABERTA',
                      style: TextStyle(color: cor, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .6)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

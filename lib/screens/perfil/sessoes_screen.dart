import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_client.dart';
import '../../services/profile_service.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/ui.dart';

/// Aparelhos com a conta aberta (app e navegadores). Dá para desconectar cada um.
class SessoesScreen extends StatefulWidget {
  const SessoesScreen({super.key});

  @override
  State<SessoesScreen> createState() => _SessoesScreenState();
}

class _SessoesScreenState extends State<SessoesScreen> {
  final _service = ProfileService();
  List<SessaoModel>? _lista;
  String? _erro;
  final _encerrando = <String>{};
  bool _encerrandoTodas = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final l = await _service.sessoes();
      l.sort((a, b) => a.atual ? -1 : b.atual ? 1 : b.ultimoUso.compareTo(a.ultimoUso));
      if (mounted) setState(() {
        _lista = l;
        _erro = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    }
  }

  void _aviso(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<bool> _confirmar(String titulo, String texto, String botao) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Text(texto),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.statusCritico, minimumSize: const Size(110, 46)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(botao),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _encerrar(SessaoModel s) async {
    if (!await _confirmar('Desconectar aparelho?', '${s.descricao.titulo} vai sair da sua conta.', 'Desconectar')) {
      return;
    }
    setState(() => _encerrando.add(s.id));
    try {
      await _service.encerrar(s.id);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _lista?.removeWhere((x) => x.id == s.id));
      _aviso('Aparelho desconectado.');
    } on ApiException catch (e) {
      if (mounted) _aviso(e.message);
    } finally {
      if (mounted) setState(() => _encerrando.remove(s.id));
    }
  }

  Future<void> _encerrarOutras() async {
    if (!await _confirmar('Desconectar os outros?',
        'Todos os outros celulares e navegadores saem da conta. Este aparelho continua conectado.', 'Desconectar todos')) {
      return;
    }
    setState(() => _encerrandoTodas = true);
    try {
      final n = await _service.encerrarOutras();
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _lista?.removeWhere((x) => !x.atual));
      _aviso(n == 0 ? 'Não havia outros aparelhos conectados.' : '$n aparelho${n == 1 ? '' : 's'} desconectado${n == 1 ? '' : 's'}.');
    } on ApiException catch (e) {
      if (mounted) _aviso(e.message);
    } finally {
      if (mounted) setState(() => _encerrandoTodas = false);
    }
  }

  static String _quando(DateTime d) {
    final min = DateTime.now().difference(d).inMinutes;
    if (min < 2) return 'ativo agora';
    if (min < 60) return 'há $min min';
    if (min < 1440) return 'há ${(min / 60).round()} h';
    return DateFormat("dd/MM 'às' HH:mm", 'pt_BR').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final lista = _lista;
    final outras = lista?.where((s) => !s.atual).length ?? 0;

    Widget corpo;
    if (lista == null && _erro != null) {
      corpo = AppErrorWidget(mensagem: _erro!, onRetry: () {
        setState(() => _erro = null);
        _carregar();
      });
    } else if (lista == null) {
      corpo = const LoadingWidget(mensagem: 'Buscando aparelhos…');
    } else {
      corpo = RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            FadeSlideIn(
              child: AppCard(
                gradient: AppGradients.hero,
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.devices_rounded, color: AppColors.cyan, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${lista.length} ${lista.length == 1 ? 'aparelho conectado' : 'aparelhos conectados'}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 3),
                      const Text('Não reconhece algum? Desconecte e troque a sua senha.',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < lista.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FadeSlideIn(index: i + 1, child: _cartao(lista[i])),
              ),
            if (outras > 0) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusCritico,
                  side: BorderSide(color: AppColors.statusCritico.withOpacity(.4)),
                ),
                onPressed: _encerrandoTodas ? null : _encerrarOutras,
                icon: _encerrandoTodas
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.logout_rounded, size: 19),
                label: Text(outras == 1 ? 'Desconectar o outro aparelho' : 'Desconectar os outros $outras aparelhos'),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Aparelhos conectados')),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: corpo),
    );
  }

  Widget _cartao(SessaoModel s) {
    final d = s.descricao;
    final icone = d.tipo == 'celular'
        ? Icons.smartphone_rounded
        : d.tipo == 'tablet'
            ? Icons.tablet_mac_rounded
            : Icons.laptop_mac_rounded;
    final cor = s.atual ? AppColors.statusNormal : AppColors.electric;
    final ocupado = _encerrando.contains(s.id);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: cor.withOpacity(.13), borderRadius: BorderRadius.circular(14)),
          child: Icon(icone, color: cor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(d.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              ),
              if (s.atual) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.statusNormal.withOpacity(.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Este aparelho',
                      style: TextStyle(color: AppColors.statusNormal, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(
              [if (s.ip != null && s.ip!.isNotEmpty) 'IP ${s.ip}', s.atual ? 'ativo agora' : _quando(s.ultimoUso)].join(' · '),
              style: TextStyle(color: mutedText(context), fontSize: 12.5),
            ),
            Text('Entrou em ${DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(s.criadaEm)}',
                style: TextStyle(color: mutedText(context).withOpacity(.8), fontSize: 11.5)),
          ]),
        ),
        if (!s.atual)
          ocupado
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  tooltip: 'Desconectar',
                  onPressed: () => _encerrar(s),
                  icon: const Icon(Icons.logout_rounded, color: AppColors.statusCritico),
                )
        else
          const SizedBox(width: 8),
      ]),
    );
  }
}

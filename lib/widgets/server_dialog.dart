import 'package:flutter/material.dart';

import '../core/config/server_config.dart';
import '../core/theme/app_theme.dart';

Future<bool> showServerDialog(BuildContext context) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => const _ServerDialog(),
  );

  return changed == true;
}

class _ServerDialog extends StatefulWidget {
  const _ServerDialog();

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: ServerConfig.apiUrl);

  bool _testando = false;
  String? _resultado;
  bool _ok = false;

  static const String macApiUrl =
      'http://10.108.26.105:3333/v1';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _testar() async {
    setState(() {
      _testando = true;
      _resultado = null;
    });

    final erro = await ServerConfig.test(_ctrl.text);

    if (!mounted) return;

    setState(() {
      _testando = false;
      _ok = erro == null;
      _resultado = erro ??
          'Conectado! A API respondeu em '
              '${ServerConfig.normalize(_ctrl.text)}.';
    });
  }

  Future<void> _salvar() async {
    await ServerConfig.save(_ctrl.text);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      title: const Text(
        'Servidor da API',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No celular, use o IP do computador onde a API está rodando '
              '(mesma rede Wi-Fi).',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Endereço',
                hintText: 'http://10.108.26.105:3333/v1',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
              onChanged: (_) {
                setState(() {
                  _resultado = null;
                });
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.cloud_rounded, size: 16),
                  label: const Text('Nuvem (Render)'),
                  onPressed: () {
                    setState(() {
                      _ctrl.text = ServerConfig.cloudUrl;
                    });
                  },
                ),
                ActionChip(
                  label: const Text('Este computador'),
                  onPressed: () {
                    setState(() {
                      _ctrl.text = 'http://localhost:3333/v1';
                    });
                  },
                ),
                ActionChip(
                  label: const Text('Emulador Android'),
                  onPressed: () {
                    setState(() {
                      _ctrl.text = 'http://10.0.2.2:3333/v1';
                    });
                  },
                ),
                ActionChip(
                  label: const Text('Celular Android'),
                  onPressed: () {
                    setState(() {
                      _ctrl.text = macApiUrl;
                    });
                  },
                ),
              ],
            ),
            if (_resultado != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _ok
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: _ok
                        ? AppColors.statusNormal
                        : AppColors.statusCritico,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _resultado!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
        TextButton(
          onPressed: _testando ? null : _testar,
          child: _testando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Testar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(96, 44),
          ),
          onPressed: _salvar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

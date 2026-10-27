import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import 'ui.dart';

/// Peças das telas de perfil/configurações (no estilo dos ajustes do iOS).

class SettingsGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final String? footer;

  const SettingsGroup({super.key, this.title, required this.children, this.footer});

  @override
  Widget build(BuildContext context) {
    final itens = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) itens.add(const Divider(height: 1, indent: 66));
      itens.add(children[i]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: Text(title!.toUpperCase(),
              style: TextStyle(
                  color: mutedText(context), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        ),
      AppCard(padding: EdgeInsets.zero, child: Column(children: itens)),
      if (footer != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: Text(footer!, style: TextStyle(color: mutedText(context), fontSize: 12)),
        ),
    ]);
  }
}

class SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    this.color = AppColors.electric,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cor = destructive ? AppColors.statusCritico : color;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: cor.withOpacity(.14), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: cor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5, color: destructive ? AppColors.statusCritico : null)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: mutedText(context), fontSize: 12.5)),
                ],
              ]),
            ),
            if (trailing != null) trailing! else if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: mutedText(context)),
          ]),
        ),
      ),
    );
  }
}

/// Switch dentro de um [SettingsGroup].
class SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitch({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.color = AppColors.electric,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => SettingsItem(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
        onTap: () => onChanged(!value),
        trailing: Switch.adaptive(value: value, onChanged: onChanged),
      );
}

/// Seletor de 2-3 opções com a pílula deslizando (tema claro/escuro/auto).
class SegmentedPicker<T> extends StatelessWidget {
  final List<(T, IconData, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Versão baixinha, só com o texto (filtros de período).
  final bool compacto;

  const SegmentedPicker(
      {super.key, required this.options, required this.value, required this.onChanged, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final idx = options.indexWhere((o) => o.$1 == value).clamp(0, options.length - 1);
    return Container(
      height: compacto ? 40 : 52,
      padding: EdgeInsets.all(compacto ? 3 : 4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0B1426) : const Color(0xFFEFF3FA),
        borderRadius: BorderRadius.circular(compacto ? 13 : 16),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / options.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: w * idx,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(
              decoration: BoxDecoration(
                color: dark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(compacto ? 10 : 12),
                border: dark ? Border.all(color: AppColors.darkBorder) : null,
                boxShadow: dark
                    ? null
                    : [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 10, offset: const Offset(0, 3))],
              ),
            ),
          ),
          Row(
            children: [
              for (final o in options)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(o.$1);
                    },
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: compacto ? 12.5 : 13,
                        fontWeight: o.$1 == value ? FontWeight.w800 : FontWeight.w600,
                        color: o.$1 == value ? (dark ? Colors.white : AppColors.primary) : mutedText(context),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (!compacto) ...[
                                Icon(o.$2,
                                    size: 17, color: o.$1 == value ? AppColors.electric : mutedText(context)),
                                const SizedBox(width: 6),
                              ],
                              Text(o.$3, maxLines: 1),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ]);
      }),
    );
  }
}

/// Campo com rótulo em cima (formulários de perfil e senha).
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final String? hint;
  const LabeledField({super.key, required this.label, required this.child, this.hint});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 7),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          child,
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6),
              child: Text(hint!, style: TextStyle(color: mutedText(context), fontSize: 11.5)),
            ),
        ]),
      );
}

/// Botão principal com carregando, preso no rodapé da tela.
class BottomActionBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;

  const BottomActionBar({super.key, required this.label, required this.icon, this.loading = false, this.onPressed});

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: onPressed == null && !loading ? .55 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.brand,
              borderRadius: BorderRadius.circular(16),
              boxShadow: onPressed == null
                  ? null
                  : [BoxShadow(color: AppColors.electric.withOpacity(.35), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
              ),
              onPressed: loading ? null : onPressed,
              child: loading
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                      Text(label),
                    ]),
            ),
          ),
        ),
      );
}

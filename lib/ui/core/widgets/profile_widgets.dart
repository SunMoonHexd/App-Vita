import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';

// La tarjeta `VitaCard` vive ahora en vita_widgets.dart (acepta `child` o `children`).

/// Título pequeño en mayúsculas dentro de una tarjeta.
class VitaCardTitle extends StatelessWidget {
  const VitaCardTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: VitaText.overline.copyWith(color: context.vita.muted),
        ),
      ),
    );
  }
}

/// Fila de dato: icono, etiqueta pequeña y valor.
class VitaDataRow extends StatelessWidget {
  const VitaDataRow({super.key, required this.emoji, required this.label, required this.value});

  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: context.vita.muted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de menú con flecha.
class VitaMenuRow extends StatelessWidget {
  const VitaMenuRow({super.key, required this.emoji, required this.label, required this.onTap, this.danger = false});

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: danger ? context.vita.dangerTone.fg : context.vita.ink,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.vita.muted),
          ],
        ),
      ),
    );
  }
}

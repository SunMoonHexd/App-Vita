import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_theme_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

/// Selector Claro / Oscuro / Auto. Solo se muestra a voluntarios y coordinación.
class VitaThemeSelector extends StatelessWidget {
  const VitaThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VitaThemeScope.of(context);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Claro')),
          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Oscuro')),
          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Auto')),
        ],
        selected: {controller.mode},
        onSelectionChanged: (selection) => controller.setMode(selection.first),
        style: const ButtonStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6, vertical: 14)),
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta "APARIENCIA" para las pantallas de perfil.
class VitaThemeCard extends StatelessWidget {
  const VitaThemeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return VitaCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('APARIENCIA', style: VitaText.overline.copyWith(color: context.vita.muted)),
          const SizedBox(height: VitaSpace.md),
          const VitaThemeSelector(),
          const SizedBox(height: VitaSpace.sm),
          Text(
            'Auto sigue la configuración de tu celular.',
            style: VitaText.caption.copyWith(color: context.vita.muted),
          ),
        ],
      ),
    );
  }
}

/// Abre el selector en una hoja inferior (para el panel de coordinación).
Future<void> showVitaThemeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apariencia', style: VitaText.title),
            const SizedBox(height: VitaSpace.lg),
            const VitaThemeSelector(),
            const SizedBox(height: VitaSpace.md),
            Text(
              'Auto sigue la configuración de tu celular.',
              style: VitaText.caption.copyWith(color: context.vita.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';

class VitaPage extends StatelessWidget {
  const VitaPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}

class VitaPrimaryButton extends StatelessWidget {
  const VitaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.height = 64,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          elevation: 2,
          shadowColor: bg.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: height >= 96 ? 40 : 30),
              const SizedBox(width: 12),
            ],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

class VitaErrorText extends StatelessWidget {
  const VitaErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaColors.alertBg,
        borderRadius: BorderRadius.circular(VitaRadius.sm),
        border: Border.all(color: VitaColors.alertBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: VitaColors.alert),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(color: VitaColors.alert, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showVitaMessage(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    // El aspecto (fondo, esquinas, tipografía) viene de `dialogTheme` en vita_theme.dart.
    builder: (context) => AlertDialog(
      title: const Text('App VITA'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
      ],
    ),
  );
}

/// Cabecera de las pantallas de inicio: saludo pequeño, nombre grande y, al final, un
/// elemento como el avatar. Reemplaza el bloque "contenedor blanco + Divider" que se repetía.
class VitaHeader extends StatelessWidget {
  const VitaHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.badge,
    this.trailing,
    this.titleSize = 30,
  });

  final String title;
  final String? eyebrow;
  final Widget? badge;
  final Widget? trailing;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(VitaSpace.xxl, 14, VitaSpace.xxl, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: VitaColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) Text(eyebrow!, style: const TextStyle(fontSize: 17, color: VitaColors.muted)),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 6),
                  badge!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: VitaSpace.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Tarjeta blanca con borde y sombra suave. Recibe un `child` o una lista de `children`
/// (se apilan en columna). Con `tone` se pinta del color de ese estado (sin sombra), útil
/// para avisos. Si recibe `onTap`, toda la tarjeta es tocable.
class VitaCard extends StatelessWidget {
  const VitaCard({
    super.key,
    this.child,
    this.children,
    this.padding,
    this.onTap,
    this.tone,
  }) : assert((child == null) != (children == null), 'Usa solo child o solo children');

  final Widget? child;
  final List<Widget>? children;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VitaTone? tone;

  @override
  Widget build(BuildContext context) {
    final colors = tone?.colors;
    final radius = BorderRadius.circular(VitaRadius.lg);
    final body = child ?? Column(children: children!);
    final content = padding == null ? body : Padding(padding: padding!, child: body);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: colors == null
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: colors?.bg ?? Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors?.border ?? VitaColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Etiqueta corta con color de estado ("Voluntario verificado", "Conexión activa"...).
class VitaPill extends StatelessWidget {
  const VitaPill({
    super.key,
    required this.label,
    this.tone = VitaTone.neutral,
    this.icon,
    this.dot = false,
  });

  final String label;
  final VitaTone tone;
  final IconData? icon;

  /// Muestra un puntito de color antes del texto (estado de conexión, por ejemplo).
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final c = tone.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(VitaRadius.pill),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 9, height: 9, decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle)),
            const SizedBox(width: VitaSpace.sm),
          ],
          if (icon != null) ...[
            Icon(icon, size: 18, color: c.fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(label, style: TextStyle(color: c.fg, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

/// Métrica con icono, etiqueta y valor ("Hoy · 3 llamadas").
class VitaStatTile extends StatelessWidget {
  const VitaStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.tone = VitaTone.primary,
  });

  final IconData icon;
  final String label;
  final String value;
  final VitaTone tone;

  @override
  Widget build(BuildContext context) {
    final c = tone.colors;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(VitaSpace.lg),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(VitaRadius.lg),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(VitaRadius.sm),
              ),
              child: Icon(icon, color: c.fg, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 15, color: VitaColors.muted)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.fg)),
          ],
        ),
      ),
    );
  }
}

/// Opción de la barra inferior.
class VitaNavItem {
  const VitaNavItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Barra inferior de Material 3 con el estilo de VITA (ver `navigationBarTheme`).
/// Las pantallas de inicio siempre dejan seleccionado el primer elemento y abren las demás
/// opciones encima, por eso `selectedIndex` casi siempre es 0.
class VitaNavBar extends StatelessWidget {
  const VitaNavBar({
    super.key,
    required this.items,
    required this.onSelected,
    this.selectedIndex = 0,
  });

  final List<VitaNavItem> items;
  final ValueChanged<int> onSelected;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: VitaColors.border))),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}

const consentText =
    'Autorizo el tratamiento de mis datos personales conforme a la Ley 1581 de 2012 (Habeas Data). '
    'App VITA usa nombre, teléfono, fecha de nacimiento y contactos de apoyo para el servicio de acompañamiento. '
    'Las videollamadas no se graban. Puedo solicitar la eliminación de mis datos.';

const termsText =
    'El acompañamiento es social y conversacional. No sustituye atención médica, psicológica ni la línea 123. '
    'No compartas dirección, dinero, claves ni códigos. No contactes a la otra persona fuera de la app.';

const conductText =
    'Código de conducta: no pedir dinero, claves, códigos ni datos sensibles; no contactar al adulto mayor '
    'fuera de VITA; tratar con respeto; avisar a coordinación ante una emergencia.';

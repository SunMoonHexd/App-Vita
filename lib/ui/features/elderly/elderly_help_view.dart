import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class ElderlyHelpView extends StatelessWidget {
  const ElderlyHelpView({super.key});

  Future<void> _call(BuildContext context, String number) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse('tel:$number'));
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      await showVitaMessage(
        context,
        'No se pudo abrir el teléfono. Marca el $number desde tu celular.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = VitaScope.of(context).currentUser;
    final familyPhone = (user?.familyPhone ?? '').trim();
    final palette = context.vita;

    return VitaPage(
      title: 'Ayuda',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Pedir compañía es sencillo',
            style: VitaText.title.copyWith(color: palette.ink, fontSize: 25),
          ),
          const SizedBox(height: 8),
          Text(
            'Sigue estos pasos para conversar con un voluntario.',
            style: VitaText.bodyMuted.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 20),
          const _StepCard(
            number: '1',
            icon: Icons.chat_bubble_rounded,
            title: 'Toca “Quiero hablar ahora”',
            description: 'Elige llamada de voz o videollamada.',
          ),
          const SizedBox(height: 12),
          const _StepCard(
            number: '2',
            icon: Icons.people_alt_rounded,
            title: 'Esperamos contigo',
            description:
                'Buscaremos a un voluntario disponible para conversar.',
          ),
          const SizedBox(height: 12),
          const _StepCard(
            number: '3',
            icon: Icons.call_rounded,
            title: 'Comienza la llamada',
            description: 'Cuando acepte, la llamada inicia. Si elegiste videollamada, permite usar la cámara y el micrófono.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.infoTone.bg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: palette.infoTone.border, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.mic_rounded, color: palette.infoTone.fg, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: VitaText.body.copyWith(color: palette.ink),
                      children: const [
                        TextSpan(
                          text: '¿Prefieres usar tu voz?\n',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        TextSpan(
                          text: 'Toca “Llamar usando mi voz” en el inicio y di: “Quiero hablar ahora”.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: VitaColors.alertBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: VitaColors.alertBorder, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: VitaColors.alert,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: VitaText.body.copyWith(color: VitaColors.ink),
                      children: const [
                        TextSpan(
                          text: '¿Es una emergencia?\n',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        TextSpan(
                          text: 'Si hay peligro o una urgencia médica, llama al 123. VITA no reemplaza los servicios de emergencia.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          VitaPrimaryButton(
            label: 'Llamar a emergencias · 123',
            icon: Icons.phone_rounded,
            color: VitaColors.alert,
            height: 74,
            onPressed: () => _call(context, '123'),
          ),
          if (familyPhone.isNotEmpty) ...[
            const SizedBox(height: 12),
            VitaPrimaryButton(
              label: 'Llamar a mi familiar',
              icon: Icons.family_restroom_rounded,
              color: VitaColors.secondary,
              height: 74,
              onPressed: () => _call(context, familyPhone),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final palette = context.vita;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: VitaColors.tint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: VitaColors.primaryDark, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PASO $number',
                  style: VitaText.overline.copyWith(
                    color: palette.accent,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: VitaText.heading.copyWith(
                    color: palette.ink,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: VitaText.body.copyWith(
                    color: palette.muted,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

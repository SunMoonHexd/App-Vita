import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class ElderlyHelpView extends StatelessWidget {
  const ElderlyHelpView({super.key});

  Future<void> _call(String number) async {
    await launchUrl(Uri.parse('tel:$number'));
  }

  @override
  Widget build(BuildContext context) {
    final user = VitaScope.of(context).currentUser;
    final familyPhone = (user?.familyPhone ?? '').trim();

    return VitaPage(
      title: 'Ayuda',
      child: ListView(
        children: [
          const Text('¿Cómo pedir compañía?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          const _Step(number: '1', text: 'En el inicio, toca el botón grande "Quiero hablar".'),
          const _Step(number: '2', text: 'Espera un momento: buscamos a un voluntario disponible para ti.'),
          const _Step(number: '3', text: 'Cuando acepte, la videollamada empieza sola. Acepta la cámara y el micrófono.'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEA),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Text(
              'Si tienes una emergencia médica o de seguridad, llama a la línea 123. VITA no la reemplaza.',
              style: TextStyle(fontSize: 18, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          VitaPrimaryButton(
            label: 'Llamar a la línea 123',
            icon: Icons.phone_rounded,
            color: VitaColors.alert,
            onPressed: () => _call('123'),
          ),
          if (familyPhone.isNotEmpty) ...[
            const SizedBox(height: 12),
            VitaPrimaryButton(
              label: 'Llamar a mi familiar',
              icon: Icons.family_restroom_rounded,
              color: VitaColors.secondary,
              onPressed: () => _call(familyPhone),
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: VitaColors.primary, shape: BoxShape.circle),
            child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 18, height: 1.4))),
        ],
      ),
    );
  }
}

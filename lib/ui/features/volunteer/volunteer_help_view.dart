import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class VolunteerHelpView extends StatelessWidget {
  const VolunteerHelpView({super.key});

  Future<void> _call123(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse('tel:123'));
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      await showVitaMessage(context, 'No se pudo abrir el teléfono. Marca el 123 desde tu celular.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Ayuda',
      child: ListView(
        children: [
          const Text('¿Cómo recibir llamadas?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          const _Step(number: '1', text: 'Activa "Mi disponibilidad" dentro de tus horarios.'),
          const _Step(number: '2', text: 'Deja esta pantalla abierta: así te llegan las solicitudes.'),
          const _Step(number: '3', text: 'Cuando suene una solicitud, toca "Aceptar" y la videollamada empieza sola.'),
          const SizedBox(height: 18),
          const Text('Cuida y cuídate', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'No pidas dinero, claves, códigos ni datos sensibles, y no contactes a la persona fuera de VITA. '
            'Si algo te parece raro, termina la llamada y repórtalo.',
            style: TextStyle(fontSize: 18, height: 1.45),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(22)),
            child: const Text(
              'Si la persona tiene una emergencia médica o de seguridad, activa la alerta de emergencia y llama a la línea 123. '
              'VITA no la reemplaza.',
              style: TextStyle(fontSize: 18, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          VitaPrimaryButton(
            label: 'Llamar a la línea 123',
            icon: Icons.phone_rounded,
            color: VitaColors.alert,
            onPressed: () => _call123(context),
          ),
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
            decoration: const BoxDecoration(color: VitaColors.secondary, shape: BoxShape.circle),
            child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 18, height: 1.4))),
        ],
      ),
    );
  }
}

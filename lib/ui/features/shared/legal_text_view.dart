import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class LegalSection {
  const LegalSection(this.title, this.body);

  final String title;
  final String body;
}

class LegalTextView extends StatelessWidget {
  const LegalTextView({super.key, required this.title, required this.sections});

  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: title,
      child: ListView(
        children: [
          for (final s in sections) ...[
            Text(s.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(s.body, style: const TextStyle(fontSize: 18, height: 1.45)),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

// Textos basados en el consentimiento y los términos que ya usa la app.
// Antes de publicar, deben ser revisados por una persona con formación legal.
const privacySections = [
  LegalSection('Autorización de tratamiento de datos', consentText),
  LegalSection(
    'Qué datos usamos',
    'App VITA usa tu nombre, teléfono, fecha de nacimiento y los contactos de apoyo que registraste '
        'para ofrecerte el servicio de acompañamiento.',
  ),
  LegalSection(
    'Cómo se tratan',
    'Tratamos tus datos conforme a la Ley 1581 de 2012 (Habeas Data). Las videollamadas no se graban.',
  ),
  LegalSection(
    'Tus derechos',
    'Puedes actualizar tus datos desde "Editar mis datos" y solicitar su eliminación desde tu perfil '
        'en cualquier momento.',
  ),
];

const termsSections = [
  LegalSection(
    'Qué es VITA',
    'El acompañamiento es social y conversacional. No sustituye la atención médica, psicológica ni la línea 123.',
  ),
  LegalSection(
    'Cuida tu seguridad',
    'No compartas tu dirección, dinero, claves ni códigos. No contactes a la otra persona fuera de la app.',
  ),
  LegalSection(
    'Si algo te parece raro',
    'Termina la llamada y repórtalo desde la app.',
  ),
];

/// Dos enlaces para leer los términos de uso y la política de privacidad.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  void _open(BuildContext context, String title, List<LegalSection> sections) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalTextView(title: title, sections: sections)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        TextButton(
          onPressed: () => _open(context, 'Términos de uso', termsSections),
          child: const Text('Leer términos de uso'),
        ),
        TextButton(
          onPressed: () => _open(context, 'Política de privacidad', privacySections),
          child: const Text('Leer política de privacidad'),
        ),
      ],
    );
  }
}

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
            Text(
              s.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(s.body, style: const TextStyle(fontSize: 19, height: 1.5)),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

// Resumen en lenguaje claro para la aplicación. Validar datos de contacto,
// acceso y conservación de grabaciones con la persona responsable antes de publicar.
const privacySections = [
  LegalSection('Tu autorización', consentText),
  LegalSection(
    'Qué información usamos',
    'Usamos tu nombre, celular, fecha de nacimiento y contactos de apoyo. Si agregas una foto de perfil, '
        'también la guardamos. La cuenta puede generar información sobre disponibilidad, solicitudes y '
        'llamadas, reportes de seguridad y autorizaciones. El dispositivo puede guardar un identificador '
        'técnico para recibir avisos de la app.',
  ),
  LegalSection(
    'Para qué usamos tus datos',
    'Los usamos para crear y proteger tu cuenta, encontrar a una persona disponible, conectar llamadas, '
        'enviar avisos, atender reportes y mejorar la seguridad y el funcionamiento de VITA.',
  ),
  LegalSection(
    'Llamadas y grabaciones',
    'Las llamadas no se graban automáticamente. Durante una llamada cualquiera puede solicitar una '
        'grabación. Solo empieza si ambas personas aceptan. Mientras está activa, las dos ven el indicador '
        'de grabación y cualquiera puede detenerla. El archivo se guarda en el almacenamiento configurado '
        'por VITA. Antes de usar esta función con personas reales, el equipo responsable debe informar '
        'quién puede acceder al archivo y cuánto tiempo se conserva.',
  ),
  LegalSection(
    'Servicios que ayudan a operar VITA',
    'VITA utiliza Firebase para cuentas, datos y avisos; LiveKit para conectar las llamadas; y almacenamiento '
        'de Supabase para los archivos de grabación. Un servicio de servidor coordina estas funciones.',
  ),
  LegalSection(
    'Tus derechos y cómo solicitar cambios',
    'Puedes editar tus datos desde tu perfil o solicitar la eliminación de tu cuenta desde allí. También '
        'puedes pedir información sobre tus datos y solicitar su corrección o revocar tu autorización al '
        'responsable de VITA. Antes de publicar, el equipo debe indicar claramente el nombre y un canal de '
        'contacto de esa persona u organización.',
  ),
];

const termsSections = [
  LegalSection(
    'Qué es VITA',
    'VITA conecta a personas adultas mayores con voluntarios para conversar y recibir compañía por llamada '
        'de voz o videollamada. El servicio es de acompañamiento social: no ofrece atención médica ni '
        'psicológica profesional.',
  ),
  LegalSection(
    'La app no es para emergencias',
    'VITA no es una línea de emergencia y no garantiza que alguien responda de inmediato. Si hay peligro '
        'o necesitas atención urgente, llama al 123 o a tu contacto de confianza.',
  ),
  LegalSection(
    'Cuida tu información',
    'No compartas contraseñas, PIN, códigos de verificación, dinero, datos bancarios ni información '
        'personal que te haga sentir inseguro. No compartas tu PIN de VITA.',
  ),
  LegalSection(
    'Trato respetuoso y seguro',
    'Trata a la otra persona con respeto. No pidas dinero ni claves y no presiones a nadie para compartir '
        'datos o continuar una conversación. Evita intercambiar datos de contacto o continuar la relación '
        'por fuera de VITA.',
  ),
  LegalSection(
    'Llamadas y grabación',
    'Puedes terminar la llamada cuando quieras y reportar algo que te preocupe. Una llamada solo se graba '
        'si una persona lo solicita durante la llamada y ambas aceptan. Ambas ven el indicador y cualquiera '
        'puede detener la grabación. Si una persona no acepta, la llamada continúa sin grabarse.',
  ),
  LegalSection(
    'Si algo te preocupa',
    'Cuelga si no te sientes cómodo y usa la opción de reportar en la aplicación. Si se trata de una '
        'emergencia, llama al 123; no esperes respuesta de VITA.',
  ),
];

/// Dos enlaces para leer los términos de uso y la política de privacidad.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  void _open(BuildContext context, String title, List<LegalSection> sections) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalTextView(title: title, sections: sections),
      ),
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
          onPressed: () =>
              _open(context, 'Política de privacidad', privacySections),
          child: const Text('Leer política de privacidad'),
        ),
      ],
    );
  }
}

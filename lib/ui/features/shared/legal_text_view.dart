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
    'Usamos tu nombre, celular, fecha de nacimiento, contactos de apoyo y, en el registro de voluntarios, '
        'una foto personal tomada para el perfil. La cuenta puede generar información sobre disponibilidad, solicitudes y '
        'llamadas, reportes de seguridad y autorizaciones. El dispositivo puede guardar un identificador '
        'técnico para recibir avisos de la app.',
  ),
  LegalSection(
    'Para qué usamos tus datos',
    'Los usamos para crear y proteger tu cuenta, encontrar a una persona disponible, conectar llamadas, '
        'enviar avisos, atender reportes y mejorar la seguridad y el funcionamiento de VITA.',
  ),
  LegalSection(
    'Presentación del voluntario',
    'Los voluntarios pueden autorizar por separado que VITA muestre a la persona mayor asignada su nombre, '
        'foto de perfil, presentación, intereses y experiencia de voluntariado. La autorización es '
        'voluntaria, específica y revocable. Coordinación revisa el contenido antes de publicarlo; si el '
        'voluntario cambia la presentación o retira el permiso, se oculta hasta una nueva revisión o deja '
        de mostrarse. Sin autorización no se publica esta presentación.',
  ),
  LegalSection(
    'Datos sensibles y datos de otras personas',
    'VITA no solicita datos de salud para prestar el acompañamiento social. Si decides compartir '
        'información sensible durante una conversación, hazlo solo si lo consideras necesario. Los '
        'contactos de apoyo que registres también son datos personales: debes contarles que los '
        'incluiste y procurar que sus datos sean correctos. No ingreses información de otra persona '
        'sin autorización o sin una base legal aplicable.',
  ),
  LegalSection(
    'Verificación de identidad de voluntarios',
    'Con autorización del voluntario, VITA recopila imágenes del frente y reverso de su cédula para que '
        'coordinación verifique su identidad antes de aprobar la cuenta. Las imágenes se guardan en el '
        'perfil privado y solo son accesibles para el voluntario y coordinación. No se muestran ni se '
        'entregan al adulto mayor; a este solo se le informa si coordinación marcó la identidad como '
        'verificada. Cuando coordinación verifica la identidad, VITA elimina las imágenes y el número '
        'de documento, y conserva únicamente el resultado, la fecha y quién realizó la revisión. Si el '
        'trámite no se completa, las imágenes y el número se eliminan automáticamente después de 30 días.',
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
    'Transferencias y conservación',
    'Algunos proveedores tecnológicos pueden procesar o alojar información fuera de Colombia. El '
        'responsable debe verificar las condiciones legales aplicables a la transmisión o transferencia '
        'internacional de datos y mantener acuerdos y salvaguardas adecuados. Conservamos los datos '
        'durante el tiempo necesario para los fines informados y para atender obligaciones legales, '
        'reclamaciones o incidentes de seguridad; después se eliminan o anonimizan cuando corresponda. '
        'Las grabaciones requieren reglas específicas de acceso y plazo que deben definirse antes de '
        'activar esa función con usuarios reales.',
  ),
  LegalSection(
    'Tus derechos y cómo solicitar cambios',
    'Puedes conocer, actualizar y rectificar tus datos; solicitar prueba de la autorización, información '
        'sobre el uso, y la supresión de datos o revocatoria de la autorización cuando proceda. Presenta '
        'consultas o reclamos en el canal del responsable indicado arriba. Incluye tu nombre, medio para '
        'recibir respuesta y una descripción de lo que solicitas. Las consultas se responden dentro de '
        '10 días hábiles y los reclamos dentro de 15 días hábiles, con las prórrogas y avisos previstos '
        'por la ley. Puedes acudir a la Superintendencia de Industria y Comercio después de agotar el '
        'trámite ante el responsable o encargado.',
  ),
  LegalSection(
    'Seguridad y cambios',
    'Aplicamos medidas razonables para proteger la información, aunque ningún medio de transmisión o '
        'almacenamiento puede garantizar seguridad absoluta. Si actualizamos esta política, publicaremos '
        'la nueva versión en VITA e informaremos los cambios relevantes; cuando la ley lo exija, '
        'solicitaremos una nueva autorización.',
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
    'Aceptación, elegibilidad y cuenta',
    'Al crear una cuenta o usar VITA aceptas estos términos y la política de privacidad. El registro '
        'está destinado a personas adultas. Debes entregar información veraz, mantener seguro tu PIN y '
        'avisarnos si sospechas que alguien accedió a tu cuenta. No uses la cuenta de otra persona ni '
        'intentes acceder a sistemas o información sin autorización.',
  ),
  LegalSection(
    'Alcance del servicio',
    'VITA facilita el contacto entre personas para acompañamiento social. No presta ni sustituye servicios '
        'de salud, psicología, trabajo social, asesoría jurídica o atención de emergencias; tampoco '
        'garantiza disponibilidad, compatibilidad, continuidad o respuesta inmediata. La app puede '
        interrumpirse por mantenimiento, conectividad o fallas de terceros.',
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
    'Conducta de voluntarios',
    'Quien participa como voluntario debe respetar la privacidad y autonomía de la otra persona, limitar '
        'la interacción al acompañamiento social, seguir las pautas de seguridad de VITA y reportar '
        'situaciones de riesgo por los canales habilitados. No debe solicitar dinero, contraseñas, códigos, '
        regalos ni datos financieros, ofrecer diagnósticos o tratamientos, ni iniciar relaciones de '
        dependencia o contacto fuera de la plataforma.',
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
  LegalSection(
    'Reportes y medidas de seguridad',
    'VITA puede revisar reportes de seguridad y, cuando sea razonable y necesario, limitar temporalmente '
        'o cerrar cuentas que incumplan estos términos o pongan a alguien en riesgo. Procuraremos permitir '
        'que expliques lo ocurrido por el canal de contacto indicado por el operador. Ante peligro '
        'inmediato, contacta al 123 y a tus contactos de confianza; VITA no reemplaza a las autoridades.',
  ),
  LegalSection(
    'Disponibilidad, cambios y ley aplicable',
    'Podemos actualizar estos términos para reflejar cambios del servicio o de la ley. Informaremos los '
        'cambios relevantes en la app; si afectan materialmente tus derechos o requieren aceptación, te '
        'pediremos aceptarlos para continuar. Estos términos se interpretan conforme a las leyes de la '
        'República de Colombia y no limitan los derechos irrenunciables que la ley reconoce a las personas '
        'usuarias o consumidoras.',
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

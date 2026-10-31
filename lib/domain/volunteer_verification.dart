import 'package:vita_app/domain/models/vita_models.dart';

/// Coordinación solo aprueba si verificó correo, inducción e identidad con las dos caras de la cédula.
bool canApproveVolunteer(VitaUser user) =>
    user.role == UserRole.volunteer &&
    user.status == AccountStatus.pending &&
    user.emailVerified &&
    user.inductionDone &&
    user.photoBase64 != null &&
    user.identityDocumentConsent &&
    user.idFrontBase64 != null &&
    user.idBackBase64 != null &&
    user.identityVerified;

/// Mensaje que ve el voluntario pendiente al intentar entrar, según el paso en que va.
String volunteerPendingMessage({required bool emailVerified}) {
  if (emailVerified) {
    return 'Tu correo ya está verificado. Coordinación debe revisar tu cédula y aprobar la cuenta antes de que puedas ingresar.';
  }
  return 'Verifica tu correo: te enviamos un enlace. Si no lo ves, revisa la carpeta de spam o pide que te lo reenviemos.';
}

/// Edad cumplida en la fecha [on].
int ageOn(DateTime birthDate, DateTime on) {
  var age = on.year - birthDate.year;
  final hadBirthday = on.month > birthDate.month || (on.month == birthDate.month && on.day >= birthDate.day);
  if (!hadBirthday) age--;
  return age;
}

import 'package:vita_app/domain/models/vita_models.dart';

/// RF3: coordinación solo puede aprobar a un voluntario pendiente si ya verificó su correo y
/// completó la inducción (RF34). Rechazar siempre se puede.
bool canApproveVolunteer(VitaUser user) =>
    user.role == UserRole.volunteer &&
    user.status == AccountStatus.pending &&
    user.emailVerified &&
    user.inductionDone;

/// Mensaje que ve el voluntario pendiente al intentar entrar, según el paso en que va.
String volunteerPendingMessage({required bool emailVerified}) {
  if (emailVerified) {
    return 'Tu correo ya está verificado. Falta la aprobación de coordinación; vuelve a intentarlo más tarde.';
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

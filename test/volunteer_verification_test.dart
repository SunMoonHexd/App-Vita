import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/domain/volunteer_verification.dart';

VitaUser pendingVolunteer({bool emailVerified = false, bool inductionDone = true, AccountStatus? status}) {
  return VitaUser(
    id: 'v1',
    role: UserRole.volunteer,
    displayName: 'Vol',
    status: status ?? AccountStatus.pending,
    inductionDone: inductionDone,
    emailVerified: emailVerified,
  );
}

void main() {
  group('RF3: cuándo coordinación puede aprobar', () {
    test('con correo verificado e inducción hecha, sí', () {
      expect(canApproveVolunteer(pendingVolunteer(emailVerified: true)), isTrue);
    });

    test('sin correo verificado, no', () {
      expect(canApproveVolunteer(pendingVolunteer()), isFalse);
    });

    test('sin inducción, no, aunque el correo esté verificado', () {
      expect(canApproveVolunteer(pendingVolunteer(emailVerified: true, inductionDone: false)), isFalse);
    });

    test('solo aplica a voluntarios pendientes', () {
      expect(canApproveVolunteer(pendingVolunteer(emailVerified: true, status: AccountStatus.active)), isFalse);
      expect(canApproveVolunteer(pendingVolunteer(emailVerified: true, status: AccountStatus.suspended)), isFalse);
      final elderly = VitaUser(
        id: 'a1',
        role: UserRole.elderly,
        displayName: 'Abuela',
        status: AccountStatus.pending,
        inductionDone: true,
        emailVerified: true,
      );
      expect(canApproveVolunteer(elderly), isFalse);
    });
  });

  group('RF3: mensajes al voluntario pendiente', () {
    test('sin verificar pide revisar el correo', () {
      expect(volunteerPendingMessage(emailVerified: false), contains('Verifica tu correo'));
    });

    test('verificado dice que falta la aprobación de coordinación', () {
      expect(volunteerPendingMessage(emailVerified: true), contains('aprobación de coordinación'));
    });
  });

  group('RF3: dato emailVerified en el perfil', () {
    test('por defecto es falso y sobrevive al JSON', () {
      final user = pendingVolunteer();
      expect(user.emailVerified, isFalse);
      expect(VitaUser.fromJson(user.toJson()).emailVerified, isFalse);
      expect(VitaUser.fromJson(user.copyWith(emailVerified: true).toJson()).emailVerified, isTrue);
    });

    test('copyWith conserva el valor si no se indica otro', () {
      expect(pendingVolunteer(emailVerified: true).copyWith(available: true).emailVerified, isTrue);
    });
  });

  group('Edad que ve coordinación', () {
    test('cumple años hoy', () {
      expect(ageOn(DateTime(2000, 10, 13), DateTime(2026, 10, 13)), 26);
    });

    test('todavía no cumple años este año', () {
      expect(ageOn(DateTime(2000, 10, 14), DateTime(2026, 10, 13)), 25);
    });

    test('ya cumplió años este año', () {
      expect(ageOn(DateTime(2000, 1, 5), DateTime(2026, 10, 13)), 26);
    });

    test('justo en el límite de los 18 años', () {
      expect(ageOn(DateTime(2008, 10, 13), DateTime(2026, 10, 13)), 18);
      expect(ageOn(DateTime(2008, 10, 14), DateTime(2026, 10, 13)), 17);
    });
  });
}

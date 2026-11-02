import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/domain/models/vita_models.dart';

void main() {
  final created = DateTime.utc(2026, 11, 1, 17);

  group('SupportRequest', () {
    test('round-trips an accepted audio request and its timestamps', () {
      final acceptedAt = created.add(const Duration(minutes: 2));
      final closedAt = acceptedAt.add(const Duration(minutes: 10));
      final original = SupportRequest(
        id: 'support-1',
        callId: 'call-1',
        roomName: 'room-1',
        requestedById: 'volunteer-1',
        elderlyId: 'elderly-1',
        createdAt: created,
        audioOnly: true,
        note: 'Solicita apoyo',
        status: SupportStatus.accepted,
        psychologistId: 'psych-1',
        acceptedAt: acceptedAt,
        closedAt: closedAt,
      );

      final json = original.toJson();
      final restored = SupportRequest.fromJson(json);
      expect(json['createdAt'], endsWith('Z'));
      expect(restored.status, SupportStatus.accepted);
      expect(restored.audioOnly, isTrue);
      expect(restored.psychologistId, 'psych-1');
      expect(restored.acceptedAt, acceptedAt);
      expect(restored.closedAt, closedAt);
      expect(restored.isAnonymized, isFalse);
    });

    test('reads older documents and safely defaults unknown values', () {
      final restored = SupportRequest.fromJson({
        'id': 'support-old',
        'callId': 'call-1',
        'roomName': 'room-1',
        'requestedById': 'volunteer-1',
        'elderlyId': 'elderly-1',
        'createdAt': created.toIso8601String(),
        'status': 'future-status',
        'acceptedAt': 123,
        'closedAt': 'not-a-date',
      });

      expect(restored.status, SupportStatus.open);
      expect(restored.audioOnly, isFalse);
      expect(restored.note, isNull);
      expect(restored.acceptedAt, isNull);
      expect(restored.closedAt, isNull);
    });

    test(
      'copyWith changes lifecycle fields and anonymization removes identifiers',
      () {
        final original = SupportRequest(
          id: 'support-1',
          callId: 'call-1',
          roomName: 'room-1',
          requestedById: 'volunteer-1',
          elderlyId: 'elderly-1',
          createdAt: DateTime.utc(2026, 11, 1),
          psychologistId: 'psych-1',
        );
        final accepted = original.copyWith(
          status: SupportStatus.accepted,
          psychologistId: 'psych-2',
          acceptedAt: created,
          closedAt: created.add(const Duration(minutes: 1)),
        );
        expect(accepted.status, SupportStatus.accepted);
        expect(accepted.psychologistId, 'psych-2');
        expect(accepted.note, original.note);

        final anonymous = accepted.anonymized();
        expect(anonymous.isAnonymized, isTrue);
        expect(anonymous.requestedById, kAnonymized);
        expect(anonymous.psychologistId, kAnonymized);
        expect(anonymous.roomName, 'anonimizada');
        expect(anonymous.note, isNull);
        expect(original.anonymized().psychologistId, kAnonymized);
      },
    );
  });

  test('availability slots and surveys round-trip through JSON', () {
    const slot = AvailabilitySlot(
      id: 'slot-1',
      volunteerId: 'volunteer-1',
      weekday: 2,
      startHour: 8,
      endHour: 12,
    );
    final restoredSlot = AvailabilitySlot.fromJson(slot.toJson());
    expect(restoredSlot.id, slot.id);
    expect(restoredSlot.volunteerId, slot.volunteerId);
    expect(restoredSlot.weekday, slot.weekday);
    expect(restoredSlot.startHour, slot.startHour);
    expect(restoredSlot.endHour, slot.endHour);

    const survey = CallSurvey(
      callId: 'call-1',
      userId: 'elderly-1',
      experience: 5,
      feltAccompanied: 4,
    );
    final restoredSurvey = CallSurvey.fromJson(survey.toJson());
    expect(restoredSurvey.callId, survey.callId);
    expect(restoredSurvey.userId, survey.userId);
    expect(restoredSurvey.experience, 5);
    expect(restoredSurvey.feltAccompanied, 4);
    expect(
      CallSurvey.fromJson({...survey.toJson(), 'feltAccompanied': null})
          .feltAccompanied,
      isNull,
    );
  });

  test('AuthResult reports success and failure consistently', () {
    const user = VitaUser(
      id: 'user-1',
      role: UserRole.elderly,
      displayName: 'Adulto',
      status: AccountStatus.active,
    );
    const ok = AuthResult.ok(user);
    const failure = AuthResult.error('No se pudo ingresar');

    expect(ok.isOk, isTrue);
    expect(ok.user, user);
    expect(ok.error, isNull);
    expect(failure.isOk, isFalse);
    expect(failure.user, isNull);
    expect(failure.error, 'No se pudo ingresar');
  });

  test('VitaUser clear flags explicitly remove optional information', () {
    final user = VitaUser(
      id: 'volunteer-1',
      role: UserRole.volunteer,
      displayName: 'Voluntario',
      status: AccountStatus.active,
      phone: '3001234567',
      documentId: '12345',
      photoBase64: 'profile-photo',
      volunteerPresentationPhoto: 'presentation-photo',
      idFrontBase64: 'front',
      idBackBase64: 'back',
      lockedUntil: created,
      idDocumentsUploadedAt: created,
      identityVerifiedAt: created,
      identityVerifiedBy: 'coordinator-1',
    );
    final cleared = user.copyWith(
      clearDocumentId: true,
      clearPhoto: true,
      clearVolunteerPresentationPhoto: true,
      clearIdFront: true,
      clearIdBack: true,
      clearLock: true,
      clearIdDocumentsUploadedAt: true,
      clearIdentityVerification: true,
    );

    expect(cleared.documentId, isNull);
    expect(cleared.photoBase64, isNull);
    expect(cleared.volunteerPresentationPhoto, isNull);
    expect(cleared.idFrontBase64, isNull);
    expect(cleared.idBackBase64, isNull);
    expect(cleared.lockedUntil, isNull);
    expect(cleared.idDocumentsUploadedAt, isNull);
    expect(cleared.identityVerifiedAt, isNull);
    expect(cleared.identityVerifiedBy, isNull);
    expect(cleared.email, user.email);
    expect(cleared.birthDate, user.birthDate);
    expect(cleared.createdAt, user.createdAt);
  });

  group('CallRequest', () {
    test('round-trips an audio call and its lifecycle fields', () {
      final started = created.add(const Duration(minutes: 1));
      final ended = started.add(const Duration(minutes: 3));
      final original = CallRequest(
        id: 'call-1',
        elderlyId: 'elderly-1',
        volunteerId: 'volunteer-1',
        roomName: 'room-1',
        joinCode: '123456',
        status: CallRequestStatus.completed,
        createdAt: created,
        audioOnly: true,
        attempts: 2,
        startedAt: started,
        endedAt: ended,
      );
      final restored = CallRequest.fromJson(original.toJson());

      expect(restored.audioOnly, isTrue);
      expect(restored.attempts, 2);
      expect(restored.status, CallRequestStatus.completed);
      expect(restored.startedAt, started);
      expect(restored.endedAt, ended);
      expect(restored.duration, const Duration(minutes: 3));
      expect(restored.anonymized().elderlyId, kAnonymized);
      expect(restored.anonymized().volunteerId, kAnonymized);
    });

    test(
      'supports old call records and copyWith without changing identity',
      () {
        final restored = CallRequest.fromJson({
          'id': 'call-old',
          'elderlyId': 'elderly-1',
          'roomName': 'room-1',
          'joinCode': '123456',
          'status': 'searching',
          'createdAt': created.toIso8601String(),
        });
        expect(restored.audioOnly, isFalse);
        expect(restored.attempts, 1);
        expect(restored.duration, Duration.zero);

        final changed = restored.copyWith(
          volunteerId: 'volunteer-1',
          status: CallRequestStatus.connected,
          attempts: 3,
          audioOnly: true,
          startedAt: created,
        );
        expect(changed.id, restored.id);
        expect(changed.volunteerId, 'volunteer-1');
        expect(changed.status, CallRequestStatus.connected);
        expect(changed.attempts, 3);
        expect(changed.audioOnly, isTrue);
      },
    );
  });

  test('UserReport round-trips, changes status, and anonymizes identities', () {
    final original = UserReport(
      id: 'report-1',
      reporterId: 'elderly-1',
      reportedId: 'volunteer-1',
      callId: 'call-1',
      reason: 'Inappropriate behavior',
      comment: 'Comentario privado',
      status: ReportStatus.pending,
      createdAt: created,
    );
    final restored = UserReport.fromJson(original.toJson());
    expect(restored.reason, original.reason);
    expect(restored.comment, original.comment);
    expect(restored.status, ReportStatus.pending);
    expect(
      restored.copyWith(status: ReportStatus.warned).status,
      ReportStatus.warned,
    );

    final anonymous = restored.anonymized();
    expect(anonymous.reporterId, kAnonymized);
    expect(anonymous.reportedId, kAnonymized);
    expect(anonymous.comment, isNull);
    expect(anonymous.callId, restored.callId);
  });
}

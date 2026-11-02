import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/domain/user_document_data.dart';

void main() {
  VitaUser volunteer({
    bool consent = false,
    bool reviewed = false,
    UserRole role = UserRole.volunteer,
  }) => VitaUser(
    id: 'user-1',
    role: role,
    displayName: 'Voluntario',
    status: AccountStatus.active,
    phone: '3001234567',
    email: 'volunteer@example.com',
    documentId: '123456789',
    photoBase64: 'private-profile-photo',
    volunteerBio: 'Me gusta conversar',
    volunteerInterests: 'Lectura',
    volunteerExperience: 'Acompañamiento',
    volunteerPresentationPhoto: 'presentation-photo',
    idFrontBase64: 'front-document',
    idBackBase64: 'back-document',
    identityDocumentConsent: true,
    volunteerPresentationConsent: consent,
    volunteerPresentationReviewed: reviewed,
  );

  test(
    'public user document excludes contact, identity, and private profile data',
    () {
      final publicData = publicUserDocument(
        volunteer(consent: true, reviewed: true),
      );

      expect(publicData['id'], 'user-1');
      expect(publicData['role'], 'volunteer');
      expect(publicData['displayName'], 'Voluntario');
      expect(publicData['volunteerBio'], 'Me gusta conversar');
      expect(publicData['volunteerPresentationPhoto'], 'presentation-photo');
      for (final privateField in [
        'phone',
        'email',
        'documentId',
        'photoBase64',
        'idFrontBase64',
        'idBackBase64',
        'identityDocumentConsent',
      ]) {
        expect(
          publicData.containsKey(privateField),
          isFalse,
          reason: privateField,
        );
      }
    },
  );

  test('presentation stays hidden unless consent and coordinator review are both true', () {
    for (final user in [
      volunteer(),
      volunteer(consent: true),
      volunteer(reviewed: true),
      volunteer(consent: true, reviewed: true, role: UserRole.elderly),
    ]) {
      final publicData = publicUserDocument(user);
      expect(publicData['volunteerBio'], isNull);
      expect(publicData['volunteerInterests'], isNull);
      expect(publicData['volunteerExperience'], isNull);
      expect(publicData['volunteerPresentationPhoto'], isNull);
    }
  });

  test(
    'private document carries sensitive fields separately from public profile',
    () {
      final privateData = privateUserDocument(
        volunteer(consent: true, reviewed: true),
      );

      expect(privateData['phone'], '3001234567');
      expect(privateData['email'], 'volunteer@example.com');
      expect(privateData['documentId'], '123456789');
      expect(privateData['photoBase64'], 'private-profile-photo');
      expect(privateData['idFrontBase64'], 'front-document');
      expect(privateData['idBackBase64'], 'back-document');
      expect(privateData['identityDocumentConsent'], isTrue);
      expect(privateData.containsKey('role'), isFalse);
      expect(privateData.containsKey('available'), isFalse);
    },
  );
}

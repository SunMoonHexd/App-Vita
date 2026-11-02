import 'package:vita_app/domain/models/vita_models.dart';

/// Campos visibles en `users`: datos de perfil y estado, nunca información privada.
Map<String, dynamic> publicUserDocument(VitaUser user) => {
  'id': user.id,
  'role': user.role.name,
  'displayName': user.displayName,
  'status': user.status.name,
  'consentAccepted': user.consentAccepted,
  'conductAccepted': user.conductAccepted,
  'inductionDone': user.inductionDone,
  'available': user.available,
  'onboardingDone': user.onboardingDone,
  'lastCallAt': user.lastCallAt == null ? null : vitaIso(user.lastCallAt!),
  'lastSeenAt': user.lastSeenAt == null ? null : vitaIso(user.lastSeenAt!),
  'emailVerified': user.emailVerified,
  'createdAt': user.createdAt == null ? null : vitaIso(user.createdAt!),
  'volunteerPresentationConsent': user.volunteerPresentationConsent,
  'volunteerPresentationReviewed': user.volunteerPresentationReviewed,
  'identityVerified': user.identityVerified,
  'volunteerBio': _canShowVolunteerPresentation(user)
      ? user.volunteerBio
      : null,
  'volunteerInterests': _canShowVolunteerPresentation(user)
      ? user.volunteerInterests
      : null,
  'volunteerExperience': _canShowVolunteerPresentation(user)
      ? user.volunteerExperience
      : null,
  'volunteerPresentationPhoto': _canShowVolunteerPresentation(user)
      ? user.volunteerPresentationPhoto
      : null,
};

/// Campos personales que se guardan por separado en `private/{uid}`.
Map<String, dynamic> privateUserDocument(VitaUser user) => {
  'phone': user.phone,
  'email': user.email,
  'documentId': user.documentId,
  'birthDate': user.birthDate?.toIso8601String(),
  'familyName': user.familyName,
  'familyPhone': user.familyPhone,
  'alternateName': user.alternateName,
  'alternatePhone': user.alternatePhone,
  'photoBase64': user.photoBase64,
  'volunteerBio': user.volunteerBio,
  'volunteerInterests': user.volunteerInterests,
  'volunteerExperience': user.volunteerExperience,
  'idFrontBase64': user.idFrontBase64,
  'idBackBase64': user.idBackBase64,
  'identityDocumentConsent': user.identityDocumentConsent,
  'idDocumentsUploadedAt': user.idDocumentsUploadedAt == null
      ? null
      : vitaIso(user.idDocumentsUploadedAt!),
  'identityVerifiedAt': user.identityVerifiedAt == null
      ? null
      : vitaIso(user.identityVerifiedAt!),
  'identityVerifiedBy': user.identityVerifiedBy,
};

bool _canShowVolunteerPresentation(VitaUser user) =>
    user.role == UserRole.volunteer &&
    user.volunteerPresentationConsent &&
    user.volunteerPresentationReviewed;

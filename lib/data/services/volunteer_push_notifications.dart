import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:vita_app/config/app_navigator.dart';
import 'package:vita_app/data/services/call_notice.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_incoming_call_view.dart';

/// Registra el dispositivo del voluntario para avisarle cuando le asignen una solicitud.
class VolunteerPushNotifications {
  VolunteerPushNotifications._();

  static final instance = VolunteerPushNotifications._();

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _registeredUserId;

  /// Pide permiso, guarda el token y escucha renovaciones mientras la app esté abierta.
  /// Devuelve false si el dispositivo no permite recibir notificaciones.
  Future<bool> registerVolunteer(String userId) async {
    final messaging = FirebaseMessaging.instance;
    if (!await messaging.isSupported()) return false;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return false;

    await _saveToken(userId, token);
    await _listenForTokenRefresh(userId, messaging);
    _listenForMessages();
    _registeredUserId = userId;

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) _openVolunteerHome(initialMessage);
    return true;
  }

  Future<void> _saveToken(String userId, String token) async {
    await FirebaseFirestore.instance.collection('pushTokens').doc(userId).set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _listenForTokenRefresh(
    String userId,
    FirebaseMessaging messaging,
  ) async {
    if (_registeredUserId == userId && _tokenSubscription != null) return;
    await _tokenSubscription?.cancel();
    _tokenSubscription = messaging.onTokenRefresh.listen((token) async {
      try {
        await _saveToken(userId, token);
      } catch (error) {
        debugPrint('No se pudo actualizar el token de notificaciones: $error');
      }
    });
  }

  void _listenForMessages() {
    _messageSubscription ??= FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'incoming_call') {
        CallNotice.show('Tienes una nueva solicitud de llamada.');
      }
    });
    _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _openVolunteerHome,
    );
  }

  void _openVolunteerHome(RemoteMessage message) {
    if (message.data['type'] != 'incoming_call') return;
    final requestId = message.data['requestId']?.toString();
    final navigator = appNavigatorKey.currentState;
    final context = navigator?.context;
    if (requestId == null || requestId.isEmpty || navigator == null || context == null) return;

    final user = VitaScope.of(context).currentUser;
    if (user == null || user.role != UserRole.volunteer) return;

    navigator
      ..popUntil((route) => route.isFirst)
      ..push(
        MaterialPageRoute<void>(
          builder: (_) => VolunteerIncomingCallView(requestId: requestId),
        ),
      );
  }
}

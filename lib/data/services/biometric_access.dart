import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/ui/core/vita_scope.dart';

/// Preferencia local para volver a desbloquear una sesión ya autenticada.
/// No se guardan PIN, correo ni contraseña en el dispositivo.
class BiometricAccess {
  BiometricAccess._();

  static const _enabledUidKey = 'vita_biometric_enabled_uid';
  static const _choiceUidKey = 'vita_biometric_choice_uid';
  static final LocalAuthentication _auth = LocalAuthentication();
  static final ValueNotifier<String?> enabledUidChanges = ValueNotifier(null);

  /// Sesión autenticada por formulario en este proceso (no persiste al cerrar la app).
  static String? _credentialAuthenticatedUid;

  static void markCredentialLogin(String uid) {
    _credentialAuthenticatedUid = uid;
  }

  static bool wasCredentialAuthenticated(String uid) =>
      _credentialAuthenticatedUid == uid;

  static void clearProcessSession() {
    _credentialAuthenticatedUid = null;
  }

  static Future<bool> isEnabledFor(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_enabledUidKey) == uid;
  }

  static Future<void> clearFor(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString(_enabledUidKey) == uid) {
      await preferences.remove(_enabledUidKey);
      enabledUidChanges.value = null;
    }
    if (preferences.getString(_choiceUidKey) == uid) {
      await preferences.remove(_choiceUidKey);
    }
  }

  /// Ofrece habilitar biometría luego de un ingreso normal correcto.
  static Future<void> offerAfterLogin(
    BuildContext context, {
    required String uid,
  }) async {
    try {
      if (!await _auth.isDeviceSupported() || !await _auth.canCheckBiometrics) {
        return;
      }
      if ((await _auth.getAvailableBiometrics()).isEmpty) return;

      final preferences = await SharedPreferences.getInstance();
      if (preferences.getString(_choiceUidKey) == uid) return;

      if (!context.mounted) return;
      final enable = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Protege tu sesión'),
          content: const Text(
            '¿Quieres desbloquear VITA con huella o reconocimiento facial '
            'cuando vuelvas a abrir la app?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Activar'),
            ),
          ],
        ),
      );
      if (!context.mounted || enable == null) return;

      await preferences.setString(_choiceUidKey, uid);
      if (!enable) return;

      final authenticated = await _auth.authenticate(
        localizedReason: 'Confirma tu identidad para activar el acceso biométrico a VITA',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        await preferences.setString(_enabledUidKey, uid);
        enabledUidChanges.value = uid;
      }
    } catch (error) {
      debugPrint('No se pudo configurar el acceso biométrico: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo activar la biometría en este dispositivo.'),
          ),
        );
      }
    }
  }

  static Future<bool> authenticate() async => _auth.authenticate(
    localizedReason: 'Desbloquea VITA para continuar',
    biometricOnly: true,
    persistAcrossBackgrounding: true,
  );
}

/// Cubre la pantalla con un bloqueo local cuando una sesión protegida vuelve del fondo.
class BiometricAccessGate extends StatefulWidget {
  const BiometricAccessGate({super.key, required this.child});

  final Widget child;

  @override
  State<BiometricAccessGate> createState() => _BiometricAccessGateState();
}

class _BiometricAccessGateState extends State<BiometricAccessGate>
    with WidgetsBindingObserver {
  String? _uid;
  bool _ready = false;
  bool _loading = false;
  bool _enabled = false;
  bool _locked = false;
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BiometricAccess.enabledUidChanges.addListener(_onPreferenceChanged);
  }

  void _onPreferenceChanged() {
    final uid = _uid;
    if (uid != null) _loadPreference(uid);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = VitaScope.of(context).currentUser?.id;
    if (uid == _uid && (_ready || _loading)) return;
    final previousUid = _uid;
    _uid = uid;
    _loading = true;
    if (uid == null && previousUid != null) {
      BiometricAccess.clearFor(previousUid);
    }
    _loadPreference(uid);
  }

  Future<void> _loadPreference(String? uid) async {
    if (uid == null) {
      BiometricAccess.clearProcessSession();
      if (mounted) {
        setState(() {
          _loading = false;
          _enabled = false;
          _locked = false;
          _ready = true;
          _error = null;
        });
      }
      return;
    }
    if (mounted) setState(() => _ready = false);
    final enabled = await BiometricAccess.isEnabledFor(uid);
    if (!mounted || uid != _uid) {
      _loading = false;
      return;
    }
    final shouldLock = enabled && !BiometricAccess.wasCredentialAuthenticated(uid);
    setState(() {
      _enabled = enabled;
      _locked = shouldLock;
      _ready = true;
      _loading = false;
      _error = null;
    });
    if (shouldLock) _authenticate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled || _uid == null) return;
    if (state == AppLifecycleState.paused && !_authenticating) {
      setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed && _locked) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating || !_enabled || _uid == null) return;
    _authenticating = true;
    try {
      final ok = await BiometricAccess.authenticate();
      if (!mounted) return;
      setState(() {
        _locked = !ok;
        _error = ok ? null : 'No se confirmó la identidad. Inténtalo de nuevo.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo abrir la biometría. $error');
    } finally {
      _authenticating = false;
    }
  }

  Future<void> _usePasswordInstead() async {
    final uid = _uid;
    if (uid != null) await BiometricAccess.clearFor(uid);
    BiometricAccess.clearProcessSession();
    if (!mounted) return;
    await VitaScope.of(context).logout();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BiometricAccess.enabledUidChanges.removeListener(_onPreferenceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_locked) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint_rounded, size: 76),
                const SizedBox(height: 16),
                const Text(
                  'Tu sesión está protegida',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Confirma con huella o reconocimiento facial para continuar.'),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _authenticating ? null : _authenticate,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Desbloquear VITA'),
                ),
                TextButton(
                  onPressed: _usePasswordInstead,
                  child: const Text('Cerrar sesión y entrar con contraseña o PIN'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

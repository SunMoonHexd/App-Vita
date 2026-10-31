import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vita_app/config/app_navigator.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/biometric_access.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/firebase_options.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/vita_theme_scope.dart';
import 'package:vita_app/ui/root_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Etapa 1: solo conectamos la app con Firebase. Los datos siguen siendo locales.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Firebase listo: ${Firebase.app().options.projectId}');

  final storage = LocalStorageService();
  await storage.init();

  final repository = VitaRepository(
    storage: storage,
    jitsi: LiveKitCallService(),
  );
  await repository.bootstrap();

  final themeController = VitaThemeController();
  await themeController.load();

  runApp(VitaApp(repository: repository, themeController: themeController));
}

class VitaApp extends StatefulWidget {
  const VitaApp({super.key, required this.repository, this.themeController});

  final VitaRepository repository;

  /// Apariencia elegida (claro/oscuro). Si no se pasa, se crea una en claro.
  final VitaThemeController? themeController;

  @override
  State<VitaApp> createState() => _VitaAppState();
}

class _VitaAppState extends State<VitaApp> {
  late final VitaThemeController _theme = widget.themeController ?? VitaThemeController();
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    if (widget.themeController == null) _theme.dispose();
    super.dispose();
  }

  /// Si coordinación suspendió o bloqueó la cuenta con la sesión abierta, se vuelve a la
  /// pantalla inicial y se explica por qué.
  void _onRepositoryChanged() {
    final notice = widget.repository.accessNotice;
    if (notice == null) return;
    widget.repository.accessNotice = null;
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dialogContext = appNavigatorKey.currentContext;
      if (dialogContext == null) return;
      showDialog<void>(
        context: dialogContext,
        builder: (context) => AlertDialog(
          title: const Text('Tu cuenta no está activa'),
          content: Text(notice),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return VitaScope(
      repository: widget.repository,
      child: VitaThemeScope(
        controller: _theme,
        // Se reconstruye al cambiar de sesión (rol) o de apariencia.
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.repository, _theme]),
          builder: (context, _) {
            final role = widget.repository.currentUser?.role;
            return MaterialApp(
              // LiveKit usa esta clave para abrir y cerrar la pantalla de llamada.
              navigatorKey: appNavigatorKey,
              title: 'App VITA',
              debugShowCheckedModeBanner: false,
              theme: VitaTheme.light,
              darkTheme: VitaTheme.dark,
              // El adulto mayor y las pantallas de ingreso siempre van en claro.
              themeMode: _theme.effectiveFor(role),
              builder: (context, child) {
                final dark = Theme.of(context).brightness == Brightness.dark;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
                    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: const BiometricAccessGate(child: RootGate()),
            );
          },
        ),
      ),
    );
  }
}

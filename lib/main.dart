import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/data/services/jitsi_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/firebase_options.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
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
    jitsi: JitsiCallService(),
  );
  await repository.bootstrap();

  runApp(VitaApp(repository: repository));
}

class VitaApp extends StatefulWidget {
  const VitaApp({super.key, required this.repository});

  final VitaRepository repository;

  @override
  State<VitaApp> createState() => _VitaAppState();
}

class _VitaAppState extends State<VitaApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  /// Si coordinación suspendió o bloqueó la cuenta con la sesión abierta, se vuelve a la
  /// pantalla inicial y se explica por qué.
  void _onRepositoryChanged() {
    final notice = widget.repository.accessNotice;
    if (notice == null) return;
    widget.repository.accessNotice = null;
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dialogContext = _navigatorKey.currentContext;
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
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'App VITA',
        debugShowCheckedModeBanner: false,
        theme: VitaTheme.light,
        home: const RootGate(),
      ),
    );
  }
}

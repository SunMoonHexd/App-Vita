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

class VitaApp extends StatelessWidget {
  const VitaApp({super.key, required this.repository});

  final VitaRepository repository;

  @override
  Widget build(BuildContext context) {
    return VitaScope(
      repository: repository,
      child: MaterialApp(
        title: 'App VITA',
        debugShowCheckedModeBanner: false,
        theme: VitaTheme.light,
        home: const RootGate(),
      ),
    );
  }
}

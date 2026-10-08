import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/coordinator/coordinator_home_view.dart';

class CoordinatorLoginView extends StatefulWidget {
  const CoordinatorLoginView({super.key});

  @override
  State<CoordinatorLoginView> createState() => _CoordinatorLoginViewState();
}

class _CoordinatorLoginViewState extends State<CoordinatorLoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Coordinación',
      child: ListView(
        children: [
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo')),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
          const SizedBox(height: 12),
          VitaErrorText(_error),
          VitaPrimaryButton(
            label: 'Entrar',
            onPressed: () async {
              final result = await VitaScope.of(context).loginCoordinator(
                email: _email.text.trim(),
                password: _password.text,
              );
              if (!context.mounted) return;
              if (!result.isOk) {
                setState(() => _error = result.error);
                return;
              }
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const CoordinatorHomeView()),
                (route) => route.isFirst,
              );
            },
          ),
        ],
      ),
    );
  }
}

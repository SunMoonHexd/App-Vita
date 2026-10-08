import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_home_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_recover_view.dart';

class VolunteerLoginView extends StatefulWidget {
  const VolunteerLoginView({super.key});

  @override
  State<VolunteerLoginView> createState() => _VolunteerLoginViewState();
}

class _VolunteerLoginViewState extends State<VolunteerLoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await VitaScope.of(context).loginVolunteer(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.isOk) {
      setState(() => _error = result.error);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const VolunteerHomeView()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Ingreso voluntario',
      child: ListView(
        children: [
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo')),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
          const SizedBox(height: 12),
          VitaErrorText(_error),
          VitaPrimaryButton(label: _loading ? 'Ingresando...' : 'Entrar', color: Colors.blue.shade700, onPressed: _loading ? null : _submit),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerRecoverView())),
            child: const Text('¿Olvidó su contraseña?'),
          ),
        ],
      ),
    );
  }
}

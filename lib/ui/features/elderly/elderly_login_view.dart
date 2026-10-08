import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/elderly/elderly_home_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_recover_view.dart';

class ElderlyLoginView extends StatefulWidget {
  const ElderlyLoginView({super.key});

  @override
  State<ElderlyLoginView> createState() => _ElderlyLoginViewState();
}

class _ElderlyLoginViewState extends State<ElderlyLoginView> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await VitaScope.of(context).loginElderly(phone: _phone.text.trim(), pin: _pin.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.isOk) {
      setState(() => _error = result.error);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ElderlyHomeView()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Ingresar',
      child: ListView(
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'PIN de 4 dígitos'),
          ),
          VitaErrorText(_error),
          VitaPrimaryButton(
            label: _loading ? 'Ingresando...' : 'Entrar',
            onPressed: _loading ? null : _submit,
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ElderlyRecoverView())),
            child: const Text('Olvidé mi PIN', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

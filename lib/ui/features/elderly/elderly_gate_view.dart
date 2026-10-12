import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/elderly/elderly_login_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_register_view.dart';

class ElderlyGateView extends StatelessWidget {
  const ElderlyGateView({super.key});

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Adulto mayor',
      child: Column(
        children: [
          const Text('¿Cómo deseas ingresar?', textAlign: TextAlign.center, style: TextStyle(fontSize: 22)),
          const SizedBox(height: 28),
          VitaPrimaryButton(
            label: 'Ya tengo cuenta',
            icon: Icons.login,
            height: 88,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ElderlyLoginView())),
          ),
          const SizedBox(height: 16),
          VitaPrimaryButton(
            label: 'Quiero registrarme',
            icon: Icons.person_add,
            color: VitaColors.slate,
            height: 88,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ElderlyRegisterView())),
          ),
        ],
      ),
    );
  }
}

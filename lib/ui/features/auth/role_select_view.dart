import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/auth/coordinator_login_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_gate_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_gate_view.dart';

class RoleSelectView extends StatelessWidget {
  const RoleSelectView({super.key});

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'App VITA',
      child: ListView(
        children: [
          const Text(
            'Videollamada de acompañamiento para el adulto mayor',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Este servicio no reemplaza atención médica ni la línea 123.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          VitaPrimaryButton(
            label: 'Soy adulto mayor',
            icon: Icons.favorite,
            height: 96,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ElderlyGateView())),
          ),
          const SizedBox(height: 16),
          VitaPrimaryButton(
            label: 'Soy voluntario',
            icon: Icons.volunteer_activism,
            color: Colors.blue.shade700,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerGateView())),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoordinatorLoginView())),
            child: const Text('Entrar como coordinación', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cuentas de demostración\n'
            'Adulto: 3001112233 / PIN 1234\n'
            'Voluntario: voluntario@vita.app / Voluntario1\n'
            'Coordinación: coordinacion@vita.app / CoordVita1',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
        ],
      ),
    );
  }
}

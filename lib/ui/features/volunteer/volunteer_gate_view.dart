import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_login_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_register_view.dart';

class VolunteerGateView extends StatelessWidget {
  const VolunteerGateView({super.key});

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Voluntario',
      child: Column(
        children: [
          VitaPrimaryButton(
            label: 'Ya tengo cuenta',
            icon: Icons.login,
            color: Colors.blue.shade700,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerLoginView())),
          ),
          const SizedBox(height: 16),
          VitaPrimaryButton(
            label: 'Quiero ser voluntario',
            icon: Icons.person_add,
            color: Colors.teal.shade700,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerRegisterView())),
          ),
        ],
      ),
    );
  }
}

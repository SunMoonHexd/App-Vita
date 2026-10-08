import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/auth/onboarding_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_profile_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_searching_view.dart';

class ElderlyHomeView extends StatelessWidget {
  const ElderlyHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final user = repo.currentUser;
    if (user == null) {
      return const VitaPage(title: 'VITA', child: Text('Sesión cerrada'));
    }
    if (!user.onboardingDone) {
      return OnboardingView(onDone: () {});
    }

    return VitaPage(
      title: 'Hola, ${user.displayName}',
      actions: [
        IconButton(
          icon: const Icon(Icons.person),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ElderlyProfileView())),
        ),
      ],
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.wifi, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text('Listo para llamar'),
            ],
          ),
          const SizedBox(height: 12),
          Text(repo.serviceHoursLabel, textAlign: TextAlign.center),
          const Spacer(),
          VitaPrimaryButton(
            label: 'Necesito hablar',
            icon: Icons.video_call,
            height: 120,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ElderlySearchingView()));
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Un voluntario te acompañará por videollamada. No es un servicio médico.',
            textAlign: TextAlign.center,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

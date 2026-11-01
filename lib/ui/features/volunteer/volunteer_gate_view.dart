import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_login_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_register_view.dart';

class VolunteerGateView extends StatelessWidget {
  const VolunteerGateView({super.key});

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Voluntario',
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: VitaGradients.blueColors),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/images/role_volunteer.png', height: 142, width: 142, fit: BoxFit.cover),
              ),
              const SizedBox(height: 14),
              const Text('Acompaña con tu tiempo', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Conversar y escuchar puede hacer una gran diferencia.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, height: 1.35)),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('¿Qué quieres hacer?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _VolunteerChoiceCard(
            icon: Icons.login_rounded,
            title: 'Ya tengo cuenta',
            description: 'Continúa con tu correo y contraseña para ver tus horarios y acompañamientos.',
            buttonLabel: 'Ingresar',
            color: VitaColors.secondary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerLoginView())),
          ),
          const SizedBox(height: 12),
          _VolunteerChoiceCard(
            icon: Icons.volunteer_activism_rounded,
            title: 'Quiero ser voluntario',
            description: 'El registro es guiado y toma unos pasos: tus datos, verificación de identidad y una breve presentación.',
            buttonLabel: 'Empezar registro',
            color: VitaColors.slate,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerRegisterView())),
          ),
          const SizedBox(height: 14),
          const _VolunteerStepHint(icon: Icons.badge_outlined, title: 'Identidad protegida', text: 'Tu cédula solo la revisa coordinación y se elimina después de verificarla.'),
          const SizedBox(height: 8),
          const _VolunteerStepHint(icon: Icons.verified_user_outlined, title: 'Aprobación de coordinación', text: 'Tu cuenta se activa cuando completes la revisión y la inducción.'),
        ],
      ),
    );
  }
}

class _VolunteerChoiceCard extends StatelessWidget {
  const _VolunteerChoiceCard({required this.icon, required this.title, required this.description, required this.buttonLabel, required this.color, required this.onTap});

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 9),
            Text(description, style: const TextStyle(fontSize: 15, height: 1.35, color: VitaColors.muted)),
            const SizedBox(height: 12),
            VitaPrimaryButton(label: buttonLabel, icon: icon, color: color, height: 54, onPressed: onTap),
          ]),
        ),
      );
}

class _VolunteerStepHint extends StatelessWidget {
  const _VolunteerStepHint({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: VitaColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text.rich(TextSpan(children: [
          TextSpan(text: '$title. ', style: const TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: text),
        ]))),
      ]);
}

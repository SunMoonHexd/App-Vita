import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/features/auth/coordinator_login_view.dart';
import 'package:vita_app/ui/features/psychologist/psychologist_login_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_gate_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_gate_view.dart';

class RoleSelectView extends StatelessWidget {
  const RoleSelectView({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitaColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera blanca con logo y título
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: VitaColors.primaryLight.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset('assets/icon/logo.png', fit: BoxFit.cover, cacheWidth: 288),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'VITA',
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Videollamada de Interacción y\nTelecompañía para el Adulto Mayor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: VitaColors.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '¿Cómo vas a usar VITA?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Elige tu perfil para comenzar',
                    style: TextStyle(fontSize: 17, color: VitaColors.muted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                children: [
                  _RoleCard(
                    image: 'assets/images/role_elderly.png',
                    title: 'Soy adulto mayor',
                    subtitle: 'Quiero conversar con alguien y recibir compañía',
                    pill: '60+ años',
                    colors: VitaGradients.tealColors,
                    onTap: () => _go(context, const ElderlyGateView()),
                  ),
                  const SizedBox(height: 18),
                  _RoleCard(
                    image: 'assets/images/role_volunteer.png',
                    title: 'Soy voluntario',
                    subtitle: 'Quiero acompañar y ofrecer mi tiempo',
                    pill: 'Mayor de 18 años',
                    colors: VitaGradients.blueColors,
                    onTap: () => _go(context, const VolunteerGateView()),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: VitaColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: VitaColors.muted),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Este servicio no reemplaza atención médica ni la línea 123.',
                            style: TextStyle(fontSize: 15, height: 1.3, color: VitaColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: VitaColors.slate),
                      onPressed: () => _go(context, const CoordinatorLoginView()),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Entrar como coordinación'),
                    ),
                  ),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: VitaColors.slate),
                      onPressed: () => _go(context, const PsychologistLoginView()),
                      icon: const Icon(Icons.psychology_alt_outlined),
                      label: const Text('Entrar como profesional de apoyo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.pill,
    required this.colors,
    required this.onTap,
  });

  final String image;
  final String title;
  final String subtitle;
  final String pill;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 104,
                    height: 112,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        image,
                        fit: BoxFit.cover,
                        cacheWidth: 312,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Colors.white24,
                          child: Icon(Icons.people_alt_rounded, color: Colors.white, size: 42),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            pill,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

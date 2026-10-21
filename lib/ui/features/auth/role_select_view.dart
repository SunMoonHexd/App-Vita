import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/features/auth/coordinator_login_view.dart';
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
                    emoji: '🧓',
                    title: 'Soy adulto mayor',
                    subtitle: 'Quiero conversar con alguien y recibir compañía',
                    pill: '60+ años',
                    colors: const [Color(0xFF16897B), Color(0xFF26AA9A)],
                    onTap: () => _go(context, const ElderlyGateView()),
                  ),
                  const SizedBox(height: 18),
                  _RoleCard(
                    emoji: '🤝',
                    title: 'Soy voluntario',
                    subtitle: 'Quiero acompañar y ofrecer mi tiempo',
                    pill: 'Mayor de 18 años',
                    colors: const [Color(0xFF3F6DB3), Color(0xFF5E8CD2)],
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
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.pill,
    required this.colors,
    required this.onTap,
  });

  final String emoji;
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
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 38)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            pill,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.chevron_right_rounded, color: Colors.white, size: 32),
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

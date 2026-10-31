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
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Container(
                  width: 174,
                  height: 174,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(38),
                    border: Border.all(color: VitaColors.tintBorder, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: VitaColors.primaryLight.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/images/role_elderly.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  '¡Qué bueno verte!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Elige una opción para continuar en VITA.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    color: VitaColors.muted,
                  ),
                ),
                const SizedBox(height: 26),
                _ElderlyEntryButton(
                  title: 'Ya tengo una cuenta',
                  subtitle: 'Entrar con mi celular y PIN',
                  icon: Icons.login_rounded,
                  colors: VitaGradients.heroTeal,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ElderlyLoginView()),
                  ),
                ),
                const SizedBox(height: 14),
                _ElderlyEntryButton(
                  title: 'Quiero crear mi cuenta',
                  subtitle: 'Registrarme por primera vez',
                  icon: Icons.person_add_alt_1_rounded,
                  colors: VitaGradients.heroBlue,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ElderlyRegisterView(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ElderlyEntryButton extends StatelessWidget {
  const _ElderlyEntryButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 116),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.17),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: Icon(icon, color: Colors.white, size: 38),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

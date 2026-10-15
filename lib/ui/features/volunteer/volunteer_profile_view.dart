import 'package:flutter/material.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/auth_widgets.dart';
import 'package:vita_app/ui/core/widgets/profile_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/shared/legal_text_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_actions.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_edit_profile_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_format.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_schedule_view.dart';

String _maskDocument(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Sin registrar';
  if (v.length <= 4) return v;
  return '${'•' * (v.length - 4)}${v.substring(v.length - 4)}';
}

class VolunteerProfileView extends StatelessWidget {
  const VolunteerProfileView({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final user = repo.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sesión cerrada')));
    }
    final active = user.status == AccountStatus.active;
    final hours = repo.volunteerHours(user.id);
    final completed = repo.requests
        .where((r) => r.volunteerId == user.id && r.status == CallRequestStatus.completed)
        .length;

    return Scaffold(
      backgroundColor: VitaColors.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 22),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Volver',
                      iconSize: 36,
                      color: VitaColors.secondary,
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  VitaAvatar(name: user.displayName, size: 96),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      user.displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFFE3F5EA) : const Color(0xFFFFF0D6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? const Color(0xFF8BCFA3) : const Color(0xFFE0A93B)),
                    ),
                    child: Text(
                      active ? '✓ Voluntario verificado' : 'Cuenta ${user.status.name}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: active ? const Color(0xFF1E6B3F) : const Color(0xFF8A5300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _Stat(emoji: '⏱️', value: formatDuration(hours), label: 'Acompañando')),
                      const SizedBox(width: 14),
                      Expanded(child: _Stat(emoji: '📞', value: '$completed', label: 'Llamadas completadas')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  VitaCard(
                    children: [
                      const VitaCardTitle('MIS DATOS'),
                      VitaDataRow(
                        emoji: '📱',
                        label: 'Teléfono',
                        value: (user.phone ?? '').isEmpty ? 'Sin registrar' : user.phone!,
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      VitaDataRow(
                        emoji: '✉️',
                        label: 'Correo',
                        value: (user.email ?? '').isEmpty ? 'Sin registrar' : user.email!,
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      VitaDataRow(emoji: '🪪', label: 'Documento', value: _maskDocument(user.documentId)),
                      const SizedBox(height: 8),
                    ],
                  ),
                  const SizedBox(height: 20),
                  VitaCard(
                    children: [
                      VitaMenuRow(
                        emoji: '✏️',
                        label: 'Editar mis datos',
                        onTap: () => _open(context, const VolunteerEditProfileView()),
                      ),
                      const Divider(height: 1),
                      VitaMenuRow(
                        emoji: '🗓️',
                        label: 'Mis horarios',
                        onTap: () => _open(context, const VolunteerScheduleView()),
                      ),
                      const Divider(height: 1),
                      VitaMenuRow(
                        emoji: '📄',
                        label: 'Política de privacidad',
                        onTap: () => _open(
                          context,
                          const LegalTextView(title: 'Política de privacidad', sections: privacySections),
                        ),
                      ),
                      const Divider(height: 1),
                      VitaMenuRow(
                        emoji: '📋',
                        label: 'Términos y código de conducta',
                        onTap: () => _open(
                          context,
                          const LegalTextView(title: 'Términos y código de conducta', sections: [
                            ...termsSections,
                            LegalSection('Código de conducta del voluntario', conductText),
                          ]),
                        ),
                      ),
                      const Divider(height: 1),
                      VitaMenuRow(
                        emoji: '🗑️',
                        label: 'Solicitar eliminación de mis datos',
                        danger: true,
                        onTap: () => confirmVolunteerDeletion(context),
                      ),
                      const Divider(height: 1),
                      VitaMenuRow(
                        emoji: '🚪',
                        label: 'Cerrar sesión',
                        danger: true,
                        onTap: () => confirmVolunteerLogout(context),
                      ),
                    ],
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

class _Stat extends StatelessWidget {
  const _Stat({required this.emoji, required this.value, required this.label});

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: VitaColors.border),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: VitaColors.secondary),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: VitaColors.muted),
          ),
        ],
      ),
    );
  }
}

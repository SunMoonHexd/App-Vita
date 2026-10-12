import 'package:flutter/material.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/features/auth/role_select_view.dart';
import 'package:vita_app/ui/features/coordinator/coordinator_home_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_home_view.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_home_view.dart';

/// Pantalla raíz: si hay una sesión abierta, entra directo a la pantalla de inicio
/// del perfil correspondiente; si no, muestra la elección de perfil.
/// Al ingresar o cerrar sesión cambia sola, sin tener que navegar a mano.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = VitaScope.of(context).currentUser;
    if (user == null) return const RoleSelectView();
    switch (user.role) {
      case UserRole.elderly:
        return const ElderlyHomeView();
      case UserRole.volunteer:
        return const VolunteerHomeView();
      case UserRole.coordinator:
        return const CoordinatorHomeView();
    }
  }
}

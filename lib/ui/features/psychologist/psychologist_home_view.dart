import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/theme_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_format.dart';

/// Inicio del profesional de apoyo: ve las solicitudes abiertas que pidieron los voluntarios
/// y se une a la llamada de la persona que lo necesita.
class PsychologistHomeView extends StatefulWidget {
  const PsychologistHomeView({super.key});

  @override
  State<PsychologistHomeView> createState() => _PsychologistHomeViewState();
}

class _PsychologistHomeViewState extends State<PsychologistHomeView> {
  Timer? _clock;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    // Refresca "hace X min" sin depender de que llegue otro cambio de Firestore.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _accept(SupportRequest request) async {
    final repo = VitaScope.of(context);
    setState(() => _busyId = request.id);
    try {
      await repo.acceptSupport(request.id);
      await repo.joinSupportCall(request.id);
    } catch (e) {
      if (mounted) {
        await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _rejoin(SupportRequest request) async {
    final repo = VitaScope.of(context);
    setState(() => _busyId = request.id);
    try {
      await repo.joinSupportCall(request.id);
    } catch (e) {
      if (mounted) {
        await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _since(DateTime t) {
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 1) return 'hace menos de 1 min';
    return 'hace $m min';
  }

  String _personName(VitaRepository repo, SupportRequest r) {
    final u = repo.userById(r.elderlyId);
    return u == null ? 'Adulto mayor' : shortName(u.displayName, fallback: 'Adulto mayor');
  }

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final me = repo.currentUser;
    if (me == null) {
      return const VitaPage(title: 'Apoyo psicológico', child: Text('Sesión cerrada'));
    }
    final open = repo.openSupportRequests;
    final mine = repo.mySupportInProgress;

    return VitaPage(
      title: 'Hola, ${shortName(me.displayName, fallback: 'profesional')}',
      actions: [
        IconButton(
          tooltip: 'Apariencia',
          icon: const Icon(Icons.brightness_6_rounded),
          onPressed: () => showVitaThemeSheet(context),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await repo.logout();
            if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ],
      child: ListView(
        children: [
          const Text(
            'Cuando un voluntario note a una persona muy triste, la solicitud aparece aquí. '
            'Al aceptar, entras a la misma videollamada. Mantén la app abierta para ver las solicitudes.',
          ),
          const SizedBox(height: 16),
          if (mine.isNotEmpty) ...[
            const Text('En curso', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 8),
            for (final r in mine)
              VitaCard(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(_personName(repo, r), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('Aceptada ${_since(r.acceptedAt ?? r.createdAt)}'),
                  const SizedBox(height: 12),
                  VitaPrimaryButton(
                    label: _busyId == r.id ? 'Conectando…' : 'Volver a unirme',
                    onPressed: _busyId == null ? () => _rejoin(r) : null,
                  ),
                ],
              ),
            const SizedBox(height: 16),
          ],
          const Text('Solicitudes abiertas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 8),
          if (open.isEmpty) const Text('No hay solicitudes por ahora.'),
          for (final r in open) ...[
            VitaCard(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_personName(repo, r), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 4),
                Text('Pedida ${_since(r.createdAt)}'),
                if (r.note != null) ...[
                  const SizedBox(height: 4),
                  Text(r.note!),
                ],
                const SizedBox(height: 12),
                VitaPrimaryButton(
                  label: _busyId == r.id ? 'Conectando…' : 'Aceptar y unirme',
                  onPressed: _busyId == null ? () => _accept(r) : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

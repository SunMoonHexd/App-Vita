import 'package:flutter/material.dart';
import 'package:vita_app/domain/audit_log.dart';
import 'package:vita_app/domain/data_retention.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

/// Administración de seguridad, privacidad y Habeas Data para coordinación (RF44 · F18.7).
class PrivacyAdminView extends StatefulWidget {
  const PrivacyAdminView({super.key});

  @override
  State<PrivacyAdminView> createState() => _PrivacyAdminViewState();
}

class _PrivacyAdminViewState extends State<PrivacyAdminView> {
  final _days = TextEditingController();
  Stream<List<AuditEntry>>? _audit;
  Future<List<Map<String, dynamic>>>? _requests;
  bool _started = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final repo = VitaScope.of(context);
    _days.text = repo.retentionDays.toString();
    _audit = repo.auditStream();
    _requests = repo.loadDataRequests();
    repo.loadPrivacyConfig().then((_) {
      if (mounted) _days.text = repo.retentionDays.toString();
    });
  }

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  static String _fmt(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _save() async {
    final repo = VitaScope.of(context);
    final parsed = int.tryParse(_days.text.trim());
    if (parsed == null || parsed < kMinRetentionDays) {
      await showVitaMessage(context, 'Escribe un número de días de $kMinRetentionDays o más.');
      return;
    }
    setState(() => _busy = true);
    try {
      await repo.saveRetentionDays(parsed);
      if (!mounted) return;
      _days.text = repo.retentionDays.toString();
      await showVitaMessage(context, 'Tiempo de retención guardado: ${repo.retentionDays} días.');
    } catch (_) {
      if (mounted) {
        await showVitaMessage(context, 'No se pudo guardar. Revisa tu conexión y las reglas de Firebase.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _anonymize() async {
    final repo = VitaScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Anonimizar datos vencidos'),
        content: const Text(
          'Se quitarán los nombres y datos personales de las llamadas, reportes y alertas que superaron '
          'el tiempo de retención. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Anonimizar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final count = await repo.anonymizeExpiredData();
    if (!mounted) return;
    setState(() => _busy = false);
    await showVitaMessage(context, count == 0 ? 'No había datos vencidos.' : 'Se anonimizaron $count registros.');
  }

  String _roleLine(List<VitaUser> users, UserRole role, String label) {
    final of = users.where((u) => u.role == role);
    final active = of.where((u) => u.status == AccountStatus.active).length;
    final pending = of.where((u) => u.status == AccountStatus.pending).length;
    final restricted = of.where((u) => u.status == AccountStatus.suspended || u.status == AccountStatus.blocked).length;
    return '$label: $active activas · $pending pendientes · $restricted suspendidas o bloqueadas';
  }

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final muted = context.vita.muted;
    final users = repo.users.where((u) => u.status != AccountStatus.deleted).toList();
    final expired = repo.expiredCounts;
    final totalExpired = expired.values.fold<int>(0, (a, b) => a + b);

    return VitaPage(
      title: 'Privacidad y seguridad',
      child: ListView(
        children: [
          _Section(
            title: 'Protección de la información',
            children: [
              const Text('• En tránsito: las conexiones con Firebase y con LiveKit van cifradas (TLS).'),
              const Text('• En reposo: los datos se guardan cifrados en Firebase (Google Cloud).'),
              const Text('• Las videollamadas se autorizan con pases firmados en el servidor: la clave secreta no va en la app.'),
              const Text('• El acceso a cada dato depende del rol, con reglas en Firestore.'),
              const Text('• Las imágenes de cédula de voluntarios quedan en su documento privado: solo puede leerlas el propio voluntario y coordinación. No se comparten con adultos mayores.'),
              const SizedBox(height: 6),
              Text('Estos parámetros los administra la plataforma; no se cambian desde la app.', style: TextStyle(color: muted)),
            ],
          ),
          _Section(
            title: 'Cuentas por rol',
            children: [
              Text(_roleLine(users, UserRole.elderly, 'Adultos mayores')),
              Text(_roleLine(users, UserRole.volunteer, 'Voluntarios')),
              Text(_roleLine(users, UserRole.coordinator, 'Coordinación')),
              Text(_roleLine(users, UserRole.psychologist, 'Psicología')),
              const SizedBox(height: 6),
              Text('Los voluntarios solo pasan a activos cuando coordinación los aprueba.', style: TextStyle(color: muted)),
            ],
          ),
          _Section(
            title: 'Retención y anonimización de datos',
            children: [
              TextField(
                controller: _days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Días que se conservan los datos',
                  helperText: 'Entre $kMinRetentionDays y $kMaxRetentionDays días.',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: _busy ? null : _save, child: const Text('Guardar')),
              const Divider(height: 24),
              Text(
                totalExpired == 0
                    ? 'No hay datos que hayan superado la retención.'
                    : 'Superaron la retención: ${expired.entries.map((e) => '${e.value} ${e.key.toLowerCase()}').join(', ')}.',
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: (_busy || totalExpired == 0) ? null : _anonymize,
                child: const Text('Anonimizar datos vencidos'),
              ),
              const SizedBox(height: 6),
              Text(
                'Al anonimizar se conservan fechas, estados y duraciones para las estadísticas, sin nombres ni identificadores.',
                style: TextStyle(color: muted),
              ),
            ],
          ),
          _Section(
            title: 'Solicitudes de supresión de datos',
            children: [
              Text(
                'Cada persona puede eliminar su cuenta desde su perfil, con su PIN o contraseña. Se atiende al instante y queda este registro, sin identidad.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _requests,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) return const Text('Cargando…');
                  if (snap.hasError) return const Text('No se pudo leer el registro (revisa las reglas de Firestore).');
                  final items = snap.data ?? const <Map<String, dynamic>>[];
                  if (items.isEmpty) return const Text('Todavía no hay solicitudes de supresión.');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${items.length} atendidas (se muestran las últimas 5):'),
                      for (final item in items.take(5))
                        Text(
                          '• ${DateTime.tryParse('${item['requestedAt']}') == null ? '-' : _fmt(DateTime.parse('${item['requestedAt']}'))} · ${item['role']} · atendida al instante',
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          _Section(
            title: 'Registro de cambios de seguridad',
            children: [
              StreamBuilder<List<AuditEntry>>(
                stream: _audit,
                builder: (context, snap) {
                  if (snap.hasError) return const Text('No se pudo leer el registro (revisa las reglas de Firestore).');
                  final entries = snap.data;
                  if (entries == null) return const Text('Cargando…');
                  if (entries.isEmpty) return const Text('Todavía no hay cambios registrados.');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            '${_fmt(e.createdAt)} · ${e.actorName} · ${auditLabel(e.action)}'
                            '${e.detail == null ? '' : ' (${e.detail})'}',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

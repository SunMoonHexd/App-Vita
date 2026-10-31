import 'package:flutter/material.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/shared/survey_view.dart';

/// Destino directo de una notificación de llamada entrante.
class VolunteerIncomingCallView extends StatefulWidget {
  const VolunteerIncomingCallView({super.key, required this.requestId});

  final String requestId;

  @override
  State<VolunteerIncomingCallView> createState() =>
      _VolunteerIncomingCallViewState();
}

class _VolunteerIncomingCallViewState extends State<VolunteerIncomingCallView> {
  bool _working = false;

  Future<void> _accept(CallRequest request) async {
    if (_working) return;
    setState(() => _working = true);
    final repo = VitaScope.of(context);
    try {
      await repo.acceptRequest(request.id);
      await repo.joinCurrentCall();
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SurveyView(request: request, askAccompanied: false),
        ),
      );
    } catch (error) {
      if (mounted) {
        await showVitaMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _reject(CallRequest request) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await VitaScope.of(context).rejectRequest(request.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        await showVitaMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final request = repo.requests.cast<CallRequest?>().firstWhere(
          (item) => item?.id == widget.requestId,
          orElse: () => null,
        );
        final user = repo.currentUser;
        final assignedToMe = request?.volunteerId == user?.id;
        final stillRinging = request?.status == CallRequestStatus.ringing;
        final connecting =
            request != null &&
            assignedToMe &&
            request.status == CallRequestStatus.connected;
        final canAnswer = request != null && assignedToMe && stillRinging;

        return VitaPage(
          title: request?.audioOnly == true
              ? 'Solicitud de llamada de voz'
              : 'Solicitud de videollamada',
          child: Center(
            child: VitaCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📞', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      canAnswer
                          ? 'Alguien espera compañía'
                          : connecting
                          ? 'Conectando a la llamada…'
                          : 'Esta solicitud ya no está disponible',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      canAnswer
                          ? request.audioOnly
                                ? 'La persona quiere conversar por voz. Acepta para iniciar la llamada.'
                                : 'Si puedes conversar ahora, acepta para iniciar la videollamada.'
                          : connecting
                          ? request.audioOnly
                                ? 'Estamos preparando la llamada de voz. Esto puede tardar unos segundos.'
                                : 'Estamos preparando la videollamada. Esto puede tardar unos segundos.'
                          : 'Puede que otra persona ya la haya atendido o que haya vencido.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.vita.muted, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    if (connecting) ...[
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No cierres esta pantalla mientras conectamos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.vita.muted),
                      ),
                    ] else if (canAnswer) ...[
                      SizedBox(
                        width: double.infinity,
                        child: VitaPrimaryButton(
                          label: _working ? 'Un momento…' : 'Aceptar llamada',
                          onPressed: _working ? null : () => _accept(request),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _working ? null : () => _reject(request),
                        child: const Text('Rechazar'),
                      ),
                    ] else
                      VitaPrimaryButton(
                        label: 'Volver al inicio',
                        onPressed: _working
                            ? null
                            : () => Navigator.pop(context),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

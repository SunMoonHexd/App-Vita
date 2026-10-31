import 'dart:async';

import 'package:vita_app/ui/core/theme/vita_theme.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/shared/report_view.dart';
import 'package:vita_app/ui/features/shared/survey_view.dart';

class ElderlySearchingView extends StatefulWidget {
  const ElderlySearchingView({super.key, this.audioOnly = false});

  final bool audioOnly;

  @override
  State<ElderlySearchingView> createState() => _ElderlySearchingViewState();
}

class _ElderlySearchingViewState extends State<ElderlySearchingView> {
  CallRequest? _request;
  String? _error;
  Timer? _ringTimer;
  bool _joining = false;
  bool _closed = false;
  VitaRepository? _repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _repo?.removeListener(_onRepoChanged);
    super.dispose();
  }

  /// Cierra esta pantalla UNA sola vez. Al cancelar se disparan dos caminos (el aviso del
  /// repositorio y el botón); si los dos hacían pop, el segundo sacaba también la pantalla de
  /// abajo y la app quedaba en negro.
  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.pop(context);
  }

  Future<void> _start({String? recallOf}) async {
    try {
      final repo = VitaScope.of(context);
      final request = recallOf == null
          ? await repo.startCallRequest(audioOnly: widget.audioOnly)
          : await repo.recallAfterInterruption(
              recallOf,
              audioOnly: widget.audioOnly,
            );
      if (!mounted) return;
      setState(() => _request = request);
      _repo = VitaScope.of(context);
      _repo!.addListener(_onRepoChanged);
      _watch(request);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Reacciona cuando el voluntario (en otro celular) acepta o cambia la solicitud.
  void _onRepoChanged() {
    final current = _request;
    final repo = _repo;
    if (!mounted || current == null || repo == null) return;
    final latest = repo.requests.cast<CallRequest?>().firstWhere(
      (r) => r?.id == current.id,
      orElse: () => null,
    );
    if (latest == null) return;
    if (latest.status == current.status &&
        latest.volunteerId == current.volunteerId)
      return;
    setState(() => _request = latest);
    _watch(latest);
  }

  void _watch(CallRequest request) {
    _ringTimer?.cancel();
    switch (request.status) {
      case CallRequestStatus.expired:
        setState(() => _error = 'No hay voluntarios disponibles ahora.');
      case CallRequestStatus.cancelled:
        _close();
      case CallRequestStatus.connected:
        _enterCall();
      case CallRequestStatus.ringing:
        _ringTimer = Timer(VitaRepositoryTimes.ring, () async {
          if (!mounted) return;
          final repo = VitaScope.of(context);
          if (request.volunteerId == 'volunteer-demo') {
            final accepted = await repo.autoAcceptDemo(request.id);
            if (!mounted) return;
            setState(() => _request = accepted);
            _watch(accepted);
            return;
          }
          final next = await repo.timeoutRing(request.id);
          if (!mounted) return;
          setState(() => _request = next);
          _watch(next);
        });
      case CallRequestStatus.searching:
      case CallRequestStatus.completed:
      case CallRequestStatus.interrupted:
        break;
    }
  }

  Future<void> _enterCall() async {
    if (_joining) return;
    setState(() => _joining = true);
    final repo = VitaScope.of(context);
    try {
      await repo.joinCurrentCall();
    } catch (e) {
      if (mounted) {
        await showVitaMessage(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
    if (!mounted) return;
    final request = repo.requests.cast<CallRequest?>().firstWhere(
      (r) => r?.id == _request?.id,
      orElse: () => _request,
    );
    var recall = false;
    if (request != null) {
      recall =
          await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) =>
                  SurveyView(request: request, askAccompanied: true),
            ),
          ) ??
          false;
    }
    // RF35: si la llamada se cortó y la persona pidió "Llamar de nuevo", se empieza otra búsqueda
    // en esta misma pantalla (con el mismo voluntario si sigue disponible).
    if (recall && request != null && mounted) {
      _ringTimer?.cancel();
      _repo?.removeListener(_onRepoChanged);
      setState(() {
        _request = null;
        _error = null;
        _joining = false;
      });
      await _start(recallOf: request.id);
      return;
    }
    _close();
  }

  Future<void> _cancel() async {
    final id = _request?.id;
    if (id != null) await VitaScope.of(context).cancelRequest(id);
    _close();
  }

  Future<void> _help() {
    return showVitaMessage(
      context,
      (_request?.audioOnly ?? widget.audioOnly)
          ? 'Activa el micrófono y sube el volumen. La llamada será solo de voz; podrás encender la cámara si lo deseas.'
          : 'Activa el micrófono, sube el volumen y permite la cámara. La llamada no se corta al leer esta ayuda.',
    );
  }

  Future<void> _emergency() async {
    final repo = VitaScope.of(context);
    final user = repo.currentUser;
    final request = _request;
    if (user == null || request == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Llamar a tu familiar?'),
        content: const Text(
          'Se cerrará la búsqueda o la llamada y se abrirá el marcador.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, llamar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await repo.addAlert(
      callId: request.id,
      elderlyId: user.id,
      note: 'Botón de emergencia del adulto mayor',
    );
    await repo.finishCall(request.id, status: CallRequestStatus.interrupted);
    final phone = user.familyPhone;
    if (phone != null) {
      await launchUrl(Uri.parse('tel:$phone'));
    }
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;

    // Si no se pudo buscar, solo se muestra el aviso y el botón para volver.
    if (_error != null) {
      return VitaPage(
        title: 'Buscando voluntario',
        child: Column(
          children: [
            VitaErrorText(_error),
            VitaPrimaryButton(
              label: 'Volver',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }

    // El mensaje y el paso cambian según avanza la solicitud: buscando → encontrado → conectando.
    final status = request?.status;
    final audioOnly = request?.audioOnly ?? widget.audioOnly;
    final connecting = _joining || status == CallRequestStatus.connected;
    final step = connecting ? 2 : (status == CallRequestStatus.ringing ? 1 : 0);
    final headline = connecting
        ? (audioOnly
              ? 'Conectando la llamada de voz…'
              : 'Conectando la videollamada…')
        : status == CallRequestStatus.ringing
        ? '¡Encontramos un voluntario! Esperando que conteste…'
        : audioOnly
        ? 'Buscamos a alguien para conversar por voz…'
        : 'Estamos buscando a alguien para acompañarte…';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: VitaColors.bg,
        body: Column(
          children: [
            _SearchHero(headline: headline, step: step),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                child: request == null
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          if (request.volunteerId != null)
                            _MatchedVolunteerCard(user: VitaScope.of(context).userById(request.volunteerId!)),
                          _CodeCard(code: request.joinCode),
                        ],
                      ),
              ),
            ),
            // Las acciones quedan siempre a la vista, aunque la pantalla sea pequeña.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VitaPrimaryButton(
                      label: 'Emergencia',
                      icon: Icons.emergency,
                      color: VitaColors.alert,
                      onPressed: _emergency,
                    ),
                    const SizedBox(height: VitaSpace.md),
                    Row(
                      children: [
                        Expanded(
                          child: VitaSecondaryButton(
                            label: 'Ayuda',
                            icon: Icons.help_outline_rounded,
                            onPressed: _help,
                          ),
                        ),
                        const SizedBox(width: VitaSpace.md),
                        Expanded(
                          child: VitaSecondaryButton(
                            label: 'Cancelar',
                            icon: Icons.close_rounded,
                            onPressed: _cancel,
                          ),
                        ),
                      ],
                    ),
                    if (request?.volunteerId != null)
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportView(
                              request: request!,
                              reportedId: request.volunteerId!,
                            ),
                          ),
                        ),
                        child: const Text('Reportar'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchedVolunteerCard extends StatelessWidget {
  const _MatchedVolunteerCard({required this.user});
  final VitaUser? user;

  @override
  Widget build(BuildContext context) {
    final volunteer = user;
    if (volunteer == null ||
        volunteer.role != UserRole.volunteer ||
        volunteer.status != AccountStatus.active ||
        !volunteer.identityVerified) {
      return const SizedBox.shrink();
    }
    final showPresentation = volunteer.volunteerPresentationConsent && volunteer.volunteerPresentationReviewed;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (showPresentation) VitaAvatar(name: volunteer.displayName, size: 64, photoBase64: volunteer.volunteerPresentationPhoto),
              if (showPresentation) const SizedBox(width: 14),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(volunteer.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Identidad verificada por coordinación', style: TextStyle(color: VitaColors.success)),
              ])),
            ]),
            if (showPresentation && volunteer.volunteerBio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(volunteer.volunteerBio),
            ],
            if (showPresentation && volunteer.volunteerInterests.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Intereses: ${volunteer.volunteerInterests}'),
            ],
            if (showPresentation && volunteer.volunteerExperience.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Voluntariado: ${volunteer.volunteerExperience}'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Parte de arriba de la pantalla: radar animado, mensaje de estado y pasos.
class _SearchHero extends StatelessWidget {
  const _SearchHero({required this.headline, required this.step});

  final String headline;
  final int step;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(24, top + 12, 24, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: VitaGradients.heroTeal,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SearchRadar(),
            const SizedBox(height: VitaSpace.md),
            Semantics(
              liveRegion: true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  headline,
                  key: ValueKey(headline),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: VitaSpace.lg),
            _SearchSteps(current: step),
          ],
        ),
      ),
    );
  }
}

/// Logo con ondas que se expanden mientras se busca. Con las animaciones desactivadas en el
/// celular se muestra quieto.
class _SearchRadar extends StatefulWidget {
  const _SearchRadar();

  @override
  State<_SearchRadar> createState() => _SearchRadarState();
}

class _SearchRadarState extends State<_SearchRadar>
    with SingleTickerProviderStateMixin {
  static const double _core = 112;
  static const double _full = 200;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _ring(double t) {
    final size = _core + (_full - _core) * t;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.16 * (1 - t)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55 * (1 - t)),
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final core = Container(
      width: _core,
      height: _core,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: Image.asset(
          'assets/icon/logo.png',
          fit: BoxFit.cover,
          cacheWidth: 336,
        ),
      ),
    );

    // Es solo decoración: el estado se lee en el mensaje de abajo.
    return ExcludeSemantics(
      child: SizedBox(
        width: _full,
        height: _full,
        child: reduceMotion
            ? Stack(alignment: Alignment.center, children: [_ring(0.5), core])
            : AnimatedBuilder(
                animation: _controller,
                child: core,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final phase in const [0.0, 0.33, 0.66])
                        _ring((_controller.value + phase) % 1.0),
                      child!,
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// Tres pasos: Buscando → Encontrado → Conectando.
class _SearchSteps extends StatelessWidget {
  const _SearchSteps({required this.current});

  final int current;

  static const _labels = ['Buscando', 'Encontrado', 'Conectando'];

  Widget _step(int i) {
    final done = i < current;
    final active = i == current;
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 27,
            height: 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= current
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.25),
            ),
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    size: 19,
                    color: VitaColors.primary,
                  )
                : active
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: VitaColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            _labels[i],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              color: Colors.white.withValues(alpha: active ? 1 : 0.82),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _labels.length; i++) {
      if (i > 0) {
        children.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 4, right: 4),
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: i <= current ? 0.9 : 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }
      children.add(_step(i));
    }
    return Semantics(
      container: true,
      label: 'Paso ${current + 1} de ${_labels.length}: ${_labels[current]}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Código de 6 dígitos para que el voluntario entre desde otro celular, con botón de copiar.
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return VitaCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CÓDIGO PARA EL VOLUNTARIO', style: VitaText.overline),
          const SizedBox(height: VitaSpace.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: VitaColors.primary,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Copiar código',
                iconSize: 28,
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: VitaSpace.xs),
          const Text(
            'Si el voluntario está en otro celular, que ingrese este código.',
            style: TextStyle(
              fontSize: 16,
              height: 1.3,
              color: VitaColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class VitaRepositoryTimes {
  static const ring = Duration(seconds: 30);
}

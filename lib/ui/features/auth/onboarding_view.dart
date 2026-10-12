import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';

class _Slide {
  const _Slide({required this.emoji, required this.title, required this.body, required this.colors});

  final String emoji;
  final String title;
  final String body;
  final List<Color> colors;
}

const _slides = [
  _Slide(
    emoji: '💬',
    title: 'Habla con alguien',
    body: 'Con un solo botón puedes pedir compañía. Nosotros buscamos automáticamente un voluntario disponible para ti.',
    colors: [Color(0xFF16978A), Color(0xFF2BB5A5)],
  ),
  _Slide(
    emoji: '✅',
    title: 'Voluntarios verificados',
    body:
        'Todos los voluntarios son mayores de 18 años, pasan por un proceso de verificación y aceptan un código de conducta antes de poder atenderte.',
    colors: [Color(0xFF4A7BC0), Color(0xFF6C98D8)],
  ),
  _Slide(
    emoji: '🛡️',
    title: 'Tu seguridad es importante',
    body:
        'No compartas tu dirección, dinero, claves, códigos ni los horarios en que estás solo. Si algo te parece raro, termina la llamada y repórtalo.',
    colors: [Color(0xFF6A44BE), Color(0xFF8C5CF2)],
  ),
  _Slide(
    emoji: '🤝',
    title: 'VITA ofrece compañía social',
    body:
        'VITA es un espacio de conversación y acompañamiento. No reemplaza la atención médica, psicológica ni los servicios de emergencia profesionales.',
    colors: [Color(0xFFD97706), Color(0xFFF29B10)],
  ),
];

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await VitaScope.of(context).completeOnboarding();
    widget.onDone();
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _SlidePage(slide: _slides[i]),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: _finish,
                    child: const Text('Saltar →'),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: active ? 30 : 10,
                            height: 10,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: active ? 1 : 0.45),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 62,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            elevation: _isLast ? 4 : 0,
                            backgroundColor: _isLast ? Colors.white : Colors.white.withValues(alpha: 0.25),
                            foregroundColor: _isLast ? VitaColors.primary : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: Colors.white.withValues(alpha: _isLast ? 0 : 0.4)),
                            ),
                          ),
                          child: Text(_isLast ? 'Empezar' : 'Siguiente'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: slide.colors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 56, 32, 150),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(slide.emoji, style: const TextStyle(fontSize: 58)),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    slide.body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 19, height: 1.5, color: Colors.white),
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

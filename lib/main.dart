import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App VITA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final JitsiMeet _jitsiMeet = JitsiMeet();
  String _lastSummary = "";
  bool _isLoadingIA = false;

  // Reemplaza con tu clave de Gemini API para las pruebas
  final String _geminiApiKey = "TU_GEMINI_API_KEY_AQUI";

  // 1. Iniciar Videollamada Simplificada en Jitsi
  void _startCall({required bool isElderly}) async {
    var options = JitsiMeetConferenceOptions(
      serverURL: "https://meet.jit.si",
      room: "VITA_Acompanamiento_Sala_1", // Sala fija para las 15 pruebas
      configOverrides: {
        "startWithAudioMuted": false,
        "startWithVideoMuted": false,
        "subject": "Acompañamiento VITA",
      },
      featureFlags: {
        "unsaferoomwarning.enabled": false,
        "welcomepage.enabled": false,
        "toolbox.alwaysVisible": true,
      },
      userInfo: JitsiMeetUserInfo(
        displayName: isElderly ? "Adulto Mayor" : "Voluntario",
      ),
    );

    await _jitsiMeet.join(options);
  }

  // 2. Generar Resumen Asistido por IA usando Gemini API
  Future<void> _generateAISummary(String transcriptSimulado) async {
    setState(() => _isLoadingIA = true);

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey',
    );

    final prompt = '''
    Analiza la siguiente transcripción corta de una llamada de acompañamiento entre un voluntario y un adulto mayor:
    "$transcriptSimulado"

    Genera en español:
    1. Resumen breve de la conversación (máximo 2 oraciones).
    2. Estado de ánimo aparente del adulto mayor.
    3. Tareas, compromisos o recordatorios acordados.
    ''';

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        setState(() => _lastSummary = text);
      } else {
        setState(() => _lastSummary = "Error al conectar con la IA de Gemini.");
      }
    } catch (e) {
      setState(() => _lastSummary = "Error de conexión: $e");
    } finally {
      setState(() => _isLoadingIA = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App VITA', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.green.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // ✅ Forma correcta
            children: [
              const Text(
                'Selecciona cómo deseas ingresar:',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),

              // Botón Gigante de Accesibilidad para el Adulto Mayor
              SizedBox(
                height: 110,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.video_call, size: 52),
                  label: const Text(
                    'LLAMAR AL VOLUNTARIO',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _startCall(isElderly: true),
                ),
              ),

              const SizedBox(height: 20),

              // Botón para Ingreso de Voluntarios
              SizedBox(
                height: 75,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.person, size: 36),
                  label: const Text('Entrar como Voluntario', style: TextStyle(fontSize: 20)),
                  onPressed: () => _startCall(isElderly: false),
                ),
              ),

              const SizedBox(height: 35),
              const Divider(thickness: 2),
              const SizedBox(height: 15),

              // Demostración de IA para la Evaluación de Pruebas
              const Text(
                'Demostración de Asistente IA (Post-Llamada):',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Simular Análisis IA de Llamada'),
                onPressed: _isLoadingIA
                    ? null
                    : () => _generateAISummary(
                          "Hola Don Pedro, ¿cómo ha estado hoy? Me contó que le dolía la rodilla pero ya tomó su medicina. Recuerde que el jueves tiene la cita médica a las 10:00 AM.",
                        ),
              ),

              const SizedBox(height: 15),

              if (_isLoadingIA)
                const Center(child: CircularProgressIndicator())
              else if (_lastSummary.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Text(_lastSummary, style: const TextStyle(fontSize: 16, height: 1.4)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
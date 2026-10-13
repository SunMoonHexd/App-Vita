/// Cada cuánto tiempo de llamada se sugiere una pausa (RF36). El aviso NO corta la llamada.
/// El requerimiento RF36 pide 20 minutos. Para probarlo rápido, cámbialo a  Duration(minutes: 1)
/// (usa minutos enteros) y vuelve a dejarlo en 20 antes de entregar.
const Duration kBreakSuggestionAfter = Duration(minutes: 20);

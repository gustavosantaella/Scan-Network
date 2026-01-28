import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // ⚠️ RECORDATORIO: Borra tu clave anterior en AI Studio y genera una nueva.
  // No subas esta clave a GitHub.
  static const String _apiKey = String.fromEnvironment("GEMINI_API_KEY");

  late final GenerativeModel _model;

  GeminiService() {
    // Se usa 'gemini-1.5-flash' o 'gemini-1.5-flash-latest'
    // El SDK suele preferir el nombre sin el prefijo 'models/',
    // pero si falla, 'models/gemini-1.5-flash' es la ruta completa.
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
  }

  Future<String> explainPort(int port) async {
    try {
      final prompt =
          'Explain briefly (max 2 sentences) what network port $port '
          'is commonly used for and its security implications if open.';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text == null) {
        return 'No se encontró una explicación para este puerto.';
      }

      return response.text!;
    } catch (e) {
      // Esto capturará errores de red, de API o de cuota.
      return 'Error al obtener la explicación: $e';
    }
  }
}

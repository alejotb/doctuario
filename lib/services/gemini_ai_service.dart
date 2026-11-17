import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';

/// Servicio centralizado de Inteligencia Artificial médica con Google Gemini 3.8 Flash.
///
/// Implementa la arquitectura Bring Your Own Key (BYOK) para garantizar:
/// 1. Aislamiento absoluto de datos clínicos y privacidad médica por doctor.
/// 2. Cuota independiente y gratuita sin agotar límites de la plataforma.
/// 3. Reutilización global en toda la suite médica: importación de pacientes,
///    asistencia en diagnósticos, generación de informes y resúmenes clínicos.
class GeminiAiService {
  GeminiAiService._();

  static GeminiAiService? _instance;
  static GeminiAiService get instance => _instance ??= GeminiAiService._();

  /// Modelo oficial de Google DeepMind de última generación para producción
  static const String modelName = 'gemini-3.8-flash';
  static const List<String> candidateModels = [
    'gemini-3.8-flash',
    'gemini-3.5-flash',
    'gemini-3.0-flash',
    'gemini-2.0-flash',
  ];
  static const String _apiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const String _kPrefsKeyPrefix = 'prontudoc_gemini_api_key_';

  String? _cachedKey;
  bool _isInitialized = false;

  /// Obtiene el identificador del doctor activo
  String get _currentDoctorId {
    final uid = SupaFlow.client.auth.currentUser?.id ?? currentUserUid;
    return uid.isNotEmpty ? uid : 'default_doctor';
  }

  /// Clave de almacenamiento en SharedPreferences para el doctor actual
  String get _storageKey => '$_kPrefsKeyPrefix$_currentDoctorId';

  /// Ofuscación ligera para evitar almacenamiento de claves en texto plano en disco
  String _obfuscate(String plain) => base64Encode(utf8.encode(plain));
  String _deobfuscate(String encoded) {
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (_) {
      return encoded; // Fallback compatible si la clave previa estaba en texto plano
    }
  }

  /// Inicializa el servicio cargando la clave del doctor activo de forma segura
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      if (stored != null && stored.trim().isNotEmpty) {
        _cachedKey = _deobfuscate(stored.trim());
      } else {
        const envKey = String.fromEnvironment('GEMINI_API_KEY');
        if (envKey.isNotEmpty) {
          _cachedKey = envKey;
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error inicializando GeminiAiService: $e');
    }
  }

  /// Retorna si el doctor tiene una clave configurada
  bool get hasKey => _cachedKey != null && _cachedKey!.trim().isNotEmpty;
  bool get isConfigured => hasKey;

  /// Retorna la clave actual en memoria
  String? get currentKey => _cachedKey;

  /// Guarda una nueva clave de API para el doctor actual con ofuscación local
  Future<void> saveApiKey(String key) async {
    final cleaned = key.trim();
    final prefs = await SharedPreferences.getInstance();
    if (cleaned.isEmpty) {
      await prefs.remove(_storageKey);
      _cachedKey = null;
    } else {
      await prefs.setString(_storageKey, _obfuscate(cleaned));
      _cachedKey = cleaned;
    }
    _isInitialized = true;
  }

  /// Elimina la clave de API configurada
  Future<void> removeApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    _cachedKey = null;
  }

  /// Ejecuta una petición POST segura pasando la API Key en el encabezado HTTP
  /// ('x-goog-api-key') en lugar de la URL para evitar fugas en logs de red.
  Future<http.Response> _postWithFallback(
    String key,
    Map<String, dynamic> payload,
  ) async {
    http.Response? lastResponse;
    for (final model in candidateModels) {
      final url = Uri.parse('$_apiBaseUrl/$model:generateContent');
      try {
        final res = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': key,
          },
          body: jsonEncode(payload),
        );
        if (res.statusCode != 404) {
          return res;
        }
        lastResponse = res;
      } catch (e) {
        if (model == candidateModels.last) rethrow;
      }
    }
    return lastResponse!;
  }

  /// Valida una clave contra el modelo Gemini 3.8 Flash realizando una petición de prueba
  Future<Map<String, dynamic>> validateApiKey(String testKey) async {
    final key = testKey.trim();
    if (key.isEmpty) {
      return {'valid': false, 'message': 'La clave de API no puede estar vacía.'};
    }

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': 'Ping de verificación para Doctuario. Responde únicamente "OK".'}
          ]
        }
      ],
      'generationConfig': {
        'maxOutputTokens': 10,
        'temperature': 0.0,
      }
    };

    try {
      final res = await _postWithFallback(key, payload);

      if (res.statusCode == 200) {
        return {
          'valid': true,
          'message': 'Conexión exitosa con Gemini 3.8 Flash.',
        };
      }

      final errorBody = jsonDecode(res.body);
      final errorMsg = errorBody['error']?['message'] ?? 'Error de autenticación (${res.statusCode})';
      return {
        'valid': false,
        'message': 'Google rechazó la clave: $errorMsg',
      };
    } catch (e) {
      return {
        'valid': false,
        'message': 'Error de conexión a la red: $e',
      };
    }
  }

  /// Envía un texto clínico desestructurado a Gemini 3.8 Flash para extraer
  /// una ficha de paciente con esquema estructurado JSON.
  Future<Map<String, dynamic>> extractPatientFromText(String documentText) async {
    if (!hasKey) {
      throw Exception(
        'No se ha configurado la clave de Gemini 3.8 Flash en el perfil del doctor.',
      );
    }

    final key = _cachedKey!;

    const systemPrompt = '''
Eres un asistente médico experto de Doctuario. Analiza el siguiente documento clínico o ficha médica y extrae los datos del paciente en formato JSON estricto.
Esquema de campos requerido:
{
  "nombre": "Nombre completo del paciente o null si no existe",
  "cedula": "Cédula, DNI o número de identificación o null",
  "telefono": "Teléfono de contacto o null",
  "email": "Correo electrónico o null",
  "fecha_nacimiento": "YYYY-MM-DD o null si no se conoce",
  "sexo": "M o F o null",
  "tipo_sangre": "Ejemplo O+, A+ o null",
  "antecedentes": "Antecedentes médicos relevantes, alergias, cirugías o null",
  "diagnostico_inicial": "Motivo de consulta o diagnóstico registrado o null"
}
Si un dato no está en el documento, usa null. Devuelve ÚNICAMENTE el JSON sin bloques markdown ni explicaciones adicionales.
''';

    final safeText = documentText.length > 8000
        ? documentText.substring(0, 8000)
        : documentText;

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': '$systemPrompt\n\nDocumento clínico a procesar:\n$safeText'}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.1,
        'maxOutputTokens': 1024,
      }
    };

    final res = await _postWithFallback(key, payload);

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      final msg = body['error']?['message'] ?? 'Código de error ${res.statusCode}';
      throw Exception('Fallo en Gemini 3.8 Flash: $msg');
    }

    final data = jsonDecode(res.body);
    final textResponse =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '{}';

    try {
      final parsed = jsonDecode(textResponse);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
      return {};
    } catch (e) {
      debugPrint('Error parseando JSON devuelto por Gemini: $e');
      return {};
    }
  }

  /// Método general para ejecutar cualquier prompt con Gemini 3.8 Flash en Doctuario
  /// (usado en resúmenes de historias clínicas, recetas o sugerencias médicas).
  Future<String> executePrompt({
    required String prompt,
    double temperature = 0.2,
    int? maxTokens = 600,
  }) async {
    if (!hasKey) {
      throw Exception('Debes configurar tu Gemini API Key en el Perfil.');
    }

    // Proteger contra prompts excesivamente largos que quemen cuota
    final safePrompt = prompt.length > 8000 ? prompt.substring(0, 8000) : prompt;

    final key = _cachedKey!;
    final payload = {
      'contents': [
        {
          'parts': [
            {'text': safePrompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens ?? 600,
      }
    };

    final res = await _postWithFallback(key, payload);

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      final msg = body['error']?['message'] ?? 'Error ${res.statusCode}';
      throw Exception('Error llamando a Gemini 3.8 Flash: $msg');
    }

    final data = jsonDecode(res.body);
    final text =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
    return text.toString().trim();
  }

  /// Genera un resumen clínico estructurado a partir del motivo, examen y diagnóstico
  Future<String?> generateClinicalSummary({
    required String sintomas,
    required String diagnostico,
    String? examen,
  }) async {
    if (!hasKey) return null;
    final prompt = '''
Eres un asistente médico redactando una nota clínica para el doctor en Doctuario.
Datos de la consulta:
- Motivo / Síntomas: $sintomas
- Diagnóstico: $diagnostico
- Examen / Paraclínicos: ${examen ?? 'Sin observaciones adicionales'}

Redacta un resumen clínico objetivo, profesional y conciso en un párrafo para la ficha médica o receta. Sin introducciones ni saludos.
''';
    try {
      return await executePrompt(prompt: prompt, temperature: 0.2, maxTokens: 400);
    } catch (e) {
      debugPrint('Error generando resumen clínico: $e');
      return null;
    }
  }

  /// Sugiere una pauta de prescripción médica con fármacos y duración
  Future<Map<String, String>?> suggestPrescription({
    required String diagnostico,
    required String sintomas,
  }) async {
    if (!hasKey) return null;
    final prompt = '''
Eres un asistente médico. Con base en:
- Diagnóstico: $diagnostico
- Síntomas: $sintomas

Sugiere una pauta de tratamiento estándar habitual. Devuelve ÚNICAMENTE un JSON estricto con:
{
  "medicamentos": "Fármaco, dosis y frecuencia",
  "duracion": "Tiempo sugerido (ej: 7 días)",
  "indicaciones": "Pautas adicionales de cuidado"
}
''';
    try {
      final text = await executePrompt(prompt: prompt, temperature: 0.1, maxTokens: 350);
      final clean = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(clean);
      if (decoded is Map) {
        return {
          'medicamentos': decoded['medicamentos']?.toString() ?? '',
          'duracion': decoded['duracion']?.toString() ?? '',
          'indicaciones': decoded['indicaciones']?.toString() ?? '',
        };
      }
    } catch (e) {
      debugPrint('Error sugiriendo prescripción con Gemini: $e');
    }
    return null;
  }

  /// Resume en 2 líneas clave el historial de consultas previas de un paciente
  Future<String?> summarizePatientHistory(
    List<HistoriasClinicasRow> historias,
  ) async {
    if (!hasKey || historias.isEmpty) return null;
    final buffer = StringBuffer();
    for (final h in historias.take(4)) {
      buffer.writeln('- Consulta: Dx: ${h.diagnostico ?? 'N/A'}, Síntomas: ${h.sintomas ?? 'N/A'}, Tto: ${h.tratamiento ?? 'N/A'}');
    }
    final prompt = '''
Eres un asistente médico clínico. A partir del historial de consultas previas de este paciente:
$buffer

Genera un resumen evolutivo clave (máximo 2 a 3 líneas) sintetizando antecedentes relevantes y evolución del tratamiento. Sé conciso y directo.
''';
    try {
      return await executePrompt(prompt: prompt, temperature: 0.2, maxTokens: 250);
    } catch (e) {
      debugPrint('Error resumiendo historial clínico: $e');
      return null;
    }
  }
}

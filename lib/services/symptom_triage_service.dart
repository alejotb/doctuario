import '../backend/supabase/supabase.dart';

class SymptomTriageResult {
  final String nivelUrgencia; // 'leve' | 'moderado' | 'urgente_hospital'
  final bool requiereHospital;
  final String mensajeOrientacion;
  final String resumenPreconsulta;

  SymptomTriageResult({
    required this.nivelUrgencia,
    required this.requiereHospital,
    required this.mensajeOrientacion,
    required this.resumenPreconsulta,
  });
}

class SymptomTriageService {
  static final SymptomTriageService _instance =
      SymptomTriageService._internal();
  factory SymptomTriageService() => _instance;
  SymptomTriageService._internal();

  /// Evalúa los síntomas descritos por el paciente (orientación preventiva, no emite recetas)
  SymptomTriageResult evaluarSintomas(String descripcionSintomas) {
    final texto = descripcionSintomas.toLowerCase();

    // Signos de alarma / Banderas rojas que ameritan atención de urgencias
    final banderasRojas = [
      'dolor de pecho',
      'dolor en el pecho',
      'opresión en el pecho',
      'dificultad para respirar',
      'falta de aire severa',
      'asfixia',
      'desmayo',
      'pérdida de conciencia',
      'parálisis',
      'adormecimiento facial',
      'no puede hablar',
      'sangrado abundante',
      'hemorragia',
      'convulsión',
      'fiebre mayor a 40',
      'rigidez de nuca',
    ];

    bool esUrgenciaHospitalaria = false;
    for (final bandera in banderasRojas) {
      if (texto.contains(bandera)) {
        esUrgenciaHospitalaria = true;
        break;
      }
    }

    if (esUrgenciaHospitalaria) {
      return SymptomTriageResult(
        nivelUrgencia: 'urgente_hospital',
        requiereHospital: true,
        mensajeOrientacion:
            '🚨 ATENCIÓN PREVENTIVA: Los síntomas descritos presentan signos de alarma médica. Le recomendamos acudir de inmediato al centro de urgencias hospitalarias más cercano en lugar de esperar una cita programada.',
        resumenPreconsulta:
            '⚠️ ALERTA DE TRIAJE: El paciente reportó síntomas de potencial urgencia: "$descripcionSintomas".',
      );
    }

    // Síntomas moderados
    final sintomasModerados = [
      'fiebre',
      'dolor abdominal',
      'vómito',
      'diarrea',
      'mareo',
      'tos persistente',
      'dolor intenso',
    ];

    bool esModerado = false;
    for (final sintoma in sintomasModerados) {
      if (texto.contains(sintoma)) {
        esModerado = true;
        break;
      }
    }

    if (esModerado) {
      return SymptomTriageResult(
        nivelUrgencia: 'moderado',
        requiereHospital: false,
        mensajeOrientacion:
            'Su consulta médica presencial es adecuada para evaluar estos síntomas. Si presenta dificultad para respirar o dolor intenso súbito, acuda a urgencias.',
        resumenPreconsulta:
            'Pre-evaluación: El paciente refiere sintomatología moderada: "$descripcionSintomas".',
      );
    }

    return SymptomTriageResult(
      nivelUrgencia: 'leve',
      requiereHospital: false,
      mensajeOrientacion:
          'Información registrada con éxito. Sus síntomas han sido sintetizados para que el doctor pueda revisarlos antes de atenderle.',
      resumenPreconsulta:
          'Pre-evaluación rutinaria: "$descripcionSintomas".',
    );
  }

  /// Guarda el registro de triaje en la base de datos
  Future<TriageConsultasRow> guardarTriage({
    required String idPaciente,
    String? idCita,
    required String descripcionSintomas,
    required SymptomTriageResult resultado,
  }) async {
    return await TriageConsultasTable().insert({
      'id_paciente': idPaciente,
      'id_cita': idCita,
      'descripcion_sintomas': descripcionSintomas,
      'nivel_urgencia': resultado.nivelUrgencia,
      'requiere_hospital': resultado.requiereHospital,
      'resumen_preconsulta': resultado.resumenPreconsulta,
    });
  }
}

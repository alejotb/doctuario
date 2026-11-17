import '../backend/supabase/supabase.dart';

class ClinicalHistoryService {
  static final ClinicalHistoryService _instance =
      ClinicalHistoryService._internal();
  factory ClinicalHistoryService() => _instance;
  ClinicalHistoryService._internal();

  /// Guarda una nueva historia clínica confidencial
  Future<HistoriasClinicasRow> guardarHistoriaClinica({
    required String idPaciente,
    required String idDoctor,
    String? idCita,
    String? idPlantilla,
    required String motivoConsulta,
    required String sintomas,
    String? examenFisico,
    required String diagnostico,
    required String tratamiento,
    String? notasPrivadas,
    Map<String, dynamic>? datosAdicionalesJson,
  }) async {
    return await HistoriasClinicasTable().insert({
      'id_paciente': idPaciente,
      'id_doctor': idDoctor,
      'id_cita': idCita,
      'id_plantilla': idPlantilla,
      'motivo_consulta': motivoConsulta,
      'sintomas': sintomas,
      'examen_fisico': examenFisico,
      'diagnostico': diagnostico,
      'tratamiento': tratamiento,
      'notas_privadas': notasPrivadas,
      'datos_historia_json': datosAdicionalesJson ?? {},
      'es_privado': true,
    });
  }

  /// Obtiene el historial clínico confidencial de un paciente (solo para el doctor)
  Future<List<HistoriasClinicasRow>> obtenerHistorialPaciente({
    required String idPaciente,
    required String idDoctor,
  }) async {
    return await HistoriasClinicasTable().queryRows(
      queryFn: (q) => q
          .eq('id_paciente', idPaciente)
          .eq('id_doctor', idDoctor)
          .order('created_at', ascending: false),
    );
  }

  /// Obtiene las plantillas predefinidas y personalizadas del doctor
  Future<List<PlantillasHistoriaRow>> obtenerPlantillas(String idDoctor) async {
    return await PlantillasHistoriaTable().queryRows(
      queryFn: (q) => q
          .or('id_doctor.eq.$idDoctor,es_predeterminada.eq.true')
          .order('titulo', ascending: true),
    );
  }

  /// Plantillas por defecto para autocompletar síntomas y examen físico
  static List<Map<String, dynamic>> plantillasPorDefecto() {
    return [
      {
        'titulo': 'Consulta General / Medicina Interna',
        'especialidad': 'Medicina General',
        'motivo': 'Control rutinario / Malestar general',
        'sintomas': 'Cefalea, astenia, sin fiebre cuantificada.',
        'examen_fisico': 'Signos vitales estables. PA: 120/80 mmHg, FC: 72 lpm. Abdomen blando, no doloroso.',
        'diagnostico': 'Evaluación clínica sin signos de alarma.',
        'tratamiento': 'Medidas higiénico-dietéticas, hidratación abundante.',
      },
      {
        'titulo': 'Control Pediátrico / Niño Sano',
        'especialidad': 'Pediatría',
        'motivo': 'Control de crecimiento y desarrollo',
        'sintomas': 'Paciente asintomático, buen apetito y sueño adecuado.',
        'examen_fisico': 'Peso y talla acordes al percentil. Faringe sin exudado, otoscopia bilateral normal.',
        'diagnostico': 'Desarrollo pondoestatural adecuado.',
        'tratamiento': 'Continuar esquema de vacunación y alimentación balanceada.',
      },
      {
        'titulo': 'Evaluación Cardiovascular / Hipertensión',
        'especialidad': 'Cardiología',
        'motivo': 'Chequeo cardiovascular / Control de presión arterial',
        'sintomas': 'Sin disnea de esfuerzo, sin dolor torácico, sin palpitaciones.',
        'examen_fisico': 'Ruidos cardíacos rítmicos sin soplos. Pulsos periféricos presentes y simétricos.',
        'diagnostico': 'Hipertensión arterial controlada.',
        'tratamiento': 'Mantener medicación antihipertensiva, control de sodio en dieta.',
      },
    ];
  }
}

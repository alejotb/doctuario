class SpecialtiesService {
  static final SpecialtiesService _instance = SpecialtiesService._internal();
  factory SpecialtiesService() => _instance;
  SpecialtiesService._internal();

  static final List<String> _especialidadesBase = [
    'Cardiología',
    'Cirugía Cardiovascular',
    'Cirugía General',
    'Cirugía Pediátrica',
    'Cirugía Plástica y Reconstructiva',
    'Dermatología',
    'Endocrinología y Metabolismo',
    'Gastroenterología',
    'Geriatría',
    'Ginecología y Obstetricia',
    'Hematología',
    'Infectología',
    'Medicina de Emergencia',
    'Medicina Familiar',
    'Medicina Física y Rehabilitación',
    'Medicina General',
    'Medicina Interna',
    'Medicina Ocupacional',
    'Nefrología',
    'Neumonología',
    'Neurología',
    'Neurocirugía',
    'Nutrición y Dietética',
    'Odontología',
    'Oftalmología',
    'Oncología Médica',
    'Otorrinolaringología',
    'Pediatría',
    'Psicología Clínica',
    'Psiquiatría',
    'Radiología e Imágenes',
    'Reumatología',
    'Traumatología y Ortopedia',
    'Urología',
  ];

  static final List<String> _especialidadesPersonalizadas = [];
  static final Map<String, List<String>> _subespecialidadesPersonalizadas = {};

  static List<String> getEspecialidades() {
    final list = {..._especialidadesBase, ..._especialidadesPersonalizadas}.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static void agregarEspecialidad(String nueva) {
    final clean = nueva.trim();
    if (clean.isNotEmpty &&
        !_especialidadesBase.any((e) => e.toLowerCase() == clean.toLowerCase()) &&
        !_especialidadesPersonalizadas.any((e) => e.toLowerCase() == clean.toLowerCase())) {
      _especialidadesPersonalizadas.add(clean);
    }
  }

  static void agregarSubespecialidad(String especialidad, String nuevaSub) {
    final espKey = especialidad.trim();
    final cleanSub = nuevaSub.trim();
    if (espKey.isEmpty || cleanSub.isEmpty) return;
    final list = _subespecialidadesPersonalizadas.putIfAbsent(espKey, () => []);
    if (!list.any((s) => s.toLowerCase() == cleanSub.toLowerCase())) {
      list.add(cleanSub);
    }
  }

  /// Formatea múltiples especialidades y sus respectivas subespecialidades en una cadena estructurada.
  static String formatEspecialidadesCompuestas(
    List<String> especialidades,
    Map<String, List<String>> subespecialidadesPorEsp,
  ) {
    final parts = <String>[];
    for (final esp in especialidades) {
      final cleanEsp = esp.trim();
      if (cleanEsp.isEmpty) continue;
      final subs = (subespecialidadesPorEsp[cleanEsp] ?? [])
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (subs.isNotEmpty) {
        parts.add('$cleanEsp (${subs.join(', ')})');
      } else {
        parts.add(cleanEsp);
      }
    }
    return parts.isEmpty ? 'Medicina General' : parts.join(' | ');
  }

  /// Parsea una cadena de especialidades y subespecialidades guardada en la base de datos.
  static ({List<String> especialidades, Map<String, List<String>> subespecialidades})
      parseEspecialidadesCompuestas(String? raw) {
    final especialidades = <String>[];
    final subespecialidades = <String, List<String>>{};
    if (raw == null || raw.trim().isEmpty) {
      return (especialidades: especialidades, subespecialidades: subespecialidades);
    }

    final segments = raw.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty);
    for (final seg in segments) {
      String espName = seg;
      List<String> subs = [];

      if (seg.contains('(') && seg.endsWith(')')) {
        final start = seg.indexOf('(');
        espName = seg.substring(0, start).trim();
        final subRaw = seg.substring(start + 1, seg.length - 1).trim();
        subs = subRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      } else if (seg.contains(' - ')) {
        final parts = seg.split(' - ');
        espName = parts[0].trim();
        final subRaw = parts.sublist(1).join(' - ').trim();
        subs = subRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }

      if (espName.isNotEmpty) {
        agregarEspecialidad(espName);
        if (!especialidades.contains(espName)) {
          especialidades.add(espName);
        }
        if (subs.isNotEmpty) {
          for (final s in subs) {
            agregarSubespecialidad(espName, s);
          }
          subespecialidades[espName] = subs;
        }
      }
    }

    return (especialidades: especialidades, subespecialidades: subespecialidades);
  }

  static List<String> getSugerenciasSubespecialidad(String? especialidad) {
    if (especialidad == null || especialidad.isEmpty) return [];
    final base = _getBaseSugerencias(especialidad);
    final custom = _subespecialidadesPersonalizadas[especialidad.trim()] ?? [];
    final combined = <String>[...base];
    for (final c in custom) {
      if (!combined.any((s) => s.toLowerCase() == c.toLowerCase())) {
        combined.add(c);
      }
    }
    return combined;
  }

  static List<String> _getBaseSugerencias(String especialidad) {
    final espLower = especialidad.toLowerCase();

    if (espLower.contains('cardio')) {
      return [
        'Electrofisiología / Marcapasos',
        'Hemodinamia / Cateterismo',
        'Cardiología Pediátrica',
        'Ecocardiografía Doppler',
        'Cirugía Cardiovascular',
        'Insuficiencia Cardíaca',
        'Rehabilitación Cardíaca',
      ];
    }
    if (espLower.contains('trauma') || espLower.contains('ortoped')) {
      return [
        'Cirugía de Rodilla y Cadera',
        'Columna Vertebral',
        'Artroscopia y Medicina Deportiva',
        'Cirugía de Hombro y Codo',
        'Cirugía de Mano y Miembro Superior',
        'Ortopedia Pediátrica',
        'Trauma Complejo y Reconstrucción',
      ];
    }
    if (espLower.contains('gineco') || espLower.contains('obstet')) {
      return [
        'Fertilidad y Reproducción Asistida',
        'Cirugía Laparoscópica e Histeroscopia',
        'Medicina Materno-Fetal / Alto Riesgo',
        'Oncología Ginecológica',
        'Uroginecología y Piso Pélvico',
        'Colposcopia y Patología Cervical',
      ];
    }
    if (espLower.contains('pediatr')) {
      return [
        'Neonatología',
        'Neuropediatría',
        'Cardiopediatría',
        'Gastroenterología Pediátrica',
        'Neumología Pediátrica',
        'Infectología Pediátrica',
        'Cirugía Pediátrica',
        'Lactancia y Crecimiento',
      ];
    }
    if (espLower.contains('interna')) {
      return [
        'Valoración Preoperatoria',
        'Hipertensión y Riesgo Cardiovascular',
        'Diabetes y Control Metabólico',
        'Enfermedades Crónicas Complejas',
        'Cuidados Intensivos',
      ];
    }
    if (espLower.contains('general') || espLower.contains('familiar')) {
      return [
        'Atención Primaria e Integral',
        'Chequeo Médico Preventivo',
        'Control de Enfermedades Crónicas',
        'Salud Familiar y Comunitaria',
        'Atención Domiciliaria',
      ];
    }
    if (espLower.contains('derma')) {
      return [
        'Dermatología Clínica',
        'Dermatología Estética y Láser',
        'Cirugía Dermatológica y Cáncer de Piel',
        'Tricología (Cabello y Cuero Cabelludo)',
        'Dermatología Pediátrica',
      ];
    }
    if (espLower.contains('neuro')) {
      return [
        'Epilepsia y Electroencefalografía',
        'Neurología Vascular (ACV / Ictus)',
        'Trastornos del Movimiento / Parkinson',
        'Cefaleas y Migraña',
        'Enfermedades Desmielinizantes',
      ];
    }
    if (espLower.contains('oftalmo')) {
      return [
        'Cirugía Refractiva (Láser)',
        'Cirugía de Catarata',
        'Retina y Vítreo',
        'Glaucoma',
        'Oftalmopediatría y Estrabismo',
        'Córnea y Superficie Ocular',
      ];
    }
    if (espLower.contains('otorrino')) {
      return [
        'Rinología y Cirugía Endoscópica',
        'Otología y Cirugía del Oído',
        'Laringología y Voz Profesional',
        'Otoneurología y Vértigo',
        'Cirugía de Cabeza y Cuello',
      ];
    }
    if (espLower.contains('gastro')) {
      return [
        'Endoscopia Digestiva Avanzada',
        'Hepatología (Hígado)',
        'Vía Biliar y Páncreas (CPRE)',
        'Enfermedad Inflamatoria Intestinal',
        'Motilidad Digestiva',
      ];
    }
    if (espLower.contains('uro')) {
      return [
        'Endourología y Litiasis Renal',
        'Urología Oncológica',
        'Andrología y Salud Masculina',
        'Uroginecología',
        'Cirugía Laparoscópica Urológica',
      ];
    }
    if (espLower.contains('cirug') && !espLower.contains('cardio') && !espLower.contains('pediatr')) {
      return [
        'Cirugía Laparoscópica Avanzada',
        'Cirugía Bariátrica y Metabólica',
        'Cirugía de Pared Abdominal (Hernias)',
        'Coloproctología',
        'Cirugía Oncológica',
      ];
    }
    if (espLower.contains('endocrin')) {
      return [
        'Diabetes y Resistencia a la Insulina',
        'Patología Tiroidea y Nódulos',
        'Metabolismo Óseo y Osteoporosis',
        'Endocrinología Reproductiva',
      ];
    }
    if (espLower.contains('neumon') || espLower.contains('pulmon')) {
      return [
        'Asma y EPOC',
        'Trastornos del Sueño y Apnea',
        'Broncoscopia Intervencionista',
        'Enfermedades Pulmonares Intersticiales',
      ];
    }
    if (espLower.contains('oncol')) {
      return [
        'Oncología Médica / Quimioterapia',
        'Inmunoterapia y Terapias Dirigidas',
        'Tumores Sólidos',
        'Cuidados Paliativos',
      ];
    }
    if (espLower.contains('psiquiatr')) {
      return [
        'Psiquiatría de Adultos',
        'Paidopsiquiatría (Niños y Adolescentes)',
        'Trastornos del Ánimo y Ansiedad',
        'Adicciones y Dependencias',
        'Psicogeriatría',
      ];
    }
    if (espLower.contains('nefro')) {
      return [
        'Diálisis y Hemodiálisis',
        'Glomerulopatías',
        'Trasplante Renal',
        'Hipertensión y Daño Renal',
      ];
    }
    if (espLower.contains('reumat')) {
      return [
        'Artritis Reumatoide',
        'Lupus y Enfermedades Autoinmunes',
        'Fibromialgia y Dolor Crónico',
        'Osteoartritis y Gota',
      ];
    }
    if (espLower.contains('odontol')) {
      return [
        'Ortodoncia y Brackets',
        'Implantología y Cirugía Oral',
        'Endodoncia (Tratamiento de Conducto)',
        'Periodoncia y Estética Dental',
        'Odontopediatría',
        'Rehabilitación Oral y Prótesis',
      ];
    }
    if (espLower.contains('psicol')) {
      return [
        'Terapia Cognitivo-Conductual',
        'Psicología Infantil y Juvenil',
        'Terapia de Pareja y Familia',
        'Neuropsicología y Evaluación Cognitiva',
        'Manejo del Estrés y Ansiedad',
      ];
    }
    if (espLower.contains('nutri')) {
      return [
        'Nutrición Clínica y Bariátrica',
        'Nutrición Deportiva y Rendimiento',
        'Pérdida de Peso y Metabolismo',
        'Nutrición Infantil',
        'Enfermedades Renales y Digestivas',
      ];
    }

    return [
      'Procedimientos Especializados',
      'Consultas de Alta Complejidad',
      'Diagnóstico Avanzado',
    ];
  }
}

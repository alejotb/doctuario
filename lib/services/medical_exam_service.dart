import 'package:flutter/foundation.dart';
import '../backend/supabase/supabase.dart';

class MedicalExamService {
  static final MedicalExamService _instance = MedicalExamService._internal();
  factory MedicalExamService() => _instance;
  MedicalExamService._internal();

  static const String bucketName = 'examenes';
  static const int maxFileSizeBytes = 25 * 1024 * 1024; // 25 MB límite por archivo

  /// Resuelve el Content-Type (MIME) exacto según la extensión del archivo
  /// para que el navegador web pueda abrir PDFs e imágenes de forma nativa.
  static String resolveContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      case 'dcm':
      case 'dicom':
        return 'application/dicom';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/vnd.rar';
      case '7z':
        return 'application/x-7z-compressed';
      case 'xml':
        return 'application/xml';
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain; charset=utf-8';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  /// Clasifica el formato del estudio según su extensión
  static String resolveFormato(String ext) {
    final e = ext.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif', 'bmp'].contains(e)) {
      return 'imagen';
    } else if (e == 'pdf') {
      return 'pdf';
    } else if (['dcm', 'dicom'].contains(e)) {
      return 'dicom';
    } else if (['ecg', 'ekg', 'scp', 'edf', 'bdf', 'hl7', 'dat', 'xml'].contains(e)) {
      return 'electro_datos';
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(e)) {
      return 'comprimido';
    }
    return 'documento';
  }

  /// Catálogo de tipos de estudios clínicos y sus estudios más frecuentes
  static const Map<String, List<String>> catalogoEstudiosPorTipo = {
    'Laboratorio Clínico': [
      'Hemograma Completo',
      'Química Sanguínea (Glucosa, Urea, Creatinina)',
      'Perfil Lipídico (Colesterol, Triglicéridos)',
      'Perfil Hepático (TGO, TGP, Bilirrubinas)',
      'Examen General de Orina (EGO)',
      'Coprológico / Coproparasitológico',
      'Pruebas Tiroideas (TSH, T3, T4 Libre)',
      'Hemoglobina Glicosilada (HbA1c)',
      'Electrolitos Séricos (Na, K, Cl)',
      'Tiempos de Coagulación (TP, TTP)',
      'Urocultivo con Antibiograma',
      'Otro Examen de Laboratorio',
    ],
    'Imagenología y Rayos X': [
      'Radiografía de Tórax PA / Lateral',
      'Radiografía de Columna Lumbar',
      'Radiografía de Extremidades',
      'Tomografía Axial Computarizada (TAC) Craneal',
      'Tomografía Axial Computarizada (TAC) Abdominal',
      'Resonancia Magnética Nuclear (RMN) Cerebral',
      'Resonancia Magnética Nuclear (RMN) Columna',
      'Mamografía Bilateral',
      'Densitometría Ósea',
      'Otra Imagenología / Rayos X',
    ],
    'Ecografía y Ultrasonido': [
      'Ecografía Abdominal Total',
      'Ecografía Pélvica / Ginecológica',
      'Ecografía Obstétrica',
      'Ecografía Renal y Vías Urinarias',
      'Ecografía Tiroidea',
      'Ecografía Doppler Venoso / Arterial',
      'Ecografía de Partes Blandas / Articular',
      'Otra Ecografía / Ultrasonido',
    ],
    'Cardiología y Función Cardiovascular': [
      'Electrocardiograma (ECG) en reposo',
      'Ecocardiograma Transtorácico',
      'Monitoreo Holter 24 Horas',
      'Monitoreo Ambulatorio de Presión Arterial (MAPA)',
      'Prueba de Esfuerzo (Ergometría)',
      'Otro Estudio Cardiológico',
    ],
    'Endoscopia y Gastroenterología': [
      'Endoscopia Digestiva Alta (Gastroscopia)',
      'Colonoscopia Total',
      'Rectosigmoidoscopia',
      'Otro Estudio Endoscópico',
    ],
    'Anatomía Patológica y Biopsias': [
      'Citología Cervical (Papanicolaou)',
      'Biopsia por Aspiración con Aguja Fina (PAAF)',
      'Informe Histopatológico de Biopsia',
      'Otro Estudio Patológico',
    ],
    'Otros Estudios Médicos': [
      'Espirometría / Función Pulmonar',
      'Audiometría Clínica',
      'Electroencefalograma (EEG)',
      'Polisomnografía (Estudio del Sueño)',
      'Estudio Especializado No Clasificado',
    ],
  };

  /// Sube un examen médico a Supabase Storage y registra la entrada en examenes_medicos con estado 'por_revisar'
  Future<ExamenesMedicosRow> subirExamen({
    required String idPaciente,
    required String? subidoPorUsuarioId,
    required String titulo,
    required String tipoExamen,
    required String fileName,
    required Uint8List fileBytes,
    String? idDoctor,
    String? idCita,
    String? especialidad,
    String? notas,
    DateTime? fechaEstudio,
    DateTime? fechaEntrega,
    String estadoInicial = 'por_revisar',
    bool compartirConPaciente = true,
    String? correoFamiliar,
  }) async {
    if (fileBytes.lengthInBytes > maxFileSizeBytes) {
      throw Exception(
        'El archivo supera el límite máximo permitido de 25 MB.',
      );
    }

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'file';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = 'pacientes/$idPaciente/${timestamp}_$cleanFileName';
    final mimeType = resolveContentType(ext);

    // Subida al bucket en Supabase Storage con el Content-Type correcto
    await SupaFlow.client.storage.from(bucketName).uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: mimeType,
          ),
        );

    final publicUrl =
        SupaFlow.client.storage.from(bucketName).getPublicUrl(storagePath);

    // Calcular fecha de entrega si no fue especificada
    DateTime fechaEntregaFinal = fechaEntrega ?? (fechaEstudio ?? DateTime.now()).add(const Duration(days: 7));
    if (fechaEntrega == null) {
      try {
        final citas = await CitasTable().queryRows(
          queryFn: (q) => q
              .eq('id_paciente', idPaciente)
              .gte('fecha_hora', DateTime.now().toUtc().toIso8601String())
              .order('fecha_hora', ascending: true)
              .limit(1),
        );
        if (citas.isNotEmpty && citas.first.fechaHora != null) {
          fechaEntregaFinal = citas.first.fechaHora!;
        }
      } catch (_) {}
    }

    final String formatoFinal = resolveFormato(ext);

    // Registro en la base de datos con estado inicial 'por_revisar' por defecto
    final insertData = <String, dynamic>{
      'id_paciente': idPaciente,
      'id_doctor': idDoctor,
      if (idCita != null) 'id_cita': idCita,
      'subido_por_usuario_id': subidoPorUsuarioId,
      'titulo': titulo,
      'tipo_examen': tipoExamen,
      'especialidad': especialidad ?? tipoExamen,
      'archivo_url': publicUrl,
      'formato': formatoFinal,
      'fecha_estudio':
          (fechaEstudio ?? DateTime.now()).toIso8601String().split('T').first,
      'fecha_entrega': fechaEntregaFinal.toIso8601String(),
      'estado': estadoInicial,
      'notas': notas,
      'hallazgos': notas,
      'compartir_con_paciente': compartirConPaciente,
      if (correoFamiliar != null && correoFamiliar.trim().isNotEmpty)
        'correo_familiar': correoFamiliar.trim().toLowerCase(),
    };

    try {
      return await ExamenesMedicosTable().insert(insertData);
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('PGRST204') ||
          errStr.contains('compartir_con_paciente') ||
          errStr.contains('correo_familiar')) {
        final fallbackData = Map<String, dynamic>.from(insertData)
          ..remove('compartir_con_paciente')
          ..remove('correo_familiar');
        return await ExamenesMedicosTable().insert(fallbackData);
      }
      rethrow;
    }
  }

  /// Marca un estudio como revisado directamente por el doctor
  Future<void> marcarComoRevisado({
    required String idExamen,
    String? hallazgos,
  }) async {
    final updateData = <String, dynamic>{
      'estado': 'revisado',
    };
    if (hallazgos != null && hallazgos.trim().isNotEmpty) {
      updateData['hallazgos'] = hallazgos.trim();
      updateData['notas'] = hallazgos.trim();
    }
    await ExamenesMedicosTable().update(
      data: updateData,
      matchingRows: (q) => q.eq('id', idExamen),
    );
  }

  /// Permite al doctor revisar un estudio, ingresar los hallazgos clínicos y ajustar la fecha de entrega
  Future<void> guardarHallazgosYRevisar({
    required String idExamen,
    required String hallazgos,
    DateTime? fechaEntrega,
    bool? compartirConPaciente,
    String? correoFamiliar,
  }) async {
    final updateData = <String, dynamic>{
      'hallazgos': hallazgos,
      'notas': hallazgos,
      'estado': 'revisado',
    };
    if (fechaEntrega != null) {
      updateData['fecha_entrega'] = fechaEntrega.toIso8601String();
    }
    if (compartirConPaciente != null) {
      updateData['compartir_con_paciente'] = compartirConPaciente;
    }
    if (correoFamiliar != null) {
      updateData['correo_familiar'] = correoFamiliar.trim().isEmpty ? null : correoFamiliar.trim().toLowerCase();
    }
    try {
      await ExamenesMedicosTable().update(
        data: updateData,
        matchingRows: (q) => q.eq('id', idExamen),
      );
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('PGRST204') ||
          errStr.contains('compartir_con_paciente') ||
          errStr.contains('correo_familiar')) {
        final fallbackData = Map<String, dynamic>.from(updateData)
          ..remove('compartir_con_paciente')
          ..remove('correo_familiar');
        await ExamenesMedicosTable().update(
          data: fallbackData,
          matchingRows: (q) => q.eq('id', idExamen),
        );
      } else {
        rethrow;
      }
    }
  }

  /// Obtiene la lista de exámenes de un paciente con soporte de visibilidad y acceso para familiares
  Future<List<ExamenesMedicosRow>> obtenerExamenesPaciente(
    String idPaciente, {
    String? correoUsuario,
    bool soloCompartidos = false,
  }) async {
    final List<ExamenesMedicosRow> examenes = [];
    final idList = await ExamenesMedicosTable().queryRows(
      queryFn: (q) => q.eq('id_paciente', idPaciente).order('fecha_estudio', ascending: false),
    );
    for (final ex in idList) {
      final compartido = ex.getField<bool>('compartir_con_paciente') ?? true;
      if (!soloCompartidos || compartido) {
        examenes.add(ex);
      }
    }

    if (correoUsuario != null && correoUsuario.trim().isNotEmpty) {
      final emailClean = correoUsuario.trim().toLowerCase();
      try {
        final familiarList = await ExamenesMedicosTable().queryRows(
          queryFn: (q) => q.eq('correo_familiar', emailClean).order('fecha_estudio', ascending: false),
        );
        for (final ex in familiarList) {
          final compartido = ex.getField<bool>('compartir_con_paciente') ?? true;
          if (compartido && !examenes.any((e) => e.id == ex.id)) {
            examenes.add(ex);
          }
        }
      } catch (_) {}
    }
    return examenes;
  }

  /// Obtiene los exámenes médicos asociados directamente a una cita médica específica
  Future<List<ExamenesMedicosRow>> obtenerExamenesPorCita(String idCita) async {
    try {
      return await ExamenesMedicosTable().queryRows(
        queryFn: (q) =>
            q.eq('id_cita', idCita).order('fecha_estudio', ascending: false),
      );
    } catch (_) {
      return [];
    }
  }

  /// Agrupa los exámenes médicos por el tipo o nombre de categoría
  static Map<String, List<ExamenesMedicosRow>> agruparPorTipoEstudio(
      List<ExamenesMedicosRow> examenes) {
    final map = <String, List<ExamenesMedicosRow>>{};
    for (final ex in examenes) {
      final tipo = ex.tipoExamen != null && ex.tipoExamen!.trim().isNotEmpty
          ? ex.tipoExamen!.trim()
          : (ex.especialidad != null && ex.especialidad!.trim().isNotEmpty
              ? ex.especialidad!.trim()
              : 'Otros Estudios');
      map.putIfAbsent(tipo, () => []).add(ex);
    }
    return map;
  }

  /// Agrupa los exámenes médicos por especialidad
  static Map<String, List<ExamenesMedicosRow>> agruparPorEspecialidad(
      List<ExamenesMedicosRow> examenes) {
    final map = <String, List<ExamenesMedicosRow>>{};
    for (final ex in examenes) {
      final esp = ex.especialidad != null && ex.especialidad!.trim().isNotEmpty
          ? ex.especialidad!.trim()
          : (ex.tipoExamen != null && ex.tipoExamen!.isNotEmpty
              ? ex.tipoExamen!
              : 'General');
      map.putIfAbsent(esp, () => []).add(ex);
    }
    return map;
  }

  /// Filtra una lista de exámenes para retornar el más reciente de cada tipo de estudio
  /// asegurando que el médico tenga acceso rápido a al menos uno de cada categoría médica.
  static List<ExamenesMedicosRow> filtrarUltimoPorCadaTipo(
      List<ExamenesMedicosRow> examenes) {
    final Map<String, ExamenesMedicosRow> ultimosPorTipo = {};
    final copia = List<ExamenesMedicosRow>.from(examenes)
      ..sort((a, b) {
        final fA = a.fechaEstudio ?? a.createdAt;
        final fB = b.fechaEstudio ?? b.createdAt;
        return fB.compareTo(fA);
      });

    for (final ex in copia) {
      final tipo = (ex.tipoExamen != null && ex.tipoExamen!.trim().isNotEmpty)
          ? ex.tipoExamen!.trim()
          : ((ex.especialidad != null && ex.especialidad!.trim().isNotEmpty)
              ? ex.especialidad!.trim()
              : 'General');
      if (!ultimosPorTipo.containsKey(tipo)) {
        ultimosPorTipo[tipo] = ex;
      }
    }
    return ultimosPorTipo.values.toList();
  }

  /// Obtiene una URL firmada segura temporal para ver o descargar un examen médico privado
  static Future<String> getSecureExamUrl(String fileUrlOrPath, {int expiresIn = 3600}) async {
    try {
      if (fileUrlOrPath.trim().isEmpty) return fileUrlOrPath;
      if (fileUrlOrPath.contains('token=')) return fileUrlOrPath;

      String relativePath = fileUrlOrPath.trim();
      if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
        final uri = Uri.tryParse(relativePath);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          final segments = uri.pathSegments;
          final bucketIdx = segments.indexOf(bucketName);
          if (bucketIdx != -1 && bucketIdx + 1 < segments.length) {
            relativePath = segments.sublist(bucketIdx + 1).join('/');
          }
        }
      }

      if (relativePath.isNotEmpty) {
        final signed = await SupaFlow.client.storage
            .from(bucketName)
            .createSignedUrl(relativePath, expiresIn);
        return signed;
      }
    } catch (e) {
      debugPrint('Nota al generar URL firmada para examen: $e');
    }
    return fileUrlOrPath;
  }
}

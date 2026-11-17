import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '/backend/supabase/supabase.dart';
import 'gemini_ai_service.dart';

/// Modelo de datos que representa a un paciente extraído y listo para importar.
class ImportedPatientItem {
  ImportedPatientItem({
    required this.sourceFile,
    this.nombre,
    this.cedula,
    this.telefono,
    this.email,
    this.fechaNacimiento,
    this.sexo,
    this.tipoSangre,
    this.antecedentes,
    this.diagnosticoInicial,
    this.isDuplicate = false,
    this.errorMessage,
  });

  final String sourceFile;
  String? nombre;
  String? cedula;
  String? telefono;
  String? email;
  String? fechaNacimiento;
  String? sexo;
  String? tipoSangre;
  String? antecedentes;
  String? diagnosticoInicial;
  bool isDuplicate;
  String? errorMessage;

  bool get isValid =>
      (nombre != null && nombre!.trim().isNotEmpty) ||
      (cedula != null && cedula!.trim().isNotEmpty);

  Map<String, dynamic> toMap() => {
        'sourceFile': sourceFile,
        'nombre': nombre,
        'cedula': cedula,
        'telefono': telefono,
        'email': email,
        'fechaNacimiento': fechaNacimiento,
        'sexo': sexo,
        'tipoSangre': tipoSangre,
        'antecedentes': antecedentes,
        'diagnosticoInicial': diagnosticoInicial,
      };
}

/// Servicio integral para procesar archivos multiformato e importarlos
/// directamente a la base de datos privada del doctor.
class PatientImportService {
  PatientImportService._();
  static final PatientImportService instance = PatientImportService._();

  /// Extrae texto plano desde los bytes de un archivo Word (.docx)
  String extractTextFromDocx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXml = archive.findFile('word/document.xml');
      if (documentXml == null) return '';

      final contentBytes = documentXml.content as List<int>;
      final xmlString = utf8.decode(contentBytes, allowMalformed: true);

      // Reemplazar etiquetas XML comunes de párrafo por saltos de línea
      final withNewlines = xmlString
          .replaceAll(RegExp(r'</w:p>'), '\n')
          .replaceAll(RegExp(r'<w:tab/>'), '\t');

      // Eliminar el resto de etiquetas XML <...>
      final cleanText = withNewlines.replaceAll(RegExp(r'<[^>]+>'), '');
      return cleanText.trim();
    } catch (e) {
      debugPrint('Error extrayendo texto de archivo .docx: $e');
      return '';
    }
  }

  /// Procesa un archivo CSV o tabla delimitada
  List<ImportedPatientItem> parseCsvData(String csvContent, String filename) {
    final results = <ImportedPatientItem>[];
    try {
      // Detectar si el delimitador es coma, punto y coma o tabulador
      final firstLine = csvContent.split('\n').firstOrNull ?? '';
      String delimiter = ',';
      if (firstLine.contains(';') && !firstLine.contains(',')) {
        delimiter = ';';
      } else if (firstLine.contains('\t')) {
        delimiter = '\t';
      }

      final rows = Csv(
        fieldDelimiter: delimiter,
        autoDetect: false,
      ).decode(csvContent.replaceAll('\r\n', '\n'));

      if (rows.isEmpty) return results;

      // 1. Mapear cabeceras
      final headers = rows.first
          .map((c) => c.toString().trim().toLowerCase())
          .toList();

      int colNombre = -1;
      int colCedula = -1;
      int colTelefono = -1;
      int colEmail = -1;
      int colFechaNac = -1;
      int colSexo = -1;
      int colSangre = -1;

      for (int i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (h.contains('nom') || h.contains('paciente') || h.contains('titular')) {
          colNombre = i;
        } else if (h.contains('ced') || h.contains('ci') || h.contains('dni') || h.contains('doc')) {
          colCedula = i;
        } else if (h.contains('tel') || h.contains('cel') || h.contains('movil') || h.contains('what')) {
          colTelefono = i;
        } else if (h.contains('mail') || h.contains('corr')) {
          colEmail = i;
        } else if (h.contains('nac') || h.contains('edad') || h.contains('birth')) {
          colFechaNac = i;
        } else if (h.contains('sex') || h.contains('gen')) {
          colSexo = i;
        } else if (h.contains('sangre') || h.contains('rh')) {
          colSangre = i;
        }
      }

      // Si no detectó nombre, usar la columna 0 si tiene datos
      if (colNombre == -1 && headers.isNotEmpty) colNombre = 0;

      // 2. Extraer filas
      for (int r = 1; r < rows.length; r++) {
        final row = rows[r];
        if (row.isEmpty) continue;

        String? getVal(int col) {
          if (col >= 0 && col < row.length) {
            final v = row[col].toString().trim();
            return v.isNotEmpty ? v : null;
          }
          return null;
        }

        final item = ImportedPatientItem(
          sourceFile: '$filename (Fila ${r + 1})',
          nombre: getVal(colNombre),
          cedula: getVal(colCedula),
          telefono: getVal(colTelefono),
          email: getVal(colEmail),
          fechaNacimiento: getVal(colFechaNac),
          sexo: getVal(colSexo),
          tipoSangre: getVal(colSangre),
        );

        if (item.isValid) {
          results.add(item);
        }
      }
    } catch (e) {
      debugPrint('Error parseando archivo CSV $filename: $e');
    }
    return results;
  }

  /// Procesa un documento individual (Word .docx o TXT) usando Gemini 3.8 Flash
  Future<ImportedPatientItem> parseDocumentWithGemini({
    required String filename,
    required String textContent,
  }) async {
    if (textContent.trim().isEmpty) {
      return ImportedPatientItem(
        sourceFile: filename,
        errorMessage: 'El documento no contiene texto legible.',
      );
    }

    try {
      final jsonResult = await GeminiAiService.instance.extractPatientFromText(
        textContent,
      );

      return ImportedPatientItem(
        sourceFile: filename,
        nombre: jsonResult['nombre']?.toString(),
        cedula: jsonResult['cedula']?.toString(),
        telefono: jsonResult['telefono']?.toString(),
        email: jsonResult['email']?.toString(),
        fechaNacimiento: jsonResult['fecha_nacimiento']?.toString(),
        sexo: jsonResult['sexo']?.toString(),
        tipoSangre: jsonResult['tipo_sangre']?.toString(),
        antecedentes: jsonResult['antecedentes']?.toString(),
        diagnosticoInicial: jsonResult['diagnostico_inicial']?.toString(),
      );
    } catch (e) {
      return ImportedPatientItem(
        sourceFile: filename,
        errorMessage: 'Error al consultar Gemini 3.8 Flash: $e',
      );
    }
  }

  /// Inserta un lote de pacientes verificados en la base de datos privada del doctor
  Future<Map<String, int>> insertPatientsBatch({
    required String idDoctor,
    required List<ImportedPatientItem> patients,
  }) async {
    int insertados = 0;
    int omitidos = 0;

    final docClient = DualDatabaseConfig.instance.doctorClient;

    for (final p in patients) {
      if (!p.isValid || p.isDuplicate) {
        omitidos++;
        continue;
      }

      try {
        final newPatientId = const Uuid().v4();
        DateTime? fn;
        if (p.fechaNacimiento != null) {
          fn = DateTime.tryParse(p.fechaNacimiento!);
        }

        final nowIso = DateTime.now().toIso8601String();
        final fnStr = fn != null
            ? '${fn.year.toString().padLeft(4, '0')}-${fn.month.toString().padLeft(2, '0')}-${fn.day.toString().padLeft(2, '0')}'
            : null;

        // 1. Guardar ficha completa directamente en la tabla pacientes de la base privada
        final pacPayload = <String, dynamic>{
          'id': newPatientId,
          'id_doctor': idDoctor,
          'nombre': p.nombre ?? 'Paciente',
          if (p.cedula != null) 'cedula': p.cedula,
          if (p.telefono != null) 'telefono': p.telefono,
          if (p.email != null) 'email': p.email,
          if (fnStr != null) 'fecha_nacimiento': fnStr,
          if (p.tipoSangre != null) 'tipo_sangre': p.tipoSangre,
          if (p.antecedentes != null) 'antecedentes': p.antecedentes,
          'created_at': nowIso,
        };

        try {
          await docClient.from('pacientes').insert(pacPayload);
        } catch (_) {
          try {
            await docClient.from('pacientes').upsert({
              'id': newPatientId,
              'id_doctor': idDoctor,
              if (fnStr != null) 'fecha_nacimiento': fnStr,
              'created_at': nowIso,
            });
          } catch (_) {}
          try {
            await docClient.from('usuarios').insert({
              'id': newPatientId,
              'nombre': p.nombre ?? 'Paciente',
              if (p.cedula != null) 'cedula': p.cedula,
              if (p.telefono != null) 'telefono': p.telefono,
              if (p.email != null) 'email': p.email,
              'rol': 'paciente',
              'created_at': nowIso,
            });
          } catch (_) {}
        }

        // 3. Si el documento incluía antecedentes o diagnóstico, crear primera historia clínica
        if ((p.antecedentes != null && p.antecedentes!.isNotEmpty) ||
            (p.diagnosticoInicial != null && p.diagnosticoInicial!.isNotEmpty)) {
          await docClient.from('historias_clinicas').insert({
            'id': const Uuid().v4(),
            'id_paciente': newPatientId,
            'id_doctor': idDoctor,
            'fecha': DateTime.now().toIso8601String(),
            if (p.diagnosticoInicial != null)
              'motivo_consulta': p.diagnosticoInicial,
            if (p.antecedentes != null)
              'diagnostico': 'Antecedentes: ${p.antecedentes}',
          });
        }

        insertados++;
      } catch (e) {
        debugPrint('Error guardando paciente en base privada: $e');
        omitidos++;
      }
    }

    return {'insertados': insertados, 'omitidos': omitidos};
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backend/supabase/supabase.dart';

class AiClinicalSummaryService {
  static final AiClinicalSummaryService _instance =
      AiClinicalSummaryService._internal();
  factory AiClinicalSummaryService() => _instance;
  AiClinicalSummaryService._internal();

  /// Genera un resumen clínico estructurado para el doctor
  /// Analiza la última historia clínica, motivo de consulta, diagnósticos y citas.
  String generarResumenClinico({
    required UsuariosRow? paciente,
    required List<HistoriasClinicasRow> historias,
    List<CitasRow>? citas,
    List<ExamenesMedicosRow>? examenes,
    String? especialidadDoctor,
  }) {
    final nombre = paciente?.nombre ?? 'Paciente';
    final buffer = StringBuffer();

    // Obtener motivo más reciente de citas si existe
    String? motivoCita;
    DateTime? fechaCita;
    if (citas != null && citas.isNotEmpty) {
      final c = citas.first;
      motivoCita = c.motivo;
      fechaCita = c.fechaHora;
    }

    if (historias.isNotEmpty) {
      final ultima = historias.first;
      final fechaStr = DateFormat('dd/MM/yyyy').format(ultima.createdAt);

      buffer.writeln('📋 RESUMEN CLÍNICO ($fechaStr) - $nombre:');
      
      final motivoPrincipal = (ultima.motivoConsulta != null && ultima.motivoConsulta!.trim().isNotEmpty)
          ? ultima.motivoConsulta!.trim()
          : (motivoCita ?? 'Consulta Médica');
      buffer.writeln('• Motivo de Consulta: $motivoPrincipal');

      if (ultima.sintomas != null && ultima.sintomas!.trim().isNotEmpty) {
        buffer.writeln('• Síntomas referidos: ${ultima.sintomas!.trim()}');
      }

      if (ultima.diagnostico != null && ultima.diagnostico!.trim().isNotEmpty) {
        buffer.writeln('• Diagnóstico: ${ultima.diagnostico!.trim()}');
      }

      if (ultima.tratamiento != null && ultima.tratamiento!.trim().isNotEmpty) {
        buffer.writeln('• Plan / Tratamiento: ${ultima.tratamiento!.trim()}');
      }
    } else {
      // Paciente sin historias previas
      buffer.writeln('📋 VALORACIÓN INICIAL - $nombre:');
      if (motivoCita != null && motivoCita.trim().isNotEmpty) {
        buffer.writeln('• Motivo de Consulta: ${motivoCita.trim()}');
      } else {
        buffer.writeln('• Motivo de Consulta: Valoración médica general');
      }
      final fechaStr = fechaCita != null ? ' (${DateFormat('dd/MM/yyyy').format(fechaCita)})' : '';
      buffer.writeln('• Estado: Primera consulta con este especialista$fechaStr. Sin antecedentes previos registrados en sistema.');
    }

    // Agregar mención de estudios recientes si existen
    if (examenes != null && examenes.isNotEmpty) {
      final count = examenes.length;
      final ultEstudio = examenes.first.titulo ?? 'Estudio';
      buffer.writeln('• Estudios: $count estudio(s) en historial (Último: $ultEstudio).');
    }

    return buffer.toString().trim();
  }

  /// Calcula la fecha de entrega de un estudio médico.
  /// Regla: Si el estudio tiene fecha_entrega asignada, se usa.
  /// Si no, se calcula con la próxima consulta del paciente; si no hay próxima consulta, 7 días desde el estudio.
  static DateTime calcularFechaEntrega(
    ExamenesMedicosRow estudio, {
    List<CitasRow>? citasFuturasPaciente,
  }) {
    if (estudio.fechaEntrega != null) {
      return estudio.fechaEntrega!;
    }

    if (citasFuturasPaciente != null && citasFuturasPaciente.isNotEmpty) {
      final ahora = DateTime.now();
      final proximas = citasFuturasPaciente
          .where((c) => c.fechaHora != null && c.fechaHora!.isAfter(ahora))
          .toList();
      if (proximas.isNotEmpty) {
        proximas.sort((a, b) => a.fechaHora!.compareTo(b.fechaHora!));
        return proximas.first.fechaHora!;
      }
    }

    // Fallback: 7 días después de la fecha del estudio o creación
    final base = estudio.fechaEstudio ?? estudio.createdAt;
    return base.add(const Duration(days: 7));
  }

  /// Formatea el tiempo restante para la revisión del estudio
  /// Retorna un mapa con:
  /// - 'texto': String legible (ej. "Vence en 2 días", "Vence hoy", "Atrasado 1 día")
  /// - 'urgencia': 'urgente' | 'proximo' | 'al_dia' | 'vencido'
  /// - 'color': Color para el badge
  static Map<String, dynamic> formatearTiempoRevision(DateTime fechaEntrega) {
    final ahora = DateTime.now();
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
    final finEntrega = DateTime(fechaEntrega.year, fechaEntrega.month, fechaEntrega.day);
    final diferenciaDias = finEntrega.difference(inicioHoy).inDays;

    if (diferenciaDias < 0) {
      final diasPasados = diferenciaDias.abs();
      return {
        'texto': diasPasados == 1 ? 'Atrasado hace 1 día' : 'Atrasado hace $diasPasados días',
        'urgencia': 'vencido',
        'color': const Color(0xFFE11D48), // Rose 600
        'bgColor': const Color(0xFFFFF1F2),
        'dias': diferenciaDias,
      };
    } else if (diferenciaDias == 0) {
      return {
        'texto': 'Vence hoy (Próxima consulta)',
        'urgencia': 'urgente',
        'color': const Color(0xFFEA580C), // Orange 600
        'bgColor': const Color(0xFFFFF7ED),
        'dias': 0,
      };
    } else if (diferenciaDias == 1) {
      return {
        'texto': '1 día para la entrega / consulta',
        'urgencia': 'proximo',
        'color': const Color(0xFFD97706), // Amber 600
        'bgColor': const Color(0xFFFEF3C7),
        'dias': 1,
      };
    } else if (diferenciaDias <= 3) {
      return {
        'texto': '$diferenciaDias días para la consulta',
        'urgencia': 'proximo',
        'color': const Color(0xFF0284C7), // Sky 600
        'bgColor': const Color(0xFFE0F2FE),
        'dias': diferenciaDias,
      };
    } else {
      return {
        'texto': '$diferenciaDias días restantes para revisión',
        'urgencia': 'al_dia',
        'color': const Color(0xFF059669), // Emerald 600
        'bgColor': const Color(0xFFECFDF5),
        'dias': diferenciaDias,
      };
    }
  }

  /// Guarda la nota o resumen privado del doctor para el paciente
  Future<void> guardarResumenPrivado({
    required String idPaciente,
    required String idDoctor,
    required String resumenTexto,
    String? idUltimaHistoria,
  }) async {
    if (idUltimaHistoria != null && idUltimaHistoria.isNotEmpty) {
      await HistoriasClinicasTable().update(
        data: {
          'notas_privadas': resumenTexto,
          'es_privado': true,
        },
        matchingRows: (q) => q.eq('id', idUltimaHistoria),
      );
    } else {
      // Crear registro de historia confidencial si no existía ninguna
      await HistoriasClinicasTable().insert({
        'id_paciente': idPaciente,
        'id_doctor': idDoctor,
        'motivo_consulta': 'Nota de Resumen Clínico Confidencial',
        'sintomas': 'Registro de seguimiento del paciente.',
        'diagnostico': 'Seguimiento clínico privado',
        'tratamiento': 'Plan del médico tratante',
        'notas_privadas': resumenTexto,
        'es_privado': true,
      });
    }
  }
}

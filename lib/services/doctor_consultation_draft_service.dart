import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase/supabase.dart';

/// Modelo de datos que representa el borrador de una consulta médica activa.
class ConsultaBorrador {
  final String idCita;
  final String? idPaciente;
  final String? idDoctor;
  final String motivo;
  final String evolucion;
  final String diagnostico;
  final String tratamiento;
  final String signosVitales;
  final List<String> estudiosSeleccionados;
  final List<Map<String, dynamic>> examenesSubidos;
  final DateTime fechaActualizacion;

  const ConsultaBorrador({
    required this.idCita,
    this.idPaciente,
    this.idDoctor,
    this.motivo = '',
    this.evolucion = '',
    this.diagnostico = '',
    this.tratamiento = '',
    this.signosVitales = '',
    this.estudiosSeleccionados = const [],
    this.examenesSubidos = const [],
    required this.fechaActualizacion,
  });

  Map<String, dynamic> toMap() => {
        'id_cita': idCita,
        'id_paciente': idPaciente,
        'id_doctor': idDoctor,
        'motivo': motivo,
        'evolucion': evolucion,
        'diagnostico': diagnostico,
        'tratamiento': tratamiento,
        'signos_vitales': signosVitales,
        'estudios_seleccionados': estudiosSeleccionados,
        'examenes_subidos': examenesSubidos,
        'fecha_actualizacion': fechaActualizacion.toUtc().toIso8601String(),
      };

  factory ConsultaBorrador.fromMap(Map<String, dynamic> map) {
    DateTime fecha;
    try {
      fecha = DateTime.parse(map['fecha_actualizacion'].toString());
    } catch (_) {
      fecha = DateTime.now();
    }

    final rawEstudios = map['estudios_seleccionados'];
    final List<String> estudios = [];
    if (rawEstudios is List) {
      for (final e in rawEstudios) {
        if (e != null) estudios.add(e.toString());
      }
    }

    final rawExamenes = map['examenes_subidos'];
    final List<Map<String, dynamic>> examenes = [];
    if (rawExamenes is List) {
      for (final ex in rawExamenes) {
        if (ex is Map) {
          examenes.add(Map<String, dynamic>.from(ex));
        }
      }
    }

    return ConsultaBorrador(
      idCita: map['id_cita']?.toString() ?? '',
      idPaciente: map['id_paciente']?.toString(),
      idDoctor: map['id_doctor']?.toString(),
      motivo: map['motivo']?.toString() ?? '',
      evolucion: map['evolucion']?.toString() ?? '',
      diagnostico: map['diagnostico']?.toString() ?? '',
      tratamiento: map['tratamiento']?.toString() ?? '',
      signosVitales: map['signos_vitales']?.toString() ?? '',
      estudiosSeleccionados: estudios,
      examenesSubidos: examenes,
      fechaActualizacion: fecha,
    );
  }

  bool get tieneContenido =>
      motivo.trim().isNotEmpty ||
      evolucion.trim().isNotEmpty ||
      diagnostico.trim().isNotEmpty ||
      tratamiento.trim().isNotEmpty ||
      estudiosSeleccionados.isNotEmpty ||
      examenesSubidos.isNotEmpty;
}

/// Servicio de persistencia y respaldo en borrador para la atención médica en curso.
/// Permite al médico guardar sus notas, diagnósticos y estudios sin perder nada
/// aunque cambie de pantalla, refresque o cierre el navegador.
class DoctorConsultationDraftService {
  DoctorConsultationDraftService._();
  static final DoctorConsultationDraftService instance =
      DoctorConsultationDraftService._();
  factory DoctorConsultationDraftService() => instance;

  static const _draftPrefix = 'doctor_consultation_draft_';

  /// Guarda el borrador de la consulta tanto en local (SharedPreferences)
  /// como en la nube (columna borrador_consulta en tabla citas).
  Future<void> guardarBorrador({
    required String idCita,
    String? idPaciente,
    String? idDoctor,
    required String motivo,
    required String evolucion,
    required String diagnostico,
    required String tratamiento,
    String signosVitales = '',
    List<String> estudiosSeleccionados = const [],
    List<Map<String, dynamic>> examenesSubidos = const [],
  }) async {
    final borrador = ConsultaBorrador(
      idCita: idCita,
      idPaciente: idPaciente,
      idDoctor: idDoctor,
      motivo: motivo,
      evolucion: evolucion,
      diagnostico: diagnostico,
      tratamiento: tratamiento,
      signosVitales: signosVitales,
      estudiosSeleccionados: estudiosSeleccionados,
      examenesSubidos: examenesSubidos,
      fechaActualizacion: DateTime.now(),
    );

    final jsonStr = jsonEncode(borrador.toMap());

    // 1. Respaldo local prioritario e inmediato
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_draftPrefix$idCita', jsonStr);
    } catch (e) {
      debugPrint('Nota guardando borrador local: $e');
    }

    // 2. Respaldo en la nube (tabla citas)
    try {
      final client = DualDatabaseConfig.instance.doctorClient;
      await client.from('citas').update({
        'borrador_consulta': borrador.toMap(),
        'es_borrador': true,
        'estado': 'en_consulta',
      }).eq('id', idCita);
    } catch (e) {
      debugPrint('Nota sincronizando borrador en base de datos: $e');
    }
  }

  /// Recupera el borrador previo de una cita si existe
  Future<ConsultaBorrador?> obtenerBorrador(String idCita) async {
    // 1. Intentar leer desde local
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString('$_draftPrefix$idCita');
      if (localJson != null && localJson.isNotEmpty) {
        final decoded = jsonDecode(localJson);
        if (decoded is Map<String, dynamic>) {
          return ConsultaBorrador.fromMap(decoded);
        }
      }
    } catch (e) {
      debugPrint('Nota leyendo borrador local: $e');
    }

    // 2. Intentar leer desde la nube en citas
    try {
      final client = DualDatabaseConfig.instance.doctorClient;
      final res = await client
          .from('citas')
          .select('borrador_consulta, es_borrador, estado')
          .eq('id', idCita)
          .maybeSingle();

      if (res != null && res['borrador_consulta'] != null) {
        final data = res['borrador_consulta'];
        if (data is Map<String, dynamic>) {
          return ConsultaBorrador.fromMap(data);
        } else if (data is String) {
          return ConsultaBorrador.fromMap(jsonDecode(data));
        }
      }
    } catch (e) {
      debugPrint('Nota leyendo borrador remoto: $e');
    }

    return null;
  }

  /// Elimina el borrador una vez que la consulta ha sido formalmente finalizada y guardada.
  Future<void> limpiarBorrador(String idCita) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_draftPrefix$idCita');
    } catch (_) {}

    try {
      final client = DualDatabaseConfig.instance.doctorClient;
      await client.from('citas').update({
        'borrador_consulta': null,
        'es_borrador': false,
      }).eq('id', idCita);
    } catch (_) {}
  }

  /// Retorna la lista de todas las citas del doctor que tienen consultas en borrador
  Future<List<Map<String, dynamic>>> obtenerConsultasEnBorrador(String idDoctor) async {
    final List<Map<String, dynamic>> borradores = [];
    try {
      final client = DualDatabaseConfig.instance.doctorClient;
      final data = await client
          .from('citas')
          .select('id, fecha_hora, motivo, estado, es_borrador, borrador_consulta, id_paciente, duracion_minutos')
          .eq('id_doctor', idDoctor)
          .or('es_borrador.eq.true,estado.eq.en_consulta')
          .order('fecha_hora', ascending: false);

      for (final item in data) {
        borradores.add(item);
      }
    } catch (e) {
      debugPrint('Error obteniendo consultas en borrador: $e');
    }
    return borradores;
  }

  /// Retorna el historial de consultas finalizadas del doctor
  Future<List<Map<String, dynamic>>> obtenerConsultasRealizadas(String idDoctor) async {
    final List<Map<String, dynamic>> realizadas = [];
    try {
      final client = DualDatabaseConfig.instance.doctorClient;
      final data = await client
          .from('citas')
          .select('id, fecha_hora, motivo, estado, id_paciente, duracion_minutos, notas_medicas')
          .eq('id_doctor', idDoctor)
          .eq('estado', 'completada')
          .order('fecha_hora', ascending: false)
          .limit(100);

      for (final item in data) {
        realizadas.add(item);
      }
    } catch (e) {
      debugPrint('Error obteniendo consultas realizadas: $e');
    }
    return realizadas;
  }
}

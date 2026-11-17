import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../backend/supabase/supabase.dart';

/// Información estructurada del estado de un bloque horario individual
class TimeSlotInfo {
  final String horaTexto; // Ej: "08:30"
  final DateTime fechaHoraCompleta;
  final bool estaOcupado;
  final int duracionMinutos;
  final String? motivoBloqueo;

  const TimeSlotInfo({
    required this.horaTexto,
    required this.fechaHoraCompleta,
    required this.estaOcupado,
    required this.duracionMinutos,
    this.motivoBloqueo,
  });

  @override
  String toString() =>
      'TimeSlotInfo($horaTexto, ocupado: $estaOcupado, duracion: ${duracionMinutos}m)';
}

/// Información del conteo y disponibilidad de cupos por día para modalidad orden de llegada
class DayQuotaInfo {
  final DateTime fecha;
  final int limiteTotal;
  final int citasAgendadas;
  final int cuposDisponibles;
  final bool estaAgotado;

  const DayQuotaInfo({
    required this.fecha,
    required this.limiteTotal,
    required this.citasAgendadas,
    required this.cuposDisponibles,
    required this.estaAgotado,
  });

  @override
  String toString() =>
      'DayQuotaInfo(${fecha.toIso8601String().split('T').first}, disponibles: $cuposDisponibles/$limiteTotal)';
}

/// Servicio integral de sincronización coordinada de citas entre la Base de Datos
/// Central (Catálogo público y semáforo de disponibilidad) y la Base de Datos
/// Privada de cada Doctor (Expediente clínico confidencial y agenda de consultorio).
class AppointmentSyncService {
  AppointmentSyncService._();

  static final AppointmentSyncService instance = AppointmentSyncService._();
  factory AppointmentSyncService() => instance;

  static const _uuid = Uuid();

  /// Solicita una cita desde la aplicación de pacientes:
  /// 1. Genera un UUID unificado para que la cita tenga el mismo identificador en ambas bases.
  /// 2. Inserta en la Base de Datos Central con estado 'por_confirmar' (amarillo).
  /// 3. Conecta dinámicamente con la base de datos privada del doctor y replica el registro.
  Future<Map<String, dynamic>> solicitarCitaPaciente({
    required String idDoctor,
    required String idPaciente,
    required String idSede,
    required DateTime fechaHora,
    String modalidadAtencion = 'hora_fija',
    String? motivo,
    int duracionMinutos = 30,
    bool tratoEspecial = false,
  }) async {
    final citaId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final fechaHoraIso = fechaHora.toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'id': citaId,
      'id_doctor': idDoctor,
      'id_paciente': idPaciente,
      'id_sede': idSede,
      'fecha_hora': fechaHoraIso,
      'fecha_hora_estimada_actual': fechaHoraIso,
      'duracion_minutos': duracionMinutos,
      'modalidad_atencion': modalidadAtencion,
      'estado': 'por_confirmar', // 🟡 Estado inicial para revisión del consultorio
      'motivo': (motivo != null && motivo.trim().isNotEmpty)
          ? motivo.trim()
          : 'Consulta Médica General',
      'trato_especial': tratoEspecial,
      'created_at': nowIso,
    };

    debugPrint('AppointmentSyncService: Iniciando solicitud de cita $citaId...');

    // Asegurar que el paciente existe en la tabla pacientes (para satisfacer citas_id_paciente_fkey)
    try {
      final centralClient = DualDatabaseConfig.instance.patientClient;
      final usrData = await centralClient
          .from('usuarios')
          .select('nombre, telefono, cedula, email')
          .eq('id', idPaciente)
          .maybeSingle();

      await centralClient.from('pacientes').upsert({
        'id': idPaciente,
        'id_usuario': idPaciente,
        if (usrData?['nombre'] != null) 'nombre': usrData!['nombre'],
        if (usrData?['telefono'] != null) 'telefono': usrData!['telefono'],
        if (usrData?['cedula'] != null) 'cedula': usrData!['cedula'],
        if (usrData?['email'] != null) 'email': usrData!['email'],
        'created_at': nowIso,
      });
      debugPrint('AppointmentSyncService: Registro de paciente asegurado en tabla pacientes con nombre.');
    } catch (e) {
      debugPrint('Nota asegurando paciente en Base Central: $e');
    }

    // 1. Guardar en Base de Datos Central (Garantiza bloqueo inmediato del horario)
    try {
      final centralClient = DualDatabaseConfig.instance.patientClient;
      final citasColision = await centralClient
          .from('citas')
          .select('id')
          .eq('id_doctor', idDoctor)
          .eq('fecha_hora', fechaHoraIso)
          .neq('estado', 'cancelada')
          .limit(1);
      if (citasColision.isNotEmpty) {
        throw Exception(
          'El horario seleccionado ya no se encuentra disponible. Por favor elige otro horario libre.',
        );
      }
      try {
        await centralClient.from('citas').insert(payload);
        debugPrint('AppointmentSyncService: Registrada en Base Central con estado por_confirmar.');
      } catch (insertErr) {
        if (insertErr.toString().contains('citas_id_paciente_fkey') || insertErr.toString().contains('23503')) {
          debugPrint('FK citas_id_paciente_fkey detectada, creando paciente de respaldo...');
          try {
            await centralClient.from('pacientes').upsert({'id': idPaciente});
            await centralClient.from('citas').insert(payload);
            debugPrint('AppointmentSyncService: Cita registrada tras auto-crear paciente.');
          } catch (_) {
            rethrow;
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error crítico insertando cita en Base Central: $e');
      if (e.toString().contains('ya no se encuentra disponible')) {
        rethrow;
      }
      throw Exception('No se pudo apartar el horario en la plataforma central: $e');
    }

    // 2. Conectar y replicar en la Base de Datos Privada del Doctor
    bool sincronizadoEnDoctor = false;
    try {
      final tenantData = await DualDatabaseConfig.instance
          .consultarYConectarTenantDoctor(idDoctor);

      if (tenantData != null) {
        final doctorClient = DualDatabaseConfig.instance.doctorClient;
        await doctorClient.from('citas').insert(payload);
        sincronizadoEnDoctor = true;
        debugPrint('AppointmentSyncService: Replicada exitosamente en Base Privada del Doctor.');
      } else {
        debugPrint('Nota: Doctor sin tenant dedicado; se mantendrá en Base Central compartida.');
        sincronizadoEnDoctor = true;
      }
    } catch (e) {
      debugPrint('Nota de sincronización: Base del doctor pendiente de réplica ($e).');
      // La cita queda en Central y el dashboard del médico la sincronizará al abrir sesión.
    }

    return {
      'id': citaId,
      'estado': 'por_confirmar',
      'fecha_hora': fechaHora,
      'sincronizado_doctor': sincronizadoEnDoctor,
    };
  }

  /// Registra una cita presencial o telefónica creada directamente en el consultorio:
  /// 1. Inserta en la Base de Datos del Doctor como 'confirmada'.
  /// 2. Inserta el bloqueo en la Base Central para que el horario quede no disponible públicamente.
  Future<bool> bloquearHorarioDesdeClinica({
    required String idDoctor,
    required String idSede,
    required DateTime fechaHora,
    int duracionMinutos = 30,
    String? idPaciente,
    String? motivo,
    int? turnoNumero,
  }) async {
    final citaId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final fechaHoraIso = fechaHora.toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'id': citaId,
      'id_doctor': idDoctor,
      if (idPaciente != null) 'id_paciente': idPaciente,
      'id_sede': idSede,
      'fecha_hora': fechaHoraIso,
      'fecha_hora_estimada_actual': fechaHoraIso,
      'duracion_minutos': duracionMinutos,
      'modalidad_atencion': 'hora_fija',
      'estado': 'confirmada',
      'motivo': motivo ?? 'Cita agendada por consultorio',
      if (turnoNumero != null) 'turno_numero': turnoNumero,
      'created_at': nowIso,
    };

    if (idPaciente != null && idPaciente.isNotEmpty) {
      try {
        final client = DualDatabaseConfig.instance.patientClient;
        final pac = await client.from('pacientes').select('id').eq('id', idPaciente).maybeSingle();
        if (pac == null) {
          await client.from('pacientes').upsert({'id': idPaciente, 'created_at': nowIso});
        }
      } catch (_) {}
    }

    try {
      // 1. Guardar en Base de Datos de la Clínica
      final doctorClient = DualDatabaseConfig.instance.doctorClient;
      await doctorClient.from('citas').insert(payload);

      // 2. Bloquear horario en Base Central (para que ningún paciente lo elija)
      try {
        final centralClient = DualDatabaseConfig.instance.patientClient;
        await centralClient.from('citas').upsert(payload);
      } catch (e) {
        debugPrint('Nota sincronizando bloqueo en Base Central: $e');
      }

      return true;
    } catch (e) {
      debugPrint('Error en bloquearHorarioDesdeClinica: $e');
      return false;
    }
  }

  /// Confirma, rechaza o cancela una cita, actualizando el estado en ambas bases
  Future<bool> actualizarEstadoCita({
    required String idCita,
    required String idDoctor,
    required String nuevoEstado, // 'confirmada' | 'rechazada' | 'cancelada'
    String? notasMedicas,
  }) async {
    final updateData = <String, dynamic>{
      'estado': nuevoEstado,
      if (notasMedicas != null) 'notas_medicas': notasMedicas,
    };

    bool exitoCentral = false;
    bool exitoDoctor = false;

    // 1. Actualizar en Base Central
    try {
      final centralClient = DualDatabaseConfig.instance.patientClient;
      await centralClient.from('citas').update(updateData).eq('id', idCita);
      exitoCentral = true;
    } catch (e) {
      debugPrint('Error actualizando estado en Base Central: $e');
    }

    // 2. Actualizar en Base del Doctor
    try {
      await DualDatabaseConfig.instance.consultarYConectarTenantDoctor(idDoctor);
      final doctorClient = DualDatabaseConfig.instance.doctorClient;
      await doctorClient.from('citas').update(updateData).eq('id', idCita);
      exitoDoctor = true;
    } catch (e) {
      debugPrint('Error actualizando estado en Base del Doctor: $e');
    }

    return exitoCentral || exitoDoctor;
  }

  /// Consulta las citas del doctor en la Base Central para calcular disponibilidad
  Future<List<Map<String, dynamic>>> obtenerCitasDoctorParaRango({
    required String idDoctor,
    required DateTime fechaDesde,
    required DateTime fechaHasta,
  }) async {
    try {
      final centralClient = DualDatabaseConfig.instance.patientClient;
      final List<dynamic> rows = await centralClient
          .from('citas')
          .select('id, fecha_hora, duracion_minutos, estado, modalidad_atencion')
          .eq('id_doctor', idDoctor)
          .gte('fecha_hora', fechaDesde.toUtc().toIso8601String())
          .lte('fecha_hora', fechaHasta.toUtc().toIso8601String())
          .neq('estado', 'cancelada');

      return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      debugPrint('Error consultando citas en Base Central: $e');
      return [];
    }
  }

  /// Calcula los cupos disponibles de un día para la modalidad "Orden de Llegada".
  /// No promete ni calcula turno estimado previo a la llegada física.
  DayQuotaInfo calcularCuposDia({
    required DateTime fecha,
    required int limitePacientesDia,
    required List<Map<String, dynamic>> citasExistentes,
  }) {
    final inicioDia = DateTime(fecha.year, fecha.month, fecha.day, 0, 0, 0);
    final finDia = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);

    final citasDelDia = citasExistentes.where((c) {
      final fechaCita = DateTime.tryParse(c['fecha_hora']?.toString() ?? '')?.toLocal();
      if (fechaCita == null) return false;
      return fechaCita.isAfter(inicioDia.subtract(const Duration(seconds: 1))) &&
          fechaCita.isBefore(finDia.add(const Duration(seconds: 1)));
    }).length;

    final cuposLibres = (limitePacientesDia - citasDelDia).clamp(0, limitePacientesDia);

    return DayQuotaInfo(
      fecha: fecha,
      limiteTotal: limitePacientesDia,
      citasAgendadas: citasDelDia,
      cuposDisponibles: cuposLibres,
      estaAgotado: cuposLibres <= 0,
    );
  }

  /// Calcula los bloques horarios disponibles considerando duraciones variables
  /// (ej. 45 o 60 min) y evitando cualquier solapamiento de intervalos.
  List<TimeSlotInfo> calcularBloquesHorarios({
    required DateTime fecha,
    required String horaInicioStr, // Ej: "08:00"
    required String horaFinStr,    // Ej: "13:00"
    required int duracionBaseMinutos,
    required List<Map<String, dynamic>> citasExistentes,
  }) {
    final slots = <TimeSlotInfo>[];

    final partesInicio = horaInicioStr.split(':');
    final partesFin = horaFinStr.split(':');

    final horaInicio = int.tryParse(partesInicio[0]) ?? 8;
    final minInicio = partesInicio.length > 1 ? (int.tryParse(partesInicio[1]) ?? 0) : 0;
    final horaFin = int.tryParse(partesFin[0]) ?? 13;
    final minFin = partesFin.length > 1 ? (int.tryParse(partesFin[1]) ?? 0) : 0;

    var cursor = DateTime(fecha.year, fecha.month, fecha.day, horaInicio, minInicio);
    final limiteHora = DateTime(fecha.year, fecha.month, fecha.day, horaFin, minFin);

    // Mapear intervalos ocupados por citas existentes [inicio, fin]
    final rangosOcupados = <_TimeRange>[];
    for (final c in citasExistentes) {
      final citaInicio = DateTime.tryParse(c['fecha_hora']?.toString() ?? '')?.toLocal();
      if (citaInicio == null) continue;
      final duracion = (c['duracion_minutos'] as int?) ?? duracionBaseMinutos;
      final citaFin = citaInicio.add(Duration(minutes: duracion));
      rangosOcupados.add(_TimeRange(citaInicio, citaFin));
    }

    while (cursor.add(Duration(minutes: duracionBaseMinutos)).isBefore(limiteHora.add(const Duration(minutes: 1)))) {
      final slotInicio = cursor;
      final slotFin = cursor.add(Duration(minutes: duracionBaseMinutos));

      // Comprobación de solapamiento estricto de intervalos:
      // Un bloque choca si slotInicio < citaFin Y slotFin > citaInicio
      final solapa = rangosOcupados.any(
        (r) => slotInicio.isBefore(r.fin) && slotFin.isAfter(r.inicio),
      );

      final horaTexto =
          '${cursor.hour.toString().padLeft(2, '0')}:${cursor.minute.toString().padLeft(2, '0')}';

      slots.add(
        TimeSlotInfo(
          horaTexto: horaTexto,
          fechaHoraCompleta: slotInicio,
          estaOcupado: solapa,
          duracionMinutos: duracionBaseMinutos,
          motivoBloqueo: solapa ? 'Horario reservado' : null,
        ),
      );

      cursor = cursor.add(Duration(minutes: duracionBaseMinutos));
    }

    return slots;
  }
}

class _TimeRange {
  final DateTime inicio;
  final DateTime fin;
  const _TimeRange(this.inicio, this.fin);
}

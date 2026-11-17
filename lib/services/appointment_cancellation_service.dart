import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../backend/supabase/supabase.dart';

/// Servicio especializado en la cancelación y reprogramación de citas médicas.
/// Maneja operaciones individuales y masivas por día para doctores, secretarias
/// y pacientes, asegurando la liberación inmediata de horarios y la notificación
/// correspondiente a cada parte interesada.
class AppointmentCancellationService {
  AppointmentCancellationService._internal();

  /// Instancia única (Singleton) del servicio.
  static final AppointmentCancellationService instance =
      AppointmentCancellationService._internal();

  final _uuid = const Uuid();

  /// Cancela una cita individual, actualiza su estado en ambas bases de datos
  /// (liberando el horario para futuras reservas) y notifica al paciente o doctor.
  Future<bool> cancelarCitaIndividual({
    required String idCita,
    required String motivo,
    required bool canceladoPorDoctor,
    String? idDoctor,
    String? idPaciente,
  }) async {
    final motivoFinal = motivo.trim().isNotEmpty
        ? motivo.trim()
        : (canceladoPorDoctor
            ? 'Cancelación por motivos de agenda del consultorio'
            : 'Cancelación solicitada por el paciente');

    try {
      final updateData = <String, dynamic>{
        'estado': 'cancelada',
        'motivo_cancelacion': motivoFinal,
        'fecha_hora_estimada_actual': null,
      };

      // 1. Actualizar en Base Central
      final centralClient = DualDatabaseConfig.instance.patientClient;
      await centralClient.from('citas').update(updateData).eq('id', idCita);

      // 2. Replicar en Base del Doctor si existe tenant
      if (idDoctor != null && idDoctor.isNotEmpty) {
        try {
          await DualDatabaseConfig.instance.consultarYConectarTenantDoctor(idDoctor);
          final doctorClient = DualDatabaseConfig.instance.doctorClient;
          await doctorClient.from('citas').update(updateData).eq('id', idCita);
        } catch (e) {
          debugPrint('Nota replicando cancelación en Base Doctor: $e');
        }
      }

      // 3. Notificar a la contraparte
      if (canceladoPorDoctor) {
        await _notificarPaciente(
          idPaciente: idPaciente,
          idCita: idCita,
          tipo: 'cancelacion_doctor',
          titulo: '❌ Cita Médica Cancelada por el Consultorio',
          mensaje: 'Tu cita médica ha sido cancelada por el consultorio. Motivo: $motivoFinal.',
        );
      } else if (idDoctor != null && idDoctor.isNotEmpty) {
        await _notificarDoctor(
          idDoctor: idDoctor,
          idCita: idCita,
          tipo: 'cancelacion_paciente',
          titulo: '📢 Paciente Canceló su Cita',
          mensaje: 'El paciente canceló su cita agendada. Motivo: $motivoFinal. El horario ha quedado disponible.',
        );
      }

      return true;
    } catch (e) {
      debugPrint('[AppointmentCancellationService] Error cancelando cita $idCita: $e');
      return false;
    }
  }

  /// Reprograma una cita individual a una nueva fecha y hora.
  /// Valida que el nuevo horario no colisione con otra cita activa del doctor.
  Future<bool> reprogramarCitaIndividual({
    required String idCita,
    required DateTime nuevaFechaHora,
    required String motivo,
    required bool reprogramadoPorDoctor,
    required String idDoctor,
    String? idPaciente,
    int duracionMinutos = 30,
  }) async {
    final nuevaFechaIso = nuevaFechaHora.toUtc().toIso8601String();
    final centralClient = DualDatabaseConfig.instance.patientClient;

    // Verificar si el nuevo bloque está libre (excluyendo la misma cita)
    final colision = await centralClient
        .from('citas')
        .select('id')
        .eq('id_doctor', idDoctor)
        .eq('fecha_hora', nuevaFechaIso)
        .neq('id', idCita)
        .neq('estado', 'cancelada')
        .limit(1);

    if (colision.isNotEmpty) {
      throw Exception(
        'El horario seleccionado ya está reservado por otra cita activa. Por favor elige otro horario.',
      );
    }

    final motivoFinal = motivo.trim().isNotEmpty
        ? motivo.trim()
        : (reprogramadoPorDoctor
            ? 'Ajuste de fecha u hora por el consultorio'
            : 'Reprogramación solicitada por el paciente');

    try {
      final nuevoEstado = reprogramadoPorDoctor ? 'confirmada' : 'por_confirmar';
      final updateData = <String, dynamic>{
        'fecha_hora': nuevaFechaIso,
        'fecha_hora_estimada_actual': nuevaFechaIso,
        'estado': nuevoEstado,
        'motivo_reprogramacion': motivoFinal,
        'minutos_retraso_acumulados': 0,
        'duracion_minutos': duracionMinutos,
      };

      // 1. Actualizar en Base Central
      await centralClient.from('citas').update(updateData).eq('id', idCita);

      // 2. Replicar en Base del Doctor
      try {
        await DualDatabaseConfig.instance.consultarYConectarTenantDoctor(idDoctor);
        final docClient = DualDatabaseConfig.instance.doctorClient;
        await docClient.from('citas').update(updateData).eq('id', idCita);
      } catch (e) {
        debugPrint('Nota replicando reprogramación en Base Doctor: $e');
      }

      // 3. Notificar
      final horaFormato = DateFormat('hh:mm a').format(nuevaFechaHora);
      final fechaFormato = DateFormat('dd/MM/yyyy').format(nuevaFechaHora);

      if (reprogramadoPorDoctor) {
        await _notificarPaciente(
          idPaciente: idPaciente,
          idCita: idCita,
          tipo: 'reprogramacion_doctor',
          titulo: '📅 Tu Cita Médica ha sido Reprogramada',
          mensaje: 'Tu cita ha sido reubicada para el $fechaFormato a las $horaFormato. Motivo: $motivoFinal.',
        );
      } else {
        await _notificarDoctor(
          idDoctor: idDoctor,
          idCita: idCita,
          tipo: 'reprogramacion_paciente',
          titulo: '🔄 Solicitud de Cambio de Horario',
          mensaje: 'El paciente solicitó cambiar su cita al $fechaFormato a las $horaFormato. Motivo: $motivoFinal.',
        );
      }

      return true;
    } catch (e) {
      debugPrint('[AppointmentCancellationService] Error reprogramando cita: $e');
      rethrow;
    }
  }

  /// Cancela de forma masiva todas las citas activas de un doctor para un día completo
  /// y notifica a cada uno de los pacientes con el motivo proporcionado.
  Future<int> cancelarCitasDelDia({
    required String idDoctor,
    required DateTime fecha,
    required String motivo,
  }) async {
    final centralClient = DualDatabaseConfig.instance.patientClient;
    final inicioDia = DateTime(fecha.year, fecha.month, fecha.day, 0, 0, 0).toUtc().toIso8601String();
    final finDia = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59).toUtc().toIso8601String();

    final motivoFinal = motivo.trim().isNotEmpty
        ? motivo.trim()
        : 'Cierre de agenda por imprevistos médicos o personales del doctor.';

    // Consultar citas no canceladas ni atendidas del día
    final List<dynamic> citas = await centralClient
        .from('citas')
        .select('id, id_paciente, fecha_hora')
        .eq('id_doctor', idDoctor)
        .gte('fecha_hora', inicioDia)
        .lte('fecha_hora', finDia)
        .neq('estado', 'cancelada')
        .neq('estado', 'atendida');

    int canceladas = 0;
    for (final c in citas) {
      final cMap = Map<String, dynamic>.from(c as Map);
      final idCita = cMap['id']?.toString() ?? '';
      final idPac = cMap['id_paciente']?.toString();
      if (idCita.isEmpty) continue;

      final ok = await cancelarCitaIndividual(
        idCita: idCita,
        motivo: motivoFinal,
        canceladoPorDoctor: true,
        idDoctor: idDoctor,
        idPaciente: idPac,
      );
      if (ok) canceladas++;
    }

    return canceladas;
  }

  /// Mueve / reprograma de forma masiva todas las citas de una fecha origen hacia una fecha destino,
  /// conservando la misma hora del día de cada cita y notificando a los pacientes.
  Future<int> reprogramarCitasDelDia({
    required String idDoctor,
    required DateTime fechaOrigen,
    required DateTime fechaDestino,
    required String motivo,
  }) async {
    final centralClient = DualDatabaseConfig.instance.patientClient;
    final inicioDia = DateTime(fechaOrigen.year, fechaOrigen.month, fechaOrigen.day, 0, 0, 0).toUtc().toIso8601String();
    final finDia = DateTime(fechaOrigen.year, fechaOrigen.month, fechaOrigen.day, 23, 59, 59).toUtc().toIso8601String();

    final List<dynamic> citas = await centralClient
        .from('citas')
        .select('id, id_paciente, fecha_hora, duracion_minutos')
        .eq('id_doctor', idDoctor)
        .gte('fecha_hora', inicioDia)
        .lte('fecha_hora', finDia)
        .neq('estado', 'cancelada')
        .neq('estado', 'atendida');

    int reprogramadas = 0;
    for (final c in citas) {
      final cMap = Map<String, dynamic>.from(c as Map);
      final idCita = cMap['id']?.toString() ?? '';
      final idPac = cMap['id_paciente']?.toString();
      final fechaHoraOrig = DateTime.tryParse(cMap['fecha_hora']?.toString() ?? '')?.toLocal();
      final duracion = (cMap['duracion_minutos'] as int?) ?? 30;

      if (idCita.isEmpty || fechaHoraOrig == null) continue;

      final nuevaFechaHora = DateTime(
        fechaDestino.year,
        fechaDestino.month,
        fechaDestino.day,
        fechaHoraOrig.hour,
        fechaHoraOrig.minute,
      );

      try {
        await reprogramarCitaIndividual(
          idCita: idCita,
          nuevaFechaHora: nuevaFechaHora,
          motivo: motivo,
          reprogramadoPorDoctor: true,
          idDoctor: idDoctor,
          idPaciente: idPac,
          duracionMinutos: duracion,
        );
        reprogramadas++;
      } catch (err) {
        debugPrint('Nota: No se pudo reprogramar cita masiva $idCita: $err');
      }
    }

    return reprogramadas;
  }

  /// Inserta una notificación en `notificaciones_citas` resolviendo el `id_usuario`
  /// del paciente (sea que idPaciente coincida con auth.users o esté en la tabla pacientes).
  Future<void> _notificarPaciente({
    required String? idPaciente,
    required String idCita,
    required String tipo,
    required String titulo,
    required String mensaje,
  }) async {
    if (idPaciente == null || idPaciente.isEmpty) return;
    try {
      final centralClient = DualDatabaseConfig.instance.patientClient;
      String idUsuarioFinal = idPaciente;

      // Buscar si idPaciente tiene una referencia a usuarios.id
      final pacRow = await centralClient
          .from('pacientes')
          .select('id_usuario')
          .eq('id', idPaciente)
          .maybeSingle();

      if (pacRow != null && pacRow['id_usuario'] != null) {
        idUsuarioFinal = pacRow['id_usuario'].toString();
      }

      await centralClient.from('notificaciones_citas').insert({
        'id': _uuid.v4(),
        'id_usuario': idUsuarioFinal,
        'id_cita': idCita,
        'tipo': tipo,
        'titulo': titulo,
        'mensaje': mensaje,
        'leido': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[AppointmentCancellationService] Error enviando notificación a paciente: $e');
    }
  }

  /// Inserta una notificación en `notificaciones_citas` dirigida al doctor.
  Future<void> _notificarDoctor({
    required String idDoctor,
    required String idCita,
    required String tipo,
    required String titulo,
    required String mensaje,
  }) async {
    try {
      final centralClient = DualDatabaseConfig.instance.patientClient;
      await centralClient.from('notificaciones_citas').insert({
        'id': _uuid.v4(),
        'id_usuario': idDoctor,
        'id_cita': idCita,
        'tipo': tipo,
        'titulo': titulo,
        'mensaje': mensaje,
        'leido': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[AppointmentCancellationService] Error notificando a doctor: $e');
    }
  }
}

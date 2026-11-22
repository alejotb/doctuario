import 'package:url_launcher/url_launcher.dart';
import '../backend/supabase/supabase.dart';

class EmergencyAppointmentService {
  static final EmergencyAppointmentService _instance =
      EmergencyAppointmentService._internal();
  factory EmergencyAppointmentService() => _instance;
  EmergencyAppointmentService._internal();

  /// Inserta un paciente de emergencia en el horario actual o próximo disponible,
  /// desplaza las citas posteriores y genera las notificaciones correspondientes.
  Future<CitasRow> insertarPacienteEmergencia({
    required String idDoctor,
    required String idPaciente,
    required String idSede,
    required String motivo,
    int duracionEmergenciaMinutos = 30,
  }) async {
    final ahora = DateTime.now();

    final baseData = <String, dynamic>{
      'id_doctor': idDoctor,
      'id_paciente': idPaciente,
      'id_sede': idSede,
      'fecha_hora': ahora.toUtc().toIso8601String(),
      'fecha_hora_estimada_actual': ahora.toUtc().toIso8601String(),
      'estado': 'en_consulta',
      'motivo': '[EMERGENCIA] $motivo',
      'es_emergencia': true,
      'trato_especial': false,
      'minutos_retraso_acumulados': 0,
      'modalidad_atencion': 'orden_llegada',
    };
    try {
      await DualDatabaseConfig.instance.doctorClient.from('pacientes').insert({
        'id': idPaciente,
        'id_doctor': idDoctor,
      });
    } catch (_) {}

    CitasRow nuevaCitaEmergencia;
    try {
      nuevaCitaEmergencia = await CitasTable().insert({
        ...baseData,
        'duracion_minutos': duracionEmergenciaMinutos,
      });
    } catch (e) {
      if (e.toString().contains('duracion_minutos')) {
        nuevaCitaEmergencia = await CitasTable().insert(baseData);
      } else if (e.toString().contains('citas_id_paciente_fkey')) {
        try {
          await DualDatabaseConfig.instance.doctorClient.from('pacientes').insert({
            'id': idPaciente,
            'id_doctor': idDoctor,
          });
          nuevaCitaEmergencia = await CitasTable().insert(baseData);
        } catch (_) {
          rethrow;
        }
      } else {
        rethrow;
      }
    }

    // 2. Buscar todas las citas del día posteriores a este momento para el mismo doctor
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day, 0, 0, 0);
    final finHoy = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);

    final citasPosteriores = await CitasTable().queryRows(
      queryFn: (q) => q
          .eq('id_doctor', idDoctor)
          .gte('fecha_hora', inicioHoy.toIso8601String())
          .lte('fecha_hora', finHoy.toIso8601String())
          .neq('id', nuevaCitaEmergencia.id)
          .inFilter('estado', ['solicitada', 'confirmada', 'en_espera']),
    );

    // 3. Desplazar las citas posteriores y crear notificaciones
    for (final cita in citasPosteriores) {
      final fechaOriginal =
          cita.fechaHoraEstimadaActual ?? cita.fechaHora ?? ahora;
      final nuevaFechaEstimada =
          fechaOriginal.add(Duration(minutes: duracionEmergenciaMinutos));
      final retrasoTotal = (cita.minutosRetrasoAcumulados ?? 0) +
          duracionEmergenciaMinutos;

      await CitasTable().update(
        data: {
          'fecha_hora_estimada_actual': nuevaFechaEstimada.toIso8601String(),
          'minutos_retraso_acumulados': retrasoTotal,
        },
        matchingRows: (q) => q.eq('id', cita.id),
      );

      // Generar notificación interna en base de datos
      if (cita.idPaciente != null) {
        final horaFormateada =
            '${nuevaFechaEstimada.hour.toString().padLeft(2, '0')}:${nuevaFechaEstimada.minute.toString().padLeft(2, '0')}';
        await NotificacionesCitasTable().insert({
          'id_usuario': cita.idPaciente!,
          'id_cita': cita.id,
          'tipo': 'retraso_emergencia',
          'titulo': '⚠️ Retraso por Atención de Emergencia',
          'mensaje':
              'El médico ha ingresado una atención de emergencia. Su consulta ha sido corrida $duracionEmergenciaMinutos min. Nueva hora estimada: $horaFormateada.',
          'minutos_retraso': retrasoTotal,
          'leido': false,
        });
      }
    }

    return nuevaCitaEmergencia;
  }

  /// Registra un retraso general del doctor (ej. llegada tarde, salida temporal o tráfico)
  /// y desplaza todas las citas pendientes del día notificando a los pacientes.
  Future<int> notificarRetrasoGeneralDoctor({
    required String idDoctor,
    required int minutosRetraso,
    String motivo = 'Retraso de itinerario / Llegada tardía del médico',
  }) async {
    final ahora = DateTime.now();
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day, 0, 0, 0);
    final finHoy = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);

    final citasDelDia = await CitasTable().queryRows(
      queryFn: (q) => q
          .eq('id_doctor', idDoctor)
          .gte('fecha_hora', inicioHoy.toIso8601String())
          .lte('fecha_hora', finHoy.toIso8601String())
          .inFilter('estado', ['solicitada', 'confirmada', 'en_espera']),
    );

    for (final cita in citasDelDia) {
      final fechaOriginal =
          cita.fechaHoraEstimadaActual ?? cita.fechaHora ?? ahora;
      final nuevaFechaEstimada =
          fechaOriginal.add(Duration(minutes: minutosRetraso));
      final retrasoTotal =
          (cita.minutosRetrasoAcumulados ?? 0) + minutosRetraso;

      await CitasTable().update(
        data: {
          'fecha_hora_estimada_actual': nuevaFechaEstimada.toIso8601String(),
          'minutos_retraso_acumulados': retrasoTotal,
        },
        matchingRows: (q) => q.eq('id', cita.id),
      );

      if (cita.idPaciente != null) {
        final horaFormateada =
            '${nuevaFechaEstimada.hour.toString().padLeft(2, '0')}:${nuevaFechaEstimada.minute.toString().padLeft(2, '0')}';
        await NotificacionesCitasTable().insert({
          'id_usuario': cita.idPaciente!,
          'id_cita': cita.id,
          'tipo': 'retraso_doctor',
          'titulo': '📢 Aviso de Retraso del Médico',
          'mensaje':
              'El Dr(a). presenta un retraso estimado de $minutosRetraso minutos ($motivo). Su nueva hora estimada de atención es: $horaFormateada.',
          'minutos_retraso': retrasoTotal,
          'leido': false,
        });
      }
    }

    return citasDelDia.length;
  }

  /// Aplica el recálculo en cascada para citas posteriores del día cuando se agrega un procedimiento
  Future<int> aplicarRetrasoPorProcedimiento({
    required String idDoctor,
    required String idCitaActual,
    required int minutosExtra,
    required List<String> nombresProcedimientos,
  }) async {
    final ahora = DateTime.now();
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day, 0, 0, 0);
    final finHoy = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);

    // 1. Obtener la cita actual para extender su duración
    final citasActuales = await CitasTable().queryRows(
      queryFn: (q) => q.eq('id', idCitaActual).limit(1),
    );
    if (citasActuales.isNotEmpty) {
      final actual = citasActuales.first;
      final nuevaDuracion = (actual.duracionMinutos ?? 30) + minutosExtra;
      await CitasTable().update(
        data: {'duracion_minutos': nuevaDuracion},
        matchingRows: (q) => q.eq('id', idCitaActual),
      );
      try {
        final clientCentral = DualDatabaseConfig.instance.patientClient;
        await clientCentral.from('citas').update({'duracion_minutos': nuevaDuracion}).eq('id', idCitaActual);
      } catch (_) {}
    }

    // 2. Buscar todas las citas del día posteriores
    final citasPosteriores = await CitasTable().queryRows(
      queryFn: (q) => q
          .eq('id_doctor', idDoctor)
          .gte('fecha_hora', inicioHoy.toIso8601String())
          .lte('fecha_hora', finHoy.toIso8601String())
          .neq('id', idCitaActual)
          .inFilter('estado', ['solicitada', 'confirmada', 'en_espera']),
    );

    final listaProcedimientosStr = nombresProcedimientos.join(', ');

    for (final cita in citasPosteriores) {
      final fechaOriginal = cita.fechaHoraEstimadaActual ?? cita.fechaHora ?? ahora;
      final nuevaFechaEstimada = fechaOriginal.add(Duration(minutes: minutosExtra));
      final retrasoTotal = (cita.minutosRetrasoAcumulados ?? 0) + minutosExtra;

      // Actualizar en BD local del doctor
      await CitasTable().update(
        data: {
          'fecha_hora_estimada_actual': nuevaFechaEstimada.toIso8601String(),
          'minutos_retraso_acumulados': retrasoTotal,
        },
        matchingRows: (q) => q.eq('id', cita.id),
      );

      // Replicar a base central
      try {
        final clientCentral = DualDatabaseConfig.instance.patientClient;
        await clientCentral.from('citas').update({
          'fecha_hora': nuevaFechaEstimada.toUtc().toIso8601String(),
        }).eq('id', cita.id);
      } catch (_) {}

      // Generar notificación para el paciente
      if (cita.idPaciente != null) {
        final horaFormateada =
            '${nuevaFechaEstimada.hour.toString().padLeft(2, '0')}:${nuevaFechaEstimada.minute.toString().padLeft(2, '0')}';
        await NotificacionesCitasTable().insert({
          'id_usuario': cita.idPaciente!,
          'id_cita': cita.id,
          'tipo': 'retraso_procedimiento',
          'titulo': '⏱️ Ajuste de Horario por Procedimiento Médico',
          'mensaje':
              'El médico está realizando un procedimiento ($listaProcedimientosStr). Su hora estimada se ha corrido $minutosExtra min. Nueva hora estimada: $horaFormateada.',
          'minutos_retraso': retrasoTotal,
          'leido': false,
        });
      }
    }

    return citasPosteriores.length;
  }

  /// Construye el enlace para enviar aviso directo por WhatsApp al paciente
  String generarUrlWhatsAppAviso({
    required String telefonoPaciente,
    required String nombrePaciente,
    required String nombreDoctor,
    required String nombreSede,
    required DateTime nuevaHoraEstimada,
    required int minutosRetraso,
    String? motivoPersonalizado,
  }) {
    final hora =
        '${nuevaHoraEstimada.hour.toString().padLeft(2, '0')}:${nuevaHoraEstimada.minute.toString().padLeft(2, '0')}';
    final motivoTexto = motivoPersonalizado ??
        'ha debido atender una emergencia médica / retraso de itinerario';
    final mensaje =
        'Hola $nombrePaciente, le informamos que el Dr. $nombreDoctor en $nombreSede $motivoTexto. Su cita se ha corrido $minutosRetraso minutos. Su nueva hora estimada de atención es a las $hora. Agradecemos su comprensión.';

    final telefonoLimpio =
        telefonoPaciente.replaceAll(RegExp(r'[^0-9]'), '');
    return 'https://wa.me/$telefonoLimpio?text=${Uri.encodeComponent(mensaje)}';
  }

  /// Abre WhatsApp con el mensaje prellenado
  Future<void> abrirWhatsAppAviso({
    required String telefonoPaciente,
    required String nombrePaciente,
    required String nombreDoctor,
    required String nombreSede,
    required DateTime nuevaHoraEstimada,
    required int minutosRetraso,
    String? motivoPersonalizado,
  }) async {
    final urlString = generarUrlWhatsAppAviso(
      telefonoPaciente: telefonoPaciente,
      nombrePaciente: nombrePaciente,
      nombreDoctor: nombreDoctor,
      nombreSede: nombreSede,
      nuevaHoraEstimada: nuevaHoraEstimada,
      minutosRetraso: minutosRetraso,
      motivoPersonalizado: motivoPersonalizado,
    );

    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

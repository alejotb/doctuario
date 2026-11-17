import 'package:flutter/material.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/emergency_appointment_service.dart';
import '/services/appointment_sync_service.dart';

/// Servicio de acciones de gestión clínica para citas de la agenda del doctor.
/// Coordina la actualización del estado local del consultorio y la sincronización
/// bilateral con la base de datos central de ProntuDoc / MediConnect.
class AgendaAppointmentActions {
  AgendaAppointmentActions._();

  /// Extiende la duración de una cita en minutos y notifica retrasos acumulados
  /// a los pacientes subsiguientes en la fila de espera.
  static Future<bool> extenderDuracion({
    required BuildContext context,
    required String idDoctor,
    required CitasRow cita,
    required int minutosExtra,
  }) async {
    final duracionActual = cita.duracionMinutos ?? 30;
    final nuevaDuracion = (duracionActual + minutosExtra).clamp(10, 180);

    try {
      await CitasTable().update(
        data: {'duracion_minutos': nuevaDuracion},
        matchingRows: (q) => q.eq('id', cita.id),
      );

      // Notificar automáticamente a pacientes posteriores si hubo retraso
      if (minutosExtra > 0) {
        await EmergencyAppointmentService().notificarRetrasoGeneralDoctor(
          idDoctor: idDoctor,
          minutosRetraso: minutosExtra,
          motivo: 'Extensión de tiempo en consulta médica previa',
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⏱️ Duración ajustada a $nuevaDuracion min.${minutosExtra > 0 ? " Próximos horarios recalculados." : ""}',
            ),
            backgroundColor: FlutterFlowTheme.of(context).primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error actualizando duración de cita: $e');
      return false;
    }
  }

  /// Registra la llegada física del paciente a la sala de espera y sella la hora.
  static Future<bool> marcarLlegada({
    required BuildContext context,
    required CitasRow cita,
  }) async {
    final ahora = DateTime.now();
    try {
      await CitasTable().update(
        data: {
          'llegada_confirmada': true,
          'hora_llegada': ahora.toIso8601String(),
          'estado': 'en_espera',
        },
        matchingRows: (q) => q.eq('id', cita.id),
      );

      // Sincronizar estado en BD Central si aplica
      if (cita.idDoctor != null) {
        await AppointmentSyncService.instance.actualizarEstadoCita(
          idCita: cita.id,
          idDoctor: cita.idDoctor!,
          nuevoEstado: 'en_espera',
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Paciente registrado en sala de espera.'),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error marcando llegada de paciente: $e');
      return false;
    }
  }

  /// Cambia el estado de una cita médica y asegura la sincronización
  /// tanto en la base de datos local del doctor como en la base central.
  static Future<bool> cambiarEstado({
    required BuildContext context,
    required CitasRow cita,
    required String nuevoEstado,
  }) async {
    try {
      final data = <String, dynamic>{'estado': nuevoEstado};
      if (nuevoEstado == 'en_espera' && (cita.llegadaConfirmada != true)) {
        data['llegada_confirmada'] = true;
        data['hora_llegada'] = DateTime.now().toIso8601String();
      }

      // 1. Actualizar base del doctor / clínica
      await CitasTable().update(
        data: data,
        matchingRows: (q) => q.eq('id', cita.id),
      );

      // 2. Replicar cambio a la base de datos central
      if (cita.idDoctor != null) {
        await AppointmentSyncService.instance.actualizarEstadoCita(
          idCita: cita.id,
          idDoctor: cita.idDoctor!,
          nuevoEstado: nuevoEstado,
        );
      }

      if (context.mounted) {
        final label = _obtenerEtiquetaEstado(nuevoEstado);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estado de cita actualizado: $label.'),
            backgroundColor: _obtenerColorEstado(nuevoEstado),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error cambiando estado de cita: $e');
      return false;
    }
  }

  /// Confirmación rápida para citas solicitadas en línea por pacientes
  static Future<bool> confirmarCitaOnline({
    required BuildContext context,
    required CitasRow cita,
  }) async {
    return cambiarEstado(
      context: context,
      cita: cita,
      nuevoEstado: 'confirmada',
    );
  }

  /// Rechazo o cancelación de cita solicitada en línea
  static Future<bool> rechazarCitaOnline({
    required BuildContext context,
    required CitasRow cita,
  }) async {
    return cambiarEstado(
      context: context,
      cita: cita,
      nuevoEstado: 'cancelada',
    );
  }

  /// Obtiene la etiqueta amigable para mostrar en notificaciones y mensajes
  static String _obtenerEtiquetaEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'por_confirmar':
        return 'Por Confirmar';
      case 'confirmada':
        return 'Confirmada';
      case 'en_espera':
        return 'En Sala de Espera';
      case 'en_consulta':
        return 'En Consulta';
      case 'atendida':
      case 'completada':
        return 'Atendida / Completada';
      case 'cancelada':
        return 'Cancelada';
      default:
        return estado.toUpperCase();
    }
  }

  /// Retorna el color distintivo según el estado de la cita
  static Color _obtenerColorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'por_confirmar':
        return const Color(0xFFD97706);
      case 'confirmada':
        return const Color(0xFF059669);
      case 'en_espera':
        return const Color(0xFF0D9488);
      case 'en_consulta':
        return const Color(0xFF0284C7);
      case 'cancelada':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF475569);
    }
  }
}

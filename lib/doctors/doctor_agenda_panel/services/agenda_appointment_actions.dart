import 'package:flutter/material.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/appointment_cancellation_service.dart';
import '/services/emergency_appointment_service.dart';
import '/services/appointment_sync_service.dart';

/// Servicio de acciones de gestión clínica para citas de la agenda del doctor.
/// Coordina la actualización del estado local del consultorio y la sincronización
/// con la base de datos única de ProntuDoc / MediConnect.
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

  /// Solicita el motivo de cancelación al doctor/secretaria y cancela la cita notificando al paciente.
  static Future<bool> pedirMotivoYCancelar({
    required BuildContext context,
    required CitasRow cita,
  }) async {
    final motivoCtrl = TextEditingController();
    final String? motivoConfirmado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar Cita', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indica el motivo de la cancelación para notificar al paciente:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ej. Reajuste de horario o imprevisto médico',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(motivoCtrl.text.trim()),
            child: const Text('Confirmar Cancelación'),
          ),
        ],
      ),
    );
    motivoCtrl.dispose();

    if (motivoConfirmado == null) return false;

    final ok = await AppointmentCancellationService.instance.cancelarCitaIndividual(
      idCita: cita.id,
      motivo: motivoConfirmado,
      canceladoPorDoctor: true,
      idDoctor: cita.idDoctor,
      idPaciente: cita.idPaciente,
    );

    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Cita cancelada y paciente notificado.'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 2),
        ),
      );
    }
    return ok;
  }

  /// Cambia el estado de una cita médica y asegura la sincronización en la base única.
  static Future<bool> cambiarEstado({
    required BuildContext context,
    required CitasRow cita,
    required String nuevoEstado,
  }) async {
    if (nuevoEstado.toLowerCase() == 'cancelada') {
      return pedirMotivoYCancelar(context: context, cita: cita);
    }
    try {
      final data = <String, dynamic>{'estado': nuevoEstado};
      if (nuevoEstado == 'en_espera' && (cita.llegadaConfirmada != true)) {
        data['llegada_confirmada'] = true;
        data['hora_llegada'] = DateTime.now().toIso8601String();
      }

      await CitasTable().update(
        data: data,
        matchingRows: (q) => q.eq('id', cita.id),
      );

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

  /// Rechazo o cancelación de cita solicitada en línea con motivo
  static Future<bool> rechazarCitaOnline({
    required BuildContext context,
    required CitasRow cita,
  }) async {
    return pedirMotivoYCancelar(
      context: context,
      cita: cita,
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

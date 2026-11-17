import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/i18n_service.dart';

/// Tarjeta para renderizar una cita médica individual dentro de la cronología de la agenda.
/// Soporta estados: por_confirmar, en_espera, en_consulta, confirmada, atendida y cancelada.
class AgendaAppointmentItemCard extends StatelessWidget {
  final CitasRow cita;
  final UsuariosRow? paciente;
  final bool esSeleccionada;
  final VoidCallback onTap;
  final void Function(CitasRow cita, UsuariosRow? paciente) onEditarCita;
  final ValueChanged<CitasRow> onMarcarLlegada;
  final void Function(CitasRow cita, String nuevoEstado) onCambiarEstado;
  final void Function(CitasRow cita, UsuariosRow? paciente) onAbrirHistoria;
  final void Function(CitasRow cita, int minutosExtra) onExtenderDuracion;

  const AgendaAppointmentItemCard({
    super.key,
    required this.cita,
    required this.paciente,
    required this.esSeleccionada,
    required this.onTap,
    required this.onEditarCita,
    required this.onMarcarLlegada,
    required this.onCambiarEstado,
    required this.onAbrirHistoria,
    required this.onExtenderDuracion,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final hora = cita.fechaHoraEstimadaActual ?? cita.fechaHora;
    final horaStr = hora != null ? DateFormat('hh:mm a').format(hora) : '--:--';
    final duracion = cita.duracionMinutos ?? 30;
    final estado = (cita.estado ?? 'pendiente').toLowerCase();

    Color borderStatusColor = const Color(0xFFCBD5E1);
    Color statusBg = const Color(0xFFF1F5F9);
    Color statusTextColor = const Color(0xFF334155);
    String statusLabel = isEs ? 'Programada' : 'Scheduled';

    if (estado == 'por_confirmar' || estado == 'solicitada') {
      borderStatusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFFEF3C7);
      statusTextColor = const Color(0xFFB45309);
      statusLabel = isEs ? 'Por Confirmar' : 'Pending Approval';
    } else if (estado == 'en_consulta') {
      borderStatusColor = const Color(0xFF0284C7);
      statusBg = const Color(0xFFE0F2FE);
      statusTextColor = const Color(0xFF0369A1);
      statusLabel = isEs ? 'En Consulta' : 'In Consultation';
    } else if (estado == 'pendiente' || estado == 'en_sala' || estado == 'en_espera') {
      borderStatusColor = const Color(0xFF0D9488);
      statusBg = const Color(0xFFCCFBF1);
      statusTextColor = const Color(0xFF0F766E);
      statusLabel = isEs ? 'En Sala' : 'Waiting';
    } else if (estado == 'confirmada') {
      borderStatusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFFD1FAE5);
      statusTextColor = const Color(0xFF065F46);
      statusLabel = isEs ? 'Confirmada' : 'Confirmed';
    } else if (estado == 'atendida' || estado == 'completada') {
      borderStatusColor = Colors.grey.shade400;
      statusBg = Colors.grey.shade100;
      statusTextColor = Colors.grey.shade700;
      statusLabel = isEs ? 'Atendida' : 'Completed';
    } else if (estado == 'cancelada') {
      borderStatusColor = const Color(0xFFEF4444);
      statusBg = const Color(0xFFFEE2E2);
      statusTextColor = const Color(0xFF991B1B);
      statusLabel = isEs ? 'Cancelada' : 'Cancelled';
    }

    final esPorConfirmar = estado == 'por_confirmar' || estado == 'solicitada';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: esSeleccionada
              ? const Color(0xFFF0F9FF)
              : esPorConfirmar
                  ? const Color(0xFFFFFBEB)
                  : (estado == 'atendida' ? const Color(0xFFF8FAFC) : Colors.white),
          border: Border(left: BorderSide(color: borderStatusColor, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 65,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        horaStr,
                        style: GoogleFonts.mooli(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: estado == 'atendida' ? Colors.grey : const Color(0xFF0369A1),
                        ),
                      ),
                      Text('$duracion min', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              paciente?.nombre ?? (isEs ? 'Paciente Registrado' : 'Registered Patient'),
                              style: GoogleFonts.mooli(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                            child: Text(statusLabel, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusTextColor)),
                          ),
                          if ((cita.llegadaConfirmada ?? false) && estado != 'atendida' && estado != 'completada') ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF6EE7B7)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, size: 10, color: Color(0xFF059669)),
                                  const SizedBox(width: 3),
                                  Text(
                                    cita.horaLlegada != null
                                        ? '${isEs ? "En Sala" : "Arrived"} (${cita.horaLlegada!.hour.toString().padLeft(2, '0')}:${cita.horaLlegada!.minute.toString().padLeft(2, '0')})'
                                        : (isEs ? 'En Sala' : 'Arrived'),
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        cita.motivo ?? (isEs ? 'Consulta médica general' : 'General medical consultation'),
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          if (cita.esEmergencia == true)
                            Text(isEs ? '🚨 Urgencia' : '🚨 Emergency',
                                style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                          if (cita.esControl == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF93C5FD)),
                              ),
                              child: Text(
                                cita.cobrarControl == false
                                    ? (isEs ? '🔄 Control (Gratis)' : '🔄 Follow-up (Free)')
                                    : (isEs ? '🔄 Control' : '🔄 Follow-up'),
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                              ),
                            ),
                          if (cita.turnoNumero != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                '${isEs ? "Turno" : "Queue"} #${cita.turnoNumero}',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (val) {
                    if (val == 'confirmar') {
                      onCambiarEstado(cita, 'confirmada');
                    } else if (val == 'rechazar') {
                      onCambiarEstado(cita, 'cancelada');
                    } else if (val == 'editar') {
                      onEditarCita(cita, paciente);
                    } else if (val == 'llegada') {
                      onMarcarLlegada(cita);
                    } else if (val == 'iniciar') {
                      onCambiarEstado(cita, 'en_consulta');
                    } else if (val == 'atendida') {
                      onAbrirHistoria(cita, paciente);
                    } else if (val == 'extender') {
                      onExtenderDuracion(cita, 15);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (esPorConfirmar) ...[
                      PopupMenuItem(
                        value: 'confirmar',
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            Text(isEs ? 'Aprobar / Confirmar Cita' : 'Confirm Appointment',
                                style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rechazar',
                        child: Row(
                          children: [
                            const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(isEs ? 'Rechazar Solicitud' : 'Reject Appointment',
                                style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    if (!esPorConfirmar && !(cita.llegadaConfirmada ?? false) && estado != 'atendida' && estado != 'completada')
                      PopupMenuItem(
                        value: 'llegada',
                        child: Row(
                          children: [
                            const Icon(Icons.how_to_reg, size: 16, color: Colors.teal),
                            const SizedBox(width: 8),
                            Text(isEs ? 'Marcar Llegada a Sala' : 'Mark Arrival in Waiting Room'),
                          ],
                        ),
                      ),
                    if (estado != 'en_consulta' && !esPorConfirmar)
                      PopupMenuItem(
                        value: 'iniciar',
                        child: Text(isEs ? 'Llamar a Box / Iniciar Consulta' : 'Call Patient / Start Consultation'),
                      ),
                    PopupMenuItem(
                      value: 'atendida',
                      child: Text(isEs ? 'Ficha y Receta (Finalizar)' : 'Chart & Prescription (Complete)'),
                    ),
                    PopupMenuItem(
                      value: 'extender',
                      child: Text(isEs ? 'Alargar +15 min' : 'Extend +15 min'),
                    ),
                    PopupMenuItem(
                      value: 'editar',
                      child: Text(isEs ? 'Modificar Cita / Horario' : 'Edit Appointment / Time'),
                    ),
                  ],
                ),
              ],
            ),

            // Botones de acción rápida si está Por Confirmar
            if (esPorConfirmar) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB45309)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isEs ? 'Solicitud online por paciente' : 'Online booking request',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => onCambiarEstado(cita, 'confirmada'),
                      icon: const Icon(Icons.check, size: 14),
                      label: Text(isEs ? 'Aprobar' : 'Approve', style: const TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => onCambiarEstado(cita, 'cancelada'),
                      child: Text(isEs ? 'Rechazar' : 'Reject', style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

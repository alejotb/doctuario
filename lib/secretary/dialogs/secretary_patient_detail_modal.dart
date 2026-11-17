import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/backend/supabase/supabase.dart';
import '/services/emergency_appointment_service.dart';
import '/services/i18n_service.dart';
import '/doctors/doctor_agenda_panel/dialogs/appointment_studies_procedures_modal.dart';

/// Modal detallado para que las secretarias visualicen los datos principales
/// del paciente (nombre, teléfono, cédula, etc.) y ejecuten acciones sobre la cita.
class SecretaryPatientDetailModal extends StatelessWidget {
  final CitasRow cita;
  final UsuariosRow? paciente;
  final UsuariosRow doctorActual;
  final List<DoctorSedesRow> sedesDoctor;
  final void Function(CitasRow cita, String nuevoEstado) onCambiarEstado;
  final void Function(CitasRow cita) onMarcarLlegada;
  final VoidCallback? onActualizar;

  const SecretaryPatientDetailModal({
    super.key,
    required this.cita,
    required this.paciente,
    required this.doctorActual,
    required this.sedesDoctor,
    required this.onCambiarEstado,
    required this.onMarcarLlegada,
    this.onActualizar,
  });

  static Future<void> show(
    BuildContext context, {
    required CitasRow cita,
    required UsuariosRow? paciente,
    required UsuariosRow doctorActual,
    required List<DoctorSedesRow> sedesDoctor,
    required void Function(CitasRow cita, String nuevoEstado) onCambiarEstado,
    required void Function(CitasRow cita) onMarcarLlegada,
    VoidCallback? onActualizar,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => SecretaryPatientDetailModal(
        cita: cita,
        paciente: paciente,
        doctorActual: doctorActual,
        sedesDoctor: sedesDoctor,
        onCambiarEstado: onCambiarEstado,
        onMarcarLlegada: onMarcarLlegada,
        onActualizar: onActualizar,
      ),
    );
  }

  String _formatFechaNacimiento(DateTime? fn) {
    if (fn == null) return 'No registrada';
    final edad = DateTime.now().year - fn.year;
    return '${fn.day}/${fn.month}/${fn.year} ($edad años)';
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'en_espera':
        return const Color(0xFF0D9488);
      case 'en_consulta':
        return const Color(0xFF0284C7);
      case 'completada':
        return const Color(0xFF16A34A);
      case 'cancelada':
        return const Color(0xFFE11D48);
      case 'confirmada':
        return const Color(0xFF4F46E5);
      default:
        return const Color(0xFFD97706);
    }
  }

  String _nombreEstado(String estado, bool isEs) {
    switch (estado) {
      case 'en_espera':
        return isEs ? 'En Sala de Espera' : 'In Waiting Room';
      case 'en_consulta':
        return isEs ? 'En Consulta' : 'In Consultation';
      case 'completada':
        return isEs ? 'Completada' : 'Completed';
      case 'cancelada':
        return isEs ? 'Cancelada' : 'Cancelled';
      case 'confirmada':
        return isEs ? 'Confirmada' : 'Confirmed';
      default:
        return isEs ? 'Solicitada / Pendiente' : 'Requested';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final hora = cita.fechaHoraEstimadaActual ?? cita.fechaHora;
    final horaStr = hora != null
        ? '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}'
        : '--:--';
    final fechaStr = hora != null ? DateFormat('EEEE d MMMM, yyyy', isEs ? 'es' : 'en').format(hora) : '';
    final estado = cita.estado ?? 'solicitada';
    final llegadaConfirmada = (cita.llegadaConfirmada ?? false) || estado == 'en_espera';
    final esEmergencia = cita.esEmergencia ?? false;
    final esForaneo = paciente?.esForaneo ?? false;
    final esEspecial = (cita.tratoEspecial ?? false) || (paciente?.esFamiliarMedico ?? false);

    final sedeNombre = sedesDoctor.isNotEmpty
        ? (sedesDoctor.firstWhere((s) => s.id == cita.idSede, orElse: () => sedesDoctor.first).nombreSede ?? 'Consultorio')
        : 'Consultorio';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Cabecera con datos principales y foto
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF0284C7),
                      backgroundImage: (paciente?.fotoUrl != null && paciente!.fotoUrl!.isNotEmpty)
                          ? NetworkImage(paciente!.fotoUrl!)
                          : null,
                      child: (paciente?.fotoUrl == null || paciente!.fotoUrl!.isEmpty)
                          ? const Icon(Icons.person, color: Colors.white, size: 32)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _colorEstado(estado).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _colorEstado(estado)),
                                ),
                                child: Text(
                                  _nombreEstado(estado, isEs).toUpperCase(),
                                  style: TextStyle(
                                    color: _colorEstado(estado),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (llegadaConfirmada) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 14),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            paciente?.nombre ?? 'Paciente',
                            style: GoogleFonts.mooli(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Dr(a). ${(doctorActual.nombre ?? "Médico").trim()} • $sedeNombre',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // 2. Insignias especiales
              if (esEmergencia || esForaneo || esEspecial || cita.modalidadAtencion == 'orden_llegada')
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (esEmergencia) _buildPill('🚨 EMERGENCIA', Colors.red),
                      if (esEspecial) _buildPill('⭐ TRATO ESPECIAL / FAMILIAR', Colors.amber.shade800),
                      if (esForaneo) _buildPill('🚗 FORÁNEO (VIAJA)', Colors.blue),
                      if (cita.modalidadAtencion == 'orden_llegada') _buildPill('📋 ORDEN DE LLEGADA', Colors.purple),
                    ],
                  ),
                ),

              // 3. Bloque de Datos Personales
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEs ? 'Datos del Paciente' : 'Patient Information',
                      style: GoogleFonts.mooli(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(Icons.badge_outlined, isEs ? 'Cédula / Documento' : 'National ID', paciente?.cedula ?? 'No registrada'),
                    _buildPhoneTile(context, paciente?.telefono, isEs, sedeNombre, hora),
                    _buildInfoTile(Icons.email_outlined, isEs ? 'Correo Electrónico' : 'Email', paciente?.email ?? 'No registrado'),
                    _buildInfoTile(Icons.cake_outlined, isEs ? 'Fecha de Nacimiento' : 'Birth Date', _formatFechaNacimiento(paciente?.fechaNacimiento)),
                    _buildInfoTile(Icons.location_on_outlined, isEs ? 'Ciudad de Origen' : 'City', paciente?.ciudadOrigen ?? 'No registrada'),

                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 10),

                    // 4. Datos de la Cita
                    Text(
                      isEs ? 'Detalle de la Cita' : 'Appointment Details',
                      style: GoogleFonts.mooli(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(Icons.calendar_today_outlined, isEs ? 'Fecha y Hora' : 'Date & Time', '$fechaStr • $horaStr'),
                    _buildInfoTile(Icons.location_city_rounded, isEs ? 'Consultorio / Sede' : 'Clinic', sedeNombre),
                    if (cita.motivo != null && cita.motivo!.trim().isNotEmpty)
                      _buildInfoTile(Icons.notes_rounded, isEs ? 'Motivo / Síntomas' : 'Reason / Symptoms', cita.motivo!.trim()),

                    const SizedBox(height: 18),

                    // 5. Botones de Acción Rápida
                    Row(
                      children: [
                        if (!llegadaConfirmada && estado != 'completada' && estado != 'cancelada')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                onMarcarLlegada(cita);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.how_to_reg, size: 18),
                              label: Text(isEs ? 'Marcar Llegada a Sala' : 'Mark Arrival', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          )
                        else if (estado == 'en_espera')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                onCambiarEstado(cita, 'en_consulta');
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.meeting_room_rounded, size: 18),
                              label: Text(isEs ? 'Pasar a Consultorio' : 'Pass to Doctor', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            AppointmentStudiesProceduresModal.show(
                              context,
                              cita: cita,
                              paciente: paciente,
                              idDoctor: doctorActual.id,
                              idUsuarioOperador: doctorActual.id,
                              onHorariosRecalculados: () {
                                if (onActualizar != null) onActualizar!();
                              },
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFFBAE6FD)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.biotech_rounded, size: 18),
                          label: Text(isEs ? 'Estudios & Tiempo' : 'Studies & Time', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                Text(value, style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneTile(BuildContext context, String? tel, bool isEs, String sedeNombre, DateTime? hora) {
    final hasTel = tel != null && tel.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEs ? 'Teléfono de Contacto' : 'Phone Number', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                Text(hasTel ? tel : 'No registrado', style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (hasTel)
            ElevatedButton.icon(
              onPressed: () {
                EmergencyAppointmentService().abrirWhatsAppAviso(
                  telefonoPaciente: tel,
                  nombrePaciente: paciente?.nombre ?? 'Paciente',
                  nombreDoctor: doctorActual.nombre ?? 'Doctor',
                  nombreSede: sedeNombre,
                  nuevaHoraEstimada: hora ?? DateTime.now(),
                  minutosRetraso: cita.minutosRetrasoAcumulados ?? 0,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.chat, size: 14),
              label: const Text('WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold)),
    );
  }
}

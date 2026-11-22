import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/supabase/supabase.dart';
import '/services/emergency_appointment_service.dart';
import '/medical_records/patient_exams_widget.dart';

/// Tarjeta de gestión de paciente en la cola de la sala de espera para secretarias.
/// Permite gestionar estados, confirmar citas online ('por_confirmar'), registrar llegada y avisar demoras.
class SecretaryPatientQueueCard extends StatelessWidget {
  const SecretaryPatientQueueCard({
    super.key,
    required this.cita,
    required this.paciente,
    required this.doctorActual,
    required this.sedesDoctor,
    required this.onCambiarEstado,
    required this.onMarcarLlegada,
  });

  final CitasRow cita;
  final UsuariosRow? paciente;
  final UsuariosRow doctorActual;
  final List<DoctorSedesRow> sedesDoctor;
  final void Function(CitasRow cita, String nuevoEstado) onCambiarEstado;
  final void Function(CitasRow cita) onMarcarLlegada;

  @override
  Widget build(BuildContext context) {
    final hora = cita.fechaHoraEstimadaActual ?? cita.fechaHora;
    final horaStr = hora != null
        ? '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}'
        : '--:--';

    final esEmergencia = cita.esEmergencia ?? false;
    final esForaneo = paciente?.esForaneo ?? false;
    final esEspecial = (cita.tratoEspecial ?? false) ||
        (paciente?.esFamiliarMedico ?? false);
    final rawEstado = (cita.estado ?? 'solicitada').toLowerCase();
    final estadoValido = [
      'por_confirmar',
      'confirmada',
      'solicitada',
      'en_espera',
      'en_consulta',
      'completada',
      'cancelada'
    ].contains(rawEstado)
        ? rawEstado
        : 'solicitada';

    final llegadaConfirmada =
        (cita.llegadaConfirmada ?? false) || estadoValido == 'en_espera';
    final horaLlegada = cita.horaLlegada;
    final esPorConfirmar = estadoValido == 'por_confirmar';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: esEmergencia
            ? const BorderSide(color: Colors.red, width: 2)
            : esPorConfirmar
                ? const BorderSide(color: Color(0xFFF59E0B), width: 1.5)
                : llegadaConfirmada && estadoValido != 'completada'
                    ? const BorderSide(color: Colors.teal, width: 1.5)
                    : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila de encabezado: Turno / Hora y selector de estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cita.turnoNumero != null
                      ? 'Turno #${cita.turnoNumero} • $horaStr'
                      : '⏰ $horaStr',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: esEmergencia
                        ? Colors.red
                        : esPorConfirmar
                            ? const Color(0xFFB45309)
                            : Colors.teal.shade800,
                    fontSize: 15,
                  ),
                ),
                DropdownButton<String>(
                  value: estadoValido,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: 'por_confirmar',
                      child: Text('⏳ Por Confirmar', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                    ),
                    DropdownMenuItem(
                      value: 'confirmada',
                      child: Text('✅ Confirmada', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                    ),
                    DropdownMenuItem(
                      value: 'solicitada',
                      child: Text('Solicitada'),
                    ),
                    DropdownMenuItem(
                      value: 'en_espera',
                      child: Text('En Sala de Espera'),
                    ),
                    DropdownMenuItem(
                      value: 'en_consulta',
                      child: Text('En Consultorio'),
                    ),
                    DropdownMenuItem(
                      value: 'completada',
                      child: Text('Atendido'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelada',
                      child: Text('Cancelada'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      onCambiarEstado(cita, val);
                    }
                  },
                ),
              ],
            ),

            // Banner destacado para citas que requieren confirmación
            if (esPorConfirmar) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cita pedida por paciente online. ¿Confirmar lugar en agenda?',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => onCambiarEstado(cita, 'confirmada'),
                      child: const Text('Aprobar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => onCambiarEstado(cita, 'cancelada'),
                      child: const Text('Rechazar', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],

            // Nombre del Paciente
            Text(
              paciente?.nombre ?? 'Paciente',
              style: GoogleFonts.mooli(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // Insignias y etiquetas de estado
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (esPorConfirmar) _badge('⏳ POR CONFIRMAR', const Color(0xFFB45309)),
                if (estadoValido == 'confirmada') _badge('✅ CONFIRMADA', const Color(0xFF059669)),
                if (llegadaConfirmada && estadoValido != 'completada')
                  _badge(
                    horaLlegada != null
                        ? '🟢 EN SALA (${horaLlegada.hour.toString().padLeft(2, '0')}:${horaLlegada.minute.toString().padLeft(2, '0')})'
                        : '🟢 EN SALA DE ESPERA',
                    Colors.teal,
                  ),
                if (esEmergencia) _badge('🚨 EMERGENCIA', Colors.red),
                if (esEspecial) _badge('⭐ ESPECIAL', Colors.amber),
                if (esForaneo) _badge('🚗 FORÁNEO', Colors.blue),
                if (cita.modalidadAtencion == 'orden_llegada')
                  _badge('📋 ORDEN LLEGADA', Colors.purple),
              ],
            ),
            if ((cita.tipoExoneracion != null && cita.tipoExoneracion != 'ninguno') ||
                (paciente?.tipoExoneracion != null && paciente?.tipoExoneracion != 'ninguno')) ...[
              const SizedBox(height: 8),
              Builder(builder: (_) {
                final tipo = (cita.tipoExoneracion != null && cita.tipoExoneracion != 'ninguno')
                    ? cita.tipoExoneracion!
                    : (paciente?.tipoExoneracion ?? '');
                final monto = (cita.tipoExoneracion != null && cita.tipoExoneracion != 'ninguno')
                    ? cita.montoExoneracion
                    : paciente?.montoExoneracion;

                String textoExo;
                if (tipo == 'exonerado' || (tipo == 'porcentaje' && (monto ?? 0) >= 100)) {
                  textoExo = '💚 PACIENTE EXONERADO POR EL MÉDICO (Sin cobro de consulta)';
                } else if (tipo == 'porcentaje' && monto != null) {
                  textoExo = '💲 DESCUENTO AUTORIZADO: ${monto.toStringAsFixed(0)}% sobre tarifa';
                } else if (tipo == 'monto_fijo' && monto != null) {
                  textoExo = '💲 MONTO ESPECIAL AUTORIZADO: \$${monto.toStringAsFixed(2)}';
                } else {
                  textoExo = '💚 BENEFICIO / EXONERACIÓN AUTORIZADA POR EL MÉDICO';
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6EE7B7)),
                  ),
                  child: Text(
                    textoExo,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                );
              }),
            ],
            const Divider(height: 16),

            // Botón de acción rápida: Marcar Llegada / Pasar a consultorio
            Row(
              children: [
                if (!llegadaConfirmada &&
                    estadoValido != 'completada' &&
                    estadoValido != 'cancelada' &&
                    !esPorConfirmar)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00796B),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.how_to_reg,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        '📍 Marcar Llegada a Sala',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => onMarcarLlegada(cita),
                    ),
                  )
                else if (estadoValido == 'en_espera')
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.meeting_room,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        '👨‍⚕️ Pasar a Consultorio',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => onCambiarEstado(cita, 'en_consulta'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Acciones secundarias: Subir Examen PDF y Notificación WhatsApp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.upload_file, size: 18, color: Colors.teal),
                  label: const Text(
                    'Subir Examen PDF',
                    style: TextStyle(color: Colors.teal),
                  ),
                  onPressed: () {
                    if (cita.idPaciente != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientExamsWidget(
                            idPaciente: cita.idPaciente!,
                            nombrePaciente: paciente?.nombre,
                            puedeSubir: true,
                          ),
                        ),
                      );
                    }
                  },
                ),
                if (paciente?.telefono != null &&
                    paciente!.telefono!.isNotEmpty)
                  IconButton(
                    tooltip: 'Avisar WhatsApp',
                    icon: const Icon(Icons.chat, color: Colors.green),
                    onPressed: () {
                      final sedeNombre = sedesDoctor.isNotEmpty
                          ? (sedesDoctor
                                  .firstWhere(
                                    (s) => s.id == cita.idSede,
                                    orElse: () => sedesDoctor.first,
                                  )
                                  .nombreSede ??
                              'Consultorio')
                          : 'Consultorio';

                      EmergencyAppointmentService().abrirWhatsAppAviso(
                        telefonoPaciente: paciente!.telefono!,
                        nombrePaciente: paciente?.nombre ?? 'Paciente',
                        nombreDoctor: doctorActual.nombre ?? 'Doctor',
                        nombreSede: sedeNombre,
                        nuevaHoraEstimada: hora ?? DateTime.now(),
                        minutosRetraso: cita.minutosRetrasoAcumulados ?? 0,
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

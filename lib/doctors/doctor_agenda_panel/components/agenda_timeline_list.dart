import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/i18n_service.dart';
import 'agenda_appointment_item_card.dart';
import '../dialogs/manage_day_appointments_dialog.dart';

/// Lista cronológica (timeline) de citas del día con soporte para:
/// - Modo Normal: Muestra únicamente las citas programadas/atendidas del día.
/// - Modo Programar Cita (modoSeleccionTurno): Despliega la agenda de horarios disponibles.
/// - Modo Por Orden de Llegada: Control de cupos ocupados vs disponibles.
class AgendaTimelineList extends StatelessWidget {
  final List<CitasRow> citasDelDia;
  final Map<String, UsuariosRow> pacientesMap;
  final CitasRow? citaSeleccionada;
  final String filtroEstado;
  final DateTime fechaSeleccionada;
  final DoctorSedesRow? sedeActual;
  final int? limitePacientesDia;
  final bool modoSeleccionTurno;
  final VoidCallback? onCancelarModoTurno;
  final VoidCallback? onActivarModoTurno;

  final ValueChanged<String> onFiltroChanged;
  final ValueChanged<CitasRow> onSeleccionarCita;
  final void Function(CitasRow cita, UsuariosRow? paciente) onEditarCita;
  final ValueChanged<CitasRow> onMarcarLlegada;
  final void Function(CitasRow cita, String nuevoEstado) onCambiarEstado;
  final void Function(CitasRow cita, UsuariosRow? paciente) onAbrirHistoria;
  final void Function(CitasRow cita, int minutosExtra) onExtenderDuracion;
  final void Function(DateTime fecha, String hora) onAgendarEnHorario;

  const AgendaTimelineList({
    super.key,
    required this.citasDelDia,
    required this.pacientesMap,
    required this.citaSeleccionada,
    required this.filtroEstado,
    required this.fechaSeleccionada,
    this.sedeActual,
    this.limitePacientesDia,
    this.modoSeleccionTurno = false,
    this.onCancelarModoTurno,
    this.onActivarModoTurno,
    required this.onFiltroChanged,
    required this.onSeleccionarCita,
    required this.onEditarCita,
    required this.onMarcarLlegada,
    required this.onCambiarEstado,
    required this.onAbrirHistoria,
    required this.onExtenderDuracion,
    required this.onAgendarEnHorario,
  });

  static const List<String> _horasEstandar = [
    '07:30 AM', '08:00 AM', '08:30 AM', '09:00 AM', '09:30 AM', '10:00 AM',
    '10:30 AM', '11:00 AM', '11:30 AM', '12:00 PM', '01:30 PM', '02:00 PM',
    '02:30 PM', '03:00 PM', '03:30 PM', '04:00 PM', '04:30 PM', '05:00 PM',
    '05:30 PM', '06:00 PM',
  ];

  DateTime _parseSlotDateTime(String slotStr) {
    final parts = slotStr.split(' ');
    final hm = parts[0].split(':');
    int h = int.parse(hm[0]);
    final m = int.parse(hm[1]);
    if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && h < 12) h += 12;
    if (parts.length > 1 && parts[1].toUpperCase() == 'AM' && h == 12) h = 0;
    return DateTime(fechaSeleccionada.year, fechaSeleccionada.month, fechaSeleccionada.day, h, m);
  }

  bool _isSlotInPast(String slotStr) {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final fecha = DateTime(fechaSeleccionada.year, fechaSeleccionada.month, fechaSeleccionada.day);
    if (fecha.isBefore(hoy)) return true;
    if (fecha.isAfter(hoy)) return false;
    return _parseSlotDateTime(slotStr).isBefore(now);
  }

  Widget _buildItemCard(CitasRow cita) {
    return AgendaAppointmentItemCard(
      cita: cita,
      paciente: pacientesMap[cita.idPaciente],
      esSeleccionada: citaSeleccionada?.id == cita.id,
      onTap: () => onSeleccionarCita(cita),
      onEditarCita: onEditarCita,
      onMarcarLlegada: onMarcarLlegada,
      onCambiarEstado: onCambiarEstado,
      onAbrirHistoria: onAbrirHistoria,
      onExtenderDuracion: onExtenderDuracion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final esOrdenLlegada = sedeActual?.modalidadAtencion == 'orden_llegada';
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final fecha = DateTime(fechaSeleccionada.year, fechaSeleccionada.month, fechaSeleccionada.day);
    final esDiaPasado = fecha.isBefore(hoy);

    var citasFiltradas = citasDelDia;
    if (filtroEstado == 'en_sala') {
      citasFiltradas = citasDelDia.where((c) => c.estado == 'pendiente' || c.estado == 'en_sala').toList();
    } else if (filtroEstado == 'confirmada') {
      citasFiltradas = citasDelDia.where((c) => c.estado == 'confirmada').toList();
    } else if (filtroEstado == 'atendida') {
      citasFiltradas = citasDelDia.where((c) => c.estado == 'atendida').toList();
    }

    final fechaTitulo = isEs
        ? 'Citas del ${DateFormat("EEEE d 'de' MMMM", 'es').format(fechaSeleccionada)}'
        : 'Appointments for ${DateFormat("EEEE, MMMM d", 'en').format(fechaSeleccionada)}';

    final subtituloModalidad = esOrdenLlegada
        ? (isEs ? 'Modalidad: Orden de Llegada' : 'Mode: Walk-in / First Come')
        : modoSeleccionTurno
            ? (isEs ? 'Selecciona un horario disponible para la cita' : 'Select an available time slot for the appointment')
            : (isEs ? '${citasDelDia.length} citas registradas • Por Horario' : '${citasDelDia.length} appointments • By Time Slot');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: modoSeleccionTurno ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
          width: modoSeleccionTurno ? 1.5 : 1.0,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (modoSeleccionTurno) _buildBannerModoSeleccionTurno(isEs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fechaTitulo,
                        style: GoogleFonts.mooli(fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtituloModalidad,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: modoSeleccionTurno ? const Color(0xFF0284C7) : Colors.grey.shade500,
                          fontWeight: modoSeleccionTurno ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!modoSeleccionTurno) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_calendar_rounded, size: 20, color: Color(0xFFD97706)),
                    tooltip: isEs ? 'Ajustar todas las citas del día' : 'Manage day appointments',
                    onPressed: () {
                      final docId = (citasDelDia.isNotEmpty ? citasDelDia.first.idDoctor : null) ?? sedeActual?.idDoctor ?? '';
                      if (docId.isNotEmpty) {
                        ManageDayAppointmentsDialog.show(
                          context,
                          idDoctor: docId,
                          fecha: fechaSeleccionada,
                          citasDelDia: citasDelDia,
                          onActualizado: () => onFiltroChanged(filtroEstado),
                        );
                      }
                    },
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: filtroEstado,
                      isDense: true,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      items: [
                        DropdownMenuItem(value: 'todos', child: Text(isEs ? 'Todos' : 'All')),
                        DropdownMenuItem(value: 'en_sala', child: Text(isEs ? 'En sala' : 'Waiting')),
                        DropdownMenuItem(value: 'confirmada', child: Text(isEs ? 'Confirmadas' : 'Confirmed')),
                        DropdownMenuItem(value: 'atendida', child: Text(isEs ? 'Atendidas' : 'Completed')),
                      ],
                      onChanged: (val) {
                        if (val != null) onFiltroChanged(val);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          if (esOrdenLlegada) ...[
            _buildCuposOrdenLlegadaCard(context, esDiaPasado, isEs),
            if (citasFiltradas.isEmpty)
              _buildEmptyCitasState(isEs ? 'No hay pacientes en cola para este día.' : 'No patients in queue for this day.', esDiaPasado: esDiaPasado, isEs: isEs)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: citasFiltradas.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) => _buildItemCard(citasFiltradas[idx]),
              ),
          ] else ...[
            if (modoSeleccionTurno)
              _buildGrillaSeleccionTurno(context, citasFiltradas, esDiaPasado, isEs)
            else
              _buildListaCitasNormal(context, citasFiltradas, esDiaPasado, isEs),
          ],
        ],
      ),
    );
  }

  Widget _buildBannerModoSeleccionTurno(bool isEs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
        border: Border(bottom: BorderSide(color: Color(0xFFBFDBFE))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.touch_app_rounded, color: Color(0xFF1D4ED8), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? 'Selecciona la fecha y hora' : 'Select date and time',
                  style: GoogleFonts.mooli(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF1E40AF)),
                ),
                Text(
                  isEs ? 'Elige un día arriba y toca el horario disponible para agendar.' : 'Pick a day above and tap an available time slot to schedule.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                ),
              ],
            ),
          ),
          if (onCancelarModoTurno != null)
            TextButton.icon(
              onPressed: onCancelarModoTurno,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.close_rounded, size: 15),
              label: Text(isEs ? 'Cancelar' : 'Cancel', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildListaCitasNormal(BuildContext context, List<CitasRow> citas, bool esDiaPasado, bool isEs) {
    if (citas.isEmpty) {
      return _buildEmptyCitasState(
        isEs ? 'No hay citas programadas para este día.' : 'No appointments scheduled for this day.',
        esDiaPasado: esDiaPasado,
        isEs: isEs,
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: citas.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, idx) => _buildItemCard(citas[idx]),
    );
  }

  Widget _buildEmptyCitasState(String mensaje, {required bool esDiaPasado, required bool isEs}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: Icon(Icons.calendar_today_outlined, size: 30, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 12),
            Text(
              mensaje,
              style: GoogleFonts.mooli(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              esDiaPasado
                  ? (isEs ? 'Esta fecha ya ha concluido.' : 'This date has already passed.')
                  : (isEs ? 'Presiona "Nueva Cita" para programar pacientes en este día.' : 'Press "New Appointment" to schedule patients for this day.'),
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            if (!esDiaPasado && onActivarModoTurno != null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onActivarModoTurno,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(isEs ? 'Programar Cita Aquí' : 'Schedule Appointment Here', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrillaSeleccionTurno(BuildContext context, List<CitasRow> citasFiltradas, bool esDiaPasado, bool isEs) {
    final Map<String, List<CitasRow>> citasPorHora = {};
    for (final c in citasFiltradas) {
      final horaDt = c.fechaHoraEstimadaActual ?? c.fechaHora;
      if (horaDt != null) {
        final keyHora = DateFormat('hh:mm a').format(horaDt).toUpperCase();
        citasPorHora.putIfAbsent(keyHora, () => []).add(c);
      }
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _horasEstandar.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, idx) {
        final horaStr = _horasEstandar[idx];
        final citasEnEstaHora = citasPorHora[horaStr] ?? [];
        final estaOcupada = citasEnEstaHora.isNotEmpty;
        final estaEnElPasado = esDiaPasado || _isSlotInPast(horaStr);

        if (estaOcupada) {
          return Column(children: citasEnEstaHora.map((cita) => _buildItemCard(cita)).toList());
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          color: estaEnElPasado ? const Color(0xFFF8FAFC) : Colors.white,
          child: Row(
            children: [
              SizedBox(
                width: 65,
                child: Text(
                  horaStr,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: estaEnElPasado ? Colors.grey.shade400 : const Color(0xFF0284C7)),
                ),
              ),
              const SizedBox(width: 8),
              if (estaEnElPasado) ...[
                Icon(Icons.history_toggle_off_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  isEs ? 'No disponible (Hora concluida)' : 'Unavailable (Time passed)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFBBF7D0))),
                  child: Text(isEs ? 'Disponible' : 'Available', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                  label: Text(isEs ? 'Elegir Horario' : 'Select Slot', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => onAgendarEnHorario(fechaSeleccionada, horaStr),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCuposOrdenLlegadaCard(BuildContext context, bool esDiaPasado, bool isEs) {
    final limite = limitePacientesDia ?? 20;
    final ocupados = citasDelDia.length;
    final disponibles = (limite - ocupados).clamp(0, 999);
    final porcentaje = (ocupados / limite).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.confirmation_number_outlined, size: 18, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Text(
                isEs ? 'Control de Cupos del Día (Orden de Llegada):' : 'Daily Walk-in Quota Control:',
                style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: ocupados >= limite ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  isEs ? '$ocupados / $limite Ocupados' : '$ocupados / $limite Filled',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ocupados >= limite ? const Color(0xFFDC2626) : const Color(0xFF0284C7)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: 7,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(ocupados >= limite ? const Color(0xFFEF4444) : const Color(0xFF0284C7)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isEs ? 'Quedan $disponibles cupos disponibles.' : '$disponibles slots remaining.', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              if (!esDiaPasado && disponibles > 0)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                  icon: const Icon(Icons.add, size: 15),
                  label: Text(isEs ? 'Asignar Cupo' : 'Assign Slot', style: const TextStyle(fontSize: 11.5)),
                  onPressed: () => onAgendarEnHorario(fechaSeleccionada, '08:00 AM'),
                )
              else if (esDiaPasado)
                Text(isEs ? 'Jornada concluida (Fecha pasada)' : 'Shift ended (Past date)', style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ),
        ],
      ),
    );
  }
}

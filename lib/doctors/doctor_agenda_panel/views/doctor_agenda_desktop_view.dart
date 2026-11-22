import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/doctor_vacation_service.dart';
import '../../../services/i18n_service.dart';
import '../components/patient_in_box_card.dart';
import '../components/pending_labs_card.dart';
import '../../components/patient_latest_exams_quick_card.dart';

/// Disposición de dos columnas para pantallas de escritorio/laptop.
/// Combina en un único contenedor la cabecera de Agenda Médica, la fila de los 7 días
/// y la rejilla cuadriculada de citas vinculada al resumen del paciente activo.
class DoctorAgendaDesktopView extends StatefulWidget {
  final String tituloMes, rangoSemanaStr, filtroEstado, idDoctor;
  final DateTime inicioSemana, fechaSeleccionada;
  final DoctorSedesRow? sedeActual;
  final int? limitePacientesDia;
  final List<CitasRow> citasDeLaSemana, citasDelDia;
  final Map<String, UsuariosRow> pacientesMap, pacientesExamenesMap;
  final CitasRow? citaSeleccionada;
  final UsuariosRow? pacienteSeleccionado;
  final PacientesRow? pacienteDetalleSeleccionado;
  final bool cargandoHistoriaPaciente, modoSeleccionTurno;
  final List<HistoriasClinicasRow> historiasPreviasPaciente;
  final List<ExamenesMedicosRow> examenesPendientes;
  final Set<String> diasBloqueados;
  final VoidCallback onIrAHoy, onAbrirFichaReceta, onVerHistoriaCompleta, onNuevaCita, onOrdenMedica, onReposoMedico, onInterconsulta;
  final ValueChanged<int> onCambiarSemana;
  final ValueChanged<DateTime> onSeleccionarDia;
  final ValueChanged<String> onFiltroChanged;
  final ValueChanged<CitasRow> onSeleccionarCita, onMarcarLlegada;
  final void Function(CitasRow cita, UsuariosRow? paciente) onEditarCita, onAbrirHistoria;
  final void Function(CitasRow cita, String nuevoEstado) onCambiarEstado;
  final void Function(CitasRow cita, int minutosExtra) onExtenderDuracion;
  final void Function(ExamenesMedicosRow examen, UsuariosRow? paciente) onRevisarExamen;
  final void Function(DateTime fecha, String hora) onAgendarEnHorario;
  final VoidCallback? onVitalsActualizados, onDiasBloqueadosActualizados, onCancelarModoTurno, onActivarModoTurno;

  const DoctorAgendaDesktopView({
    super.key, required this.tituloMes, required this.rangoSemanaStr, required this.inicioSemana,
    required this.fechaSeleccionada, this.sedeActual, this.limitePacientesDia,
    this.modoSeleccionTurno = false, this.onCancelarModoTurno, this.onActivarModoTurno,
    required this.citasDeLaSemana, required this.citasDelDia, required this.pacientesMap,
    required this.citaSeleccionada, required this.pacienteSeleccionado, required this.pacienteDetalleSeleccionado,
    required this.cargandoHistoriaPaciente, required this.historiasPreviasPaciente,
    required this.examenesPendientes, required this.pacientesExamenesMap, required this.filtroEstado,
    required this.idDoctor, this.diasBloqueados = const {}, required this.onIrAHoy,
    required this.onCambiarSemana, required this.onSeleccionarDia, required this.onFiltroChanged,
    required this.onSeleccionarCita, required this.onEditarCita, required this.onMarcarLlegada,
    required this.onCambiarEstado, required this.onAbrirHistoria, required this.onExtenderDuracion,
    required this.onAbrirFichaReceta, required this.onVerHistoriaCompleta, required this.onRevisarExamen,
    required this.onNuevaCita, required this.onOrdenMedica, required this.onReposoMedico,
    required this.onInterconsulta, required this.onAgendarEnHorario,
    this.onVitalsActualizados, this.onDiasBloqueadosActualizados,
  });

  @override
  State<DoctorAgendaDesktopView> createState() => _DoctorAgendaDesktopViewState();
}

class _DoctorAgendaDesktopViewState extends State<DoctorAgendaDesktopView> {
  bool _verListaCitados = false;

  String _formatRange(CitasRow c) {
    final start = c.fechaHoraEstimadaActual ?? c.fechaHora;
    if (start == null) return '--:--';
    final localStart = start.toLocal();
    final dur = c.duracionMinutos ?? 30;
    final localEnd = localStart.add(Duration(minutes: dur));
    String fmt(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${fmt(localStart)} – ${fmt(localEnd)}';
  }

  Widget _buildListaCitadosDelDia(BuildContext context, bool isEs) {
    final citas = List<CitasRow>.from(widget.citasDelDia)
      ..sort((a, b) {
        final ta = a.turnoNumero ?? 9999;
        final tb = b.turnoNumero ?? 9999;
        if (ta != tb) return ta.compareTo(tb);
        return (a.fechaHoraEstimadaActual ?? a.fechaHora ?? DateTime(2000))
            .compareTo(b.fechaHoraEstimadaActual ?? b.fechaHora ?? DateTime(2000));
      });

    if (citas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline_rounded, size: 42, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                isEs
                    ? 'No hay pacientes citados para este día.'
                    : 'No patients scheduled for this day.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: widget.onNuevaCita,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(isEs ? 'Agregar Cita' : 'Add Appointment'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: citas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final c = citas[idx];
        final pac = widget.pacientesMap[c.idPaciente];
        final isSelected = widget.citaSeleccionada?.id == c.id;
        final dur = c.duracionMinutos ?? 30;
        final estado = (c.estado ?? 'confirmada').toLowerCase();
        final isPending = estado == 'por_confirmar' || estado == 'solicitada';

        return InkWell(
          onTap: () => widget.onSeleccionarCita(c),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEFF6FF)
                  : isPending
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0284C7)
                    : isPending
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${c.turnoNumero ?? (idx + 1)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pac?.nombre ?? 'Paciente',
                        style: GoogleFonts.mooli(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatRange(c)} • $dur min • ${c.motivo ?? 'Consulta'}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    estado.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isPending ? const Color(0xFFB45309) : const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnifiedScheduleGrid(BuildContext context, bool isEs) {
    const diasEs = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const diasEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      height: 650,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            // Barra superior: Agenda Médica y navegación de semana
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isEs ? 'Agenda Médica' : 'Medical Schedule', style: GoogleFonts.mooli(fontSize: 15.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      Text('${widget.rangoSemanaStr} • ${isEs ? "Turno Activo" : "Active Shift"}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                  ),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    ChoiceChip(
                      label: Text(isEs ? 'Agenda' : 'Schedule', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: !_verListaCitados ? Colors.white : const Color(0xFF334155))),
                      selected: !_verListaCitados,
                      selectedColor: const Color(0xFF0284C7),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _verListaCitados = false),
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: Text(isEs ? 'Citados (${widget.citasDelDia.length})' : 'Queue (${widget.citasDelDia.length})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _verListaCitados ? Colors.white : const Color(0xFF334155))),
                      selected: _verListaCitados,
                      selectedColor: const Color(0xFF0284C7),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _verListaCitados = true),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(44, 28), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), side: const BorderSide(color: Color(0xFFCBD5E1))),
                      onPressed: widget.onIrAHoy,
                      child: Text(isEs ? 'Hoy' : 'Today', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => widget.onCambiarSemana(-1)),
                    const SizedBox(width: 2),
                    IconButton(icon: const Icon(Icons.chevron_right_rounded, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => widget.onCambiarSemana(1)),
                    const SizedBox(width: 6),
                    Text(widget.tituloMes, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ]),
                ],
              ),
            ),
            // Fila de los 7 días integrada como cabecera de las columnas de la rejilla
            Container(
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.2))),
              child: Row(
                children: List.generate(7, (i) {
                  final dia = widget.inicioSemana.add(Duration(days: i));
                  final esHoy = DateUtils.isSameDay(dia, DateTime.now()), esSel = DateUtils.isSameDay(dia, widget.fechaSeleccionada);
                  final esBloq = DoctorVacationService.estaBloqueado(dia, widget.diasBloqueados);
                  final count = widget.citasDeLaSemana.where((c) => c.fechaHora != null && DateUtils.isSameDay(c.fechaHora!, dia)).length;
                  final nomDia = isEs ? diasEs[i] : diasEn[i];

                  return Expanded(
                    child: InkWell(
                      onTap: esBloq ? null : () => widget.onSeleccionarDia(dia),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          color: esBloq ? Colors.grey.shade200 : (esSel ? const Color(0xFF0284C7) : (esHoy ? const Color(0xFFE0F2FE) : Colors.transparent)),
                          border: Border(right: i < 6 ? const BorderSide(color: Color(0xFFCBD5E1), width: 1) : BorderSide.none),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(nomDia.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: esSel ? Colors.white.withValues(alpha: 0.9) : (esHoy ? const Color(0xFF0284C7) : const Color(0xFF64748B)))),
                          const SizedBox(height: 2),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('${dia.day}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: esSel ? Colors.white : (esHoy ? const Color(0xFF0284C7) : const Color(0xFF0F172A)))),
                            if (count > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: esSel ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF0284C7), borderRadius: BorderRadius.circular(8)),
                                child: Text('$count', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ],
                          ]),
                        ]),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Cuerpo: o Lista de Citados del día seleccionado, o Rejilla horaria semanal
            Expanded(
              child: _verListaCitados
                  ? _buildListaCitadosDelDia(context, isEs)
                  : CustomPaint(
                      painter: _DoctorGridPainter(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(7, (index) {
                          final dia = widget.inicioSemana.add(Duration(days: index));
                          final citasDia = widget.citasDeLaSemana.where((c) {
                            final f = c.fechaHora;
                            return f != null && f.year == dia.year && f.month == dia.month && f.day == dia.day;
                          }).toList()
                            ..sort((a, b) => (a.fechaHoraEstimadaActual ?? a.fechaHora ?? DateTime(2000))
                                .compareTo(b.fechaHoraEstimadaActual ?? b.fechaHora ?? DateTime(2000)));

                          final esSeleccionado = DateUtils.isSameDay(dia, widget.fechaSeleccionada);

                          return Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: esSeleccionado ? const Color(0xFFF0F9FF).withValues(alpha: 0.35) : Colors.transparent,
                                border: Border(right: index < 6 ? const BorderSide(color: Color(0xFFCBD5E1), width: 1) : BorderSide.none),
                              ),
                              child: citasDia.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () => widget.onAgendarEnHorario(dia, "08:00 AM"),
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: Colors.white, foregroundColor: const Color(0xFF0284C7),
                                              side: const BorderSide(color: Color(0xFFBAE6FD)),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                                            label: Text(isEs ? 'Agendar Cita para este Día' : 'Book Appointment for this Day', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView(
                                      padding: const EdgeInsets.all(6),
                                      children: [
                                        ...citasDia.map((c) => _buildCitaCard(c, widget.pacientesMap[c.idPaciente], dia, widget.citaSeleccionada?.id == c.id, isEs)),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () => widget.onAgendarEnHorario(dia, "08:00 AM"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFE2E8F0), foregroundColor: const Color(0xFF334155), elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7), side: const BorderSide(color: Color(0xFFCBD5E1))),
                                            ),
                                            icon: const Icon(Icons.add_rounded, size: 14),
                                            label: Text(isEs ? 'Agregar nueva cita' : 'Add new appointment', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        }),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCitaCard(CitasRow c, UsuariosRow? pac, DateTime dia, bool isSelected, bool isEs) {
    final horaStr = _formatRange(c);
    final estado = c.estado ?? 'solicitada';
    final esSobrecitaPorConfirmar = estado == 'solicitada';

    Color estadoColor = const Color(0xFF94A3B8);
    if (esSobrecitaPorConfirmar) {
      estadoColor = const Color(0xFFF59E0B);
    } else if (estado == 'en_espera' || (c.llegadaConfirmada ?? false)) {
      estadoColor = const Color(0xFF0D9488);
    } else if (estado == 'en_consulta') {
      estadoColor = const Color(0xFF0284C7);
    } else if (estado == 'completada' || estado == 'atendida') {
      estadoColor = const Color(0xFF10B981);
    } else if (estado == 'cancelada') {
      estadoColor = const Color(0xFFEF4444);
    }

    return InkWell(
      onTap: () { widget.onSeleccionarDia(dia); widget.onSeleccionarCita(c); },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : (esSobrecitaPorConfirmar ? const Color(0xFFFFFBEB) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : (esSobrecitaPorConfirmar ? const Color(0xFFF59E0B) : (estado == 'en_consulta' ? const Color(0xFF0284C7) : (estado == 'en_espera' ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1)))),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(horaStr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)))),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (c.llegadaConfirmada == true) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.check_circle, size: 10, color: Color(0xFF10B981))),
                Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: estadoColor)),
              ]),
            ]),
            const SizedBox(height: 2),
            Text(pac?.nombre ?? 'Paciente', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            if (c.motivo != null && c.motivo!.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(c.motivo!.replaceFirst('[SOBRECITA] ', ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
            ],
            if (esSobrecitaPorConfirmar) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(child: Text(isEs ? 'Confirmar sobrecita' : 'Confirm overbook', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309)))),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    InkWell(onTap: () => widget.onCambiarEstado(c, 'confirmada'), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)))),
                    InkWell(onTap: () => widget.onCambiarEstado(c, 'cancelada'), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.cancel, size: 14, color: Color(0xFFEF4444)))),
                  ]),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: _buildUnifiedScheduleGrid(context, isEs)),
        const SizedBox(width: 18),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              PatientInBoxCard(
                citaSeleccionada: widget.citaSeleccionada,
                pacienteSeleccionado: widget.pacienteSeleccionado,
                pacienteDetalleSeleccionado: widget.pacienteDetalleSeleccionado,
                cargandoHistoriaPaciente: widget.cargandoHistoriaPaciente,
                historiasPreviasPaciente: widget.historiasPreviasPaciente,
                idDoctor: widget.idDoctor,
                onAbrirFichaReceta: widget.onAbrirFichaReceta,
                onVerHistoriaCompleta: widget.onVerHistoriaCompleta,
                onVitalsActualizados: widget.onVitalsActualizados,
              ),
              if (widget.pacienteSeleccionado != null) ...[
                const SizedBox(height: 16),
                PatientLatestExamsQuickCard(
                  idPaciente: widget.pacienteSeleccionado!.id,
                  paciente: widget.pacienteSeleccionado,
                  idDoctor: widget.idDoctor,
                  onVerTodosEstudios: widget.onVerHistoriaCompleta,
                ),
              ],
              const SizedBox(height: 16),
              PendingLabsCard(
                examenesPendientes: widget.examenesPendientes,
                pacientesExamenesMap: widget.pacientesExamenesMap,
                onRevisarExamen: widget.onRevisarExamen,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoctorGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1.0;
    for (double y = 48.0; y < size.height; y += 48.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

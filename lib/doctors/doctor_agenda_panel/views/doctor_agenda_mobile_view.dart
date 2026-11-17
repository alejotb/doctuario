import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../backend/supabase/supabase.dart';
import '../components/agenda_calendar_header.dart';
import '../components/agenda_timeline_list.dart';
import '../components/patient_in_box_card.dart';
import '../components/pending_labs_card.dart';
import '../../components/patient_latest_exams_quick_card.dart';

/// Disposición con selector de pestañas segmentadas para pantallas móviles.
class DoctorAgendaMobileView extends StatefulWidget {
  final String tituloMes;
  final String rangoSemanaStr;
  final DateTime inicioSemana;
  final DateTime fechaSeleccionada;
  final List<CitasRow> citasDeLaSemana;
  final List<CitasRow> citasDelDia;
  final Map<String, UsuariosRow> pacientesMap;
  final CitasRow? citaSeleccionada;
  final UsuariosRow? pacienteSeleccionado;
  final PacientesRow? pacienteDetalleSeleccionado;
  final bool cargandoHistoriaPaciente;
  final List<HistoriasClinicasRow> historiasPreviasPaciente;
  final List<ExamenesMedicosRow> examenesPendientes;
  final Map<String, UsuariosRow> pacientesExamenesMap;
  final String filtroEstado;
  final String idDoctor;
  final Set<String> diasBloqueados;

  // Callbacks
  final VoidCallback onIrAHoy;
  final ValueChanged<int> onCambiarSemana;
  final ValueChanged<DateTime> onSeleccionarDia;
  final ValueChanged<String> onFiltroChanged;
  final ValueChanged<CitasRow> onSeleccionarCita;
  final void Function(CitasRow cita, UsuariosRow? paciente) onEditarCita;
  final ValueChanged<CitasRow> onMarcarLlegada;
  final void Function(CitasRow cita, String nuevoEstado) onCambiarEstado;
  final void Function(CitasRow cita, UsuariosRow? paciente) onAbrirHistoria;
  final void Function(CitasRow cita, int minutosExtra) onExtenderDuracion;
  final VoidCallback onAbrirFichaReceta;
  final VoidCallback onVerHistoriaCompleta;
  final void Function(ExamenesMedicosRow examen, UsuariosRow? paciente)
      onRevisarExamen;
  final VoidCallback onNuevaCita;
  final VoidCallback onOrdenMedica;
  final VoidCallback onReposoMedico;
  final VoidCallback onInterconsulta;
  final DoctorSedesRow? sedeActual;
  final int? limitePacientesDia;
  final void Function(DateTime fecha, String hora) onAgendarEnHorario;
  final VoidCallback? onVitalsActualizados;
  final VoidCallback? onDiasBloqueadosActualizados;
  final bool modoSeleccionTurno;
  final VoidCallback? onCancelarModoTurno;
  final VoidCallback? onActivarModoTurno;

  const DoctorAgendaMobileView({
    super.key,
    required this.tituloMes,
    required this.rangoSemanaStr,
    required this.inicioSemana,
    required this.fechaSeleccionada,
    this.sedeActual,
    this.limitePacientesDia,
    this.modoSeleccionTurno = false,
    this.onCancelarModoTurno,
    this.onActivarModoTurno,
    required this.citasDeLaSemana,
    required this.citasDelDia,
    required this.pacientesMap,
    required this.citaSeleccionada,
    required this.pacienteSeleccionado,
    required this.pacienteDetalleSeleccionado,
    required this.cargandoHistoriaPaciente,
    required this.historiasPreviasPaciente,
    required this.examenesPendientes,
    required this.pacientesExamenesMap,
    required this.filtroEstado,
    required this.idDoctor,
    this.diasBloqueados = const {},
    required this.onIrAHoy,
    required this.onCambiarSemana,
    required this.onSeleccionarDia,
    required this.onFiltroChanged,
    required this.onSeleccionarCita,
    required this.onEditarCita,
    required this.onMarcarLlegada,
    required this.onCambiarEstado,
    required this.onAbrirHistoria,
    required this.onExtenderDuracion,
    required this.onAbrirFichaReceta,
    required this.onVerHistoriaCompleta,
    required this.onRevisarExamen,
    required this.onNuevaCita,
    required this.onOrdenMedica,
    required this.onReposoMedico,
    required this.onInterconsulta,
    required this.onAgendarEnHorario,
    this.onVitalsActualizados,
    this.onDiasBloqueadosActualizados,
  });

  @override
  State<DoctorAgendaMobileView> createState() => _DoctorAgendaMobileViewState();
}

class _DoctorAgendaMobileViewState extends State<DoctorAgendaMobileView> {
  int _activeTab = 0; // 0: Agenda, 1: Paciente, 2: Exámenes

  @override
  void didUpdateWidget(DoctorAgendaMobileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.modoSeleccionTurno && !oldWidget.modoSeleccionTurno) {
      _activeTab = 0; // Volver a pestaña Agenda automáticamente
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  index: 0,
                  icon: Icons.calendar_month_rounded,
                  label: 'Agenda (${widget.citasDelDia.length})',
                ),
              ),
              Expanded(
                child: _buildTabButton(
                  index: 1,
                  icon: Icons.person_search_rounded,
                  label: 'Paciente',
                ),
              ),
              Expanded(
                child: _buildTabButton(
                  index: 2,
                  icon: Icons.science_rounded,
                  label: 'Exámenes (${widget.examenesPendientes.length})',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_activeTab == 0) ...[
          AgendaCalendarHeader(
            tituloMes: widget.tituloMes,
            rangoSemanaStr: widget.rangoSemanaStr,
            inicioSemana: widget.inicioSemana,
            fechaSeleccionada: widget.fechaSeleccionada,
            citasDeLaSemana: widget.citasDeLaSemana,
            diasBloqueados: widget.diasBloqueados,
            idDoctor: widget.idDoctor,
            onIrAHoy: widget.onIrAHoy,
            onCambiarSemana: widget.onCambiarSemana,
            onSeleccionarDia: widget.onSeleccionarDia,
            onDiasBloqueadosActualizados: widget.onDiasBloqueadosActualizados,
          ),
          const SizedBox(height: 14),
          AgendaTimelineList(
            citasDelDia: widget.citasDelDia,
            pacientesMap: widget.pacientesMap,
            citaSeleccionada: widget.citaSeleccionada,
            filtroEstado: widget.filtroEstado,
            fechaSeleccionada: widget.fechaSeleccionada,
            sedeActual: widget.sedeActual,
            limitePacientesDia: widget.limitePacientesDia,
            modoSeleccionTurno: widget.modoSeleccionTurno,
            onCancelarModoTurno: widget.onCancelarModoTurno,
            onActivarModoTurno: widget.onActivarModoTurno,
            onFiltroChanged: widget.onFiltroChanged,
            onSeleccionarCita: (cita) {
              widget.onSeleccionarCita(cita);
              _mostrarFichaPacienteBottomSheet(context, cita);
            },
            onEditarCita: widget.onEditarCita,
            onMarcarLlegada: widget.onMarcarLlegada,
            onCambiarEstado: widget.onCambiarEstado,
            onAbrirHistoria: widget.onAbrirHistoria,
            onExtenderDuracion: widget.onExtenderDuracion,
            onAgendarEnHorario: widget.onAgendarEnHorario,
          ),
        ] else if (_activeTab == 1) ...[
          PatientInBoxCard(
            citaSeleccionada: widget.citaSeleccionada ?? (widget.citasDelDia.isNotEmpty ? widget.citasDelDia.first : null),
            pacienteSeleccionado: widget.pacienteSeleccionado ?? (widget.citasDelDia.isNotEmpty ? widget.pacientesMap[widget.citasDelDia.first.idPaciente] : null),
            pacienteDetalleSeleccionado: widget.pacienteDetalleSeleccionado,
            cargandoHistoriaPaciente: widget.cargandoHistoriaPaciente,
            historiasPreviasPaciente: widget.historiasPreviasPaciente,
            idDoctor: widget.idDoctor,
            onAbrirFichaReceta: widget.onAbrirFichaReceta,
            onVerHistoriaCompleta: widget.onVerHistoriaCompleta,
            onVitalsActualizados: widget.onVitalsActualizados,
          ),
          if (widget.pacienteSeleccionado != null) ...[
            const SizedBox(height: 12),
            PatientLatestExamsQuickCard(
              idPaciente: widget.pacienteSeleccionado!.id,
              paciente: widget.pacienteSeleccionado,
              idDoctor: widget.idDoctor,
              onVerTodosEstudios: widget.onVerHistoriaCompleta,
            ),
          ],
        ] else ...[
          PendingLabsCard(
            examenesPendientes: widget.examenesPendientes,
            pacientesExamenesMap: widget.pacientesExamenesMap,
            onRevisarExamen: widget.onRevisarExamen,
          ),
        ],
      ],
    );
  }

  void _mostrarFichaPacienteBottomSheet(BuildContext context, CitasRow cita) {
    final paciente = widget.pacientesMap[cita.idPaciente];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFE0F2FE),
                    backgroundImage: paciente?.fotoUrl != null && paciente!.fotoUrl!.isNotEmpty ? NetworkImage(paciente.fotoUrl!) : null,
                    child: paciente?.fotoUrl == null || paciente!.fotoUrl!.isEmpty
                        ? Text(paciente?.nombre?.isNotEmpty == true ? paciente!.nombre![0].toUpperCase() : 'P',
                            style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 18))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(paciente?.nombre ?? 'Paciente', style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                        Text('CI: ${paciente?.cedula ?? "N/D"} • Tel: ${paciente?.telefono ?? "N/D"}', style: GoogleFonts.mooli(fontSize: 12, color: const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(4)),
                          child: Text('Cita: ${cita.fechaHora != null ? DateFormat('hh:mm a').format(cita.fechaHora!) : "Hora"} • ${(cita.estado ?? "Programada").toUpperCase()}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
              if (paciente?.telefono != null && paciente!.telefono!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.phone_rounded, color: Color(0xFF0284C7), size: 16),
                        label: const Text('Llamar', style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0284C7)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: () => launchUrl(Uri.parse('tel:${paciente.telefono}')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF16A34A), size: 16),
                        label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF16A34A)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: () {
                          final cleanPhone = paciente.telefono!.replaceAll(RegExp(r'[^0-9]'), '');
                          launchUrl(Uri.parse('https://wa.me/$cleanPhone?text=Hola%20${paciente.nombre ?? "Paciente"},%20le%20escribo%20del%20consultorio%20médico.'), mode: LaunchMode.externalApplication);
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 24),
              PatientInBoxCard(
                citaSeleccionada: cita,
                pacienteSeleccionado: paciente,
                pacienteDetalleSeleccionado: widget.pacienteDetalleSeleccionado,
                cargandoHistoriaPaciente: widget.cargandoHistoriaPaciente,
                historiasPreviasPaciente: widget.historiasPreviasPaciente,
                idDoctor: widget.idDoctor,
                onAbrirFichaReceta: () {
                  Navigator.pop(ctx);
                  widget.onAbrirFichaReceta();
                },
                onVerHistoriaCompleta: () {
                  Navigator.pop(ctx);
                  widget.onVerHistoriaCompleta();
                },
                onVitalsActualizados: widget.onVitalsActualizados,
              ),
              if (paciente != null) ...[
                const SizedBox(height: 12),
                PatientLatestExamsQuickCard(
                  idPaciente: paciente.id,
                  paciente: paciente,
                  idDoctor: widget.idDoctor,
                  onVerTodosEstudios: () {
                    Navigator.pop(ctx);
                    widget.onVerHistoriaCompleta();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

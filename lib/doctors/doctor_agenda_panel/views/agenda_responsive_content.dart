import 'package:flutter/material.dart';
import '/backend/supabase/supabase.dart';
import '../../doctor_patient_detail/doctor_patient_detail_widget.dart';
import 'doctor_agenda_desktop_view.dart';
import 'doctor_agenda_mobile_view.dart';
import '../dialogs/clinical_history_quick_modal.dart';

class AgendaResponsiveContent extends StatelessWidget {
  const AgendaResponsiveContent({
    super.key,
    required this.isDesktop,
    required this.tituloMes,
    required this.rangoSemanaStr,
    required this.inicioSemana,
    required this.fechaSeleccionada,
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
    this.sedeActual,
    this.limitePacientesDia,
    this.modoSeleccionTurno = false,
    this.onCancelarModoTurno,
    this.onActivarModoTurno,
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
    required this.onRevisarExamen,
    required this.onNuevaCita,
    required this.onAgendarEnHorario,
    this.onVitalsActualizados,
    this.onDiasBloqueadosActualizados,
  });

  final bool isDesktop;
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
  final DoctorSedesRow? sedeActual;
  final int? limitePacientesDia;
  final bool modoSeleccionTurno;
  final VoidCallback? onCancelarModoTurno;
  final VoidCallback? onActivarModoTurno;

  final VoidCallback onIrAHoy;
  final Function(int) onCambiarSemana;
  final Function(DateTime) onSeleccionarDia;
  final Function(String) onFiltroChanged;
  final Function(CitasRow) onSeleccionarCita;
  final Function(CitasRow, UsuariosRow?) onEditarCita;
  final Function(CitasRow) onMarcarLlegada;
  final Function(CitasRow, String) onCambiarEstado;
  final Function(CitasRow, UsuariosRow?) onAbrirHistoria;
  final Function(CitasRow, int) onExtenderDuracion;
  final Function(ExamenesMedicosRow, UsuariosRow?) onRevisarExamen;
  final VoidCallback onNuevaCita;
  final void Function(DateTime fecha, String hora) onAgendarEnHorario;
  final VoidCallback? onVitalsActualizados;
  final VoidCallback? onDiasBloqueadosActualizados;

  @override
  Widget build(BuildContext context) {
    void onAbrirFichaReceta() {
      if (citaSeleccionada != null) {
        onAbrirHistoria(citaSeleccionada!, pacienteSeleccionado);
      }
    }

    void onVerHistoriaCompleta() {
      if (citaSeleccionada?.idPaciente != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorPatientDetailWidget(
              idDoctor: idDoctor,
              idPaciente: citaSeleccionada!.idPaciente!,
            ),
          ),
        );
      }
    }

    void onOrdenMedica() {
      if (citaSeleccionada != null) {
        ClinicalHistoryQuickModal.show(
          context,
          idDoctor: idDoctor,
          cita: citaSeleccionada!,
          paciente: pacienteSeleccionado,
          onConsultaFinalizada: () => onFiltroChanged(filtroEstado),
          tipoDocumentoInicial: 'orden',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Selecciona primero un paciente para emitir orden médica.',
            ),
          ),
        );
      }
    }

    void onReposoMedico() {
      if (citaSeleccionada != null) {
        ClinicalHistoryQuickModal.show(
          context,
          idDoctor: idDoctor,
          cita: citaSeleccionada!,
          paciente: pacienteSeleccionado,
          onConsultaFinalizada: () => onFiltroChanged(filtroEstado),
          tipoDocumentoInicial: 'reposo',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Selecciona primero un paciente para emitir reposo médico.',
            ),
          ),
        );
      }
    }

    void onInterconsulta() {
      if (citaSeleccionada != null) {
        ClinicalHistoryQuickModal.show(
          context,
          idDoctor: idDoctor,
          cita: citaSeleccionada!,
          paciente: pacienteSeleccionado,
          onConsultaFinalizada: () => onFiltroChanged(filtroEstado),
          tipoDocumentoInicial: 'interconsulta',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Selecciona primero un paciente para emitir interconsulta.',
            ),
          ),
        );
      }
    }

    if (isDesktop) {
      return DoctorAgendaDesktopView(
        tituloMes: tituloMes,
        rangoSemanaStr: rangoSemanaStr,
        inicioSemana: inicioSemana,
        fechaSeleccionada: fechaSeleccionada,
        citasDeLaSemana: citasDeLaSemana,
        citasDelDia: citasDelDia,
        pacientesMap: pacientesMap,
        citaSeleccionada: citaSeleccionada,
        pacienteSeleccionado: pacienteSeleccionado,
        pacienteDetalleSeleccionado: pacienteDetalleSeleccionado,
        cargandoHistoriaPaciente: cargandoHistoriaPaciente,
        historiasPreviasPaciente: historiasPreviasPaciente,
        examenesPendientes: examenesPendientes,
        pacientesExamenesMap: pacientesExamenesMap,
        filtroEstado: filtroEstado,
        idDoctor: idDoctor,
        diasBloqueados: diasBloqueados,
        onIrAHoy: onIrAHoy,
        onCambiarSemana: onCambiarSemana,
        onSeleccionarDia: onSeleccionarDia,
        onFiltroChanged: onFiltroChanged,
        onSeleccionarCita: onSeleccionarCita,
        onEditarCita: onEditarCita,
        onMarcarLlegada: onMarcarLlegada,
        onCambiarEstado: onCambiarEstado,
        onAbrirHistoria: onAbrirHistoria,
        onExtenderDuracion: onExtenderDuracion,
        onAbrirFichaReceta: onAbrirFichaReceta,
        onVerHistoriaCompleta: onVerHistoriaCompleta,
        onRevisarExamen: onRevisarExamen,
        onNuevaCita: onNuevaCita,
        onOrdenMedica: onOrdenMedica,
        onReposoMedico: onReposoMedico,
        onInterconsulta: onInterconsulta,
        sedeActual: sedeActual,
        limitePacientesDia: limitePacientesDia,
        modoSeleccionTurno: modoSeleccionTurno,
        onCancelarModoTurno: onCancelarModoTurno,
        onActivarModoTurno: onActivarModoTurno,
        onAgendarEnHorario: onAgendarEnHorario,
        onVitalsActualizados: onVitalsActualizados,
        onDiasBloqueadosActualizados: onDiasBloqueadosActualizados,
      );
    }

    return DoctorAgendaMobileView(
      tituloMes: tituloMes,
      rangoSemanaStr: rangoSemanaStr,
      inicioSemana: inicioSemana,
      fechaSeleccionada: fechaSeleccionada,
      sedeActual: sedeActual,
      limitePacientesDia: limitePacientesDia,
      modoSeleccionTurno: modoSeleccionTurno,
      onCancelarModoTurno: onCancelarModoTurno,
      onActivarModoTurno: onActivarModoTurno,
      citasDeLaSemana: citasDeLaSemana,
      citasDelDia: citasDelDia,
      pacientesMap: pacientesMap,
      citaSeleccionada: citaSeleccionada,
      pacienteSeleccionado: pacienteSeleccionado,
      pacienteDetalleSeleccionado: pacienteDetalleSeleccionado,
      cargandoHistoriaPaciente: cargandoHistoriaPaciente,
      historiasPreviasPaciente: historiasPreviasPaciente,
      examenesPendientes: examenesPendientes,
      pacientesExamenesMap: pacientesExamenesMap,
      filtroEstado: filtroEstado,
      idDoctor: idDoctor,
      diasBloqueados: diasBloqueados,
      onIrAHoy: onIrAHoy,
      onCambiarSemana: onCambiarSemana,
      onSeleccionarDia: onSeleccionarDia,
      onFiltroChanged: onFiltroChanged,
      onSeleccionarCita: onSeleccionarCita,
      onEditarCita: onEditarCita,
      onMarcarLlegada: onMarcarLlegada,
      onCambiarEstado: onCambiarEstado,
      onAbrirHistoria: onAbrirHistoria,
      onExtenderDuracion: onExtenderDuracion,
      onAbrirFichaReceta: onAbrirFichaReceta,
      onVerHistoriaCompleta: onVerHistoriaCompleta,
      onRevisarExamen: onRevisarExamen,
      onNuevaCita: onNuevaCita,
      onOrdenMedica: onOrdenMedica,
      onReposoMedico: onReposoMedico,
      onInterconsulta: onInterconsulta,
      onAgendarEnHorario: onAgendarEnHorario,
      onVitalsActualizados: onVitalsActualizados,
      onDiasBloqueadosActualizados: onDiasBloqueadosActualizados,
    );
  }
}

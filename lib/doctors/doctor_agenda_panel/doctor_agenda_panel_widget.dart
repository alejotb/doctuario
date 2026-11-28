import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/supabase_auth/auth_util.dart';
import '../../backend/supabase/supabase.dart';
import '../../flutter_flow/flutter_flow_util.dart';
import '../../my_account/home/home_widget.dart';
import 'components/agenda_metrics_strip.dart';
import 'services/agenda_appointment_actions.dart';
import 'views/agenda_responsive_content.dart';
import 'dialogs/edit_appointment_dialog.dart';
import 'dialogs/manual_appointment_dialog.dart';
import 'dialogs/doctor_delay_broadcast_dialog.dart';
import 'dialogs/clinical_history_quick_modal.dart';
import 'dialogs/review_lab_exam_dialog.dart';
import '../doctor_consultas_realizadas/doctor_consultas_realizadas_widget.dart';
import '../../services/doctor_patient_sync_service.dart';
import '../../services/doctor_subscription_service.dart';
import '../../services/doctor_vacation_service.dart';
import '../../services/i18n_service.dart';

class DoctorAgendaPanelWidget extends StatefulWidget {
  final String idDoctor;
  final String? idSedeInicial;

  const DoctorAgendaPanelWidget({
    super.key,
    required this.idDoctor,
    this.idSedeInicial,
  });

  static String routeName = 'DoctorAgendaPanel';
  static String routePath = '/doctorAgendaPanel';

  @override
  State<DoctorAgendaPanelWidget> createState() => _DoctorAgendaPanelWidgetState();
}

class _DoctorAgendaPanelWidgetState extends State<DoctorAgendaPanelWidget>
    with WidgetsBindingObserver {
  DateTime _fechaSeleccionada = DateTime.now();
  late DateTime _inicioSemana;
  List<CitasRow> _citasDelDia = [], _citasDeLaSemana = [];
  List<DoctorSedesRow> _sedes = [];
  final Map<String, UsuariosRow> _pacientesMap = {};
  bool _isLoading = true, _modoSeleccionTurno = false, _cargandoHistoriaPaciente = false;
  String? _sedeSeleccionadaId, _doctorPhotoUrl, _doctorNombre, _doctorEspecialidad;
  int? _doctorLimitePacientesDia; Set<String> _diasBloqueados = {};
  CitasRow? _citaSeleccionada; UsuariosRow? _pacienteSeleccionado; PacientesRow? _pacienteDetalleSeleccionado;
  List<HistoriasClinicasRow> _historiasPreviasPaciente = []; List<ExamenesMedicosRow> _examenesPendientes = [];
  Map<String, UsuariosRow> _pacientesExamenesMap = {}; String _filtroEstado = 'todos';
  RealtimeChannel? _citasChannel;
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sedeSeleccionadaId = widget.idSedeInicial;
    _fechaSeleccionada = DateTime.now();
    _inicioSemana = _calcularInicioSemana(_fechaSeleccionada);
    I18nService.instance.addListener(_onLocaleChanged);
    _cargarDatos();
    _suscribirRealtimeCitas();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) _cargarDatos();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _cargarDatos();
    }
  }

  void _suscribirRealtimeCitas() {
    if (widget.idDoctor.isEmpty) return;
    _citasChannel = SupaFlow.client
        .channel('doc-citas-${widget.idDoctor}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'citas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_doctor',
            value: widget.idDoctor,
          ),
          callback: (_) {
            if (mounted) _cargarDatos();
          },
        )
        .subscribe();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncTimer?.cancel();
    if (_citasChannel != null) {
      SupaFlow.client.removeChannel(_citasChannel!);
      _citasChannel = null;
    }
    I18nService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  DateTime _calcularInicioSemana(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - DateTime.monday), 0, 0, 0);

  void _cambiarSemana(int delta) {
    setState(() { _inicioSemana = _inicioSemana.add(Duration(days: 7 * delta)); _fechaSeleccionada = _inicioSemana; });
    _cargarDatos();
  }

  void _irAHoy() {
    final now = DateTime.now();
    setState(() { _fechaSeleccionada = now; _inicioSemana = _calcularInicioSemana(now); });
    _cargarDatos();
  }

  Future<void> _seleccionarDia(DateTime dia) async {
    final inicioSemanaDia = _calcularInicioSemana(dia);
    if (inicioSemanaDia != _inicioSemana) {
      _inicioSemana = inicioSemanaDia;
      _fechaSeleccionada = dia;
      await _cargarDatos();
      return;
    }

    setState(() {
      _fechaSeleccionada = dia;
      _citasDelDia = _citasDeLaSemana
          .where((c) => c.fechaHora?.toLocal() != null && DateUtils.isSameDay(c.fechaHora!.toLocal(), dia))
          .toList()
        ..sort((a, b) => (a.fechaHoraEstimadaActual ?? a.fechaHora ?? DateTime.now())
            .compareTo(b.fechaHoraEstimadaActual ?? b.fechaHora ?? DateTime.now()));

      if (_citasDelDia.isNotEmpty) {
        final enConsulta = _citasDelDia.where((c) => c.estado == 'en_consulta');
        _seleccionarCita(enConsulta.isNotEmpty ? enConsulta.first : _citasDelDia.first, autoCargar: false);
      } else {
        _citaSeleccionada = null;
        _pacienteSeleccionado = null;
        _pacienteDetalleSeleccionado = null;
        _historiasPreviasPaciente = [];
      }
    });

    final idsFaltantes = _citasDelDia
        .map((c) => c.idPaciente)
        .whereType<String>()
        .where((id) => !_pacientesMap.containsKey(id) || (_pacientesMap[id]?.nombre?.trim().isEmpty ?? true))
        .toSet()
        .toList();

    if (idsFaltantes.isNotEmpty) {
      await _llenarPacientesMap(idsFaltantes);
      if (mounted) {
        setState(() {
          if (_citaSeleccionada != null) {
            _pacienteSeleccionado = _pacientesMap[_citaSeleccionada!.idPaciente];
          }
        });
      }
    }
  }

  Future<void> _llenarPacientesMap(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final client = DualDatabaseConfig.instance.doctorClient;
      final pacRows = await client.from('pacientes').select().inFilter('id', ids);
      for (final p in (pacRows as List)) {
        _pacientesMap[p['id'].toString()] = UsuariosRow(Map<String, dynamic>.from(p));
      }
      final usrs = await UsuariosTable().queryRows(queryFn: (q) => q.inFilter('id', ids));
      for (final u in usrs) {
        if (_pacientesMap.containsKey(u.id)) {
          final m = Map<String, dynamic>.from(_pacientesMap[u.id]!.data);
          if (u.nombre != null && u.nombre!.isNotEmpty) m['nombre'] = u.nombre;
          if (u.fotoUrl != null && u.fotoUrl!.isNotEmpty) m['foto_url'] = u.fotoUrl;
          if (u.cedula != null && u.cedula!.isNotEmpty) m['cedula'] = u.cedula;
          if (u.telefono != null && u.telefono!.isNotEmpty) m['telefono'] = u.telefono;
          if (u.ciudadOrigen != null && u.ciudadOrigen!.isNotEmpty) m['ciudad_origen'] = u.ciudadOrigen;
          _pacientesMap[u.id] = UsuariosRow(m);
        } else {
          _pacientesMap[u.id] = u;
        }
      }
    } catch (_) {}
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = SupaFlow.client.auth.currentUser;
      final currentUid = currentUser?.id ?? '';
      final meta = currentUser?.userMetadata ?? const <String, dynamic>{};
      final metaRole = (meta['rol']?.toString() ?? '').trim().toLowerCase();
      final currentUserList = await UsuariosTable().queryRows(queryFn: (q) => q.eq('id', currentUid));
      final role = ((currentUserList.isNotEmpty ? currentUserList.first.rol : null) ?? metaRole).trim().toLowerCase();
      if (role != 'doctor' && metaRole != 'doctor' && !DualDatabaseConfig.instance.isDoctorViewActive) {
        if (mounted) {
          final isEs = I18nService.instance.isSpanish;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEs ? 'Acceso restringido: Esta vista es exclusiva para doctores.' : 'Restricted access: This view is exclusive to doctors.'),
            backgroundColor: Colors.redAccent,
          ));
          context.goNamedAuth(HomeWidget.routeName, mounted);
        }
        return;
      }

      await DoctorSubscriptionService.instance.verificarEstadoDoctor(idDoctor: widget.idDoctor);
      final docUserList = await UsuariosTable().queryRows(queryFn: (q) => q.eq('id', widget.idDoctor));
      final u = docUserList.isNotEmpty ? docUserList.first : null;
      _doctorPhotoUrl = (u?.fotoUrl?.trim().isNotEmpty ?? false) ? u!.fotoUrl : (meta['foto_url']?.toString() ?? currentUserPhoto);
      _doctorNombre = (u?.nombre?.trim().isNotEmpty ?? false) ? u!.nombre : (meta['nombre']?.toString() ?? meta['full_name']?.toString());
      try {
        final docRows = await DoctoresTable().queryRows(queryFn: (q) => q.eq('id', widget.idDoctor).limit(1));
        if (docRows.isNotEmpty) {
          _doctorEspecialidad = docRows.first.especialidad ?? meta['especialidad']?.toString();
          _doctorLimitePacientesDia = docRows.first.limitePacientesDia;
        } else {
          _doctorEspecialidad = meta['especialidad']?.toString();
        }
        await DoctorPatientSyncService().asegurarDoctorEnBaseClinica(idDoctor: widget.idDoctor, nombre: _doctorNombre, fotoUrl: _doctorPhotoUrl, especialidad: _doctorEspecialidad);
      } catch (_) {}

      _diasBloqueados = await DoctorVacationService.instance.obtenerDiasBloqueados(widget.idDoctor);
      _sedes = await DoctorSedesTable().queryRows(queryFn: (q) => q.eq('id_doctor', widget.idDoctor));
      if (_sedeSeleccionadaId != null && !_sedes.any((s) => s.id == _sedeSeleccionadaId)) {
        _sedeSeleccionadaId = null;
      }

      final finSemana = _inicioSemana.add(const Duration(days: 7, seconds: -1));
      _citasDeLaSemana = await CitasTable().queryRows(
        queryFn: (q) {
          var query = q
              .eq('id_doctor', widget.idDoctor)
              .gte('fecha_hora', _inicioSemana.toUtc().toIso8601String())
              .lte('fecha_hora', finSemana.toUtc().toIso8601String())
              .neq('estado', 'cancelada');
          if (_sedeSeleccionadaId != null) query = query.eq('id_sede', _sedeSeleccionadaId!);
          return query;
        },
      );

      final inicioDia = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day, 0, 0, 0);
      final finDia = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day, 23, 59, 59);

      _citasDelDia = await CitasTable().queryRows(
        queryFn: (q) {
          var query = q
              .eq('id_doctor', widget.idDoctor)
              .gte('fecha_hora', inicioDia.toUtc().toIso8601String())
              .lte('fecha_hora', finDia.toUtc().toIso8601String())
              .neq('estado', 'cancelada');
          if (_sedeSeleccionadaId != null) query = query.eq('id_sede', _sedeSeleccionadaId!);
          return query.order('fecha_hora_estimada_actual', ascending: true);
        },
      );

      final idsPacientes = _citasDeLaSemana.map((c) => c.idPaciente).whereType<String>().toSet().toList();
      await _llenarPacientesMap(idsPacientes);

      if (_citasDelDia.isNotEmpty) {
        final enConsulta = _citasDelDia.where((c) => c.estado == 'en_consulta');
        final citaParaActivar = enConsulta.isNotEmpty ? enConsulta.first : _citasDelDia.first;
        _seleccionarCita(citaParaActivar, autoCargar: false);
      } else {
        _citaSeleccionada = null;
        _pacienteSeleccionado = null;
        _pacienteDetalleSeleccionado = null;
        _historiasPreviasPaciente = [];
      }

      _examenesPendientes = await ExamenesMedicosTable().queryRows(
        queryFn: (q) => q.or('id_doctor.eq.${widget.idDoctor},id_doctor.is.null').order('created_at', ascending: false).limit(10),
      );
      _examenesPendientes.sort((a, b) => (a.fechaEntrega ?? a.createdAt.add(const Duration(days: 7)))
          .compareTo(b.fechaEntrega ?? b.createdAt.add(const Duration(days: 7))));
      final idsPacientesExamenes = _examenesPendientes.map((e) => e.idPaciente).whereType<String>().toSet().toList();
      if (idsPacientesExamenes.isNotEmpty) {
        final usuariosEx = await UsuariosTable().queryRows(queryFn: (q) => q.inFilter('id', idsPacientesExamenes));
        _pacientesExamenesMap = {for (var u in usuariosEx) u.id: u};
      }
    } catch (e) {
      debugPrint('Error cargando agenda del doctor: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarCita(CitasRow cita, {bool autoCargar = true}) async {
    _citaSeleccionada = cita;
    _pacienteSeleccionado = _pacientesMap[cita.idPaciente];
    if (cita.idPaciente != null && cita.idPaciente!.isNotEmpty) {
      if (_pacienteSeleccionado == null || (_pacienteSeleccionado?.nombre?.trim().isEmpty ?? true)) {
        await _llenarPacientesMap([cita.idPaciente!]);
        if (mounted) setState(() => _pacienteSeleccionado = _pacientesMap[cita.idPaciente]);
      }
      setState(() => _cargandoHistoriaPaciente = true);
      try {
        final pRows = await PacientesTable().querySingleRow(queryFn: (q) => q.eq('id', cita.idPaciente!));
        if (pRows.isNotEmpty) _pacienteDetalleSeleccionado = pRows.first;
        _historiasPreviasPaciente = await HistoriasClinicasTable().queryRows(
          queryFn: (q) => q.eq('id_paciente', cita.idPaciente!).order('created_at', ascending: false).limit(5),
        );
      } catch (e) {
        debugPrint('Error cargando historia: $e');
      } finally {
        if (mounted) setState(() => _cargandoHistoriaPaciente = false);
      }
    }
  }

  Future<void> _extenderDuracionCita(CitasRow cita, int minutosExtra) async {
    if (await AgendaAppointmentActions.extenderDuracion(context: context, idDoctor: widget.idDoctor, cita: cita, minutosExtra: minutosExtra)) _cargarDatos();
  }

  Future<void> _marcarLlegadaCita(CitasRow cita) async {
    if (await AgendaAppointmentActions.marcarLlegada(context: context, cita: cita)) _cargarDatos();
  }

  Future<void> _cambiarEstadoCita(CitasRow cita, String nuevoEstado) async {
    if (await AgendaAppointmentActions.cambiarEstado(context: context, cita: cita, nuevoEstado: nuevoEstado)) _cargarDatos();
  }

  void _mostrarDialogoEditarCita(CitasRow cita, UsuariosRow? paciente) =>
      EditAppointmentDialog.show(context, cita: cita, paciente: paciente, onCitaActualizada: _cargarDatos);

  DoctorSedesRow? get _sedeActual {
    if (_sedeSeleccionadaId == null) return _sedes.isNotEmpty ? _sedes.first : null;
    final matches = _sedes.where((s) => s.id == _sedeSeleccionadaId);
    return matches.isNotEmpty ? matches.first : (_sedes.isNotEmpty ? _sedes.first : null);
  }

  void _mostrarDialogoNuevaCita({bool esEmergencia = false, DateTime? fecha, String? hora}) {
    if (DoctorSubscriptionService.instance.isReadOnly) {
      DoctorSubscriptionService.instance.mostrarModalRestriccionPago(context);
      return;
    }
    ManualAppointmentDialog.show(
      context: context, idDoctor: widget.idDoctor, sedes: _sedes, initialSedeId: _sedeSeleccionadaId,
      initialFecha: fecha ?? _fechaSeleccionada, initialHora: hora, esEmergencia: esEmergencia,
      especialidadDoctor: _doctorEspecialidad,
      onCitaCreada: ([DateTime? f]) {
        if (f != null) {
          setState(() { _fechaSeleccionada = f; _inicioSemana = _calcularInicioSemana(f); });
        }
        _cargarDatos();
      },
    );
  }

  void _iniciarModoNuevaCita() {
    if (DoctorSubscriptionService.instance.isReadOnly) {
      DoctorSubscriptionService.instance.mostrarModalRestriccionPago(context);
      return;
    }
    setState(() => _modoSeleccionTurno = true);
  }

  void _cancelarModoTurno() => setState(() => _modoSeleccionTurno = false);

  void _agendarEnHorario(DateTime fecha, String hora) {
    final isEs = I18nService.instance.isSpanish;
    if (DoctorVacationService.estaBloqueado(fecha, _diasBloqueados)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEs
            ? 'El doctor no estará disponible el ${DateFormat('dd/MM/yyyy').format(fecha)}.'
            : 'Date ${DateFormat('dd/MM/yyyy').format(fecha)} is blocked for vacation or time off.'),
        backgroundColor: const Color(0xFFD97706),
      ));
      return;
    }
    _cancelarModoTurno();
    _mostrarDialogoNuevaCita(fecha: fecha, hora: hora);
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final loc = isEs ? 'es' : 'en';
    final finSemana = _inicioSemana.add(const Duration(days: 6));
    final tituloMes = DateFormat('MMMM yyyy', loc).format(_fechaSeleccionada).toUpperCase();
    final rangoSemanaStr =
        '${_inicioSemana.day} - ${finSemana.day} ${DateFormat('MMM', loc).format(finSemana)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1000;
                return RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 14, vertical: 16),
                    children: [
                      const DoctorReadOnlyBannerWidget(),
                      AgendaMetricsStrip(
                        citasDelDia: _citasDelDia, examenesPendientes: _examenesPendientes,
                        fechaSeleccionada: _fechaSeleccionada, isDesktop: isDesktop,
                        sedes: _sedes, sedeSeleccionadaId: _sedeSeleccionadaId,
                        onSedeChanged: (val) { setState(() => _sedeSeleccionadaId = val); _cargarDatos(); },
                      ),
                      const SizedBox(height: 16),
                      AgendaResponsiveContent(
                        isDesktop: isDesktop, tituloMes: tituloMes, rangoSemanaStr: rangoSemanaStr,
                        inicioSemana: _inicioSemana, fechaSeleccionada: _fechaSeleccionada,
                        citasDeLaSemana: _citasDeLaSemana, citasDelDia: _citasDelDia, pacientesMap: _pacientesMap,
                        citaSeleccionada: _citaSeleccionada, pacienteSeleccionado: _pacienteSeleccionado,
                        pacienteDetalleSeleccionado: _pacienteDetalleSeleccionado,
                        cargandoHistoriaPaciente: _cargandoHistoriaPaciente,
                        historiasPreviasPaciente: _historiasPreviasPaciente,
                        examenesPendientes: _examenesPendientes, pacientesExamenesMap: _pacientesExamenesMap,
                        filtroEstado: _filtroEstado, idDoctor: widget.idDoctor, diasBloqueados: _diasBloqueados,
                        sedeActual: _sedeActual, limitePacientesDia: _doctorLimitePacientesDia,
                        modoSeleccionTurno: _modoSeleccionTurno, onCancelarModoTurno: _cancelarModoTurno,
                        onActivarModoTurno: _iniciarModoNuevaCita, onIrAHoy: _irAHoy,
                        onCambiarSemana: _cambiarSemana, onSeleccionarDia: _seleccionarDia,
                        onFiltroChanged: (val) => setState(() => _filtroEstado = val),
                        onSeleccionarCita: _seleccionarCita, onEditarCita: _mostrarDialogoEditarCita,
                        onMarcarLlegada: _marcarLlegadaCita, onCambiarEstado: _cambiarEstadoCita,
                        onAbrirHistoria: (c, p) => ClinicalHistoryQuickModal.show(context, idDoctor: widget.idDoctor, cita: c, paciente: p, onConsultaFinalizada: _cargarDatos),
                        onExtenderDuracion: _extenderDuracionCita,
                        onRevisarExamen: (e, p) => ReviewLabExamDialog.show(context, examen: e, paciente: p, onExamenRevisado: _cargarDatos),
                        onNuevaCita: _iniciarModoNuevaCita, onAgendarEnHorario: _agendarEnHorario,
                        onVitalsActualizados: _cargarDatos, onDiasBloqueadosActualizados: _cargarDatos,
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: PopupMenuButton<String>(
        tooltip: isEs ? 'Acciones Rápidas' : 'Quick Actions',
        offset: const Offset(0, -320),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF1E293B),
        onSelected: (val) async {
          if (val == 'urgencia') _mostrarDialogoNuevaCita(esEmergencia: true);
          if (val == 'retraso') DoctorDelayBroadcastDialog.show(context, idDoctor: widget.idDoctor, onNotificado: _cargarDatos);
          if (val == 'receta' || val == 'orden' || val == 'reposo' || val == 'interconsulta') _abrirDocumentoModal(val);
        },
        itemBuilder: (ctx) => [
          _menuItem('urgencia', Icons.emergency_rounded, const Color(0xFFE11D48), isEs ? 'Ingresar Urgencia' : 'Emergency Admission', isEs ? 'Atención directa' : 'Immediate care'),
          _menuItem('receta', Icons.description_rounded, const Color(0xFF10B981), isEs ? 'Receta / Ficha' : 'Prescription / Chart', isEs ? 'Emisión e impresión' : 'Issue and print'),
          _menuItem('orden', Icons.science_rounded, const Color(0xFF38BDF8), isEs ? 'Orden Médica' : 'Medical Order', isEs ? 'Lab y Rayos X' : 'Lab & Imaging'),
          _menuItem('reposo', Icons.hotel_rounded, const Color(0xFFA78BFA), isEs ? 'Reposo Médico' : 'Sick Leave', isEs ? 'Permiso o incapacidad' : 'Medical leave certificate'),
          _menuItem('interconsulta', Icons.alt_route_rounded, const Color(0xFF2DD4BF), isEs ? 'Interconsulta' : 'Referral', isEs ? 'Derivación médica' : 'Specialist referral'),
          _menuItem('retraso', Icons.campaign_rounded, const Color(0xFFF59E0B), isEs ? 'Avisar Retraso / Salida' : 'Broadcast Delay / Exit', isEs ? 'Notificar sala de espera' : 'Notify waiting room'),
        ],
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0369A1)]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(isEs ? 'Acciones' : 'Actions', style: GoogleFonts.mooli(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const Icon(Icons.arrow_drop_up_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width >= 900
          ? null
          : BottomNavigationBar(
              currentIndex: 0,
              selectedItemColor: const Color(0xFF0284C7),
              unselectedItemColor: const Color(0xFF64748B),
              backgroundColor: Colors.white,
              type: BottomNavigationBarType.fixed,
              onTap: (idx) {
                if (idx == 1) {
                  DoctorConsultasRealizadasWidget.open(context, idDoctor: widget.idDoctor);
                }
              },
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: isEs ? 'Agenda' : 'Schedule',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.assignment_turned_in_rounded),
                  label: isEs ? 'Consultas' : 'Consultations',
                ),
              ],
            ),
    );
  }

  void _abrirDocumentoModal(String tipo) {
    final isEs = I18nService.instance.isSpanish;
    if (DoctorSubscriptionService.instance.isReadOnly) {
      DoctorSubscriptionService.instance.mostrarModalRestriccionPago(context);
      return;
    }
    if (_citaSeleccionada != null) {
      ClinicalHistoryQuickModal.show(context, idDoctor: widget.idDoctor, cita: _citaSeleccionada!, paciente: _pacienteSeleccionado, onConsultaFinalizada: _cargarDatos, tipoDocumentoInicial: tipo);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEs ? 'Selecciona primero un paciente de la lista para emitir el documento.' : 'Please select a patient from the list first to issue the document.')));
    }
  }

  PopupMenuItem<String> _menuItem(String val, IconData icon, Color color, String title, String sub) => PopupMenuItem<String>(
    value: val,
    child: Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
        Text(sub, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
      ]),
    ]),
  );
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/backend/supabase/supabase.dart';
import '/doctors/doctor_agenda_panel/dialogs/doctor_delay_broadcast_dialog.dart';
import '/doctors/doctor_agenda_panel/dialogs/manage_day_appointments_dialog.dart';
import '/doctors/doctor_agenda_panel/dialogs/manual_appointment_dialog.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/i18n_service.dart';
import '/services/secretary_management_service.dart';
import '/services/appointment_sync_service.dart';
import 'components/secretary_doctor_switcher_banner.dart';
import 'dialogs/secretary_patient_detail_modal.dart';
import 'dialogs/upload_patient_study_dialog.dart';

class SecretaryDashboardWidget extends StatefulWidget {
  final String idSecretaria;
  const SecretaryDashboardWidget({super.key, required this.idSecretaria});

  static String routeName = 'SecretaryDashboard';
  static String routePath = '/secretaryDashboard';

  @override
  State<SecretaryDashboardWidget> createState() => _SecretaryDashboardWidgetState();
}

class _SecretaryDashboardWidgetState extends State<SecretaryDashboardWidget> {
  List<UsuariosRow> _doctoresAsignados = [];
  String? _doctorSeleccionadoId, _sedeSeleccionadaId;
  List<DoctorSedesRow> _sedesDoctor = [];
  DateTime _fecha = DateTime.now();
  late DateTime _inicioSemana;
  List<CitasRow> _citas = [], _citasDeLaSemana = [];
  final Map<String, UsuariosRow> _pacientesMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _inicioSemana = _calcularInicioSemana(_fecha);
    _cargarDoctores();
  }

  DateTime _calcularInicioSemana(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

  void _cambiarSemana(int delta) {
    setState(() { _inicioSemana = _inicioSemana.add(Duration(days: 7 * delta)); _fecha = _inicioSemana; });
    _cargarSedesYCitas();
  }

  void _irAHoy() {
    final now = DateTime.now();
    setState(() { _fecha = now; _inicioSemana = _calcularInicioSemana(now); });
    _cargarSedesYCitas();
  }

  Future<void> _seleccionarDia(DateTime dia) async {
    final ini = _calcularInicioSemana(dia);
    setState(() { if (ini != _inicioSemana) _inicioSemana = ini; _fecha = dia; });
    await _cargarSedesYCitas();
  }

  Future<void> _cargarDoctores() async {
    setState(() => _isLoading = true);
    try {
      final docContexts = await SecretaryManagementService().obtenerDoctoresDeSecretaria(widget.idSecretaria);
      if (docContexts.isNotEmpty) {
        _doctoresAsignados = docContexts.map((c) => c.doctor).toList();
        _doctorSeleccionadoId = _doctoresAsignados.first.id;
        _sedeSeleccionadaId = docContexts.first.idSedeAsignada;
      } else {
        final asignaciones = await SecretariaDoctoresTable().queryRows(queryFn: (q) => q.eq('id_secretaria', widget.idSecretaria));
        final ids = asignaciones.map((a) => a.idDoctor).whereType<String>().toList();
        if (ids.isNotEmpty) {
          _doctoresAsignados = await UsuariosTable().queryRows(queryFn: (q) => q.inFilter('id', ids));
          if (_doctoresAsignados.isNotEmpty) _doctorSeleccionadoId = _doctoresAsignados.first.id;
        }
      }
      if (_doctorSeleccionadoId != null) {
        await DualDatabaseConfig.instance.consultarYConectarTenantDoctor(_doctorSeleccionadoId!);
        await _cargarSedesYCitas();
      }
    } catch (e) { debugPrint('Error cargando doctores: $e'); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _cargarSedesYCitas() async {
    if (_doctorSeleccionadoId == null) return;
    try {
      List<DoctorSedesRow> sedes = [];
      try { sedes = await DoctorSedesTable().queryRows(queryFn: (q) => q.eq('id_doctor', _doctorSeleccionadoId!)); } catch (_) {}
      for (final client in [DualDatabaseConfig.instance.doctorClient, DualDatabaseConfig.instance.patientClient]) {
        if (sedes.isNotEmpty) break;
        try {
          final res = await client.from('doctor_sedes').select();
          final all = (res as List).map((r) => DoctorSedesRow(Map<String, dynamic>.from(r))).toList();
          sedes = all.where((s) => s.idDoctor == _doctorSeleccionadoId).toList();
          if (sedes.isEmpty) sedes = all;
        } catch (_) {}
      }
      if (sedes.isEmpty && _sedeSeleccionadaId != null) {
        try { final byId = await DoctorSedesTable().queryRows(queryFn: (q) => q.eq('id', _sedeSeleccionadaId!)); if (byId.isNotEmpty) sedes = byId; } catch (_) {}
      }
      _sedesDoctor = sedes;
      if (_sedesDoctor.isNotEmpty) {
        if (_sedesDoctor.length == 1 || _sedeSeleccionadaId == null || !_sedesDoctor.any((s) => s.id == _sedeSeleccionadaId)) {
          _sedeSeleccionadaId = _sedesDoctor.first.id;
        }
      } else { _sedeSeleccionadaId = null; }

      final finSem = _inicioSemana.add(const Duration(days: 7, seconds: -1));
      _citasDeLaSemana = await CitasTable().queryRows(queryFn: (q) {
        var query = q.eq('id_doctor', _doctorSeleccionadoId!).gte('fecha_hora', _inicioSemana.toUtc().toIso8601String()).lte('fecha_hora', finSem.toUtc().toIso8601String()).neq('estado', 'cancelada');
        return _sedeSeleccionadaId != null ? query.eq('id_sede', _sedeSeleccionadaId!) : query;
      });

      final iDia = DateTime(_fecha.year, _fecha.month, _fecha.day, 0, 0, 0);
      final fDia = DateTime(_fecha.year, _fecha.month, _fecha.day, 23, 59, 59);
      _citas = await CitasTable().queryRows(queryFn: (q) {
        var query = q.eq('id_doctor', _doctorSeleccionadoId!).gte('fecha_hora', iDia.toUtc().toIso8601String()).lte('fecha_hora', fDia.toUtc().toIso8601String()).neq('estado', 'cancelada');
        if (_sedeSeleccionadaId != null) query = query.eq('id_sede', _sedeSeleccionadaId!);
        return query.order('fecha_hora_estimada_actual', ascending: true);
      });

      final idsPac = _citasDeLaSemana.map((c) => c.idPaciente).whereType<String>().toSet().toList();
      if (idsPac.isNotEmpty) {
        try {
          final resPac = await DualDatabaseConfig.instance.doctorClient.from('pacientes').select().inFilter('id', idsPac);
          for (final p in (resPac as List)) { _pacientesMap[p['id'].toString()] = UsuariosRow(Map<String, dynamic>.from(p)); }
          final usrs = await UsuariosTable().queryRows(queryFn: (q) => q.inFilter('id', idsPac));
          for (final u in usrs) {
            if (_pacientesMap.containsKey(u.id)) {
              final m = Map<String, dynamic>.from(_pacientesMap[u.id]!.data);
              if (u.nombre != null && u.nombre!.isNotEmpty) m['nombre'] = u.nombre;
              if (u.fotoUrl != null && u.fotoUrl!.isNotEmpty) m['foto_url'] = u.fotoUrl;
              if (u.cedula != null && u.cedula!.isNotEmpty) m['cedula'] = u.cedula;
              if (u.telefono != null && u.telefono!.isNotEmpty) m['telefono'] = u.telefono;
              _pacientesMap[u.id] = UsuariosRow(m);
            } else { _pacientesMap[u.id] = u; }
          }
        } catch (_) {}
      }
    } catch (e) { debugPrint('Error cargando citas: $e'); }
  }

  void _abrirAgendarCita([DateTime? dia, bool esSobrecita = false]) {
    if (_doctorSeleccionadoId == null) return;
    ManualAppointmentDialog.show(
      context: context, idDoctor: _doctorSeleccionadoId!, sedes: _sedesDoctor,
      initialSedeId: _sedeSeleccionadaId, initialFecha: dia ?? _fecha, esSobrecita: esSobrecita,
      onCitaCreada: ([f]) {
        if (f != null) setState(() { _fecha = f; _inicioSemana = _calcularInicioSemana(f); });
        _cargarSedesYCitas().then((_) { if (mounted) setState(() {}); });
      },
    );
  }

  void _abrirSubirEstudio() => UploadPatientStudyDialog.show(context: context, idSecretaria: widget.idSecretaria, idDoctor: _doctorSeleccionadoId, onExamenSubido: () => _cargarSedesYCitas().then((_) { if (mounted) setState(() {}); }));

  void _abrirAvisarRetraso() {
    if (_doctorSeleccionadoId == null) return;
    DoctorDelayBroadcastDialog.show(context, idDoctor: _doctorSeleccionadoId!, onNotificado: () => _cargarSedesYCitas().then((_) { if (mounted) setState(() {}); }));
  }

  void _abrirGestionarDia() {
    if (_doctorSeleccionadoId == null) return;
    ManageDayAppointmentsDialog.show(context, idDoctor: _doctorSeleccionadoId!, fecha: _fecha, citasDelDia: _citas, onActualizado: _cargarSedesYCitas);
  }

  Future<void> _marcarLlegada(CitasRow cita) async {
    await CitasTable().update(data: {'llegada_confirmada': true, 'hora_llegada': DateTime.now().toIso8601String(), 'estado': 'en_espera'}, matchingRows: (q) => q.eq('id', cita.id));
    await _cargarSedesYCitas();
    if (mounted) setState(() {});
  }

  Future<void> _cambiarEstadoCita(CitasRow cita, String nuevo) async {
    final data = <String, dynamic>{'estado': nuevo};
    if (nuevo == 'en_espera' && (cita.llegadaConfirmada != true)) { data['llegada_confirmada'] = true; data['hora_llegada'] = DateTime.now().toIso8601String(); }
    await CitasTable().update(data: data, matchingRows: (q) => q.eq('id', cita.id));
    if (cita.idDoctor != null) {
      await AppointmentSyncService.instance.actualizarEstadoCita(idCita: cita.id, idDoctor: cita.idDoctor!, nuevoEstado: nuevo);
    }
    await _cargarSedesYCitas();
    if (mounted) setState(() {});
  }

  void _abrirDetallePaciente(CitasRow cita, UsuariosRow doc) => SecretaryPatientDetailModal.show(
    context, cita: cita, paciente: _pacientesMap[cita.idPaciente], doctorActual: doc, sedesDoctor: _sedesDoctor,
    onCambiarEstado: _cambiarEstadoCita, onMarcarLlegada: _marcarLlegada, onActualizar: _cargarSedesYCitas,
  );

  Future<void> _mostrarDialogoVincularDoctor() async {
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(builder: (context, setDlgState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [const Icon(Icons.medical_services_outlined, color: Color(0xFF0284C7)), const SizedBox(width: 8), Text('Vincular Médico', style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 17))]),
        content: Form(key: formKey, child: TextFormField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Correo del Médico', prefixIcon: const Icon(Icons.email_outlined, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: saving ? null : () async {
              if (!formKey.currentState!.validate()) return;
              setDlgState(() => saving = true);
              try {
                await SecretaryManagementService().vincularSecretariaConDoctorPorEmail(idSecretaria: widget.idSecretaria, emailDoctor: emailCtrl.text.trim());
                if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                await _cargarDoctores();
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('¡Solicitud enviada al médico!'), backgroundColor: Color(0xFF0284C7)));
              } catch (e) {
                setDlgState(() => saving = false);
                if (dlgCtx.mounted) ScaffoldMessenger.of(dlgCtx).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Enviar Solicitud'),
          ),
        ],
      )),
    );
  }

  Widget _buildNoDoctoresView(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(18), decoration: const BoxDecoration(color: Color(0xFFE0F2FE), shape: BoxShape.circle), child: const Icon(Icons.support_agent_rounded, size: 50, color: Color(0xFF0284C7))),
        const SizedBox(height: 14),
        Text('¡Bienvenida a Recepción Doctuario!', style: GoogleFonts.mooli(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Aún no estás vinculada a ningún consultorio. Puedes solicitar vincularte aquí:', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _mostrarDialogoVincularDoctor, icon: const Icon(Icons.person_add_alt_1_rounded, size: 17), label: const Text('Vincularme con un Doctor'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
      ]),
    ),
  );

  /// Contenedor único combinado: cabecera de navegación semanal + tira de 7 días + rejilla cuadriculada de citas.
  Widget _buildUnifiedScheduleGrid(BuildContext context, bool isEs, UsuariosRow doctorActual, String tituloMes, String rangoSemanaStr) {
    const diasEs = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const diasEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    Widget buildGridTable() => Column(children: [
      Container(
        decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.2))),
        child: Row(children: List.generate(7, (i) {
          final dia = _inicioSemana.add(Duration(days: i));
          final esHoy = DateUtils.isSameDay(dia, DateTime.now()), esSel = DateUtils.isSameDay(dia, _fecha);
          final count = _citasDeLaSemana.where((c) => c.fechaHora != null && DateUtils.isSameDay(c.fechaHora!, dia)).length;
          final nomDia = isEs ? diasEs[i] : diasEn[i];
          return Expanded(
            child: InkWell(
              onTap: () => _seleccionarDia(dia),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: esSel ? const Color(0xFF0284C7) : (esHoy ? const Color(0xFFE0F2FE) : Colors.transparent),
                  border: Border(right: i < 6 ? const BorderSide(color: Color(0xFFCBD5E1), width: 1) : BorderSide.none),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(nomDia.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: esSel ? Colors.white.withValues(alpha: 0.9) : (esHoy ? const Color(0xFF0284C7) : const Color(0xFF64748B)))),
                  const SizedBox(height: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${dia.day}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: esSel ? Colors.white : (esHoy ? const Color(0xFF0284C7) : const Color(0xFF0F172A)))),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: esSel ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF0284C7), borderRadius: BorderRadius.circular(8)), child: Text('$count', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white))),
                    ],
                  ]),
                ]),
              ),
            ),
          );
        })),
      ),
      Expanded(
        child: CustomPaint(
          painter: _ScheduleGridBackgroundPainter(),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: List.generate(7, (i) {
            final dia = _inicioSemana.add(Duration(days: i));
            final esSel = DateUtils.isSameDay(dia, _fecha);
            final citasDia = _citasDeLaSemana.where((c) => c.fechaHora != null && DateUtils.isSameDay(c.fechaHora!, dia)).toList()
              ..sort((a, b) => (a.fechaHoraEstimadaActual ?? a.fechaHora ?? DateTime.now()).compareTo(b.fechaHoraEstimadaActual ?? b.fechaHora ?? DateTime.now()));

            return Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: esSel ? const Color(0xFFF0F9FF).withValues(alpha: 0.35) : Colors.transparent,
                  border: Border(right: i < 6 ? const BorderSide(color: Color(0xFFCBD5E1), width: 1) : BorderSide.none),
                ),
                child: citasDia.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _abrirAgendarCita(dia),
                              style: OutlinedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0284C7), side: const BorderSide(color: Color(0xFFBAE6FD)), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                              label: Text(isEs ? 'Agendar Cita para este Día' : 'Book Appointment for this Day', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      )
                    : ListView(padding: const EdgeInsets.all(6), children: [
                        ...citasDia.map((c) {
                          final hora = c.fechaHoraEstimadaActual ?? c.fechaHora;
                          final horaStr = hora != null ? '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}' : '--:--';
                          final pac = _pacientesMap[c.idPaciente];
                          final estado = c.estado ?? 'solicitada';
                          final esSobrecita = estado == 'solicitada' || (c.motivo ?? '').contains('[SOBRECITA]');
                          return InkWell(
                            onTap: () => _abrirDetallePaciente(c, doctorActual),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: esSobrecita ? const Color(0xFFFFFBEB) : Colors.white, borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: esSobrecita ? const Color(0xFFF59E0B) : (estado == 'en_espera' ? const Color(0xFF0D9488) : (estado == 'en_consulta' ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1)))),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 2, offset: const Offset(0, 1))],
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(horaStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                  if (c.llegadaConfirmada == true) const Icon(Icons.check_circle, size: 11, color: Color(0xFF10B981))
                                  else if (esSobrecita) const Icon(Icons.hourglass_top_rounded, size: 11, color: Color(0xFFD97706)),
                                ]),
                                const SizedBox(height: 2),
                                Text(pac?.nombre ?? 'Paciente', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                if (esSobrecita) Text(isEs ? 'Por confirmar Dr.' : 'Pending Dr. confirm', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                if (c.motivo != null && c.motivo!.isNotEmpty) Text(c.motivo!.replaceFirst('[SOBRECITA] ', ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
                              ]),
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _abrirAgendarCita(dia, false),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE2E8F0), foregroundColor: const Color(0xFF334155), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7), side: const BorderSide(color: Color(0xFFCBD5E1)))),
                            icon: const Icon(Icons.add_rounded, size: 14),
                            label: Text(isEs ? 'Agregar nueva cita' : 'Add new appointment', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _abrirAgendarCita(dia, true),
                            style: OutlinedButton.styleFrom(backgroundColor: const Color(0xFFFFFBEB), foregroundColor: const Color(0xFFB45309), side: const BorderSide(color: Color(0xFFFDE68A)), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 13),
                            label: Text(isEs ? 'Sobrecitar (Confirma Dr.)' : 'Overbook (Dr. Confirms)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]),
              ),
            );
          })),
        ),
      ),
    ]);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEs ? 'Agenda Médica' : 'Medical Schedule', style: GoogleFonts.mooli(fontSize: 15.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                Text('$rangoSemanaStr • ${isEs ? "Turno Activo" : "Active Shift"}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ])),
              Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(44, 28), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), side: const BorderSide(color: Color(0xFFCBD5E1))), onPressed: _irAHoy, child: Text(isEs ? 'Hoy' : 'Today', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _cambiarSemana(-1)),
                const SizedBox(width: 2),
                IconButton(icon: const Icon(Icons.chevron_right_rounded, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _cambiarSemana(1)),
                const SizedBox(width: 6),
                Text(tituloMes, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) => constraints.maxWidth < 700
                ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: 840, height: constraints.maxHeight, child: buildGridTable()))
                : buildGridTable()),
          ),
        ]),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final doctorActual = _doctoresAsignados.firstWhere((d) => d.id == _doctorSeleccionadoId, orElse: () => UsuariosRow({'nombre': 'Doctor'}));
    final enEsperaCount = _citas.where((c) => (c.estado == 'en_espera' || (c.llegadaConfirmada ?? false)) && c.estado != 'completada' && c.estado != 'en_consulta').length;
    final enConsultaCount = _citas.where((c) => c.estado == 'en_consulta').length;
    final pendientesCount = _citas.where((c) => c.estado == 'solicitada' || c.estado == 'confirmada').length;
    final finSemana = _inicioSemana.add(const Duration(days: 6));
    final tituloMes = DateFormat('MMMM yyyy', isEs ? 'es' : 'en').format(_fecha).toUpperCase();
    final rangoSemanaStr = '${_inicioSemana.day} - ${finSemana.day} ${DateFormat('MMM', isEs ? 'es' : 'en').format(finSemana)}';

    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _doctoresAsignados.isEmpty
              ? _buildNoDoctoresView(context)
              : Column(children: [
                  SecretaryDoctorSwitcherBanner(
                    doctoresAsignados: _doctoresAsignados, doctorSeleccionadoId: _doctorSeleccionadoId,
                    sedesDoctor: _sedesDoctor, sedeSeleccionadaId: _sedeSeleccionadaId,
                    enEsperaCount: enEsperaCount, enConsultaCount: enConsultaCount, pendientesCount: pendientesCount,
                    onVincularDoctor: _mostrarDialogoVincularDoctor,
                    onDoctorChanged: (val) async {
                      if (val != null) await DualDatabaseConfig.instance.consultarYConectarTenantDoctor(val);
                      setState(() { _doctorSeleccionadoId = val; _sedeSeleccionadaId = null; });
                      _cargarSedesYCitas().then((_) { if (mounted) setState(() {}); });
                    },
                    onSedeChanged: (val) {
                      setState(() => _sedeSeleccionadaId = val);
                      _cargarSedesYCitas().then((_) { if (mounted) setState(() {}); });
                    },
                  ),
                  Expanded(child: _buildUnifiedScheduleGrid(context, isEs, doctorActual, tituloMes, rangoSemanaStr)),
                ]),
      floatingActionButton: _doctoresAsignados.isEmpty
          ? null
          : PopupMenuButton<String>(
              tooltip: isEs ? 'Acciones' : 'Actions',
              offset: const Offset(0, -140),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: const Color(0xFF1E293B),
              onSelected: (val) {
                if (val == 'retraso') _abrirAvisarRetraso();
                if (val == 'estudio') _abrirSubirEstudio();
                if (val == 'gestionar_dia') _abrirGestionarDia();
              },
              itemBuilder: (ctx) => [
                _menuItem('retraso', Icons.campaign_rounded, const Color(0xFFF59E0B), isEs ? 'Alerta de Retraso' : 'Delay Alert', isEs ? 'Notificar demora a pacientes' : 'Notify delay to patients'),
                _menuItem('estudio', Icons.upload_file_rounded, const Color(0xFF0D9488), isEs ? 'Subir Estudio' : 'Upload Study', isEs ? 'Adjuntar examen o PDF' : 'Attach lab or PDF study'),
                _menuItem('gestionar_dia', Icons.edit_calendar_rounded, const Color(0xFF38BDF8), isEs ? 'Ajustar Citas del Día' : 'Manage Day Appointments', isEs ? 'Cancelar o mover citas' : 'Cancel or move appointments'),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0D9488)]),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(isEs ? 'Acciones' : 'Actions', style: GoogleFonts.mooli(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const Icon(Icons.arrow_drop_up_rounded, color: Colors.white, size: 18),
                ]),
              ),
            ),
    );
  }
}

class _ScheduleGridBackgroundPainter extends CustomPainter {
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

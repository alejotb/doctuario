import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../backend/supabase/supabase.dart';
import '../../../services/emergency_appointment_service.dart';
import '../../../services/i18n_service.dart';
import 'appointment_duration_studies_section.dart';
import 'appointment_venue_datetime_section.dart';
import 'patient_selector_section.dart';
import '/doctors/doctor_sedes_config/doctor_sedes_config_widget.dart';

/// Diálogo para agendar una nueva cita médica manual, sobrecita o urgencia/emergencia.
class ManualAppointmentDialog extends StatefulWidget {
  final String idDoctor;
  final List<DoctorSedesRow> sedes;
  final String? initialSedeId;
  final DateTime initialFecha;
  final String? initialHora;
  final bool esEmergencia;
  final bool esSobrecita;
  final String? especialidadDoctor;
  final void Function([DateTime? fechaCreada]) onCitaCreada;

  const ManualAppointmentDialog({
    super.key, required this.idDoctor, required this.sedes, this.initialSedeId,
    required this.initialFecha, this.initialHora, this.esEmergencia = false,
    this.esSobrecita = false, this.especialidadDoctor, required this.onCitaCreada,
  });

  static Future<void> show({
    required BuildContext context, required String idDoctor, required List<DoctorSedesRow> sedes,
    String? initialSedeId, required DateTime initialFecha, String? initialHora,
    bool esEmergencia = false, bool esSobrecita = false, String? especialidadDoctor,
    required void Function([DateTime? fechaCreada]) onCitaCreada,
  }) async {
    await showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => ManualAppointmentDialog(
        idDoctor: idDoctor, sedes: sedes, initialSedeId: initialSedeId, initialFecha: initialFecha,
        initialHora: initialHora, esEmergencia: esEmergencia, esSobrecita: esSobrecita,
        especialidadDoctor: especialidadDoctor, onCitaCreada: onCitaCreada,
      ),
    );
  }

  @override
  State<ManualAppointmentDialog> createState() => _ManualAppointmentDialogState();
}

class _ManualAppointmentDialogState extends State<ManualAppointmentDialog> {
  UsuariosRow? _pacienteSel;
  bool _crearNuevo = false, _isSaving = false, _esNino = false, _esFamiliar = false;
  late bool _esSobrecita;

  final _nombreCtrl = TextEditingController(), _cedulaCtrl = TextEditingController();
  final _tlfCtrl = TextEditingController(), _ciudadCtrl = TextEditingController();
  final _nombreRepCtrl = TextEditingController(), _cedulaRepCtrl = TextEditingController();
  final _colegaCtrl = TextEditingController();
  DateTime? _fechaNacNuevo;

  List<DoctorSedesRow> _sedesLocales = [];
  String? _idSedeCita, _sedeDetectadaAuto;
  late DateTime _fechaCita;
  late String _horaSeleccionadaStr;
  late TextEditingController _motivoCtrl;
  int _duracionMinutos = 30;
  List<String> _estudiosSeleccionados = [];
  String _lazoFamiliar = 'Hijo(a)';

  static const List<String> _horasDisponibles = [
    '07:30 AM', '08:00 AM', '08:30 AM', '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM',
    '11:00 AM', '11:30 AM', '12:00 PM', '01:30 PM', '02:00 PM', '02:30 PM', '03:00 PM',
    '03:30 PM', '04:00 PM', '04:30 PM', '05:00 PM', '05:30 PM', '06:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _esSobrecita = widget.esSobrecita;
    _sedesLocales = List.from(widget.sedes);
    _fechaCita = widget.initialFecha;
    _horaSeleccionadaStr = widget.initialHora ?? '08:30 AM';
    if (!_horasDisponibles.contains(_horaSeleccionadaStr)) _horaSeleccionadaStr = _horasDisponibles.first;
    _motivoCtrl = TextEditingController(text: widget.esEmergencia ? 'Atención de Urgencia en Consultorio' : 'Consulta Médica Presencial');
    _idSedeCita = widget.initialSedeId;

    if (_sedesLocales.isNotEmpty) {
      _detectarSedePorFechaHora(_fechaCita, _horaSeleccionadaStr);
    } else {
      _cargarSedesYDetectar();
    }
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _cedulaCtrl, _tlfCtrl, _ciudadCtrl, _nombreRepCtrl, _cedulaRepCtrl, _motivoCtrl, _colegaCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarSedesYDetectar() async {
    try {
      var rows = await DoctorSedesTable().queryRows(queryFn: (q) => q.eq('id_doctor', widget.idDoctor));
      if (rows.isEmpty) rows = await DoctorSedesTable().queryRows(queryFn: (q) => q);
      if (mounted && rows.isNotEmpty) setState(() { _sedesLocales = rows; _detectarSedePorFechaHora(_fechaCita, _horaSeleccionadaStr); });
    } catch (_) {}
  }

  void _navegarAConfigurarSedes() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorSedesConfigWidget(idDoctor: widget.idDoctor)))
        .then((_) { if (mounted) _cargarSedesYDetectar(); });
  }

  void _detectarSedePorFechaHora(DateTime fecha, String horaStr) {
    if (_sedesLocales.isEmpty) return;
    if (_sedesLocales.length == 1) { _idSedeCita = _sedesLocales.first.id; _sedeDetectadaAuto = _sedesLocales.first.nombreSede; return; }
    const diasNombres = ['', 'lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'];
    const diasCompletos = ['', 'lunes', 'martes', 'miércoles', 'miercoles', 'jueves', 'viernes', 'sábado', 'sabado', 'domingo'];
    final diaSemana = fecha.weekday;
    DoctorSedesRow? coincidencia;
    for (final s in _sedesLocales) {
      final d = (s.diasAtencion ?? '').toLowerCase();
      if (d.contains(diasNombres[diaSemana]) || d.contains(diasCompletos[diaSemana]) ||
          (d.contains('lunes a viernes') && diaSemana <= 5) || d.contains('todos los d')) { coincidencia = s; break; }
    }
    if (coincidencia != null) {
      _idSedeCita = coincidencia.id;
      _sedeDetectadaAuto = coincidencia.nombreSede;
    } else if (_idSedeCita == null) {
      _idSedeCita = _sedesLocales.first.id;
      _sedeDetectadaAuto = null;
    }
  }

  Future<void> _crearSedePrincipalRapida() async {
    setState(() => _isSaving = true);
    try {
      final newId = const Uuid().v4();
      final docId = await _resolverIdDoctor();
      await DualDatabaseConfig.instance.doctorClient.from('doctor_sedes').insert({
        'id': newId, 'id_doctor': docId, 'nombre_sede': 'Consultorio Principal', 'tipo_lugar': 'privado',
        'dias_atencion': 'Lunes a Viernes', 'modalidad_atencion': 'cita_previa', 'es_principal': true, 'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      final rows = await DoctorSedesTable().queryRows(queryFn: (q) => q.eq('id', newId));
      if (mounted && rows.isNotEmpty) {
        setState(() { _sedesLocales.add(rows.first); _idSedeCita = newId; _sedeDetectadaAuto = 'Consultorio Principal'; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Sede Principal creada exitosamente.'), backgroundColor: Color(0xFF0284C7)));
      }
    } catch (e) {
      debugPrint('Error creando sede rapida: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      final m = int.parse(hm[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && h < 12) h += 12;
      if (parts.length > 1 && parts[1].toUpperCase() == 'AM' && h == 12) h = 0;
      return TimeOfDay(hour: h, minute: m);
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 30);
    }
  }

  Future<String> _resolverIdDoctor() async {
    final docClient = DualDatabaseConfig.instance.doctorClient;
    try {
      final doc = await docClient.from('doctores').select('id').eq('id', widget.idDoctor).limit(1);
      if (doc.isNotEmpty) return widget.idDoctor;
    } catch (_) {}
    try {
      await docClient.from('usuarios').upsert({'id': widget.idDoctor, 'rol': 'doctor'});
      await docClient.from('doctores').upsert({'id': widget.idDoctor});
      return widget.idDoctor;
    } catch (_) {}
    for (final s in _sedesLocales) {
      if (s.idDoctor != null && s.idDoctor!.isNotEmpty) return s.idDoctor!;
    }
    try {
      final docs = await docClient.from('doctores').select('id').limit(1);
      if (docs.isNotEmpty) return docs.first['id'].toString();
    } catch (_) {}
    return widget.idDoctor;
  }

  Future<void> _guardarCita() async {
    if (_crearNuevo) {
      if (_nombreCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_esNino ? 'Ingresa el nombre del niño(a)' : 'Ingresa el nombre del paciente')));
        return;
      }
      if (_esNino && _nombreRepCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa el nombre del padre o representante')));
        return;
      }
    } else if (_pacienteSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor selecciona o registra un paciente.')));
      return;
    }

    String? pacienteIdFinal;
    final docClient = DualDatabaseConfig.instance.doctorClient;
    var sedeElegidaId = _idSedeCita ?? (_sedesLocales.isNotEmpty ? _sedesLocales.first.id : null);

    if (sedeElegidaId == null) {
      await _crearSedePrincipalRapida();
      sedeElegidaId = _idSedeCita;
      if (!mounted) return;
    }
    if (sedeElegidaId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor registra o selecciona la sede de atención.')));
      return;
    }

    setState(() => _isSaving = true);
    final docIdValido = await _resolverIdDoctor();
    final baseMotivo = _motivoCtrl.text.trim().isNotEmpty ? _motivoCtrl.text.trim() : (widget.esEmergencia ? 'Atención de Urgencia' : 'Consulta Médica');
    final rawMotivo = _estudiosSeleccionados.isNotEmpty ? '$baseMotivo | Estudios: ${_estudiosSeleccionados.join(", ")}' : baseMotivo;
    final motivoFinal = _esSobrecita && !rawMotivo.startsWith('[SOBRECITA]') ? '[SOBRECITA] $rawMotivo' : rawMotivo;

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      if (_crearNuevo) {
        final newId = const Uuid().v4();
        final fechaNacStr = _fechaNacNuevo != null
            ? '${_fechaNacNuevo!.year.toString().padLeft(4, '0')}-${_fechaNacNuevo!.month.toString().padLeft(2, '0')}-${_fechaNacNuevo!.day.toString().padLeft(2, '0')}'
            : null;
        final cedulaFinal = _esNino
            ? (_cedulaCtrl.text.trim().isNotEmpty ? _cedulaCtrl.text.trim() : (_cedulaRepCtrl.text.trim().isNotEmpty ? 'Rep: ${_cedulaRepCtrl.text.trim()}' : null))
            : (_cedulaCtrl.text.trim().isNotEmpty ? _cedulaCtrl.text.trim() : null);
        final telefonoFinal = _tlfCtrl.text.trim().isNotEmpty ? _tlfCtrl.text.trim() : null;
        final ciudadFinal = _ciudadCtrl.text.trim().isNotEmpty ? _ciudadCtrl.text.trim() : null;

        final pacPayload = <String, dynamic>{
          'id': newId,
          'id_doctor': docIdValido,
          'nombre': _nombreCtrl.text.trim(),
          if (cedulaFinal != null) 'cedula': cedulaFinal,
          if (telefonoFinal != null) 'telefono': telefonoFinal,
          if (ciudadFinal != null) 'ciudad_origen': ciudadFinal,
          if (fechaNacStr != null) 'fecha_nacimiento': fechaNacStr,
          'es_menor_edad': _esNino,
          if (_esFamiliar) 'parentesco': _lazoFamiliar,
          if (_esNino) 'nombre_representante': _nombreRepCtrl.text.trim(),
          if (_esNino && _cedulaRepCtrl.text.trim().isNotEmpty) 'cedula_representante': _cedulaRepCtrl.text.trim(),
          'cuenta_vinculada': false,
          'created_at': nowIso,
        };
        try {
          await docClient.from('pacientes').insert(pacPayload);
        } catch (pacErr) {
          debugPrint('Aviso insertando paciente completo, intentando payload base: $pacErr');
          await docClient.from('pacientes').insert({
            'id': newId,
            'id_doctor': docIdValido,
            'nombre': _nombreCtrl.text.trim(),
            if (cedulaFinal != null) 'cedula': cedulaFinal,
            if (telefonoFinal != null) 'telefono': telefonoFinal,
            if (ciudadFinal != null) 'ciudad_origen': ciudadFinal,
            if (fechaNacStr != null) 'fecha_nacimiento': fechaNacStr,
            'created_at': nowIso,
          });
        }
        pacienteIdFinal = newId;
      } else {
        pacienteIdFinal = _pacienteSel!.id;
        try {
          final existePac = await docClient.from('pacientes').select('id').eq('id', pacienteIdFinal).maybeSingle();
          if (existePac == null) {
            final existeUsr = await docClient.from('usuarios').select('id').eq('id', pacienteIdFinal).maybeSingle();
            await docClient.from('pacientes').insert({
              'id': pacienteIdFinal,
              if (existeUsr != null) 'id_usuario': pacienteIdFinal,
              'id_doctor': docIdValido,
              'nombre': _pacienteSel!.nombre ?? 'Paciente',
              if ((_pacienteSel!.cedula ?? '').isNotEmpty) 'cedula': _pacienteSel!.cedula,
              if ((_pacienteSel!.telefono ?? '').isNotEmpty) 'telefono': _pacienteSel!.telefono,
              if ((_pacienteSel!.ciudadOrigen ?? '').isNotEmpty) 'ciudad_origen': _pacienteSel!.ciudadOrigen,
              'created_at': nowIso,
            });
          }
        } catch (e) {
          // Si ya existe en pacientes bajo otro doctor (invisible por RLS en SELECT),
          // el trigger BEFORE INSERT en citas (garantizar_paciente_al_crear_cita) o la fila existente permitirá crear la cita.
          debugPrint('Aviso sincronizando paciente registrado antes de cita: $e');
        }
      }

      if (widget.esEmergencia) {
        await EmergencyAppointmentService().insertarPacienteEmergencia(
          idDoctor: docIdValido, idPaciente: pacienteIdFinal, idSede: sedeElegidaId,
          motivo: motivoFinal, duracionEmergenciaMinutos: _duracionMinutos,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚨 Emergencia ingresada con prioridad.'), backgroundColor: Colors.red));
        }
        widget.onCitaCreada(DateTime.now());
      } else {
        final sedeObj = _sedesLocales.where((s) => s.id == sedeElegidaId).isNotEmpty
            ? _sedesLocales.firstWhere((s) => s.id == sedeElegidaId)
            : (_sedesLocales.isNotEmpty ? _sedesLocales.first : null);
        final esOrdenLlegada = sedeObj?.modalidadAtencion == 'orden_llegada';

        DateTime fechaHoraCompleta;
        int? turnoAsignado;
        if (esOrdenLlegada) {
          final iniDia = DateTime(_fechaCita.year, _fechaCita.month, _fechaCita.day, 0, 0, 0);
          final finDia = DateTime(_fechaCita.year, _fechaCita.month, _fechaCita.day, 23, 59, 59);
          int existentesDia = 0;
          try {
            final resDia = await docClient
                .from('citas')
                .select('id')
                .eq('id_doctor', docIdValido)
                .gte('fecha_hora', iniDia.toUtc().toIso8601String())
                .lte('fecha_hora', finDia.toUtc().toIso8601String())
                .neq('estado', 'cancelada');
            existentesDia = (resDia as List).length;
          } catch (_) {}
          turnoAsignado = existentesDia + 1;
          fechaHoraCompleta = DateTime(_fechaCita.year, _fechaCita.month, _fechaCita.day, 8, 0)
              .add(Duration(minutes: existentesDia));
        } else {
          final time = _parseTimeOfDay(_horaSeleccionadaStr);
          fechaHoraCompleta = DateTime(_fechaCita.year, _fechaCita.month, _fechaCita.day, time.hour, time.minute);
          if (!_esSobrecita) {
            final dup = await docClient.from('citas').select('id').eq('id_doctor', docIdValido).eq('fecha_hora', fechaHoraCompleta.toUtc().toIso8601String()).neq('estado', 'cancelada').limit(1);
            if (dup.isNotEmpty) {
              setState(() => _isSaving = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('⚠️ Ya existe una cita activa el ${_fechaCita.day}/${_fechaCita.month} a las $_horaSeleccionadaStr. Si deseas agendar sobrecupo, activa "Sobrecita".'),
                  backgroundColor: Colors.orange.shade800,
                  duration: const Duration(seconds: 4),
                ));
              }
              return;
            }
          }
        }
        final newCitaId = const Uuid().v4();
        final citaData = <String, dynamic>{
          'id': newCitaId, 'id_doctor': docIdValido, 'id_paciente': pacienteIdFinal, 'id_sede': sedeElegidaId,
          'fecha_hora': fechaHoraCompleta.toUtc().toIso8601String(),
          'fecha_hora_estimada_actual': fechaHoraCompleta.toUtc().toIso8601String(),
          'estado': _esSobrecita ? 'solicitada' : 'confirmada',
          'modalidad_atencion': esOrdenLlegada ? 'orden_llegada' : 'hora_fija',
          if (turnoAsignado != null) 'turno_numero': turnoAsignado,
          if (turnoAsignado != null) 'posicion_cola': turnoAsignado,
          'motivo': motivoFinal, 'trato_especial': _esFamiliar, 'minutos_retraso_acumulados': 0,
          'notas_medicas': _estudiosSeleccionados.isNotEmpty ? 'Estudios: ${_estudiosSeleccionados.join(", ")}' : null,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        try {
          await docClient.from('citas').insert({...citaData, 'duracion_minutos': _duracionMinutos});
        } catch (err) {
          if (err.toString().contains('duracion_minutos')) {
            await docClient.from('citas').insert(citaData);
          } else if (err.toString().contains('citas_id_doctor_fkey')) {
            await docClient.from('doctores').upsert({'id': docIdValido});
            await docClient.from('citas').insert(citaData);
          } else if (err.toString().contains('citas_id_paciente_fkey') || err.toString().contains('23503')) {
            try {
              await docClient.from('pacientes').insert({
                'id': pacienteIdFinal,
                'id_doctor': docIdValido,
                'nombre': _crearNuevo ? _nombreCtrl.text.trim() : (_pacienteSel?.nombre ?? 'Paciente'),
              });
            } catch (_) {}
            await docClient.from('citas').insert(citaData);
          } else {
            rethrow;
          }
        }
        for (final est in _estudiosSeleccionados) {
          try {
            await docClient.from('examenes_medicos').insert({
              'id': const Uuid().v4(), 'id_paciente': pacienteIdFinal, 'id_doctor': docIdValido,
              'id_cita': newCitaId,
              'titulo': est, 'tipo_examen': est, 'fecha_estudio': fechaHoraCompleta.toUtc().toIso8601String(),
              'estado': 'programado', 'notas': 'Programado en cita del ${fechaHoraCompleta.day}/${fechaHoraCompleta.month}/${fechaHoraCompleta.year}',
              'created_at': DateTime.now().toUtc().toIso8601String(),
            });
          } catch (_) {}
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_esSobrecita ? '⏳ Sobrecita enviada. El médico debe confirmarla en su cuenta.' : '✅ Cita agendada exitosamente.'),
            backgroundColor: _esSobrecita ? const Color(0xFFD97706) : Colors.teal,
          ));
        }
        widget.onCitaCreada(fechaHoraCompleta);
      }
    } catch (e) {
      debugPrint('Error al agendar cita: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al agendar cita: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 640;
    final dialogWidth = isMobile ? (screenWidth - 24) : 580.0;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: isMobile ? 16 : 24,
      ),
      titlePadding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 18, isMobile ? 16 : 24, 8),
      contentPadding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 0, isMobile ? 12 : 24, 10),
      actionsPadding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 0, isMobile ? 12 : 16, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          if (widget.esEmergencia) ...[
            const Icon(Icons.emergency_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
          ] else if (_esSobrecita) ...[
            const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFD97706), size: 22),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              widget.esEmergencia
                  ? (isEs ? 'Ingresar Cita de Urgencia' : 'Emergency Appointment')
                  : (_esSobrecita
                      ? (isEs ? 'Sobrecitar Paciente' : 'Overbook Patient')
                      : (isEs ? 'Agendar Nueva Cita' : 'Book New Appointment')),
              style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.esEmergencia)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _esSobrecita ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _esSobrecita ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
                  ),
                  child: SwitchListTile(
                    dense: true,
                    activeTrackColor: const Color(0xFFD97706),
                    title: Text(isEs ? 'Sobrecitar / Cupo adicional' : 'Overbook / Extra patient slot', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    subtitle: Text(isEs ? 'El doctor deberá confirmar esta cita adicional en su cuenta' : 'The doctor must confirm this extra appointment in their account', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    value: _esSobrecita,
                    onChanged: (val) => setState(() => _esSobrecita = val),
                  ),
                ),
              PatientSelectorSection(
                pacienteSel: _pacienteSel, onPacienteSelected: (u) => setState(() => _pacienteSel = u),
                crearNuevo: _crearNuevo, onCrearNuevoChanged: (val) => setState(() => _crearNuevo = val),
                nombreCtrl: _nombreCtrl, cedulaCtrl: _cedulaCtrl, tlfCtrl: _tlfCtrl, ciudadCtrl: _ciudadCtrl,
                fechaNacNuevo: _fechaNacNuevo, onFechaNacChanged: (dt) => setState(() => _fechaNacNuevo = dt),
                esNino: _esNino, onEsNinoChanged: (val) => setState(() => _esNino = val),
                nombreRepCtrl: _nombreRepCtrl, cedulaRepCtrl: _cedulaRepCtrl,
                especialidadDoctor: widget.especialidadDoctor,
                onAutoFillFamiliar: (esFam, col, lazo) => setState(() { _esFamiliar = esFam; _colegaCtrl.text = col; _lazoFamiliar = lazo; }),
              ),
              const SizedBox(height: 14),
              AppointmentVenueDatetimeSection(
                sedes: _sedesLocales, idSedeSeleccionada: _idSedeCita,
                sedeDetectadaAuto: _sedeDetectadaAuto, fechaCita: _fechaCita,
                horaSeleccionadaStr: _horaSeleccionadaStr, esEmergencia: widget.esEmergencia,
                esOrdenLlegada: (_sedesLocales.where((s) => s.id == _idSedeCita).isNotEmpty
                        ? _sedesLocales.firstWhere((s) => s.id == _idSedeCita).modalidadAtencion
                        : (_sedesLocales.isNotEmpty ? _sedesLocales.first.modalidadAtencion : null)) ==
                    'orden_llegada',
                horasDisponibles: _horasDisponibles,
                onSedeChanged: (val) => setState(() { _idSedeCita = val; _sedeDetectadaAuto = null; }),
                onFechaChanged: (picked) => setState(() { _fechaCita = picked; _detectarSedePorFechaHora(picked, _horaSeleccionadaStr); }),
                onHoraChanged: (val) => setState(() { _horaSeleccionadaStr = val; _detectarSedePorFechaHora(_fechaCita, val); }),
                onCrearSedeRapida: _crearSedePrincipalRapida, onIrAConfigurarSedes: _navegarAConfigurarSedes,
              ),
              Text(widget.esEmergencia ? '3. Duración y Estudios:' : '4. Duración y Estudios Médicos:', overflow: TextOverflow.ellipsis, style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              AppointmentDurationStudiesSection(
                idDoctor: widget.idDoctor,
                duracionMinutos: _duracionMinutos, onDuracionChanged: (mins) => setState(() => _duracionMinutos = mins),
                estudiosSeleccionados: _estudiosSeleccionados, onEstudiosChanged: (est) => setState(() => _estudiosSeleccionados = est),
                especialidadDoctor: widget.especialidadDoctor,
              ),
              const SizedBox(height: 14),
              Text(widget.esEmergencia ? '4. Motivo de Urgencia:' : '5. Motivo de Consulta:', overflow: TextOverflow.ellipsis, style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _motivoCtrl,
                decoration: const InputDecoration(labelText: 'Motivo / Observaciones', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), prefixIcon: Icon(Icons.description_outlined, size: 18)),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: Text(isEs ? 'Cancelar' : 'Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.esEmergencia ? Colors.red : (_esSobrecita ? const Color(0xFFD97706) : const Color(0xFF0284C7)),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 12),
          ),
          onPressed: _isSaving ? null : _guardarCita,
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.esEmergencia ? '🚨 Urgencia' : (_esSobrecita ? (isEs ? 'Enviar Sobrecita' : 'Send Overbook') : (isEs ? 'Confirmar Cita' : 'Confirm Appointment'))),
        ),
      ],
    );
  }
}

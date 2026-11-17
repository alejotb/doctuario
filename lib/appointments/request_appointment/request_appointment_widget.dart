import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../backend/supabase/supabase.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../services/symptom_triage_service.dart';
import '../../services/location_maps_service.dart';
import '../../services/appointment_sync_service.dart';
import '../../components/loading_button.dart';
import '../../components/skeleton_shimmer.dart';

class RequestAppointmentWidget extends StatefulWidget {
  final String idDoctor;
  final String? nombreDoctor;
  final String? especialidadDoctor;
  final DateTime? fechaHoraInicial;
  final String? idSedeInicial;
  final String? modalidadInicial;

  const RequestAppointmentWidget({
    super.key,
    required this.idDoctor,
    this.nombreDoctor,
    this.especialidadDoctor,
    this.fechaHoraInicial,
    this.idSedeInicial,
    this.modalidadInicial,
  });

  static String routeName = 'RequestAppointment';
  static String routePath = '/requestAppointment';

  @override
  State<RequestAppointmentWidget> createState() =>
      _RequestAppointmentWidgetState();
}

class _RequestAppointmentWidgetState extends State<RequestAppointmentWidget> {
  List<DoctorSedesRow> _sedes = [];
  String? _sedeSeleccionadaId;
  DateTime _fechaSeleccionada = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _horaSeleccionada = const TimeOfDay(hour: 9, minute: 0);

  final _motivoCtrl = TextEditingController();
  final _sintomasCtrl = TextEditingController();
  final _doctorRefCtrl = TextEditingController();
  String _lazoFamiliar = 'Hijo(a)';
  String _ciudadPaciente = '';

  bool _esFamiliarMedico = false;
  bool _isLoading = true;
  bool _isSaving = false;
  SymptomTriageResult? _triageResult;

  @override
  void initState() {
    super.initState();
    if (widget.fechaHoraInicial != null) {
      _fechaSeleccionada = widget.fechaHoraInicial!;
      _horaSeleccionada = TimeOfDay(
        hour: widget.fechaHoraInicial!.hour,
        minute: widget.fechaHoraInicial!.minute,
      );
    }
    if (widget.idSedeInicial != null) {
      _sedeSeleccionadaId = widget.idSedeInicial;
    }
    _cargarDatosDoctor();
  }

  Future<void> _cargarDatosDoctor() async {
    setState(() => _isLoading = true);
    try {
      _sedes = await DoctorSedesTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', widget.idDoctor),
      );
      if (_sedeSeleccionadaId == null && _sedes.isNotEmpty) {
        _sedeSeleccionadaId = _sedes.first.id;
      }

      final currentUserId = SupaFlow.client.auth.currentUser?.id;
      if (currentUserId != null) {
        final u = await UsuariosTable().querySingleRow(
          queryFn: (q) => q.eq('id', currentUserId),
        );
        if (u.isNotEmpty) {
          final user = u.first;
          _esFamiliarMedico = user.esFamiliarMedico ?? false;
          _doctorRefCtrl.text = user.doctorReferenciaNombre ?? user.nombreDoctorColega ?? '';
          _lazoFamiliar = user.lazoFamiliar ?? 'Hijo(a)';
          _ciudadPaciente = user.ciudadOrigen ?? '';
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos para agendar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DoctorSedesRow? get _sedeSeleccionada {
    if (_sedeSeleccionadaId == null) return null;
    final matches = _sedes.where((s) => s.id == _sedeSeleccionadaId);
    return matches.isNotEmpty ? matches.first : null;
  }

  void _evaluarSintomas(String texto) {
    if (texto.trim().length < 4) {
      setState(() => _triageResult = null);
      return;
    }
    final res = SymptomTriageService().evaluarSintomas(texto);
    setState(() => _triageResult = res);
  }

  Future<void> _solicitarCita() async {
    final currentUserId = SupaFlow.client.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor inicia sesión para solicitar tu cita.')),
      );
      return;
    }

    if (currentUserId == widget.idDoctor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes solicitar una cita médica contigo mismo.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_sedeSeleccionadaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una sede de atención.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final sede = _sedeSeleccionada;
      final modalidad = widget.modalidadInicial ?? (sede?.modalidadAtencion ?? 'hora_fija');

      bool esForaneoAuto = false;
      if (_ciudadPaciente.trim().isNotEmpty && sede != null) {
        final ciudadSede = (sede.ciudad ?? '').toLowerCase().trim();
        final ciudadPac = _ciudadPaciente.toLowerCase().trim();
        if (ciudadSede.isNotEmpty && !ciudadPac.contains(ciudadSede) && !ciudadSede.contains(ciudadPac)) {
          esForaneoAuto = true;
        }
      }

      await UsuariosTable().update(
        data: {
          'es_familiar_medico': _esFamiliarMedico,
          'doctor_referencia_nombre': _esFamiliarMedico ? _doctorRefCtrl.text.trim() : null,
          'nombre_doctor_colega': _esFamiliarMedico ? _doctorRefCtrl.text.trim() : null,
          'lazo_familiar': _esFamiliarMedico ? _lazoFamiliar : null,
          'es_foraneo': esForaneoAuto,
        },
        matchingRows: (q) => q.eq('id', currentUserId),
      );

      final fechaHoraCompleta = DateTime(
        _fechaSeleccionada.year,
        _fechaSeleccionada.month,
        _fechaSeleccionada.day,
        _horaSeleccionada.hour,
        _horaSeleccionada.minute,
      );

      final res = await AppointmentSyncService.instance.solicitarCitaPaciente(
        idDoctor: widget.idDoctor,
        idPaciente: currentUserId,
        idSede: _sedeSeleccionadaId!,
        fechaHora: fechaHoraCompleta,
        modalidadAtencion: modalidad,
        motivo: _motivoCtrl.text.trim().isEmpty ? 'Consulta Médica Presencial' : _motivoCtrl.text.trim(),
        duracionMinutos: 30,
        tratoEspecial: _esFamiliarMedico,
      );

      if (_sintomasCtrl.text.trim().isNotEmpty && _triageResult != null) {
        await SymptomTriageService().guardarTriage(
          idPaciente: currentUserId,
          idCita: res['id'] as String,
          descripcionSintomas: _sintomasCtrl.text.trim(),
          resultado: _triageResult!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🟡 ¡Solicitud de cita enviada! En espera de confirmación del consultorio.'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al agendar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildFormSkeleton() {
    return const SkeletonShimmer(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: double.infinity, height: 75),
            SizedBox(height: 18),
            SkeletonLine(width: 140, height: 16),
            SizedBox(height: 8),
            SkeletonBox(width: double.infinity, height: 48),
            SizedBox(height: 18),
            SkeletonLine(width: 160, height: 16),
            SizedBox(height: 8),
            SkeletonBox(width: double.infinity, height: 100),
            SizedBox(height: 18),
            SkeletonLine(width: 180, height: 16),
            SizedBox(height: 8),
            SkeletonBox(width: double.infinity, height: 60),
            SizedBox(height: 24),
            SkeletonBox(width: double.infinity, height: 48),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sedeActual = _sedeSeleccionada;
    final esOrdenLlegada = (widget.modalidadInicial ?? sedeActual?.modalidadAtencion) == 'orden_llegada';

    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        title: Text('Confirmar Solicitud de Cita', style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        foregroundColor: FlutterFlowTheme.of(context).primaryText,
        elevation: 0.5,
      ),
      body: _isLoading
          ? _buildFormSkeleton()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBAE6FD))),
                    child: Row(
                      children: [
                        const CircleAvatar(backgroundColor: Color(0xFF0284C7), child: Icon(Icons.person, color: Colors.white)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dr(a). ${widget.nombreDoctor ?? "Especialista"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(widget.especialidadDoctor ?? 'Medicina General', style: const TextStyle(fontSize: 12.5, color: Color(0xFF0369A1))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('1. Sede de Consulta:', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _sedeSeleccionadaId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _sedes.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.nombreSede ?? "Consultorio"} (${s.ciudad ?? ""})', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) => setState(() => _sedeSeleccionadaId = val),
                  ),
                  if (sedeActual != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(sedeActual.direccion ?? 'Consultorio', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                          if ((sedeActual.direccion != null && sedeActual.direccion!.isNotEmpty) || (sedeActual.latitud != null && sedeActual.longitud != null))
                            InkWell(
                              onTap: () => LocationMapsService.abrirGoogleMaps(direccion: sedeActual.direccion, ciudad: sedeActual.ciudad, estado: sedeActual.estado, latitud: sedeActual.latitud, longitud: sedeActual.longitud),
                              child: const Text('Ver Mapa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text('2. Fecha y Horario de Atención:', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: Text('${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}'),
                          onPressed: () async {
                            final f = await showDatePicker(context: context, initialDate: _fechaSeleccionada, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                            if (f != null) setState(() => _fechaSeleccionada = f);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          icon: const Icon(Icons.access_time, size: 18),
                          label: Text(esOrdenLlegada ? 'Orden llegada' : _horaSeleccionada.format(context)),
                          onPressed: esOrdenLlegada ? null : () async {
                            final h = await showTimePicker(context: context, initialTime: _horaSeleccionada);
                            if (h != null) setState(() => _horaSeleccionada = h);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('3. Motivo y Síntomas (Opcional):', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _motivoCtrl,
                    decoration: InputDecoration(
                      labelText: 'Motivo principal de consulta',
                      hintText: 'Ej. Chequeo general, control, dolor...',
                      filled: true,
                      fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _sintomasCtrl,
                    maxLines: 2,
                    onChanged: _evaluarSintomas,
                    decoration: InputDecoration(
                      labelText: 'Describe tus síntomas para orientar al doctor',
                      hintText: 'Ej. Fiebre desde hace 2 días...',
                      filled: true,
                      fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (_triageResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: _triageResult!.requiereHospital ? Colors.red.shade50 : Colors.teal.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: _triageResult!.requiereHospital ? Colors.red : Colors.teal)),
                        child: Row(
                          children: [
                            Icon(_triageResult!.requiereHospital ? Icons.warning : Icons.info_outline, color: _triageResult!.requiereHospital ? Colors.red : Colors.teal, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_triageResult!.mensajeOrientacion, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _triageResult!.requiereHospital ? Colors.red.shade900 : Colors.teal.shade900))),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Text('4. Cortesía Profesional:', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: FlutterFlowTheme.of(context).secondaryBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: const Text('🩺 ¿Es familiar de un médico o colega?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: const Text('Para consideración de cortesía profesional.', style: TextStyle(fontSize: 11)),
                          value: _esFamiliarMedico,
                          activeColor: FlutterFlowTheme.of(context).primary,
                          onChanged: (val) => setState(() => _esFamiliarMedico = val ?? false),
                        ),
                        if (_esFamiliarMedico) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: DropdownButtonFormField<String>(
                              initialValue: _lazoFamiliar,
                              decoration: const InputDecoration(labelText: 'Lazo Familiar con el Médico', border: OutlineInputBorder(), isDense: true),
                              items: const [
                                DropdownMenuItem(value: 'Hijo(a)', child: Text('Hijo(a)')),
                                DropdownMenuItem(value: 'Padre/Madre', child: Text('Padre/Madre')),
                                DropdownMenuItem(value: 'Cónyuge', child: Text('Cónyuge / Pareja')),
                                DropdownMenuItem(value: 'Hermano(a)', child: Text('Hermano(a)')),
                                DropdownMenuItem(value: 'Otro', child: Text('Otro familiar')),
                              ],
                              onChanged: (val) => (val != null) ? setState(() => _lazoFamiliar = val) : null,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            child: TextField(
                              controller: _doctorRefCtrl,
                              decoration: const InputDecoration(labelText: 'Nombre del Médico Colega', hintText: 'Ej. Dr. Carlos Mendoza', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  LoadingButton.fullWidth(
                    label: 'Enviar Solicitud de Cita',
                    loadingLabel: 'Enviando solicitud...',
                    isLoading: _isSaving,
                    backgroundColor: const Color(0xFF0284C7),
                    borderRadius: 12.0,
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    onPressed: _solicitarCita,
                  ),
                ],
              ),
            ),
    );
  }
}

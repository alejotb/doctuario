import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../backend/supabase/supabase.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../services/appointment_cancellation_service.dart';
import '../../services/i18n_service.dart';

/// Pantalla donde los pacientes visualizan sus citas médicas en tiempo real,
/// con capacidad de cancelar o reprogramar sus horarios, liberando los cupos automáticamente.
class PatientMyAppointmentsWidget extends StatefulWidget {
  final String idPaciente;

  const PatientMyAppointmentsWidget({super.key, required this.idPaciente});

  static String routeName = 'PatientMyAppointments';
  static String routePath = '/patientMyAppointments';

  @override
  State<PatientMyAppointmentsWidget> createState() =>
      _PatientMyAppointmentsWidgetState();
}

class _PatientMyAppointmentsWidgetState
    extends State<PatientMyAppointmentsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _citas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarCitas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarCitas() async {
    setState(() => _isLoading = true);
    final uid = widget.idPaciente.isNotEmpty
        ? widget.idPaciente
        : (SupaFlow.client.auth.currentUser?.id ?? '');

    if (uid.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final central = DualDatabaseConfig.instance.patientClient;

      // Buscar si el paciente tiene id en tabla pacientes
      final pacRows = await central.from('pacientes').select('id').eq('id_usuario', uid);
      final List<String> pacienteIds = [uid];
      for (final r in pacRows) {
        final idStr = r['id']?.toString();
        if (idStr != null && !pacienteIds.contains(idStr)) pacienteIds.add(idStr);
      }

      final List<dynamic> res = await central
          .from('citas')
          .select('*, doctores(especialidad), doctor_sedes(nombre_sede, direccion)')
          .inFilter('id_paciente', pacienteIds)
          .order('fecha_hora', ascending: false);

      // Enriquecer con nombres de doctores desde usuarios
      final docIds = res.map((c) => c['id_doctor']?.toString()).whereType<String>().toSet().toList();
      Map<String, Map<String, dynamic>> docUsuarios = {};
      if (docIds.isNotEmpty) {
        final List<dynamic> uDocs = await central
            .from('usuarios')
            .select('id, nombre, foto_url')
            .inFilter('id', docIds);
        for (final u in uDocs) {
          docUsuarios[u['id'].toString()] = Map<String, dynamic>.from(u as Map);
        }
      }

      final list = <Map<String, dynamic>>[];
      for (final r in res) {
        final item = Map<String, dynamic>.from(r as Map);
        final dId = item['id_doctor']?.toString();
        if (dId != null && docUsuarios.containsKey(dId)) {
          item['doctor_nombre'] = docUsuarios[dId]?['nombre'];
          item['doctor_foto'] = docUsuarios[dId]?['foto_url'];
        }
        list.add(item);
      }

      if (mounted) {
        setState(() {
          _citas = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando citas del paciente: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _citasProximas {
    final now = DateTime.now();
    return _citas.where((c) {
      final st = (c['estado'] ?? '').toString().toLowerCase();
      if (st == 'cancelada' || st == 'atendida') return false;
      final dt = DateTime.tryParse(c['fecha_hora']?.toString() ?? '')?.toLocal();
      if (dt == null) return true;
      return dt.isAfter(now.subtract(const Duration(hours: 3)));
    }).toList();
  }

  List<Map<String, dynamic>> get _citasPasadas {
    final now = DateTime.now();
    return _citas.where((c) {
      final st = (c['estado'] ?? '').toString().toLowerCase();
      if (st == 'cancelada') return false;
      if (st == 'atendida') return true;
      final dt = DateTime.tryParse(c['fecha_hora']?.toString() ?? '')?.toLocal();
      if (dt == null) return false;
      return dt.isBefore(now.subtract(const Duration(hours: 3)));
    }).toList();
  }

  List<Map<String, dynamic>> get _citasCanceladas {
    return _citas.where((c) => (c['estado'] ?? '').toString().toLowerCase() == 'cancelada').toList();
  }

  Future<void> _cancelarCita(Map<String, dynamic> cita) async {
    final motivoCtrl = TextEditingController(text: 'Imprevisto personal de horario');
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Cancelar Cita Médica', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Estás seguro de que deseas cancelar esta cita? El horario quedará disponible para otros pacientes.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text('Motivo de cancelación:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: motivoCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Cancelación'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final idCita = cita['id']?.toString() ?? '';
    final idDoc = cita['id_doctor']?.toString();
    final idPac = cita['id_paciente']?.toString() ?? widget.idPaciente;

    final ok = await AppointmentCancellationService.instance.cancelarCitaIndividual(
      idCita: idCita,
      motivo: motivoCtrl.text.trim(),
      canceladoPorDoctor: false,
      idDoctor: idDoc,
      idPaciente: idPac,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '✅ Cita cancelada y horario liberado exitosamente.' : 'Error al cancelar la cita.'),
          backgroundColor: ok ? Colors.teal : Colors.red,
        ),
      );
      _cargarCitas();
    }
  }

  Future<void> _reprogramarCita(Map<String, dynamic> cita) async {
    final dtActual = DateTime.tryParse(cita['fecha_hora']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    DateTime fechaSel = dtActual.add(const Duration(days: 1));
    TimeOfDay horaSel = TimeOfDay(hour: dtActual.hour, minute: dtActual.minute);

    final selDate = await showDatePicker(
      context: context,
      initialDate: fechaSel,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (selDate == null || !mounted) return;

    final selTime = await showTimePicker(
      context: context,
      initialTime: horaSel,
    );
    if (selTime == null || !mounted) return;

    final nuevaFechaHora = DateTime(selDate.year, selDate.month, selDate.day, selTime.hour, selTime.minute);
    final idCita = cita['id']?.toString() ?? '';
    final idDoc = cita['id_doctor']?.toString() ?? '';
    final idPac = cita['id_paciente']?.toString() ?? widget.idPaciente;

    try {
      await AppointmentCancellationService.instance.reprogramarCitaIndividual(
        idCita: idCita,
        nuevaFechaHora: nuevaFechaHora,
        motivo: 'Paciente solicitó cambio de horario',
        reprogramadoPorDoctor: false,
        idDoctor: idDoc,
        idPaciente: idPac,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cita reprogramada exitosamente. Horario anterior liberado.'),
            backgroundColor: Colors.teal,
          ),
        );
        _cargarCitas();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo reprogramar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: Column(
        children: [
          Container(
            color: theme.secondaryBackground,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0284C7),
              unselectedLabelColor: theme.secondaryText,
              indicatorColor: const Color(0xFF0284C7),
              tabs: [
                Tab(text: isEs ? 'Próximas (${_citasProximas.length})' : 'Upcoming'),
                Tab(text: isEs ? 'Historial (${_citasPasadas.length})' : 'Past'),
                Tab(text: isEs ? 'Canceladas (${_citasCanceladas.length})' : 'Cancelled'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaCitas(_citasProximas, esProxima: true, isEs: isEs),
                      _buildListaCitas(_citasPasadas, esProxima: false, isEs: isEs),
                      _buildListaCitas(_citasCanceladas, esCancelada: true, isEs: isEs),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaCitas(
    List<Map<String, dynamic>> items, {
    bool esProxima = false,
    bool esCancelada = false,
    required bool isEs,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_note_outlined, size: 54, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                esProxima
                    ? (isEs ? 'No tienes citas médicas próximas agendadas.' : 'No upcoming appointments.')
                    : (esCancelada
                        ? (isEs ? 'No tienes citas canceladas.' : 'No cancelled appointments.')
                        : (isEs ? 'No tienes citas pasadas en tu historial.' : 'No past appointments.')),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarCitas,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, idx) => _buildCardCita(items[idx], esProxima: esProxima, esCancelada: esCancelada, isEs: isEs),
      ),
    );
  }

  Widget _buildCardCita(
    Map<String, dynamic> cita, {
    required bool esProxima,
    bool esCancelada = false,
    required bool isEs,
  }) {
    final dt = DateTime.tryParse(cita['fecha_hora']?.toString() ?? '')?.toLocal();
    final fechaStr = dt != null ? DateFormat('EEEE d \'de\' MMMM', 'es').format(dt) : 'Fecha por confirmar';
    final horaStr = dt != null ? DateFormat('hh:mm a').format(dt) : '--:--';
    final estado = (cita['estado'] ?? 'pendiente').toString().toLowerCase();

    final docNombre = cita['doctor_nombre'] ?? 'Médico Especialista';
    final docFoto = cita['doctor_foto']?.toString() ?? '';
    final sedeData = cita['doctor_sedes'] as Map<String, dynamic>?;
    final nombreSede = sedeData?['nombre_sede'] ?? 'Consultorio Principal';
    final motivoCancel = cita['motivo_cancelacion']?.toString();

    Color badgeColor = const Color(0xFF10B981);
    String badgeTexto = isEs ? 'Confirmada' : 'Confirmed';

    if (estado == 'por_confirmar' || estado == 'solicitada') {
      badgeColor = const Color(0xFFF59E0B);
      badgeTexto = isEs ? 'Por Confirmar' : 'Pending';
    } else if (estado == 'cancelada') {
      badgeColor = Colors.red;
      badgeTexto = isEs ? 'Cancelada' : 'Cancelled';
    } else if (estado == 'atendida') {
      badgeColor = Colors.grey.shade600;
      badgeTexto = isEs ? 'Atendida' : 'Completed';
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFE0F2FE),
                  backgroundImage: docFoto.isNotEmpty ? NetworkImage(docFoto) : null,
                  child: docFoto.isEmpty ? const Icon(Icons.person, color: Color(0xFF0284C7)) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(docNombre, style: GoogleFonts.mooli(fontSize: 14.5, fontWeight: FontWeight.bold)),
                      Text(nombreSede, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(badgeTexto, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor)),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Text(fechaStr, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(width: 14),
                const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Text(horaStr, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
            if (esCancelada && motivoCancel != null && motivoCancel.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Motivo: $motivoCancel', style: TextStyle(fontSize: 11, color: Colors.red.shade900)),
                    ),
                  ],
                ),
              ),
            ],
            if (esProxima) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _cancelarCita(cita),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: Text(isEs ? 'Cancelar Cita' : 'Cancel', style: const TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () => _reprogramarCita(cita),
                    icon: const Icon(Icons.sync_rounded, size: 14),
                    label: Text(isEs ? 'Cambiar Horario' : 'Reschedule', style: const TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

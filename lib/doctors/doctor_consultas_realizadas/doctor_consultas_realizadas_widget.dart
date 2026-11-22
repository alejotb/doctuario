import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../backend/supabase/supabase.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../services/doctor_consultation_draft_service.dart';
import '../../services/i18n_service.dart';
import '../../services/venezuela_locations.dart';
import '../doctor_consultation/doctor_consultation_workspace_widget.dart';
import '../doctor_agenda_panel/dialogs/medical_print_preview_dialog.dart';

/// Página de consultas médicas atendidas y borradores pendientes de finalizar.
/// Permite al doctor acceder rápidamente a cualquier consulta que dejó a medias
/// y consultar todo el historial de atenciones clínicas realizadas.
class DoctorConsultasRealizadasWidget extends StatefulWidget {
  static const String routeName = 'DoctorConsultasRealizadas';
  static const String routePath = '/doctorConsultasRealizadas';

  final String idDoctor;

  const DoctorConsultasRealizadasWidget({
    super.key,
    required this.idDoctor,
  });

  static Future<void> open(BuildContext context, {required String idDoctor}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => DoctorConsultasRealizadasWidget(idDoctor: idDoctor),
      ),
    );
  }

  @override
  State<DoctorConsultasRealizadasWidget> createState() =>
      _DoctorConsultasRealizadasWidgetState();
}

class _DoctorConsultasRealizadasWidgetState
    extends State<DoctorConsultasRealizadasWidget> {
  final _searchCtrl = TextEditingController();
  bool _isLoading = true;
  String _filtroActivo = 'todos'; // 'todos', 'borradores', 'completadas'

  List<CitasRow> _citasBorradores = [];
  List<CitasRow> _citasRealizadas = [];
  final Map<String, UsuariosRow> _pacientesMap = {};

  @override
  void initState() {
    super.initState();
    _cargarConsultas();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarConsultas() async {
    setState(() => _isLoading = true);
    try {
      final docClient = DualDatabaseConfig.instance.doctorClient;

      // 1. Cargar citas en borrador o en_consulta
      final borradoresData = await docClient
          .from('citas')
          .select()
          .eq('id_doctor', widget.idDoctor)
          .or('es_borrador.eq.true,estado.eq.en_consulta')
          .order('fecha_hora', ascending: false);

      // 2. Cargar citas completadas / atendidas
      final realizadasData = await docClient
          .from('citas')
          .select()
          .eq('id_doctor', widget.idDoctor)
          .inFilter('estado', ['atendida', 'completada'])
          .order('fecha_hora', ascending: false)
          .limit(100);

      final List<CitasRow> borradores = [];
      final List<CitasRow> realizadas = [];
      final Set<String> pacienteIds = {};

      for (final m in borradoresData) {
        final c = CitasRow(m);
        borradores.add(c);
        if (c.idPaciente != null) pacienteIds.add(c.idPaciente!);
      }

      for (final m in realizadasData) {
        final c = CitasRow(m);
        realizadas.add(c);
        if (c.idPaciente != null) pacienteIds.add(c.idPaciente!);
      }

      // 3. Cargar datos de pacientes asociados (incluyendo pacientes manuales no registrados en usuarios)
      if (pacienteIds.isNotEmpty) {
        final idsList = pacienteIds.toList();
        try {
          final pacsData = await docClient
              .from('pacientes')
              .select('id, nombre, cedula, telefono, ciudad_origen')
              .inFilter('id', idsList);
          for (final p in pacsData) {
            final row = UsuariosRow(Map<String, dynamic>.from(p));
            _pacientesMap[row.id] = row;
          }
        } catch (_) {}
        try {
          final usersData = await docClient
              .from('usuarios')
              .select('id, nombre, cedula, telefono, ciudad_origen, foto_url')
              .inFilter('id', idsList);
          for (final u in usersData) {
            final row = UsuariosRow(Map<String, dynamic>.from(u));
            final prev = _pacientesMap[row.id];
            if (prev == null || (prev.nombre?.trim().isEmpty ?? true)) {
              _pacientesMap[row.id] = row;
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _citasBorradores = borradores;
          _citasRealizadas = realizadas;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando consultas realizadas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _abrirWorkspaceConsulta(CitasRow cita) {
    final pac = _pacientesMap[cita.idPaciente];
    DoctorConsultationWorkspaceWidget.open(
      context,
      idDoctor: widget.idDoctor,
      cita: cita,
      paciente: pac,
      onConsultaFinalizada: _cargarConsultas,
    );
  }

  Future<void> _descartarBorrador(CitasRow cita) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Descartar Borrador', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de descartar este borrador? Los datos no guardados se perderán y la cita volverá a su estado programado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    await DoctorConsultationDraftService.instance.limpiarBorrador(cita.id);
    await DualDatabaseConfig.instance.doctorClient.from('citas').update({
      'estado': 'confirmada',
      'es_borrador': false,
      'borrador_consulta': null,
    }).eq('id', cita.id);

    _cargarConsultas();
  }

  List<CitasRow> _filtrarCitas(List<CitasRow> lista) {
    final query = VenezuelaLocations.normalize(_searchCtrl.text);
    if (query.isEmpty) return lista;
    return lista.where((c) {
      final pac = _pacientesMap[c.idPaciente];
      final nombre = VenezuelaLocations.normalize(pac?.nombre ?? '');
      final cedula = VenezuelaLocations.normalize(pac?.cedula ?? '');
      final motivo = VenezuelaLocations.normalize(c.motivo ?? '');
      final notas = VenezuelaLocations.normalize(c.notasMedicas ?? '');
      return nombre.contains(query) || cedula.contains(query) || motivo.contains(query) || notas.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final theme = FlutterFlowTheme.of(context);
    final borradoresFiltrados = _filtrarCitas(_citasBorradores);
    final realizadasFiltradas = _filtrarCitas(_citasRealizadas);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: canPop
          ? AppBar(
              backgroundColor: theme.secondaryBackground,
              foregroundColor: theme.primaryText,
              elevation: 0.5,
              title: Text(
                isEs ? 'Consultas Médicas & Borradores' : 'Medical Consultations & Drafts',
                style: GoogleFonts.mooli(color: theme.primaryText, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeaderFiltros(isEs, theme),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargarConsultas,
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        if (_filtroActivo != 'completadas' && borradoresFiltrados.isNotEmpty) ...[
                          _buildSeccionBorradores(borradoresFiltrados, isEs, theme),
                          const SizedBox(height: 22),
                        ],
                        if (_filtroActivo != 'borradores') ...[
                          _buildSeccionRealizadas(realizadasFiltradas, isEs, theme),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderFiltros(bool isEs, FlutterFlowTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border(bottom: BorderSide(color: theme.alternate)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            style: TextStyle(color: theme.primaryText),
            decoration: InputDecoration(
              hintText: isEs ? 'Buscar por paciente, cédula o diagnóstico...' : 'Search by patient, ID or diagnosis...',
              hintStyle: TextStyle(color: theme.secondaryText),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: theme.secondaryText),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.alternate)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.alternate)),
              filled: true,
              fillColor: theme.primaryBackground,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildFiltroChip('todos', isEs ? 'Todos (${_citasBorradores.length + _citasRealizadas.length})' : 'All', theme),
              const SizedBox(width: 8),
              _buildFiltroChip('borradores', '📝 ${isEs ? "Borradores" : "Drafts"} (${_citasBorradores.length})', theme),
              const SizedBox(width: 8),
              _buildFiltroChip('completadas', '✅ ${isEs ? "Realizadas" : "Completed"} (${_citasRealizadas.length})', theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String key, String label, FlutterFlowTheme theme) {
    final isSel = _filtroActivo == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? Colors.white : theme.primaryText)),
      selected: isSel,
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: theme.primaryBackground,
      onSelected: (_) => setState(() => _filtroActivo = key),
    );
  }

  Widget _buildSeccionBorradores(List<CitasRow> lista, bool isEs, FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 22),
            const SizedBox(width: 8),
            Text(
              isEs ? 'Consultas en Borrador / En Curso (${lista.length})' : 'Draft Consultations (${lista.length})',
              style: GoogleFonts.mooli(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          children: lista.map((c) => _buildCardBorrador(c, isEs)).toList(),
        ),
      ],
    );
  }

  Widget _buildCardBorrador(CitasRow c, bool isEs) {
    final pac = _pacientesMap[c.idPaciente];
    final nombre = pac?.nombre ?? 'Paciente';
    final fechaStr = c.fechaHora != null ? DateFormat('dd/MM/yyyy - hh:mm a').format(c.fechaHora!) : 'Fecha';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFDE68A), borderRadius: BorderRadius.circular(4)),
                      child: const Text('Borrador activo', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                    ),
                  ],
                ),
                Text('Cita: $fechaStr | Motivo: ${c.motivo ?? "Consulta"}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: Text(isEs ? 'Continuar' : 'Resume', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => _abrirWorkspaceConsulta(c),
          ),
          IconButton(
            tooltip: 'Descartar borrador',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            onPressed: () => _descartarBorrador(c),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionRealizadas(List<CitasRow> lista, bool isEs, FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 8),
            Text(
              isEs ? 'Historial de Consultas Realizadas (${lista.length})' : 'Completed Consultations (${lista.length})',
              style: GoogleFonts.mooli(fontSize: 15, fontWeight: FontWeight.bold, color: theme.primaryText),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (lista.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: theme.secondaryBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.alternate)),
            child: Center(child: Text(isEs ? 'No se encontraron consultas realizadas.' : 'No completed consultations found.', style: TextStyle(color: theme.secondaryText))),
          )
        else
          Column(
            children: lista.map((c) => _buildCardRealizada(c, isEs, theme)).toList(),
          ),
      ],
    );
  }

  Widget _buildCardRealizada(CitasRow c, bool isEs, FlutterFlowTheme theme) {
    final pac = _pacientesMap[c.idPaciente];
    final nombre = pac?.nombre ?? 'Paciente';
    final fechaStr = c.fechaHora != null ? DateFormat('dd/MM/yyyy - hh:mm a').format(c.fechaHora!) : 'Fecha';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.alternate),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFDCFCE7),
            child: Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.primaryText)),
                Text('Atendido: $fechaStr', style: TextStyle(fontSize: 11, color: theme.secondaryText)),
                if (c.notasMedicas != null && c.notasMedicas!.isNotEmpty) ...[
                  Text(c.notasMedicas!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: theme.secondaryText)),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Reimprimir / Ver Récipe',
            icon: const Icon(Icons.print_outlined, color: Color(0xFF0284C7), size: 18),
            onPressed: () {
              MedicalPrintPreviewDialog.show(
                context,
                tituloDocumento: 'Ficha y Récipe Médico',
                doctorNombre: 'Doctor',
                pacienteNombre: nombre,
                diagnostico: c.notasMedicas ?? c.motivo ?? 'Consulta Médica',
                contenidoPrincipal: 'Tratamiento documentado en consulta del $fechaStr:\n${c.notasMedicas ?? ""}',
                fecha: c.fechaHora ?? DateTime.now(),
              );
            },
          ),
          IconButton(
            tooltip: 'Abrir expediente',
            icon: const Icon(Icons.folder_open_rounded, color: Color(0xFF64748B), size: 18),
            onPressed: () => _abrirWorkspaceConsulta(c),
          ),
        ],
      ),
    );
  }
}

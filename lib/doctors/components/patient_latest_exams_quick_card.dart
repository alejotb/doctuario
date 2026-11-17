import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../backend/supabase/supabase.dart';
import '../../services/i18n_service.dart';
import '../../services/medical_exam_service.dart';
import 'medical_exam_viewer_dialog.dart';

/// Tarjeta de acceso rápido que muestra los últimos exámenes del paciente en consulta,
/// buscador con chips horizontales de exámenes realizados y botón de subida directa.
class PatientLatestExamsQuickCard extends StatefulWidget {
  final String idPaciente;
  final UsuariosRow? paciente;
  final String? idDoctor;
  final VoidCallback? onVerTodosEstudios;

  const PatientLatestExamsQuickCard({
    super.key,
    required this.idPaciente,
    this.paciente,
    this.idDoctor,
    this.onVerTodosEstudios,
  });

  @override
  State<PatientLatestExamsQuickCard> createState() => _PatientLatestExamsQuickCardState();
}

class _PatientLatestExamsQuickCardState extends State<PatientLatestExamsQuickCard> {
  static const List<String> _kExamenesPorDefecto = [
    'Hematología Completa', 'Perfil 20 / Química', 'Examen de Orina',
    'Rayos X de Tórax', 'Ecografía Abdominal', 'Electrocardiograma (ECG)',
    'Perfil Lipídico', 'Glicemia e Insulina', 'Ecocardiograma',
    'Tomografía (TAC)', 'Resonancia (RMN)', 'Biopsia / Citología',
  ];

  final TextEditingController _searchCtrl = TextEditingController();
  List<ExamenesMedicosRow> _ultimosExamenesPorTipo = [];
  List<String> _examenesRealizados = [];
  String? _examenSeleccionado;
  String _filtroTexto = '';
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _cargarExamenes();
    _cargarExamenesRealizadosDoctor();
  }

  @override
  void didUpdateWidget(covariant PatientLatestExamsQuickCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idPaciente != widget.idPaciente) _cargarExamenes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarExamenesRealizadosDoctor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'doctor_examenes_realizados_${widget.idDoctor ?? "default"}';
      final guardados = prefs.getStringList(key);
      if (mounted) {
        setState(() => _examenesRealizados = (guardados != null && guardados.isNotEmpty) ? guardados : List<String>.from(_kExamenesPorDefecto));
      }
    } catch (_) {
      if (mounted) setState(() => _examenesRealizados = List<String>.from(_kExamenesPorDefecto));
    }
  }

  Future<void> _guardarExamenesDoctor(List<String> lista) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('doctor_examenes_realizados_${widget.idDoctor ?? "default"}', lista);
    } catch (_) {}
  }

  void _agregarNuevoExamen(String nuevo) {
    final limpio = nuevo.trim();
    if (limpio.isEmpty) return;
    if (!_examenesRealizados.any((e) => e.toLowerCase() == limpio.toLowerCase())) {
      final actualizados = [limpio, ..._examenesRealizados];
      setState(() {
        _examenesRealizados = actualizados;
        _examenSeleccionado = limpio;
        _filtroTexto = '';
        _searchCtrl.clear();
      });
      _guardarExamenesDoctor(actualizados);
    } else {
      setState(() {
        _examenSeleccionado = _examenesRealizados.firstWhere((e) => e.toLowerCase() == limpio.toLowerCase());
        _filtroTexto = '';
        _searchCtrl.clear();
      });
    }
  }

  String _detectarTipo(String titulo) {
    final t = titulo.toLowerCase();
    if (t.contains('lab') || t.contains('sangre') || t.contains('hemato') || t.contains('química') || t.contains('orina') || t.contains('perfil') || t.contains('glicemia')) return 'Laboratorio Clínico';
    if (t.contains('rayos') || t.contains('rx')) return 'Rayos X e Imagenología';
    if (t.contains('eco') || t.contains('ultra')) return 'Ecografía / Ultrasonido';
    if (t.contains('tomo') || t.contains('tac')) return 'Tomografía Computarizada';
    if (t.contains('reson') || t.contains('rmn')) return 'Resonancia Magnética';
    if (t.contains('cardio') || t.contains('ecg') || t.contains('ekg') || t.contains('holter')) return 'Cardiología';
    if (t.contains('biops') || t.contains('patol') || t.contains('cito')) return 'Anatomía Patológica';
    return 'Estudio Médico General';
  }

  Future<void> _subirResultadoDirecto() async {
    final titulo = _examenSeleccionado ?? (_searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null);
    if (titulo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona o escribe el nombre del examen.'), backgroundColor: Color(0xFFF59E0B)));
      return;
    }

    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'heic'], withData: true);
      if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
      final file = res.files.first;

      setState(() => _isUploading = true);
      final tipo = _detectarTipo(titulo);
      final currentUid = SupaFlow.client.auth.currentUser?.id;

      await MedicalExamService().subirExamen(
        idPaciente: widget.idPaciente,
        subidoPorUsuarioId: currentUid,
        idDoctor: widget.idDoctor,
        titulo: titulo,
        tipoExamen: tipo,
        fileName: file.name,
        fileBytes: file.bytes!,
        fechaEstudio: DateTime.now(),
        estadoInicial: 'por_revisar',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Resultado de "$titulo" subido correctamente.'), backgroundColor: const Color(0xFF10B981)));
        _cargarExamenes();
      }
    } catch (e) {
      debugPrint('Error subiendo resultado de examen: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir resultado: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _cargarExamenes() async {
    if (widget.idPaciente.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final central = DualDatabaseConfig.instance.patientClient;
      final pacRows = await central.from('pacientes').select('id').eq('id_usuario', widget.idPaciente);
      final List<String> pacienteIds = [widget.idPaciente];
      for (final r in pacRows) {
        final idStr = r['id']?.toString();
        if (idStr != null && !pacienteIds.contains(idStr)) pacienteIds.add(idStr);
      }
      final List<dynamic> rows = await central.from('examenes_medicos').select().inFilter('id_paciente', pacienteIds).order('fecha_estudio', ascending: false);
      final todos = rows.map((r) => ExamenesMedicosRow(Map<String, dynamic>.from(r as Map))).toList();
      final filtrados = MedicalExamService.filtrarUltimoPorCadaTipo(todos);
      if (mounted) setState(() { _ultimosExamenesPorTipo = filtrados; _isLoading = false; });
    } catch (e) {
      debugPrint('[PatientLatestExamsQuickCard] Error cargando exámenes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _colorParaTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('lab') || t.contains('sangre')) return const Color(0xFFE11D48);
    if (t.contains('rayos') || t.contains('rx')) return const Color(0xFF4F46E5);
    if (t.contains('eco') || t.contains('ultra')) return const Color(0xFF0D9488);
    if (t.contains('tomo') || t.contains('tac')) return const Color(0xFF7C3AED);
    if (t.contains('reson') || t.contains('rmn')) return const Color(0xFF9333EA);
    if (t.contains('cardio') || t.contains('ecg')) return const Color(0xFFDC2626);
    return const Color(0xFF0284C7);
  }

  IconData _iconoParaTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('lab') || t.contains('sangre')) return Icons.science_rounded;
    if (t.contains('rayos') || t.contains('rx')) return Icons.filter_hdr_rounded;
    if (t.contains('eco')) return Icons.waves_rounded;
    if (t.contains('tomo') || t.contains('reson')) return Icons.camera_alt_rounded;
    if (t.contains('cardio') || t.contains('ecg')) return Icons.monitor_heart_rounded;
    return Icons.description_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final listaFiltrada = _filtroTexto.isEmpty
        ? _examenesRealizados
        : _examenesRealizados.where((e) => e.toLowerCase().contains(_filtroTexto.toLowerCase())).toList();
    final bool coincideExacto = _examenesRealizados.any((e) => e.toLowerCase() == _filtroTexto.toLowerCase());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.biotech_rounded, color: Color(0xFF0284C7), size: 18)),
                const SizedBox(width: 8),
                Text(isEs ? 'Exámenes del Paciente' : 'Patient Exams', style: GoogleFonts.mooli(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              ]),
              if (_ultimosExamenesPorTipo.isNotEmpty)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)), child: Text('${_ultimosExamenesPorTipo.length} ${isEs ? "recientes" : "recent"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 38,
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B))),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _filtroTexto = v.trim()),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(hintText: isEs ? 'Buscar o crear examen (ej. Perfil 20)...' : 'Search or create exam...', hintStyle: TextStyle(fontSize: 11.5, color: Colors.grey.shade400), border: InputBorder.none, isDense: true),
                ),
              ),
              if (_filtroTexto.isNotEmpty && !coincideExacto)
                TextButton.icon(
                  onPressed: () => _agregarNuevoExamen(_filtroTexto),
                  icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF0284C7)),
                  label: Text(isEs ? 'Agregar' : 'Add', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              if (_filtroTexto.isNotEmpty)
                IconButton(icon: const Icon(Icons.clear_rounded, size: 15, color: Colors.grey), onPressed: () { _searchCtrl.clear(); setState(() => _filtroTexto = ''); }),
            ]),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ...listaFiltrada.map((nombre) {
                final esSel = _examenSeleccionado == nombre;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    selected: esSel,
                    label: Text(nombre),
                    labelStyle: TextStyle(fontSize: 11, fontWeight: esSel ? FontWeight.bold : FontWeight.normal, color: esSel ? Colors.white : const Color(0xFF334155)),
                    selectedColor: const Color(0xFF0284C7),
                    backgroundColor: const Color(0xFFF1F5F9),
                    checkmarkColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: esSel ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1))),
                    onSelected: (sel) => setState(() => _examenSeleccionado = sel ? nombre : null),
                  ),
                );
              }),
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBBF7D0))),
            child: Row(children: [
              Icon(Icons.cloud_upload_outlined, size: 17, color: Colors.green.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _examenSeleccionado != null ? '${isEs ? "Examen:" : "Exam:"} $_examenSeleccionado' : (isEs ? 'Selecciona un chip para subir resultado' : 'Select a chip to upload result'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade900),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _subirResultadoDirecto,
                icon: _isUploading
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.file_upload_outlined, size: 14, color: Colors.white),
                label: Text(
                  isEs ? (_isUploading ? 'Subiendo...' : 'Subir Resultado') : (_isUploading ? 'Uploading...' : 'Upload'),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 0),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (_ultimosExamenesPorTipo.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(children: [
                Icon(Icons.assignment_outlined, size: 18, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(child: Text(isEs ? 'Sin estudios previos registrados aún para este paciente.' : 'No studies recorded yet for this patient.', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600))),
              ]),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ultimosExamenesPorTipo.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, idx) => _buildExamRow(_ultimosExamenesPorTipo[idx], isEs),
            ),
          if (widget.onVerTodosEstudios != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.onVerTodosEstudios,
                icon: const Icon(Icons.arrow_forward_rounded, size: 13),
                label: Text(isEs ? 'Ver Todos los Estudios' : 'View All Studies', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExamRow(ExamenesMedicosRow ex, bool isEs) {
    final tipo = (ex.tipoExamen != null && ex.tipoExamen!.isNotEmpty) ? ex.tipoExamen! : (ex.especialidad ?? 'General');
    final colorTipo = _colorParaTipo(tipo);
    final iconoTipo = _iconoParaTipo(tipo);
    final fechaStr = ex.fechaEstudio != null ? DateFormat('dd/MM/yyyy').format(ex.fechaEstudio!) : DateFormat('dd/MM/yyyy').format(ex.createdAt);
    final esRevisado = ex.estado == 'revisado';

    return InkWell(
      onTap: () => MedicalExamViewerDialog.show(context, examen: ex, paciente: widget.paciente, onActualizado: _cargarExamenes),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: colorTipo.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Icon(iconoTipo, color: colorTipo, size: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ex.titulo ?? 'Estudio Clínico', style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: colorTipo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(tipo, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: colorTipo))),
                const SizedBox(width: 6),
                Text('• $fechaStr', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
              ]),
            ]),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: esRevisado ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
            child: Text(esRevisado ? (isEs ? 'Revisado' : 'Reviewed') : (isEs ? 'Por Revisar' : 'Pending'), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: esRevisado ? const Color(0xFF065F46) : const Color(0xFFB45309))),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF0284C7)),
        ]),
      ),
    );
  }
}

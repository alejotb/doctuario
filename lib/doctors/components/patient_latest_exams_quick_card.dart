import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../backend/supabase/supabase.dart';
import '../../services/i18n_service.dart';
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
  List<ExamenesMedicosRow> _ultimosExamenesPorTipo = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarExamenes();
  }

  @override
  void didUpdateWidget(covariant PatientLatestExamsQuickCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idPaciente != widget.idPaciente) _cargarExamenes();
  }

  Future<void> _cargarExamenes() async {
    if (widget.idPaciente.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final central = DualDatabaseConfig.instance.patientClient;
      final pacRows = await central
          .from('pacientes')
          .select('id, id_usuario')
          .or('id.eq.${widget.idPaciente},id_usuario.eq.${widget.idPaciente}');
      final List<String> pacienteIds = [widget.idPaciente];
      for (final r in (pacRows as List)) {
        final idStr = r['id']?.toString();
        final usrStr = r['id_usuario']?.toString();
        if (idStr != null && idStr.isNotEmpty && !pacienteIds.contains(idStr)) {
          pacienteIds.add(idStr);
        }
        if (usrStr != null && usrStr.isNotEmpty && !pacienteIds.contains(usrStr)) {
          pacienteIds.add(usrStr);
        }
      }
      final List<dynamic> rows = await central
          .from('examenes_medicos')
          .select()
          .inFilter('id_paciente', pacienteIds)
          .order('fecha_estudio', ascending: false);

      final todos = rows
          .map((r) => ExamenesMedicosRow(Map<String, dynamic>.from(r as Map)))
          .where((ex) {
            final compartido = ex.getField<bool>('compartir_con_paciente') ?? true;
            final esDelDoctor = widget.idDoctor != null &&
                (ex.idDoctor == widget.idDoctor || ex.subidoPorUsuarioId == widget.idDoctor);
            return compartido || esDelDoctor;
          })
          .toList()
        ..sort((a, b) {
          final fA = a.fechaEstudio ?? a.createdAt;
          final fB = b.fechaEstudio ?? b.createdAt;
          return fB.compareTo(fA);
        });

      if (mounted) setState(() { _ultimosExamenesPorTipo = todos; _isLoading = false; });
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
    final subidoPorDoctor = ex.subidoPorUsuarioId != null &&
        (ex.subidoPorUsuarioId == ex.idDoctor || ex.subidoPorUsuarioId == widget.idDoctor);

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
              Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: colorTipo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(tipo, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: colorTipo))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: subidoPorDoctor ? const Color(0xFFE0F2FE) : const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subidoPorDoctor ? (isEs ? 'Por Doctor' : 'By Doctor') : (isEs ? 'Por Paciente' : 'By Patient'),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: subidoPorDoctor ? const Color(0xFF0369A1) : const Color(0xFF7E22CE),
                    ),
                  ),
                ),
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

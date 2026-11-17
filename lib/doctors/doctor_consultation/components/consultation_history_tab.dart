import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/clinical_history_service.dart';
import '../../../services/medical_exam_service.dart';
import '../../components/medical_exam_viewer_dialog.dart';

/// Pestaña 2: Historial Clínico y Evolución del Paciente.
/// Permite al médico revisar todas las consultas anteriores, antecedentes y
/// estudios previos agrupados cronológicamente con destaque del estudio más actual.
class ConsultationHistoryTab extends StatefulWidget {
  final String idDoctor;
  final String? idPaciente;
  final UsuariosRow? paciente;

  const ConsultationHistoryTab({
    super.key,
    required this.idDoctor,
    required this.idPaciente,
    required this.paciente,
  });

  @override
  State<ConsultationHistoryTab> createState() => _ConsultationHistoryTabState();
}

class _ConsultationHistoryTabState extends State<ConsultationHistoryTab> {
  bool _isLoading = true;
  List<HistoriasClinicasRow> _historias = [];
  List<ExamenesMedicosRow> _examenes = [];
  List<ExamenesMedicosRow> _ultimosPorTipo = [];

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    final pacId = widget.idPaciente;
    if (pacId == null || pacId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final hList = await ClinicalHistoryService().obtenerHistorialPaciente(
        idPaciente: pacId,
        idDoctor: widget.idDoctor,
      );
      final eList = await MedicalExamService().obtenerExamenesPaciente(pacId);
      final ultimos = MedicalExamService.filtrarUltimoPorCadaTipo(eList);

      if (mounted) {
        setState(() {
          _historias = hList;
          _examenes = eList;
          _ultimosPorTipo = ultimos;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final pacId = widget.idPaciente;
    if (pacId == null || pacId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('No hay identificador de paciente disponible para consultar antecedentes.', style: TextStyle(color: Colors.grey.shade600)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildTarjetaEvolucionEstudios(),
        const SizedBox(height: 20),
        _buildSeccionConsultasAnteriores(),
        const SizedBox(height: 20),
        _buildSeccionTodosLosEstudios(),
      ],
    );
  }

  Widget _buildTarjetaEvolucionEstudios() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Color(0xFF16A34A), size: 20),
              const SizedBox(width: 8),
              Text('Evolución Reciente: Últimos Estudios Realizados', style: GoogleFonts.mooli(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF14532D))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Muestra el estudio más actual de cada categoría para evaluar rápidamente el progreso clínico del paciente.',
            style: TextStyle(fontSize: 12, color: Colors.green.shade800),
          ),
          const SizedBox(height: 12),
          if (_ultimosPorTipo.isEmpty)
            Text('No hay exámenes médicos registrados previamente.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ultimosPorTipo.map((ex) {
                final fechaStr = ex.fechaEstudio != null ? DateFormat('dd/MM/yyyy').format(ex.fechaEstudio!) : 'Fecha reciente';
                return InkWell(
                  onTap: () => MedicalExamViewerDialog.show(
                    context,
                    examen: ex,
                    paciente: widget.paciente,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.file_present_rounded, size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ex.tipoExamen ?? ex.titulo ?? 'Estudio', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                            Text('Más actual: $fechaStr', style: const TextStyle(fontSize: 10, color: Color(0xFF15803D))),
                          ],
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF0284C7)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSeccionConsultasAnteriores() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_edu_rounded, color: Color(0xFF0284C7), size: 20),
              const SizedBox(width: 8),
              Text('Historial de Consultas Previas (${_historias.length})', style: GoogleFonts.mooli(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 12),
          if (_historias.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No hay consultas previas documentadas para este paciente.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            )
          else
            Column(
              children: _historias.map((h) {
                final fechaStr = DateFormat('dd/MM/yyyy - hh:mm a').format(h.createdAt);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(fechaStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Completada', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (h.motivoConsulta != null && h.motivoConsulta!.isNotEmpty) ...[
                        Text('Motivo: ${h.motivoConsulta!}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                      if (h.diagnostico != null && h.diagnostico!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text('Diagnóstico: ${h.diagnostico!}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                      ],
                      if (h.tratamiento != null && h.tratamiento!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text('Tratamiento: ${h.tratamiento!}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSeccionTodosLosEstudios() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_shared_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              Text('Expediente de Todos los Estudios (${_examenes.length})', style: GoogleFonts.mooli(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 12),
          if (_examenes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No hay archivos de exámenes subidos para este paciente.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            )
          else
            Column(
              children: _examenes.map((ex) {
                final fechaStr = ex.fechaEstudio != null ? DateFormat('dd/MM/yyyy').format(ex.fechaEstudio!) : 'Fecha no especificada';
                final esActual = _ultimosPorTipo.any((u) => u.id == ex.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        ex.formato == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                        color: ex.formato == 'pdf' ? Colors.red.shade400 : const Color(0xFF0284C7),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(child: Text(ex.titulo ?? ex.tipoExamen ?? 'Estudio', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold))),
                                if (esActual) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('Más actual', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                                  ),
                                ],
                              ],
                            ),
                            Text('Fecha: $fechaStr | Tipo: ${ex.tipoExamen ?? "General"}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Abrir en visor',
                        icon: const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF0284C7), size: 18),
                        onPressed: () => MedicalExamViewerDialog.show(
                          context,
                          examen: ex,
                          paciente: widget.paciente,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

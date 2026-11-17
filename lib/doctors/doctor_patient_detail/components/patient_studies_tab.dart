import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../backend/supabase/supabase.dart';
import '../../../flutter_flow/flutter_flow_theme.dart';
import '../../../services/medical_exam_service.dart';
import '../../../services/medical_report_printer_service.dart';

/// Componente modular: Pestaña de Estudios y Exámenes Médicos con agrupación por Tipo de Estudio
/// y botones de acción ("Marcar como Revisado" / "Llenar Hallazgos").
class PatientStudiesTab extends StatefulWidget {
  final List<ExamenesMedicosRow> examenes;
  final UsuariosRow? paciente;
  final UsuariosRow? doctorActualUsuario;
  final DoctoresRow? doctorActualInfo;
  final Map<String, UsuariosRow> doctoresMap;
  final VoidCallback onSubirEstudio;
  final Function(ExamenesMedicosRow) onEditarHallazgo;
  final Function(String url, String titulo) onVerArchivo;
  final Future<void> Function(ExamenesMedicosRow)? onMarcarRevisado;

  const PatientStudiesTab({
    super.key,
    required this.examenes,
    required this.paciente,
    required this.doctorActualUsuario,
    required this.doctorActualInfo,
    required this.doctoresMap,
    required this.onSubirEstudio,
    required this.onEditarHallazgo,
    required this.onVerArchivo,
    this.onMarcarRevisado,
  });

  @override
  State<PatientStudiesTab> createState() => _PatientStudiesTabState();
}

class _PatientStudiesTabState extends State<PatientStudiesTab> {
  String _filtroTipo = 'Todos';

  void _imprimirEstudio(BuildContext context, ExamenesMedicosRow ex) {
    final doctorSubio = widget.doctoresMap[ex.idDoctor] ?? widget.doctorActualUsuario;
    final fechaStr = ex.fechaEstudio != null ? DateFormat('dd/MM/yyyy').format(ex.fechaEstudio!) : 'No especificada';
    final hallazgosTexto = ex.hallazgos ?? ex.notas ?? 'Sin hallazgos descritos.';

    MedicalReportPrinterService.instance.mostrarReporteImprimible(
      context: context,
      tituloDocumento: 'Informe de Estudio Médico',
      paciente: widget.paciente,
      doctorUsuario: doctorSubio,
      doctorInfo: widget.doctorActualInfo,
      logoUrl: widget.doctorActualInfo?.logoUrl,
      contenidoCuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INFORME DE ESTUDIO MÉDICO: ${ex.titulo ?? "Estudio Clínico"}',
              style: GoogleFonts.mooli(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Tipo: ${ex.tipoExamen ?? "General"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Text('Especialidad: ${ex.especialidad ?? "General"}', style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7))),
            ],
          ),
          Text('Fecha de Realización: $fechaStr', style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HALLAZGOS Y CONCLUSIONES:',
                    style: GoogleFonts.mooli(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(hallazgosTexto, style: GoogleFonts.mooli(fontSize: 12, color: const Color(0xFF1E293B))),
              ],
            ),
          ),
          if (ex.archivoUrl != null && ex.archivoUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Archivo adjunto disponible en la plataforma digital.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
          ],
        ],
      ),
      notasPie: 'Informe emitido para valoración diagnóstica.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final agrupadosPorTipo =
        MedicalExamService.agruparPorTipoEstudio(widget.examenes);
    final todosLosTipos = ['Todos', ...agrupadosPorTipo.keys];

    final Map<String, List<ExamenesMedicosRow>> agrupadosFiltrados = {};
    if (_filtroTipo == 'Todos') {
      agrupadosFiltrados.addAll(agrupadosPorTipo);
    } else if (agrupadosPorTipo.containsKey(_filtroTipo)) {
      agrupadosFiltrados[_filtroTipo] = agrupadosPorTipo[_filtroTipo]!;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onSubirEstudio,
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(Icons.upload_file, color: Colors.white),
        label: const Text('Subir Estudio',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          if (todosLosTipos.length > 2)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: FlutterFlowTheme.of(context).primaryBackground,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: todosLosTipos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final tipo = todosLosTipos[idx];
                  final isSelected = tipo == _filtroTipo;
                  final count = tipo == 'Todos'
                      ? widget.examenes.length
                      : (agrupadosPorTipo[tipo]?.length ?? 0);
                  return ChoiceChip(
                    label: Text('$tipo ($count)',
                        style: const TextStyle(fontSize: 11.5)),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _filtroTipo = tipo);
                    },
                    selectedColor: const Color(0xFF0284C7),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: widget.examenes.isEmpty
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                    children: agrupadosFiltrados.entries.map((entry) {
                      return _buildTipoSection(entry.key, entry.value);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.biotech_outlined, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text('No hay estudios médicos registrados para este paciente.',
                style: GoogleFonts.mooli(fontSize: 14, color: Colors.grey.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: widget.onSubirEstudio,
              icon: const Icon(Icons.upload_file),
              label: const Text('Subir Primer Estudio'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipoSection(String tipo, List<ExamenesMedicosRow> lista) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_shared_rounded, size: 18, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: 8),
              Text(
                tipo.toUpperCase(),
                style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                child: Text('${lista.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ],
          ),
        ),
        ...lista.map((ex) => _buildEstudioCard(ex)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildEstudioCard(ExamenesMedicosRow ex) {
    final fechaStr = ex.fechaEstudio != null
        ? DateFormat('dd/MM/yyyy').format(ex.fechaEstudio!)
        : 'Sin fecha';
    final doctorSubio = widget.doctoresMap[ex.idDoctor];
    final tieneHallazgos =
        ex.hallazgos != null && ex.hallazgos!.trim().isNotEmpty;
    final esPdf = ex.formato?.toLowerCase() == 'pdf';
    final esPorRevisar = (ex.estado ?? 'por_revisar') == 'por_revisar';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: esPorRevisar
              ? const Color(0xFFF59E0B)
              : FlutterFlowTheme.of(context).alternate,
          width: esPorRevisar ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: esPorRevisar
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    esPdf ? Icons.picture_as_pdf : Icons.image,
                    color: esPorRevisar
                        ? const Color(0xFFD97706)
                        : const Color(0xFF0284C7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ex.titulo ?? 'Estudio Clínico',
                              style: GoogleFonts.mooli(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                            ),
                          ),
                          _buildStatusBadge(esPorRevisar),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Fecha: $fechaStr • Tipo: ${ex.tipoExamen ?? "General"}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                      if (doctorSubio != null)
                        Text(
                          'Médico: Dr(a). ${doctorSubio.nombre}',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.print_outlined,
                      size: 20, color: Color(0xFF0284C7)),
                  onPressed: () => _imprimirEstudio(context, ex),
                  tooltip: 'Imprimir informe',
                ),
              ],
            ),
            const Divider(height: 14),
            _buildHallazgosContainer(ex, tieneHallazgos),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (ex.archivoUrl != null && ex.archivoUrl!.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => widget.onVerArchivo(
                        ex.archivoUrl!, ex.titulo ?? 'Estudio'),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Ver Archivo',
                        style: TextStyle(fontSize: 11.5)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (esPorRevisar)
                  ElevatedButton.icon(
                    onPressed: () {
                      if (widget.onMarcarRevisado != null) {
                        widget.onMarcarRevisado!(ex);
                      } else {
                        widget.onEditarHallazgo(ex);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Marcar Revisado',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool esPorRevisar) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: esPorRevisar ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              esPorRevisar ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            esPorRevisar
                ? Icons.pending_actions_rounded
                : Icons.check_circle_rounded,
            size: 13,
            color: esPorRevisar
                ? const Color(0xFFB45309)
                : const Color(0xFF047857),
          ),
          const SizedBox(width: 4),
          Text(
            esPorRevisar ? 'POR REVISAR' : 'REVISADO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: esPorRevisar
                  ? const Color(0xFFB45309)
                  : const Color(0xFF047857),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHallazgosContainer(
      ExamenesMedicosRow ex, bool tieneHallazgos) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: tieneHallazgos
            ? const Color(0xFFF8FAFC)
            : const Color(0xFFFEF3C7).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tieneHallazgos
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HALLAZGOS DEL ESTUDIO:',
                style: GoogleFonts.mooli(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: tieneHallazgos
                      ? const Color(0xFF475569)
                      : const Color(0xFFB45309),
                ),
              ),
              InkWell(
                onTap: () => widget.onEditarHallazgo(ex),
                child: const Row(
                  children: [
                    Icon(Icons.edit, size: 13, color: Color(0xFF0284C7)),
                    SizedBox(width: 3),
                    Text(
                      'Editar Hallazgos',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            tieneHallazgos
                ? (ex.hallazgos ?? ex.notas!)
                : 'Pendiente por registrar hallazgos clínicos.',
            style: TextStyle(
              fontSize: 12,
              color: tieneHallazgos ? Colors.black87 : Colors.brown,
              fontStyle:
                  tieneHallazgos ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

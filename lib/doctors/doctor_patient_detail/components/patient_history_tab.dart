import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../flutter_flow/flutter_flow_theme.dart';
import '../../../services/medical_report_printer_service.dart';

/// Componente modular: Pestaña de Historia Clínica y Evoluciones con botón de Imprimir.
class PatientHistoryTab extends StatelessWidget {
  final List<HistoriasClinicasRow> historias;
  final UsuariosRow? paciente;
  final UsuariosRow? doctorActualUsuario;
  final DoctoresRow? doctorActualInfo;
  final Map<String, UsuariosRow> doctoresMap;
  final Map<String, DoctoresRow> doctoresInfoMap;
  final String idDoctorActual;
  final VoidCallback onNuevaHistoria;

  const PatientHistoryTab({
    super.key,
    required this.historias,
    required this.paciente,
    required this.doctorActualUsuario,
    required this.doctorActualInfo,
    required this.doctoresMap,
    required this.doctoresInfoMap,
    required this.idDoctorActual,
    required this.onNuevaHistoria,
  });

  void _imprimirEvolucionIndividual(
      BuildContext context, HistoriasClinicasRow h) {
    final doctorAtendio = doctoresMap[h.idDoctor] ?? doctorActualUsuario;
    final doctorEspec = doctoresInfoMap[h.idDoctor] ?? doctorActualInfo;
    final fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(h.createdAt);

    MedicalReportPrinterService.instance.mostrarReporteImprimible(
      context: context,
      tituloDocumento: 'Evolución Médica - $fechaStr',
      paciente: paciente,
      doctorUsuario: doctorAtendio,
      doctorInfo: doctorEspec,
      logoUrl: doctorEspec?.logoUrl,
      contenidoCuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EVOLUCIÓN CLÍNICA (#${h.id.substring(0, h.id.length > 8 ? 8 : h.id.length).toUpperCase()})',
            style: GoogleFonts.mooli(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          Text('Fecha y Hora de Atención: $fechaStr',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
          const SizedBox(height: 14),
          if (h.motivoConsulta != null && h.motivoConsulta!.isNotEmpty)
            _buildSeccionReporte(
                'Motivo de Consulta / Anamnesis', h.motivoConsulta!),
          if (h.sintomas != null && h.sintomas!.isNotEmpty)
            _buildSeccionReporte('Síntomas Presentados', h.sintomas!),
          if (h.examenFisico != null && h.examenFisico!.isNotEmpty)
            _buildSeccionReporte('Exploración Física', h.examenFisico!),
          if (h.diagnostico != null && h.diagnostico!.isNotEmpty)
            _buildSeccionReporte('Diagnóstico Clínico', h.diagnostico!,
                destacado: true),
          if (h.tratamiento != null && h.tratamiento!.isNotEmpty)
            _buildSeccionReporte(
                'Plan Terapéutico y Órdenes Médicas', h.tratamiento!,
                color: const Color(0xFF0F766E)),
        ],
      ),
      notasPie:
          'Documento emitido para fines médicos. Válido como constancia de atención clínica.',
    );
  }

  void _imprimirHistoriaCompleta(BuildContext context) {
    if (historias.isEmpty) return;

    MedicalReportPrinterService.instance.mostrarReporteImprimible(
      context: context,
      tituloDocumento: 'Expediente Clínico Completo',
      paciente: paciente,
      doctorUsuario: doctorActualUsuario,
      doctorInfo: doctorActualInfo,
      logoUrl: doctorActualInfo?.logoUrl,
      contenidoCuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HISTORIAL COMPLETO DE EVOLUCIONES (${historias.length} consultas registradas)',
            style: GoogleFonts.mooli(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < historias.length; i++) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Consulta #${historias.length - i} - ${DateFormat('dd/MM/yyyy HH:mm').format(historias[i].createdAt)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF0284C7)),
                      ),
                      Text(
                        'Dr. ${doctoresMap[historias[i].idDoctor]?.nombre ?? "Tratante"}',
                        style: const TextStyle(
                            fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  if (historias[i].diagnostico != null)
                    Text('Diagnóstico: ${historias[i].diagnostico}',
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w600)),
                  if (historias[i].tratamiento != null)
                    Text('Tratamiento: ${historias[i].tratamiento}',
                        style: const TextStyle(fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeccionReporte(String titulo, String texto,
      {bool destacado = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: GoogleFonts.mooli(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color ??
                  (destacado ? const Color(0xFF1E40AF) : const Color(0xFF475569)),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            texto,
            style: GoogleFonts.mooli(
              fontSize: 12,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoItem(String etiqueta, String valor, IconData icono,
      {Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color != null
            ? color.withValues(alpha: 0.06)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color != null
              ? color.withValues(alpha: 0.2)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 14, color: color ?? const Color(0xFF475569)),
              const SizedBox(width: 6),
              Text(
                etiqueta,
                style: GoogleFonts.mooli(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color ?? const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: GoogleFonts.mooli(
              fontSize: 12.5,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (historias.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_edu, size: 52, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                'No hay evoluciones médicas registradas para este paciente.',
                style: GoogleFonts.mooli(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onNuevaHistoria,
                icon: const Icon(Icons.add),
                label: const Text('Registrar Primera Evolución'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onNuevaHistoria,
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva Evolución',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Barra de acciones superiores (Botón imprimir historia completa)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: FlutterFlowTheme.of(context).primaryBackground,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${historias.length} evoluciones registradas',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _imprimirHistoriaCompleta(context),
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Imprimir Historia Completa',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de evoluciones
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: historias.length,
              itemBuilder: (context, index) {
                final h = historias[index];
                final fechaStr =
                    DateFormat('dd/MM/yyyy HH:mm').format(h.createdAt);
                final doctorAtendio = doctoresMap[h.idDoctor];
                final doctorEspec = doctoresInfoMap[h.idDoctor];

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: FlutterFlowTheme.of(context).alternate),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Encabezado de la evolución
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.event,
                                    size: 16, color: Color(0xFF0284C7)),
                                const SizedBox(width: 6),
                                Text(
                                  fechaStr,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Text(
                                    doctorEspec?.especialidad ??
                                        'Medicina General',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF166534),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // BOTÓN DE IMPRIMIR ESTA EVOLUCIÓN
                                IconButton(
                                  icon: const Icon(Icons.print_outlined,
                                      size: 18, color: Color(0xFF0284C7)),
                                  onPressed: () =>
                                      _imprimirEvolucionIndividual(context, h),
                                  tooltip: 'Imprimir esta evolución',
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          'Médico Tratante: Dr(a). ${doctorAtendio?.nombre ?? "Médico Tratante"}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Divider(height: 16),

                        // Campos clínicos
                        if (h.motivoConsulta != null &&
                            h.motivoConsulta!.isNotEmpty) ...[
                          _buildCampoItem(
                              'Motivo de Consulta / Anamnesis:',
                              h.motivoConsulta!,
                              Icons.psychology_outlined),
                          const SizedBox(height: 8),
                        ],
                        if (h.sintomas != null && h.sintomas!.isNotEmpty) ...[
                          _buildCampoItem(
                              'Síntomas:', h.sintomas!, Icons.sick_outlined),
                          const SizedBox(height: 8),
                        ],
                        if (h.examenFisico != null &&
                            h.examenFisico!.isNotEmpty) ...[
                          _buildCampoItem('Exploración Física:',
                              h.examenFisico!, Icons.accessibility_new_outlined),
                          const SizedBox(height: 8),
                        ],
                        if (h.diagnostico != null &&
                            h.diagnostico!.isNotEmpty) ...[
                          _buildCampoItem('Diagnóstico Clínico:',
                              h.diagnostico!, Icons.medical_information_outlined,
                              color: const Color(0xFF1E40AF)),
                          const SizedBox(height: 8),
                        ],
                        if (h.tratamiento != null &&
                            h.tratamiento!.isNotEmpty) ...[
                          _buildCampoItem('Plan Terapéutico y Órdenes:',
                              h.tratamiento!, Icons.medication_outlined,
                              color: const Color(0xFF0F766E)),
                          const SizedBox(height: 8),
                        ],
                        if (h.idDoctor == idDoctorActual &&
                            h.notasPrivadas != null &&
                            h.notasPrivadas!.isNotEmpty) ...[
                          _buildCampoItem('Notas Confidenciales:',
                              h.notasPrivadas!, Icons.lock_outline,
                              color: const Color(0xFF475569)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

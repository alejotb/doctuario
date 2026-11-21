import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../backend/supabase/supabase.dart';
import '../../services/i18n_service.dart';
import '../../services/medical_exam_service.dart';
import '../../services/medical_report_printer_service.dart';

/// Visor completo e integrado dentro de la aplicación para estudios y exámenes médicos.
/// Permite visualizar radiografías, ecografías, laboratorios e informes clínicos con zoom interactivo,
/// impresión formal, revisión de hallazgos y descarga del archivo original.
class MedicalExamViewerDialog extends StatefulWidget {
  final ExamenesMedicosRow examen;
  final UsuariosRow? paciente;
  final VoidCallback? onActualizado;

  const MedicalExamViewerDialog({
    super.key,
    required this.examen,
    this.paciente,
    this.onActualizado,
  });

  static Future<void> show(
    BuildContext context, {
    required ExamenesMedicosRow examen,
    UsuariosRow? paciente,
    VoidCallback? onActualizado,
  }) =>
      showDialog(
        context: context,
        builder: (ctx) => MedicalExamViewerDialog(
          examen: examen,
          paciente: paciente,
          onActualizado: onActualizado,
        ),
      );

  @override
  State<MedicalExamViewerDialog> createState() => _MedicalExamViewerDialogState();
}

class _MedicalExamViewerDialogState extends State<MedicalExamViewerDialog> {
  final TransformationController _transformController = TransformationController();
  String? _secureUrl;
  bool _cargandoUrl = true;
  bool _guardandoRevisado = false;
  late String _estadoActual;
  late String _hallazgosActuales;

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.examen.estado ?? 'por_revisar';
    _hallazgosActuales = widget.examen.hallazgos ?? widget.examen.notas ?? '';
    _resolverUrl();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _resolverUrl() async {
    final url = widget.examen.archivoUrl;
    if (url == null || url.trim().isEmpty) {
      if (mounted) setState(() => _cargandoUrl = false);
      return;
    }
    try {
      final sUrl = await MedicalExamService.getSecureExamUrl(url);
      if (mounted) setState(() { _secureUrl = sUrl; _cargandoUrl = false; });
    } catch (_) {
      if (mounted) setState(() { _secureUrl = url; _cargandoUrl = false; });
    }
  }

  bool get _esImagen {
    final url = (_secureUrl ?? widget.examen.archivoUrl ?? '').toLowerCase();
    final fmt = (widget.examen.formato ?? '').toLowerCase();
    if (fmt == 'imagen') return true;
    return url.contains('.jpg') || url.contains('.jpeg') || url.contains('.png') || url.contains('.webp') || url.contains('.gif');
  }

  Future<void> _marcarRevisado() async {
    setState(() => _guardandoRevisado = true);
    try {
      await MedicalExamService().marcarComoRevisado(idExamen: widget.examen.id, hallazgos: _hallazgosActuales);
      if (mounted) {
        setState(() { _estadoActual = 'revisado'; _guardandoRevisado = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Estudio validado como revisado.'), backgroundColor: Colors.teal));
        widget.onActualizado?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardandoRevisado = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al marcar revisado: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _abrirEnlaceExterno() async {
    final target = _secureUrl ?? widget.examen.archivoUrl;
    if (target == null || target.isEmpty) return;
    final uri = Uri.parse(target);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _imprimirReporte() {
    final fechaStr = widget.examen.fechaEstudio != null ? DateFormat('dd/MM/yyyy').format(widget.examen.fechaEstudio!) : 'No especificada';
    MedicalReportPrinterService.instance.mostrarReporteImprimible(
      context: context,
      tituloDocumento: 'Informe de Estudio Médico',
      paciente: widget.paciente,
      doctorUsuario: SupaFlow.client.auth.currentUser != null ? UsuariosRow({'id': SupaFlow.client.auth.currentUser!.id, 'nombre': 'Médico Tratante'}) : null,
      doctorInfo: null,
      contenidoCuerpo: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ESTUDIO: ${widget.examen.titulo ?? "Estudio Clínico"}', style: GoogleFonts.mooli(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Categoría: ${widget.examen.tipoExamen ?? "General"} • Fecha: $fechaStr', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 14),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFCBD5E1))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('HALLAZGOS Y CONCLUSIONES:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_hallazgosActuales.isNotEmpty ? _hallazgosActuales : 'Sin observaciones descritas.', style: const TextStyle(fontSize: 12.5)),
          ]),
        ),
      ]),
      notasPie: 'Documento expedido mediante la plataforma clínica Doctuario / MediConnect.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final fechaStr = widget.examen.fechaEstudio != null ? DateFormat('dd/MM/yyyy').format(widget.examen.fechaEstudio!) : 'Fecha no especificada';
    final tipo = widget.examen.tipoExamen ?? 'General';
    final esRevisado = _estadoActual == 'revisado';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 820),
        child: Column(children: [
          // Barra superior
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(color: Color(0xFF0F172A), border: Border(bottom: BorderSide(color: Color(0xFF334155)))),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF38BDF8), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.examen.titulo ?? 'Visor de Estudio Médico', style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                  Text('$tipo • $fechaStr • ${widget.paciente?.nombre ?? "Paciente"}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: esRevisado ? const Color(0xFF065F46) : const Color(0xFF854D0E), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(esRevisado ? Icons.check_circle : Icons.schedule, color: Colors.white, size: 13),
                  const SizedBox(width: 5),
                  Text(esRevisado ? (isEs ? 'Revisado' : 'Reviewed') : (isEs ? 'Pendiente' : 'Pending'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(width: 10),
              IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), tooltip: 'Cerrar', onPressed: () => Navigator.pop(context)),
            ]),
          ),
          // Contenido central
          Expanded(
            child: Container(
              color: const Color(0xFFF1F5F9),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildViewerContent(),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.psychology_alt_rounded, size: 18, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Text(isEs ? 'Hallazgos Clínicos y Dictamen' : 'Clinical Findings', style: GoogleFonts.mooli(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      ]),
                      const Divider(height: 18),
                      Text(_hallazgosActuales.isNotEmpty ? _hallazgosActuales : (isEs ? 'Sin hallazgos clínicos registrados aún.' : 'No findings recorded yet.'), style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF334155))),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          // Barra inferior
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                if (!esRevisado)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _guardandoRevisado ? null : _marcarRevisado,
                    icon: _guardandoRevisado ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.done_all_rounded, size: 16),
                    label: Text(isEs ? 'Marcar como Revisado' : 'Mark Reviewed'),
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0284C7), side: const BorderSide(color: Color(0xFFBAE6FD)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _imprimirReporte,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: Text(isEs ? 'Imprimir Informe' : 'Print'),
                ),
              ]),
              Row(children: [
                if (widget.examen.archivoUrl != null && widget.examen.archivoUrl!.isNotEmpty)
                  TextButton.icon(onPressed: _abrirEnlaceExterno, icon: const Icon(Icons.open_in_new_rounded, size: 16), label: Text(isEs ? 'Abrir Original' : 'Open File')),
                const SizedBox(width: 8),
                TextButton(onPressed: () => Navigator.pop(context), child: Text(isEs ? 'Cerrar' : 'Close')),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildViewerContent() {
    if (_cargandoUrl) {
      return Container(height: 360, decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(14)), child: const Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    final targetUrl = _secureUrl ?? widget.examen.archivoUrl;
    if (targetUrl == null || targetUrl.isEmpty) {
      return Container(
        height: 220, width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notes_rounded, size: 48, color: Colors.grey),
          SizedBox(height: 10),
          Text('Estudio de reporte clínico (sin archivo gráfico adjunto)', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ])),
      );
    }
    if (_esImagen) {
      return Container(
        height: 440, width: double.infinity, clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: const Color(0xFF0B132B), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1E293B))),
        child: Stack(children: [
          Center(
            child: InteractiveViewer(
              transformationController: _transformController, minScale: 0.8, maxScale: 4.5,
              child: Image.network(targetUrl, fit: BoxFit.contain, loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)), errorBuilder: (_, __, ___) => const Center(child: Text('No se pudo cargar la imagen médica', style: TextStyle(color: Colors.white70)))),
            ),
          ),
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20), tooltip: 'Acercar', onPressed: () => _transformController.value = (_transformController.value.clone()..scaleByDouble(1.2, 1.2, 1.0, 1.0))),
                IconButton(icon: const Icon(Icons.zoom_out, color: Colors.white, size: 20), tooltip: 'Alejar', onPressed: () => _transformController.value = (_transformController.value.clone()..scaleByDouble(0.8, 0.8, 1.0, 1.0))),
                IconButton(icon: const Icon(Icons.restart_alt_rounded, color: Colors.white, size: 20), tooltip: 'Restablecer', onPressed: () => _transformController.value = Matrix4.identity()),
              ]),
            ),
          ),
        ]),
      );
    }
    final esPdf = targetUrl.toLowerCase().contains('.pdf') ||
        (widget.examen.formato ?? '').toLowerCase() == 'pdf';

    if (esPdf) {
      return Container(
        height: 300, width: double.infinity, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCBD5E1))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 48)),
          const SizedBox(height: 16),
          Text(widget.examen.titulo ?? 'Documento Clínico en PDF', style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Documento digital disponible para visualización en alta definición.', style: TextStyle(fontSize: 12.5, color: Colors.black54), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _abrirEnlaceExterno,
            icon: const Icon(Icons.visibility_rounded, size: 18),
            label: const Text('Abrir y Visualizar PDF Completo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      );
    }

    // Formatos médicos especiales (ej. ECG, DICOM, XML, DAT) no previsualizables en navegador
    return Container(
      height: 300, width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCBD5E1))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFE0F2FE), shape: BoxShape.circle), child: const Icon(Icons.monitor_heart_rounded, color: Color(0xFF0284C7), size: 48)),
        const SizedBox(height: 16),
        Text(widget.examen.titulo ?? 'Archivo de Estudio Médico', style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Formato especial (${(widget.examen.formato ?? "archivo").toUpperCase()}). Descárgalo para abrirlo en tu programa médico especializado.',
          style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: _abrirEnlaceExterno,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Descargar Archivo Original', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

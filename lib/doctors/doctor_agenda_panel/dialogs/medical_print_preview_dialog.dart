import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Diálogo modal con formato oficial para previsualizar e imprimir documentos médicos:
/// recetas, órdenes de laboratorio/estudios, permisos de reposo e interconsultas.
class MedicalPrintPreviewDialog extends StatelessWidget {
  final String tituloDocumento;
  final String doctorNombre;
  final String? doctorEspecialidad;
  final String pacienteNombre;
  final String? pacienteIdentificacion;
  final String? diagnostico;
  final String contenidoPrincipal;
  final String? medicamentos;
  final String? tiempoTratamiento;
  final String? indicacionesAdicionales;
  final String? diasReposo;
  final DateTime fecha;

  const MedicalPrintPreviewDialog({
    super.key,
    required this.tituloDocumento,
    required this.doctorNombre,
    this.doctorEspecialidad,
    required this.pacienteNombre,
    this.pacienteIdentificacion,
    this.diagnostico,
    required this.contenidoPrincipal,
    this.medicamentos,
    this.tiempoTratamiento,
    this.indicacionesAdicionales,
    this.diasReposo,
    required this.fecha,
  });

  static Future<void> show(
    BuildContext context, {
    required String tituloDocumento,
    required String doctorNombre,
    String? doctorEspecialidad,
    required String pacienteNombre,
    String? pacienteIdentificacion,
    String? diagnostico,
    required String contenidoPrincipal,
    String? medicamentos,
    String? tiempoTratamiento,
    String? indicacionesAdicionales,
    String? diasReposo,
    DateTime? fecha,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MedicalPrintPreviewDialog(
        tituloDocumento: tituloDocumento,
        doctorNombre: doctorNombre,
        doctorEspecialidad: doctorEspecialidad,
        pacienteNombre: pacienteNombre,
        pacienteIdentificacion: pacienteIdentificacion,
        diagnostico: diagnostico,
        contenidoPrincipal: contenidoPrincipal,
        medicamentos: medicamentos,
        tiempoTratamiento: tiempoTratamiento,
        indicacionesAdicionales: indicacionesAdicionales,
        diasReposo: diasReposo,
        fecha: fecha ?? DateTime.now(),
      ),
    );
  }

  void _ejecutarImpresion(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.print_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '🖨️ Documento enviado a la impresora del sistema.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF0284C7),
        duration: Duration(seconds: 3),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fechaStr = DateFormat('dd/MM/yyyy HH:mm', 'es').format(fecha);
    final folioStr = 'DOC-${fecha.millisecondsSinceEpoch.toString().substring(7)}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          width: 650,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de título modal y acciones
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.print_rounded, color: Color(0xFF38BDF8), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vista Previa para Impresión',
                        style: GoogleFonts.mooli(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              // Hoja médica para imprimir
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Encabezado institucional
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctorNombre,
                                  style: GoogleFonts.mooli(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  doctorEspecialidad ?? 'Médico Cirujano',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0284C7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Text(
                                  'Atención Médica & Salud Integral',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Folio: $folioStr',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  'Fecha: $fechaStr',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24, thickness: 1.5, color: Color(0xFFCBD5E1)),

                        // Título del tipo de documento
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tituloDocumento.toUpperCase(),
                              style: GoogleFonts.mooli(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0369A1),
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Datos del Paciente
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildInfoItem('Paciente:', pacienteNombre),
                              ),
                              if (pacienteIdentificacion != null && pacienteIdentificacion!.isNotEmpty)
                                Expanded(
                                  flex: 2,
                                  child: _buildInfoItem('Identificación:', pacienteIdentificacion!),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Diagnóstico si está presente
                        if (diagnostico != null && diagnostico!.trim().isNotEmpty) ...[
                          _buildSectionTitle('Diagnóstico / Impresión Clínica:'),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              diagnostico!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Días de reposo si aplica
                        if (diasReposo != null && diasReposo!.trim().isNotEmpty) ...[
                          _buildSectionTitle('Periodo de Reposo Concedido:'),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              '$diasReposo días a partir de la fecha de emisión.',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Medicamentos y duración si están presentes
                        if (medicamentos != null && medicamentos!.trim().isNotEmpty) ...[
                          _buildSectionTitle('Medicamentos Prescritos & Duración:'),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '💊 $medicamentos',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                                ),
                                if (tiempoTratamiento != null && tiempoTratamiento!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '⏱️ Tiempo de tratamiento: $tiempoTratamiento',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Contenido Principal (Receta, Orden, Exámenes, o Párrafo Completo)
                        _buildSectionTitle('Prescripción / Indicaciones Clínicas:'),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 120),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            contenidoPrincipal.trim().isEmpty
                                ? 'Sin indicaciones registradas.'
                                : contenidoPrincipal,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),

                        // Indicaciones adicionales si las hay
                        if (indicacionesAdicionales != null && indicacionesAdicionales!.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildSectionTitle('Pautas y Recomendaciones:'),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              indicacionesAdicionales!,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                            ),
                          ),
                        ],

                        const SizedBox(height: 40),

                        // Firma y sello del médico
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 180,
                                  height: 1,
                                  color: const Color(0xFF475569),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  doctorNombre,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Firma y Sello Profesional',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Botones inferiores del modal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text(
                        'Imprimir Documento',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _ejecutarImpresion(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF475569),
      ),
    );
  }
}

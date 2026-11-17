import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/ai_clinical_summary_service.dart';
import '../../../services/i18n_service.dart';

/// Tarjeta que muestra los resultados de exámenes de laboratorio e imagen pendientes de revisión y firma.
class PendingLabsCard extends StatelessWidget {
  final List<ExamenesMedicosRow> examenesPendientes;
  final Map<String, UsuariosRow> pacientesExamenesMap;
  final void Function(ExamenesMedicosRow examen, UsuariosRow? paciente)
      onRevisarExamen;

  const PendingLabsCard({
    super.key,
    required this.examenesPendientes,
    required this.pacientesExamenesMap,
    required this.onRevisarExamen,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.science_rounded,
                        color: Color(0xFFE11D48), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEs ? 'Resultados por Revisar y Firmar' : 'Results to Review & Sign',
                    style: GoogleFonts.mooli(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${examenesPendientes.length} ${isEs ? "Pendientes" : "Pending"}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE11D48),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          if (examenesPendientes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  isEs
                      ? 'No hay estudios médicos pendientes por revisar.'
                      : 'No pending medical studies to review.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: examenesPendientes.length.clamp(0, 4),
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final ex = examenesPendientes[index];
                final pacienteEx = pacientesExamenesMap[ex.idPaciente];
                final fechaEntrega = ex.fechaEntrega ??
                    ex.createdAt.add(const Duration(days: 7));
                final badgeTiempo =
                    AiClinicalSummaryService.formatearTiempoRevision(
                        fechaEntrega);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  pacienteEx?.nombre ?? (isEs ? 'Paciente' : 'Patient'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (ex.especialidad != null &&
                                  ex.especialidad!.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    ex.especialidad!,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF334155),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ex.tipoExamen ?? (isEs ? 'Laboratorio' : 'Laboratory'),
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ex.titulo ?? (isEs ? 'Hemograma / Estudio Diagnóstico' : 'Complete Blood Count / Diagnostic Study'),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 3,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event_available_rounded,
                                      size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${isEs ? "Entrega" : "Due"}: ${DateFormat('dd/MM/yyyy').format(fechaEntrega)}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: badgeTiempo['bgColor'] as Color? ??
                                      const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 10,
                                      color: badgeTiempo['color'] as Color? ??
                                          Colors.grey.shade700,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      badgeTiempo['texto'] as String? ?? '',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            badgeTiempo['color'] as Color? ??
                                                Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF0F9FF),
                        foregroundColor: const Color(0xFF0369A1),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: const Size(60, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                        ),
                      ),
                      onPressed: () => onRevisarExamen(ex, pacienteEx),
                      child: Text(isEs ? 'Revisar' : 'Review',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../flutter_flow/flutter_flow_theme.dart';

/// Componente modular: Pestaña de Consultas y Citas médicas pasadas y programadas.
class PatientConsultasTab extends StatelessWidget {
  final List<CitasRow> citas;
  final Map<String, TriageConsultasRow> triageMap;
  final Map<String, UsuariosRow> doctoresMap;

  const PatientConsultasTab({
    super.key,
    required this.citas,
    required this.triageMap,
    required this.doctoresMap,
  });

  Widget _buildVitalMini(IconData icon, String valor, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF0284C7)),
          const SizedBox(width: 4),
          Text(
            '$label: $valor',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (citas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month, size: 52, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                'No hay consultas registradas para este paciente.',
                style: GoogleFonts.mooli(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: citas.length,
      itemBuilder: (context, index) {
        final c = citas[index];
        final fechaStr = c.fechaHora != null
            ? DateFormat('dd/MM/yyyy - hh:mm a').format(c.fechaHora!)
            : 'Sin fecha';
        final doctor = doctoresMap[c.idDoctor];
        final triage = triageMap[c.id];
        final estado = c.estado ?? 'completada';

        Color badgeColor = const Color(0xFF10B981);
        String estadoTexto = 'Completada';
        if (estado == 'programada' || estado == 'confirmada') {
          badgeColor = const Color(0xFF0284C7);
          estadoTexto = 'Programada';
        } else if (estado == 'en_espera') {
          badgeColor = const Color(0xFFF59E0B);
          estadoTexto = 'En Sala de Espera';
        } else if (estado == 'cancelada') {
          badgeColor = const Color(0xFFEF4444);
          estadoTexto = 'Cancelada';
        }

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: FlutterFlowTheme.of(context).alternate),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      fechaStr,
                      style: GoogleFonts.mooli(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: FlutterFlowTheme.of(context).primaryText,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        estadoTexto,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (doctor != null)
                  Text(
                    'Médico: Dr(a). ${doctor.nombre}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                  ),
                if (c.motivo != null && c.motivo!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Motivo: ${c.motivo}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],

                // Indicador de triaje si existe
                if (triage != null) ...[
                  const Divider(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (triage.nivelUrgencia != null)
                        _buildVitalMini(Icons.priority_high,
                            triage.nivelUrgencia!, 'Urgencia'),
                      if (triage.requiereHospital == true)
                        _buildVitalMini(Icons.local_hospital_outlined,
                            'Sí', 'Hospitalización'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

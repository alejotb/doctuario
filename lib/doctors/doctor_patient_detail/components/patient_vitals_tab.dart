import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../flutter_flow/flutter_flow_theme.dart';

/// Componente modular: Pestaña de Signos Vitales y Triaje Preconsulta del paciente.
class PatientVitalsTab extends StatelessWidget {
  final TriageConsultasRow? ultimoTriage;
  final VoidCallback onActualizarSignos;

  const PatientVitalsTab({
    super.key,
    required this.ultimoTriage,
    required this.onActualizarSignos,
  });

  Widget _buildVitalCard(
      String label, String valor, String unidad, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      valor,
                      style: GoogleFonts.mooli(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (unidad.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      Text(
                        unidad,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ultimoTriage;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VALORACIÓN DE TRIAJE & SIGNOS',
                style: GoogleFonts.mooli(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              TextButton.icon(
                onPressed: onActualizarSignos,
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text('Actualizar Triaje'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (t == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text(
                  'No se ha registrado triaje para este paciente.\nLa secretaria o el médico pueden registrarlo al recibir al paciente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            )
          else ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                _buildVitalCard(
                  'Nivel de Urgencia',
                  t.nivelUrgencia ?? 'Normal',
                  '',
                  Icons.priority_high,
                  t.nivelUrgencia == 'alta'
                      ? const Color(0xFFE11D48)
                      : const Color(0xFF2563EB),
                ),
                _buildVitalCard(
                  'Hospitalización',
                  t.requiereHospital == true ? 'Requiere' : 'No requiere',
                  '',
                  Icons.local_hospital_outlined,
                  const Color(0xFF0D9488),
                ),
              ],
            ),
            if (t.descripcionSintomas != null && t.descripcionSintomas!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SÍNTOMAS REPORTADOS EN RECEPCIÓN:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.descripcionSintomas!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 24),
          Text(
            'ANTECEDENTES MÉDICOS',
            style: GoogleFonts.mooli(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FlutterFlowTheme.of(context).alternate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAntecedenteFila('Patológicos / Crónicos:',
                    'Registrados por el especialista en la evolución clínica.'),
                const Divider(height: 16),
                _buildAntecedenteFila(
                    'Quirúrgicos:', 'Sin intervenciones reportadas recientemente.'),
                const Divider(height: 16),
                _buildAntecedenteFila(
                    'Alergias Conocidas:', 'Verificadas en cada consulta.'),
                const Divider(height: 16),
                _buildAntecedenteFila('Familiares:',
                    'Antecedentes directos consignados en la anamnesis.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAntecedenteFila(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }
}

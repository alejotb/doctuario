import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Componente modular: Resumen clínico privado del médico con asistencia de IA.
class AiClinicalSummaryCard extends StatelessWidget {
  final TextEditingController controller;
  final bool generandoConIA;
  final bool guardandoResumen;
  final bool resumenModificado;
  final VoidCallback onGenerarConIA;
  final VoidCallback onGuardarResumen;

  const AiClinicalSummaryCard({
    super.key,
    required this.controller,
    required this.generandoConIA,
    required this.guardandoResumen,
    required this.resumenModificado,
    required this.onGenerarConIA,
    required this.onGuardarResumen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 16, color: Color(0xFF0369A1)),
                  const SizedBox(width: 6),
                  Text(
                    'Resumen Clínico Confidencial (Solo para ti)',
                    style: GoogleFonts.mooli(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0369A1),
                    ),
                  ),
                ],
              ),
              if (generandoConIA)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton.icon(
                  onPressed: onGenerarConIA,
                  icon: const Icon(Icons.auto_awesome,
                      size: 14, color: Color(0xFF0284C7)),
                  label: const Text(
                    'Generar con IA',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 4,
            style: GoogleFonts.mooli(fontSize: 12.5, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText:
                  'Escribe un resumen privado sobre este paciente o pulsa "Generar con IA" para sintetizar las consultas y estudios previos...',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0284C7)),
              ),
            ),
          ),
          if (resumenModificado) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: guardandoResumen ? null : onGuardarResumen,
                icon: guardandoResumen
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 14),
                label: const Text('Guardar Resumen Privado',
                    style: TextStyle(fontSize: 11.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

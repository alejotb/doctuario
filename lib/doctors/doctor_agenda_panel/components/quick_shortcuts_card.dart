import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tarjeta oscura de accesos directos médicos: Nueva Cita, Orden Médica, Reposo, Interconsulta.
class QuickShortcutsCard extends StatelessWidget {
  final VoidCallback onNuevaCita;
  final VoidCallback onOrdenMedica;
  final VoidCallback onReposoMedico;
  final VoidCallback onInterconsulta;

  const QuickShortcutsCard({
    super.key,
    required this.onNuevaCita,
    required this.onOrdenMedica,
    required this.onReposoMedico,
    required this.onInterconsulta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acciones Médicas Frecuentes',
            style: GoogleFonts.mooli(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Acceso ágil a emisión de órdenes y certificados',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              _buildShortcutButton(
                icon: Icons.add_circle_outline,
                iconColor: const Color(0xFF38BDF8),
                title: 'Nueva Cita',
                subtitle: 'Cupo adicional',
                onTap: onNuevaCita,
              ),
              _buildShortcutButton(
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF34D399),
                title: 'Orden Médica',
                subtitle: 'Lab / Rayos X',
                onTap: onOrdenMedica,
              ),
              _buildShortcutButton(
                icon: Icons.assignment_turned_in_outlined,
                iconColor: const Color(0xFFA78BFA),
                title: 'Reposo Médico',
                subtitle: 'Incapacidad',
                onTap: onReposoMedico,
              ),
              _buildShortcutButton(
                icon: Icons.alt_route_rounded,
                iconColor: const Color(0xFF2DD4BF),
                title: 'Interconsulta',
                subtitle: 'Especialidades',
                onTap: onInterconsulta,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutButton({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF334155).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 9, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

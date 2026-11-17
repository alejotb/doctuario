import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../flutter_flow/flutter_flow_theme.dart';

/// Tarjeta de presentación individual de un paciente en el listado del doctor.
///
/// Muestra avatar, nombre, badges y una columna lateral con información
/// compacta y legible de Cédula de Identidad y Fecha de Última Cita.
class DoctorPatientCard extends StatelessWidget {
  /// Datos del paciente (tabla usuarios / pacientes)
  final UsuariosRow paciente;

  /// Indica si el paciente tiene estatus de preferencial para este doctor
  final bool esPreferencial;

  /// Número total de consultas / citas registradas con este doctor
  final int totalConsultas;

  /// Fecha y hora de la última cita médica registrada
  final DateTime? ultimaCita;

  /// Callback al presionar sobre la tarjeta para abrir el expediente
  final VoidCallback onTap;

  const DoctorPatientCard({
    super.key,
    required this.paciente,
    required this.esPreferencial,
    required this.totalConsultas,
    required this.ultimaCita,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final String ultimaCitaStr = ultimaCita != null
        ? DateFormat('dd/MM/yyyy').format(ultimaCita!)
        : 'Sin citas';

    final String cedulaStr = (paciente.cedula != null && paciente.cedula!.trim().isNotEmpty)
        ? paciente.cedula!.trim()
        : 'S/C';

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: esPreferencial
            ? BorderSide(color: Colors.amber.shade600, width: 1.5)
            : BorderSide(color: theme.alternate),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(theme),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMainInfo(theme),
              ),
              const SizedBox(width: 10),
              _buildSideDetailsColumn(theme, cedulaStr, ultimaCitaStr),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el avatar del paciente con imagen de perfil o fallback
  Widget _buildAvatar(FlutterFlowTheme theme) {
    final hasPhoto = paciente.fotoUrl != null && paciente.fotoUrl!.trim().isNotEmpty;
    return CircleAvatar(
      radius: 26,
      backgroundColor: theme.primary.withValues(alpha: 0.1),
      backgroundImage: hasPhoto ? NetworkImage(paciente.fotoUrl!) : null,
      child: !hasPhoto
          ? Icon(
              Icons.person,
              size: 26,
              color: theme.primary,
            )
          : null,
    );
  }

  /// Columna principal: Nombre del paciente, badge de preferencial y etiquetas secundarias
  Widget _buildMainInfo(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                paciente.nombre ?? 'Paciente',
                style: GoogleFonts.mooli(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.0,
                  color: theme.primaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (esPreferencial) ...[
              const SizedBox(width: 6),
              _buildPreferencialBadge(),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (paciente.ciudadOrigen != null &&
                paciente.ciudadOrigen!.trim().isNotEmpty)
              _buildCiudadTag(theme),
            _buildConsultasTag(theme),
          ],
        ),
      ],
    );
  }

  /// Columna lateral con detalles discretos (Cédula y Última Cita)
  Widget _buildSideDetailsColumn(
    FlutterFlowTheme theme,
    String cedula,
    String ultimaCitaStr,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primaryBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.alternate.withValues(alpha: 0.8),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila Cédula de Identidad
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.badge_outlined,
                size: 13,
                color: theme.secondaryText,
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 85),
                child: Text(
                  cedula,
                  style: GoogleFonts.mooli(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Fila Última Cita
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 13,
                color: ultimaCita != null
                    ? const Color(0xFF0284C7)
                    : theme.secondaryText,
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 85),
                child: Text(
                  ultimaCitaStr,
                  style: GoogleFonts.mooli(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w500,
                    color: ultimaCita != null
                        ? const Color(0xFF0284C7)
                        : theme.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Insignia para pacientes preferenciales
  Widget _buildPreferencialBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.shade700, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade900),
          const SizedBox(width: 2),
          Text(
            'Preferencial',
            style: TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade900,
            ),
          ),
        ],
      ),
    );
  }

  /// Etiqueta de procedencia / ciudad origen
  Widget _buildCiudadTag(FlutterFlowTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paciente.esForaneo == true
                ? Icons.directions_car_rounded
                : Icons.location_on_rounded,
            size: 11,
            color: Colors.blue.shade800,
          ),
          const SizedBox(width: 3),
          Text(
            paciente.ciudadOrigen!,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }

  /// Etiqueta con el total acumulado de consultas
  Widget _buildConsultasTag(FlutterFlowTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_edu_rounded,
            size: 11,
            color: Colors.teal.shade800,
          ),
          const SizedBox(width: 3),
          Text(
            '$totalConsultas ${totalConsultas == 1 ? 'consulta' : 'consultas'}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Colors.teal.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

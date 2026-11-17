import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../flutter_flow/flutter_flow_theme.dart';

/// Componente modular: Encabezado con datos del paciente, contacto y estado preferencial / colega.
class PatientHeaderCard extends StatelessWidget {
  final UsuariosRow? paciente;
  final bool esPrimeraConsulta;
  final VoidCallback onEditarFamiliarColega;
  final VoidCallback onEditarPaciente;
  final CitasRow? ultimaConsulta;
  final CitasRow? proximaConsulta;

  const PatientHeaderCard({
    super.key,
    required this.paciente,
    required this.esPrimeraConsulta,
    required this.onEditarFamiliarColega,
    required this.onEditarPaciente,
    this.ultimaConsulta,
    this.proximaConsulta,
  });

  String _calcularEdad(DateTime? fechaNac) {
    if (fechaNac == null) return 'Edad no reg.';
    final ahora = DateTime.now();
    int edad = ahora.year - fechaNac.year;
    if (ahora.month < fechaNac.month ||
        (ahora.month == fechaNac.month && ahora.day < fechaNac.day)) {
      edad--;
    }
    return '$edad años';
  }

  Future<void> _abrirLlamada(String? telefono) async {
    if (telefono == null || telefono.isEmpty) return;
    final uri = Uri.parse('tel:$telefono');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _abrirWhatsApp(String? telefono) async {
    if (telefono == null || telefono.isEmpty) return;
    final telLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$telLimpio');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = paciente;
    final nombre = p?.nombre ?? 'Paciente';
    final cedula = p?.cedula ?? 'Sin cédula';
    final telefono = p?.telefono ?? '';
    final ciudad = p?.ciudadOrigen ?? '';
    final esFamiliar = p?.esFamiliarMedico ?? false;
    final edadStr = _calcularEdad(p?.fechaNacimiento);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        border: Border(
          bottom: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 64,
                  height: 64,
                  color: const Color(0xFFE0F2FE),
                  child: p?.fotoUrl != null && p!.fotoUrl!.isNotEmpty
                      ? Image.network(
                          p.fotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 36,
                            color: Color(0xFF0284C7),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 36,
                          color: Color(0xFF0284C7),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Nombre, cédula y edad
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: GoogleFonts.mooli(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: FlutterFlowTheme.of(context).primaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Cédula: $cedula',
                          style: TextStyle(
                            fontSize: 12,
                            color: FlutterFlowTheme.of(context).secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  $edadStr',
                          style: TextStyle(
                            fontSize: 12,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                        ),
                      ],
                    ),
                    if (ciudad.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 13,
                              color: FlutterFlowTheme.of(context).secondaryText),
                          const SizedBox(width: 3),
                          Text(
                            ciudad,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Botones de edición, llamada y WhatsApp
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 20, color: Color(0xFF0284C7)),
                    onPressed: onEditarPaciente,
                    tooltip: 'Editar información del paciente',
                  ),
                  if (telefono.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.phone_outlined,
                          size: 20, color: Color(0xFF0284C7)),
                      onPressed: () => _abrirLlamada(telefono),
                      tooltip: 'Llamar al paciente',
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline,
                          size: 20, color: Color(0xFF16A34A)),
                      onPressed: () => _abrirWhatsApp(telefono),
                      tooltip: 'Escribir por WhatsApp',
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Chips de estado y Familiar de Colega
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Chip Primera Consulta
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: esPrimeraConsulta
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: esPrimeraConsulta
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFBAE6FD),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      esPrimeraConsulta
                          ? Icons.fiber_new_rounded
                          : Icons.verified_outlined,
                      size: 13,
                      color: esPrimeraConsulta
                          ? const Color(0xFFB45309)
                          : const Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      esPrimeraConsulta ? 'Primera Consulta' : 'Paciente Frecuente',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: esPrimeraConsulta
                            ? const Color(0xFFB45309)
                            : const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),

              // Chip Familiar de Colega (Tappable para editar exoneración)
              InkWell(
                onTap: onEditarFamiliarColega,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: esFamiliar
                        ? const Color(0xFFF0FDF4)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: esFamiliar
                          ? const Color(0xFFBBF7D0)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        esFamiliar ? Icons.favorite : Icons.favorite_border,
                        size: 13,
                        color: esFamiliar
                            ? const Color(0xFF16A34A)
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        esFamiliar
                            ? 'Familiar de Colega (${p?.lazoFamiliar ?? "Colega"})'
                            : 'Definir Familiar de Colega',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: esFamiliar
                              ? const Color(0xFF15803D)
                              : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit,
                          size: 11,
                          color: esFamiliar
                              ? const Color(0xFF15803D)
                              : Colors.grey.shade500),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Resumen de Consultas: Última y Próxima Consulta
          _buildConsultasTrackingCard(context),
        ],
      ),
    );
  }

  Widget _buildConsultasTrackingCard(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final ultDt = ultimaConsulta?.fechaHora?.toLocal();
    final proxDt = proximaConsulta?.fechaHora?.toLocal();

    final ultStr = ultDt != null
        ? DateFormat("dd/MM/yyyy • hh:mm a").format(ultDt)
        : 'Sin consultas previas';

    final proxStr = proxDt != null
        ? DateFormat("dd/MM/yyyy • hh:mm a").format(proxDt)
        : 'Ninguna programada';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Última Consulta
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF475569)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ÚLTIMA CONSULTA',
                        style: GoogleFonts.mooli(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ultStr,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: ultDt != null ? theme.primaryText : Colors.grey.shade500,
                        ),
                      ),
                      if (ultimaConsulta?.estado != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          'Estado: ${ultimaConsulta!.estado}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 38, width: 1, color: const Color(0xFFCBD5E1)),
          const SizedBox(width: 12),
          // Próxima Consulta
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: proxDt != null ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.event_available_rounded,
                    size: 16,
                    color: proxDt != null ? const Color(0xFF16A34A) : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRÓXIMA CONSULTA',
                        style: GoogleFonts.mooli(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: proxDt != null ? const Color(0xFF15803D) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        proxStr,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: proxDt != null ? const Color(0xFF0F172A) : Colors.grey.shade500,
                        ),
                      ),
                      if (proximaConsulta?.modalidadAtencion != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          'Modo: ${proximaConsulta!.modalidadAtencion}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

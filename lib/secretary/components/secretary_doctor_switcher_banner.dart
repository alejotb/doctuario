import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/supabase/supabase.dart';

/// Barra de recepción unificada para la secretaria.
/// Muestra al médico actual, la sede asignada (o selector), métricas de sala
/// y el botón para vincular un nuevo médico a la derecha.
class SecretaryDoctorSwitcherBanner extends StatelessWidget {
  const SecretaryDoctorSwitcherBanner({
    super.key,
    required this.doctoresAsignados,
    required this.doctorSeleccionadoId,
    required this.onDoctorChanged,
    required this.sedesDoctor,
    required this.sedeSeleccionadaId,
    required this.onSedeChanged,
    required this.enEsperaCount,
    required this.enConsultaCount,
    required this.pendientesCount,
    required this.onVincularDoctor,
  });

  final List<UsuariosRow> doctoresAsignados;
  final String? doctorSeleccionadoId;
  final ValueChanged<String?> onDoctorChanged;
  final List<DoctorSedesRow> sedesDoctor;
  final String? sedeSeleccionadaId;
  final ValueChanged<String?> onSedeChanged;
  final int enEsperaCount;
  final int enConsultaCount;
  final int pendientesCount;
  final VoidCallback onVincularDoctor;

  String _nombreSede(DoctorSedesRow s) {
    if (s.nombreSede != null && s.nombreSede!.trim().isNotEmpty) return s.nombreSede!.trim();
    if (s.numeroConsultorio != null && s.numeroConsultorio!.trim().isNotEmpty) return s.numeroConsultorio!.trim();
    if (s.ciudad != null && s.ciudad!.trim().isNotEmpty) return 'Consultorio en ${s.ciudad}';
    return 'Consultorio Principal';
  }

  @override
  Widget build(BuildContext context) {
    final doctorActual = doctoresAsignados.firstWhere(
      (d) => d.id == doctorSeleccionadoId,
      orElse: () => doctoresAsignados.isNotEmpty ? doctoresAsignados.first : UsuariosRow({'nombre': 'Doctor'}),
    );

    final tieneMultiplesSedes = sedesDoctor.length > 1;
    final sedeActual = sedesDoctor.firstWhere(
      (s) => s.id == sedeSeleccionadaId,
      orElse: () => sedesDoctor.isNotEmpty ? sedesDoctor.first : DoctorSedesRow({'nombre_sede': 'Consultorio Principal'}),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila Principal: Médico actual, Sede y Botón "Vincular Médico"
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar del Doctor
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE0F2FE),
                backgroundImage: (doctorActual.fotoUrl != null && doctorActual.fotoUrl!.isNotEmpty)
                    ? NetworkImage(doctorActual.fotoUrl!)
                    : null,
                child: (doctorActual.fotoUrl == null || doctorActual.fotoUrl!.isEmpty)
                    ? const Icon(Icons.medical_services_rounded, color: Color(0xFF0284C7), size: 24)
                    : null,
              ),
              const SizedBox(width: 12),

              // Información del Médico y Selector
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
                              SizedBox(width: 4),
                              Text(
                                'EN SERVICIO',
                                style: TextStyle(
                                  color: Color(0xFF047857),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (doctoresAsignados.length > 1)
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: doctorSeleccionadoId,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF0284C7), size: 22),
                          items: doctoresAsignados.map((d) {
                            return DropdownMenuItem<String>(
                              value: d.id,
                              child: Text(
                                'Dr(a). ${(d.nombre ?? "Médico").trim()}',
                                style: GoogleFonts.mooli(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: onDoctorChanged,
                        ),
                      )
                    else
                      Text(
                        'Dr(a). ${(doctorActual.nombre ?? "Médico").trim()}',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.mooli(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Botón "Vincular Médico" ubicado a la derecha del médico
              ElevatedButton.icon(
                onPressed: onVincularDoctor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F9FF),
                  foregroundColor: const Color(0xFF0284C7),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: Text(
                  'Vincular Médico',
                  style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Fila Secundaria: Sede asignada (o selector si tiene varias) + Contadores de Sala
          Row(
            children: [
              // Sede o Selector de Sede
              Expanded(
                child: tieneMultiplesSedes
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: sedesDoctor.any((s) => s.id == sedeSeleccionadaId)
                                ? sedeSeleccionadaId
                                : (sedesDoctor.isNotEmpty ? sedesDoctor.first.id : null),
                            isDense: true,
                            isExpanded: true,
                            icon: const Icon(Icons.location_on_rounded, color: Color(0xFF0284C7), size: 16),
                            items: sedesDoctor.map((s) {
                              return DropdownMenuItem<String>(
                                value: s.id,
                                child: Text(
                                  _nombreSede(s),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: onSedeChanged,
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, color: Color(0xFF16A34A), size: 15),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _nombreSede(sedeActual),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              const SizedBox(width: 10),

              // Contadores compactos de recepción
              _buildMetricChip('En Sala', '$enEsperaCount', const Color(0xFF059669), const Color(0xFFECFDF5)),
              const SizedBox(width: 6),
              _buildMetricChip('En Consulta', '$enConsultaCount', const Color(0xFF0284C7), const Color(0xFFF0F9FF)),
              const SizedBox(width: 6),
              _buildMetricChip('Pendientes', '$pendientesCount', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

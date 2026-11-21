import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';

/// Sección para seleccionar la Sede de atención y la Fecha/Hora de la cita
/// con soporte para detección inteligente de la sede según los días y horario del doctor.
class AppointmentVenueDatetimeSection extends StatelessWidget {
  final List<DoctorSedesRow> sedes;
  final String? idSedeSeleccionada;
  final String? sedeDetectadaAuto;
  final DateTime fechaCita;
  final String horaSeleccionadaStr;
  final bool esEmergencia;
  final bool esOrdenLlegada;
  final List<String> horasDisponibles;
  final ValueChanged<String?> onSedeChanged;
  final ValueChanged<DateTime> onFechaChanged;
  final ValueChanged<String> onHoraChanged;
  final VoidCallback onCrearSedeRapida;
  final VoidCallback? onIrAConfigurarSedes;

  const AppointmentVenueDatetimeSection({
    super.key,
    required this.sedes,
    required this.idSedeSeleccionada,
    required this.sedeDetectadaAuto,
    required this.fechaCita,
    required this.horaSeleccionadaStr,
    required this.esEmergencia,
    this.esOrdenLlegada = false,
    required this.horasDisponibles,
    required this.onSedeChanged,
    required this.onFechaChanged,
    required this.onHoraChanged,
    required this.onCrearSedeRapida,
    this.onIrAConfigurarSedes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Encabezado de Sede
        Row(
          children: [
            Expanded(
              child: Text(
                '2. Sede de Atención:',
                style: GoogleFonts.mooli(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (sedeDetectadaAuto != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 12,
                      color: Color(0xFF1D4ED8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sugerida',
                      style: GoogleFonts.mooli(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Selector de Sedes o botón de creación si está vacío
        if (sedes.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            key: ValueKey(idSedeSeleccionada),
            isExpanded: true,
            initialValue: sedes.any((s) => s.id == idSedeSeleccionada)
                ? idSedeSeleccionada
                : (sedes.isNotEmpty ? sedes.first.id : null),
            decoration: const InputDecoration(
              labelText: 'Consultorio / Sede Médica',
              isDense: true,
              border: OutlineInputBorder(),
              prefixIcon: Icon(
                Icons.location_on_rounded,
                size: 18,
                color: Color(0xFF0284C7),
              ),
            ),
            selectedItemBuilder: (context) {
              return sedes.map((s) {
                final ciudad = (s.ciudad?.isNotEmpty == true) ? ' (${s.ciudad})' : '';
                return Text(
                  '${s.nombreSede ?? "Consultorio"}$ciudad',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12.5),
                );
              }).toList();
            },
            items: sedes.map((s) {
              final ciudad = (s.ciudad?.isNotEmpty == true) ? ' (${s.ciudad})' : '';
              final dias = s.diasAtencion?.isNotEmpty == true
                  ? ' • ${s.diasAtencion}'
                  : '';
              return DropdownMenuItem(
                value: s.id,
                child: Text(
                  '${s.nombreSede ?? "Consultorio"}$ciudad$dias',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            onChanged: onSedeChanged,
          ),
          if (sedeDetectadaAuto != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Detectada automáticamente según tu horario de los ${DateFormat("EEEE", "es").format(fechaCita)}.',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2563EB),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ] else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No tienes sedes vinculadas para este horario.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (onIrAConfigurarSedes != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.settings_suggest_rounded, size: 14),
                          label: const Text(
                            'Configurar Sedes',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: onIrAConfigurarSedes,
                        ),
                      ),
                    if (onIrAConfigurarSedes != null) const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.add_location_alt_rounded, size: 14),
                        label: const Text(
                          'Crear Principal',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: onCrearSedeRapida,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // 2. Selector de Fecha y Hora (si no es urgencia inmediata)
        if (!esEmergencia) ...[
          Text(
            '3. Fecha y Hora de la Cita:',
            style: GoogleFonts.mooli(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final hoy = DateTime(now.year, now.month, now.day);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          fechaCita.isBefore(hoy) ? hoy : fechaCita,
                      firstDate: hoy,
                      lastDate: hoy.add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      onFechaChanged(picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            DateFormat("EEE, d 'de' MMM", 'es')
                                .format(fechaCita),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (esOrdenLlegada)
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.groups_rounded, size: 16, color: Color(0xFF0F766E)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Por orden de llegada',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(horaSeleccionadaStr),
                    isExpanded: true,
                    initialValue: horaSeleccionadaStr,
                    decoration: const InputDecoration(
                      labelText: 'Hora',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    items: horasDisponibles
                        .map((h) => DropdownMenuItem(
                              value: h,
                              child: Text(
                                h,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) onHoraChanged(val);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

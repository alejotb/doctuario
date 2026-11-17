import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/doctor_setup_ui_helpers.dart';

class DoctorScheduleStep extends StatelessWidget {
  const DoctorScheduleStep({
    super.key,
    required this.diasSeleccionados,
    required this.onDiaToggle,
    required this.horaInicio,
    required this.horaFin,
    required this.onSeleccionarHora,
    required this.tienePausaAlmuerzo,
    required this.onTienePausaAlmuerzoChanged,
    required this.horaInicioAlmuerzo,
    required this.horaFinAlmuerzo,
    required this.onSeleccionarHoraAlmuerzo,
    required this.modalidadAtencion,
    required this.onModalidadChanged,
    required this.duracionMinutos,
    required this.onDuracionChanged,
    required this.formatearTimeOfDay,
  });

  final Set<int> diasSeleccionados;
  final Function(int dia, bool selected) onDiaToggle;
  final TimeOfDay horaInicio;
  final TimeOfDay horaFin;
  final Function(bool esInicio) onSeleccionarHora;
  final bool tienePausaAlmuerzo;
  final ValueChanged<bool> onTienePausaAlmuerzoChanged;
  final TimeOfDay horaInicioAlmuerzo;
  final TimeOfDay horaFinAlmuerzo;
  final Function(bool esInicio) onSeleccionarHoraAlmuerzo;
  final String modalidadAtencion;
  final ValueChanged<String> onModalidadChanged;
  final int duracionMinutos;
  final ValueChanged<int> onDuracionChanged;
  final String Function(TimeOfDay) formatearTimeOfDay;

  @override
  Widget build(BuildContext context) {
    const diasMap = {
      1: 'Lun',
      2: 'Mar',
      3: 'Mié',
      4: 'Jue',
      5: 'Vie',
      6: 'Sáb',
      7: 'Dom',
    };

    return DoctorSetupCardWrapper(
      icon: Icons.access_time_filled_rounded,
      iconColor: const Color(0xFF059669),
      title: '2. Días y Horarios de Atención',
      subtitle: 'Configura los días en que pasas consulta y tu horario de inicio y fin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Días de Consulta Activa:',
            style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: diasMap.entries.map((entry) {
              final diaNum = entry.key;
              final diaNombre = entry.value;
              final isSelected = diasSeleccionados.contains(diaNum);

              return FilterChip(
                label: Text(diaNombre),
                selected: isSelected,
                selectedColor: const Color(0xFF0284C7),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12.5,
                ),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                  ),
                ),
                onSelected: (selected) => onDiaToggle(diaNum, selected),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DoctorSetupTimePickerBox(
                  label: 'Hora de Inicio',
                  timeStr: formatearTimeOfDay(horaInicio),
                  icon: Icons.wb_sunny_rounded,
                  onTap: () => onSeleccionarHora(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DoctorSetupTimePickerBox(
                  label: 'Hora de Fin',
                  timeStr: formatearTimeOfDay(horaFin),
                  icon: Icons.nightlight_round,
                  onTap: () => onSeleccionarHora(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Row(
                    children: [
                      const Icon(Icons.restaurant_rounded, size: 18, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Text(
                        'Pausa de Almuerzo / Hora de Comer',
                        style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  subtitle: const Text(
                    'Bloquea automáticamente este intervalo para que no se agenden pacientes durante tu comida.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  value: tienePausaAlmuerzo,
                  activeTrackColor: const Color(0xFF0284C7),
                  onChanged: onTienePausaAlmuerzoChanged,
                ),
                if (tienePausaAlmuerzo) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DoctorSetupTimePickerBox(
                          label: 'Inicio Almuerzo',
                          timeStr: formatearTimeOfDay(horaInicioAlmuerzo),
                          icon: Icons.lunch_dining_rounded,
                          onTap: () => onSeleccionarHoraAlmuerzo(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DoctorSetupTimePickerBox(
                          label: 'Fin Almuerzo',
                          timeStr: formatearTimeOfDay(horaFinAlmuerzo),
                          icon: Icons.restaurant_menu_rounded,
                          onTap: () => onSeleccionarHoraAlmuerzo(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Modalidad de Atención:',
            style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DoctorSetupChoiceChip(
                  label: 'Cita Previa',
                  subtitle: 'Por turnos fijos',
                  icon: Icons.alarm_rounded,
                  selected: modalidadAtencion == 'cita_previa',
                  onTap: () => onModalidadChanged('cita_previa'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DoctorSetupChoiceChip(
                  label: 'Orden de Llegada',
                  subtitle: 'Turno corrido',
                  icon: Icons.groups_rounded,
                  selected: modalidadAtencion == 'orden_llegada',
                  onTap: () => onModalidadChanged('orden_llegada'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Duración Estimada por Consulta:',
            style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [15, 20, 30, 45, 60].map((dur) {
              final isSel = duracionMinutos == dur;
              return ChoiceChip(
                label: Text('$dur min'),
                selected: isSel,
                selectedColor: const Color(0xFF0284C7),
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : const Color(0xFF334155),
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (_) => onDuracionChanged(dur),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

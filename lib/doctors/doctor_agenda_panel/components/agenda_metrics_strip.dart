import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/i18n_service.dart';

/// Franja horizontal de métricas rápidas (KPIs) del día para el médico,
/// con selector rápido de sede (cuando hay más de una) e indicador de disponibilidad.
class AgendaMetricsStrip extends StatelessWidget {
  final List<CitasRow> citasDelDia;
  final List<ExamenesMedicosRow> examenesPendientes;
  final DateTime fechaSeleccionada;
  final bool isDesktop;
  final List<DoctorSedesRow> sedes;
  final String? sedeSeleccionadaId;
  final ValueChanged<String?>? onSedeChanged;

  const AgendaMetricsStrip({
    super.key,
    required this.citasDelDia,
    required this.examenesPendientes,
    required this.fechaSeleccionada,
    required this.isDesktop,
    this.sedes = const [],
    this.sedeSeleccionadaId,
    this.onSedeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final localeStr = isEs ? 'es' : 'en';
    final totalCitas = citasDelDia.length;
    final enEspera = citasDelDia
        .where((c) => c.estado == 'pendiente' || c.estado == 'en_sala')
        .length;
    final atendidos = citasDelDia
        .where((c) => c.estado == 'atendida' || c.estado == 'completada')
        .length;
    final pendientesExamenes = examenesPendientes.length;
    final hasCitaEnConsulta = citasDelDia.any((c) => c.estado == 'en_consulta');

    final items = [
      _buildMetricCard(
        title: isEs ? 'Citas Hoy' : 'Appointments Today',
        value: '$totalCitas',
        subtitle: DateFormat('EEEE, d MMM', localeStr).format(fechaSeleccionada),
        icon: Icons.calendar_today_rounded,
        iconColor: const Color(0xFF0284C7),
        bgColor: const Color(0xFFF0F9FF),
      ),
      _buildMetricCard(
        title: isEs ? 'En Sala de Espera' : 'In Waiting Room',
        value: '$enEspera',
        subtitle: isEs ? 'Pacientes pendientes' : 'Pending patients',
        icon: Icons.access_time_filled_rounded,
        iconColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
      ),
      _buildMetricCard(
        title: isEs ? 'Pacientes Atendidos' : 'Patients Seen',
        value: '$atendidos',
        subtitle: totalCitas > 0
            ? '${((atendidos / totalCitas) * 100).toInt()}% ${isEs ? "de la jornada" : "of the day"}'
            : '0%',
        icon: Icons.check_circle_rounded,
        iconColor: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
      ),
      _buildMetricCard(
        title: isEs ? 'Estudios Pendientes' : 'Pending Lab Studies',
        value: '$pendientesExamenes',
        subtitle: isEs ? 'Por revisar y firmar' : 'To review & sign',
        icon: Icons.science_rounded,
        iconColor: const Color(0xFFE11D48),
        bgColor: const Color(0xFFFFF1F2),
      ),
    ];

    final Widget metricsGrid = isDesktop
        ? Row(
            children: items
                .map((card) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: card,
                      ),
                    ))
                .toList(),
          )
        : GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: items,
          );

    if (sedes.length <= 1) {
      return metricsGrid;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildStatusPill(hasCitaEnConsulta, isEs),
              ChoiceChip(
                label: Text(
                  isEs ? '🌐 Todas las Sedes' : '🌐 All Clinics',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: sedeSeleccionadaId == null ? FontWeight.bold : FontWeight.w500,
                    color: sedeSeleccionadaId == null ? Colors.white : const Color(0xFF334155),
                  ),
                ),
                selected: sedeSeleccionadaId == null,
                selectedColor: const Color(0xFF0284C7),
                backgroundColor: Colors.white,
                onSelected: (_) => onSedeChanged?.call(null),
              ),
              ...sedes.map((s) {
                final selected = sedeSeleccionadaId == s.id;
                return ChoiceChip(
                  label: Text(
                    s.nombreSede ?? (isEs ? 'Sede' : 'Clinic'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                  selected: selected,
                  selectedColor: const Color(0xFF0284C7),
                  backgroundColor: Colors.white,
                  onSelected: (_) => onSedeChanged?.call(s.id),
                );
              }),
            ],
          ),
        ),
        metricsGrid,
      ],
    );
  }

  Widget _buildStatusPill(bool hasCitaEnConsulta, bool isEs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hasCitaEnConsulta ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasCitaEnConsulta ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: hasCitaEnConsulta ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            hasCitaEnConsulta
                ? (isEs ? 'En Consulta' : 'In Consultation')
                : (isEs ? 'Disponible' : 'Available'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: hasCitaEnConsulta ? const Color(0xFF991B1B) : const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.mooli(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ],
      ),
    );
  }
}

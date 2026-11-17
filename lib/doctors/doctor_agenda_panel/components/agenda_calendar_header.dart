import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/doctor_vacation_service.dart';
import '../../../services/i18n_service.dart';

/// Componente de encabezado de la agenda: selector de semana, mes y tira de días hábiles.
/// Soporta visualización de días deshabilitados por vacaciones o indisponibilidad en gris,
/// no clickeables, optimizado de forma responsiva para evitar desbordamientos en móvil.
class AgendaCalendarHeader extends StatelessWidget {
  final String tituloMes;
  final String rangoSemanaStr;
  final DateTime inicioSemana;
  final DateTime fechaSeleccionada;
  final List<CitasRow> citasDeLaSemana;
  final Set<String> diasBloqueados;
  final String idDoctor;
  final VoidCallback onIrAHoy;
  final Function(int offset) onCambiarSemana;
  final Function(DateTime dia) onSeleccionarDia;
  final VoidCallback? onDiasBloqueadosActualizados;

  const AgendaCalendarHeader({
    super.key,
    required this.tituloMes,
    required this.rangoSemanaStr,
    required this.inicioSemana,
    required this.fechaSeleccionada,
    required this.citasDeLaSemana,
    this.diasBloqueados = const {},
    this.idDoctor = '',
    required this.onIrAHoy,
    required this.onCambiarSemana,
    required this.onSeleccionarDia,
    this.onDiasBloqueadosActualizados,
  });

  int _conteoCitasDia(DateTime dia) {
    return citasDeLaSemana.where((c) {
      final f = c.fechaHora;
      if (f == null) return false;
      return DateUtils.isSameDay(f, dia);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEs ? 'Agenda Médica' : 'Medical Schedule',
                      style: GoogleFonts.mooli(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '$rangoSemanaStr • ${isEs ? "Turno Activo" : "Active Shift"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      minimumSize: const Size(44, 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: onIrAHoy,
                    child: Text(
                      isEs ? 'Hoy' : 'Today',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onCambiarSemana(-1),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onCambiarSemana(1),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tituloMes,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 18),
          _buildWeekDayStrip(isEs),
        ],
      ),
    );
  }

  Widget _buildWeekDayStrip(bool isEs) {
    const diasEs = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const diasEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: List.generate(7, (i) {
        final dia = inicioSemana.add(Duration(days: i));
        final esHoy = DateUtils.isSameDay(dia, DateTime.now());
        final esSeleccionado = DateUtils.isSameDay(dia, fechaSeleccionada);
        final esBloqueado =
            DoctorVacationService.estaBloqueado(dia, diasBloqueados);
        final count = _conteoCitasDia(dia);
        final idxDia = (dia.weekday - 1).clamp(0, 6);
        final nombreDia = isEs ? diasEs[idxDia] : diasEn[idxDia];

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: InkWell(
              onTap: esBloqueado ? null : () => onSeleccionarDia(dia),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: esBloqueado
                      ? Colors.grey.shade200
                      : (esSeleccionado
                          ? const Color(0xFF0284C7)
                          : (esHoy
                              ? const Color(0xFFF0F9FF)
                              : Colors.transparent)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: esBloqueado
                        ? Colors.grey.shade300
                        : (esSeleccionado
                            ? const Color(0xFF0284C7)
                            : (esHoy
                                ? const Color(0xFFBAE6FD)
                                : Colors.transparent)),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      nombreDia.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: esBloqueado
                            ? Colors.grey.shade500
                            : (esSeleccionado
                                ? Colors.white.withValues(alpha: 0.9)
                                : (esHoy
                                    ? const Color(0xFF0284C7)
                                    : Colors.grey.shade500)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dia.day}',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: esBloqueado
                            ? Colors.grey.shade400
                            : (esSeleccionado
                                ? Colors.white
                                : (esHoy
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF1E293B))),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (esBloqueado)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isEs ? 'Libre' : 'Off',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    else if (count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: esSeleccionado
                              ? Colors.white.withValues(alpha: 0.3)
                              : const Color(0xFF10B981)
                                  .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: esSeleccionado
                                ? Colors.white
                                : const Color(0xFF059669),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

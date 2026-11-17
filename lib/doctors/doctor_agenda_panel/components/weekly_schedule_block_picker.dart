import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../backend/supabase/supabase.dart';

/// Selector semanal interactivo tipo Google Calendar para agendar citas.
/// Permite al doctor o secretaria visualizar las citas registradas de la semana
/// y seleccionar directamente el bloque o franja horaria deseada.
class WeeklyScheduleBlockPicker extends StatefulWidget {
  final String idDoctor;
  final DoctorSedesRow? sedeSeleccionada;
  final DateTime fechaSeleccionada;
  final String? horaSeleccionadaStr;
  final ValueChanged<DateTime> onFechaHoraChanged;
  final ValueChanged<String> onHoraChanged;
  final int? duracionMinutos;

  const WeeklyScheduleBlockPicker({
    super.key,
    required this.idDoctor,
    required this.sedeSeleccionada,
    required this.fechaSeleccionada,
    required this.horaSeleccionadaStr,
    required this.onFechaHoraChanged,
    required this.onHoraChanged,
    this.duracionMinutos,
  });

  @override
  State<WeeklyScheduleBlockPicker> createState() =>
      _WeeklyScheduleBlockPickerState();
}

class _WeeklyScheduleBlockPickerState extends State<WeeklyScheduleBlockPicker> {
  late DateTime _inicioSemana;
  bool _cargando = false;
  List<CitasRow> _citasSemana = [];
  Map<String, String> _nombresPacientes = {};

  @override
  void initState() {
    super.initState();
    _inicioSemana = _calcularLunes(widget.fechaSeleccionada);
    _cargarCitasSemana();
  }

  @override
  void didUpdateWidget(covariant WeeklyScheduleBlockPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sedeSeleccionada?.id != widget.sedeSeleccionada?.id ||
        oldWidget.idDoctor != widget.idDoctor) {
      _cargarCitasSemana();
    }
  }

  DateTime _calcularLunes(DateTime date) {
    final diff = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day - diff);
  }

  Future<void> _cargarCitasSemana() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final docClient = DualDatabaseConfig.instance.doctorClient;
      final finSemana = _inicioSemana.add(const Duration(days: 7));

      var query = docClient
          .from('citas')
          .select('id, fecha_hora, estado, id_paciente, id_sede')
          .gte('fecha_hora', _inicioSemana.toUtc().toIso8601String())
          .lt('fecha_hora', finSemana.toUtc().toIso8601String())
          .neq('estado', 'cancelada');

      if (widget.sedeSeleccionada?.id != null) {
        query = query.eq('id_sede', widget.sedeSeleccionada!.id);
      }

      final res = await query;
      final list = (res as List).map((r) => CitasRow(Map<String, dynamic>.from(r))).toList();

      final idsPacientes = list.map((c) => c.idPaciente).whereType<String>().toSet().toList();
      final mapNombres = <String, String>{};

      if (idsPacientes.isNotEmpty) {
        try {
          final resPac = await docClient
              .from('pacientes')
              .select('id, nombre')
              .inFilter('id', idsPacientes);
          for (final p in (resPac as List)) {
            mapNombres[p['id'].toString()] = p['nombre']?.toString() ?? 'Paciente';
          }
        } catch (_) {}
        final faltantes = idsPacientes.where((id) => !mapNombres.containsKey(id)).toList();
        if (faltantes.isNotEmpty) {
          try {
            final resUsuarios = await docClient
                .from('usuarios')
                .select('id, nombre')
                .inFilter('id', faltantes);
            for (final u in (resUsuarios as List)) {
              mapNombres[u['id'].toString()] = u['nombre']?.toString() ?? 'Paciente';
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _citasSemana = list;
          _nombresPacientes = mapNombres;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando citas de la semana en picker: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _navegarSemana(int deltaSemanas) {
    setState(() {
      _inicioSemana = _inicioSemana.add(Duration(days: 7 * deltaSemanas));
    });
    _cargarCitasSemana();
  }

  bool _sedeAtiendeEnDia(int diaSemana) {
    final s = widget.sedeSeleccionada;
    if (s == null) return true;
    final dias = s.diasAtencion?.toLowerCase() ?? '';
    if (dias.isEmpty) return true;

    switch (diaSemana) {
      case DateTime.monday:
        return dias.contains('lun');
      case DateTime.tuesday:
        return dias.contains('mar');
      case DateTime.wednesday:
        return dias.contains('mié') || dias.contains('mie');
      case DateTime.thursday:
        return dias.contains('jue');
      case DateTime.friday:
        return dias.contains('vie');
      case DateTime.saturday:
        return dias.contains('sáb') || dias.contains('sab');
      case DateTime.sunday:
        return dias.contains('dom');
      default:
        return false;
    }
  }

  List<String> _generarSlotsHorarios() {
    return const [
      '07:30 AM', '08:00 AM', '08:30 AM', '09:00 AM', '09:30 AM',
      '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM', '12:00 PM',
      '01:30 PM', '02:00 PM', '02:30 PM', '03:00 PM', '03:30 PM',
      '04:00 PM', '04:30 PM', '05:00 PM', '05:30 PM', '06:00 PM',
    ];
  }

  String _formatSlot(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$min $ampm';
  }

  CitasRow? _buscarCitaEnSlot(DateTime dia, String slotStr) {
    for (final c in _citasSemana) {
      if (c.fechaHora == null) continue;
      final local = c.fechaHora!.toLocal();
      if (local.year == dia.year && local.month == dia.month && local.day == dia.day) {
        final slotCita = _formatSlot(local);
        if (slotCita == slotStr) return c;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final finSemana = _inicioSemana.add(const Duration(days: 5));
    final rangoTexto =
        '${_inicioSemana.day} ${_inicioSemana.month != finSemana.month ? DateFormat('MMM', 'es').format(_inicioSemana) : ''} - ${finSemana.day} ${DateFormat('MMM', 'es').format(finSemana)} ${finSemana.year}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera estilo Google Calendar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_view_week_rounded, size: 18, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rangoTexto,
                    style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _inicioSemana = _calcularLunes(DateTime.now()));
                    _cargarCitasSemana();
                  },
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                  child: const Text('Hoy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Semana Anterior',
                  onPressed: () => _navegarSemana(-1),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Semana Siguiente',
                  onPressed: () => _navegarSemana(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Cuerpo de la agenda semanal
          if (_cargando)
            const SizedBox(
              height: 220,
              child: Center(
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(6, (index) {
                  final dia = _inicioSemana.add(Duration(days: index));
                  final atiende = _sedeAtiendeEnDia(dia.weekday);
                  final esHoy = DateUtils.isSameDay(dia, DateTime.now());
                  final nombreDia = DateFormat('EEE', 'es').format(dia).toUpperCase();

                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: atiende ? const Color(0xFFFAFAFA) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: esHoy ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                        width: esHoy ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Encabezado de columna
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: esHoy ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                nombreDia,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: esHoy ? const Color(0xFF0284C7) : Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                '${dia.day}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: esHoy ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Bloques horarios
                        if (!atiende)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 6),
                            child: Column(
                              children: [
                                Icon(Icons.do_not_disturb_on_total_silence_rounded, size: 18, color: Colors.grey.shade400),
                                const SizedBox(height: 4),
                                Text(
                                  'Sin consulta\nen esta sede',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: Column(
                              children: _generarSlotsHorarios().map((slot) {
                                final cita = _buscarCitaEnSlot(dia, slot);
                                final esSeleccionado = DateUtils.isSameDay(widget.fechaSeleccionada, dia) &&
                                    widget.horaSeleccionadaStr == slot;

                                if (cita != null) {
                                  // Bloque ocupado
                                  final pacienteNombre = _nombresPacientes[cita.idPaciente] ?? 'Paciente';
                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFECDD3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(slot, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                                        Text(
                                          pacienteNombre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 9, color: Color(0xFF7F1D1D)),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                // Bloque disponible
                                return InkWell(
                                  onTap: () {
                                    widget.onFechaHoraChanged(dia);
                                    widget.onHoraChanged(slot);
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: esSeleccionado
                                          ? const Color(0xFF0284C7)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: esSeleccionado
                                            ? const Color(0xFF0284C7)
                                            : const Color(0xFFBBF7D0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          slot,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: esSeleccionado ? FontWeight.bold : FontWeight.w600,
                                            color: esSeleccionado ? Colors.white : const Color(0xFF15803D),
                                          ),
                                        ),
                                        if (esSeleccionado)
                                          const Icon(Icons.check_circle_rounded, size: 12, color: Colors.white)
                                        else
                                          const Icon(Icons.add_circle_outline_rounded, size: 11, color: Color(0xFF16A34A)),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),

          // Banner informativo de bloque seleccionado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Turno elegido: ${DateFormat('EEEE d MMMM', 'es').format(widget.fechaSeleccionada)} • ${widget.horaSeleccionadaStr ?? "Sin hora"}${widget.duracionMinutos != null ? " • ${widget.duracionMinutos} min" : ""}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../backend/supabase/supabase.dart';
import '../flutter_flow/flutter_flow_theme.dart';

class DoctorInteractiveCalendarWidget extends StatefulWidget {
  final String idDoctor;

  const DoctorInteractiveCalendarWidget({super.key, required this.idDoctor});

  static String routeName = 'DoctorInteractiveCalendar';
  static String routePath = '/doctorInteractiveCalendar';

  @override
  State<DoctorInteractiveCalendarWidget> createState() =>
      _DoctorInteractiveCalendarWidgetState();
}

class _DoctorInteractiveCalendarWidgetState
    extends State<DoctorInteractiveCalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;

  List<CitasRow> _citasDelDia = [];
  Map<String, UsuariosRow> _pacientesMap = {};
  DoctoresRow? _doctorInfo;
  List<DoctorSedesRow> _sedes = [];
  List<HorariosDisponibilidadRow> _horarios = [];
  String? _sedeFiltroId;

  // Mapa de excepciones/ajustes por fecha específica (Memoria o tabla)
  final Map<String, int> _limitePorFecha = {};
  final Map<String, TimeOfDay> _horaFinPorFecha = {};
  final Map<String, int> _duracionPorFecha = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionDoctor();
    _cargarCitasDia(_selectedDay);
  }

  Future<void> _cargarConfiguracionDoctor() async {
    try {
      final docs = await DoctoresTable().querySingleRow(
        queryFn: (q) => q.eq('id', widget.idDoctor),
      );
      if (docs.isNotEmpty) _doctorInfo = docs.first;

      _sedes = await DoctorSedesTable().queryRows(
        queryFn: (q) => q.eq('id', widget.idDoctor),
      );
      if (_sedeFiltroId == null && _sedes.isNotEmpty) {
        _sedeFiltroId = _sedes.first.id;
      }

      _horarios = await HorariosDisponibilidadTable().queryRows(
        queryFn: (q) => q.eq('id', widget.idDoctor),
      );
    } catch (e) {
      debugPrint('Error cargando config doctor: $e');
    }
  }

  String _fechaKey(DateTime fecha) =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  int _obtenerLimiteParaDia(DateTime dia) {
    final key = _fechaKey(dia);
    if (_limitePorFecha.containsKey(key)) {
      return _limitePorFecha[key]!;
    }
    return _doctorInfo?.limitePacientesDia ?? 5; // Base por defecto: 5
  }

  int _obtenerDuracionParaDia(DateTime dia) {
    final key = _fechaKey(dia);
    if (_duracionPorFecha.containsKey(key)) {
      return _duracionPorFecha[key]!;
    }
    return _doctorInfo?.duracionCitaMinutos ?? 30;
  }

  TimeOfDay _obtenerHoraFinParaDia(DateTime dia) {
    final key = _fechaKey(dia);
    if (_horaFinPorFecha.containsKey(key)) {
      return _horaFinPorFecha[key]!;
    }

    final diaSemana = dia.weekday;
    final h = _horarios.firstWhere(
      (item) => item.diaSemana == diaSemana && (item.activo ?? true),
      orElse: () => HorariosDisponibilidadRow({'hora_fin': '13:00'}),
    );

    final parts = (h.horaFin?.toString() ?? '13:00').split(':');
    final hora = int.tryParse(parts[0]) ?? 13;
    final min = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: hora, minute: min);
  }

  Future<void> _cargarCitasDia(DateTime dia) async {
    setState(() => _isLoading = true);
    try {
      final inicioDia = DateTime(dia.year, dia.month, dia.day, 0, 0, 0);
      final finDia = DateTime(dia.year, dia.month, dia.day, 23, 59, 59);

      _citasDelDia = await CitasTable().queryRows(
        queryFn: (q) {
          var query = q
              .eq('id_doctor', widget.idDoctor)
              .gte('fecha_hora', inicioDia.toIso8601String())
              .lte('fecha_hora', finDia.toIso8601String())
              .neq('estado', 'cancelada');
          if (_sedeFiltroId != null) {
            query = query.eq('id_sede', _sedeFiltroId!);
          }
          return query.order('fecha_hora_estimada_actual', ascending: true);
        },
      );

      final idsPacientes = _citasDelDia
          .map((c) => c.idPaciente)
          .whereType<String>()
          .toSet()
          .toList();
      if (idsPacientes.isNotEmpty) {
        final users = await UsuariosTable().queryRows(
          queryFn: (q) => q.inFilter('id', idsPacientes),
        );
        _pacientesMap = {for (var u in users) u.id: u};
      }
    } catch (e) {
      debugPrint('Error cargando citas del día: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cambiarDuracionCita(CitasRow cita, int nuevaDuracion) async {
    final duracionAnterior = cita.duracionMinutos ?? _obtenerDuracionParaDia(_selectedDay);
    final diferenciaMinutos = nuevaDuracion - duracionAnterior;

    await CitasTable().update(
      data: {'duracion_minutos': nuevaDuracion},
      matchingRows: (q) => q.eq('id', cita.id),
    );

    if (diferenciaMinutos != 0) {
      final fechaCitaActual =
          cita.fechaHoraEstimadaActual ?? cita.fechaHora ?? DateTime.now();

      final citasPosteriores = _citasDelDia.where((c) {
        final f = c.fechaHoraEstimadaActual ?? c.fechaHora ?? DateTime.now();
        return c.id != cita.id && f.isAfter(fechaCitaActual);
      }).toList();

      for (final postCita in citasPosteriores) {
        final original = postCita.fechaHoraEstimadaActual ??
            postCita.fechaHora ??
            DateTime.now();
        final nuevoEstimado =
            original.add(Duration(minutes: diferenciaMinutos));
        final nuevoRetraso = (postCita.minutosRetrasoAcumulados ?? 0) +
            diferenciaMinutos;

        await CitasTable().update(
          data: {
            'fecha_hora_estimada_actual': nuevoEstimado.toIso8601String(),
            'minutos_retraso_acumulados': nuevoRetraso > 0 ? nuevoRetraso : 0,
          },
          matchingRows: (q) => q.eq('id', postCita.id),
        );

        if (postCita.idPaciente != null) {
          final horaStr =
              '${nuevoEstimado.hour.toString().padLeft(2, '0')}:${nuevoEstimado.minute.toString().padLeft(2, '0')}';
          await NotificacionesCitasTable().insert({
            'id_usuario': postCita.idPaciente!,
            'id_cita': postCita.id,
            'tipo': 'retraso_emergencia',
            'titulo': '⏰ Ajuste en Horario de Cita',
            'mensaje':
                'Su consulta ha sido reajustada. Nueva hora estimada de atención: $horaStr.',
            'minutos_retraso': nuevoRetraso,
            'leido': false,
          });
        }
      }
    }

    _cargarCitasDia(_selectedDay);
  }

  Future<void> _reordenarCitas(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final CitasRow citaMovida = _citasDelDia.removeAt(oldIndex);
    _citasDelDia.insert(newIndex, citaMovida);

    setState(() {});

    if (_citasDelDia.isEmpty) return;
    DateTime horaBase = _citasDelDia.first.fechaHora ??
        DateTime(
            _selectedDay.year, _selectedDay.month, _selectedDay.day, 8, 0);

    for (int i = 0; i < _citasDelDia.length; i++) {
      final c = _citasDelDia[i];
      final dur = c.duracionMinutos ?? _obtenerDuracionParaDia(_selectedDay);

      await CitasTable().update(
        data: {
          'fecha_hora_estimada_actual': horaBase.toIso8601String(),
          'turno_numero': i + 1,
        },
        matchingRows: (q) => q.eq('id', c.id),
      );

      if (c.idPaciente != null) {
        final horaStr =
            '${horaBase.hour.toString().padLeft(2, '0')}:${horaBase.minute.toString().padLeft(2, '0')}';
        await NotificacionesCitasTable().insert({
          'id_usuario': c.idPaciente!,
          'id_cita': c.id,
          'tipo': 'reorden_turno',
          'titulo': '🔄 Reordenamiento de Turno',
          'mensaje':
              'Se ha actualizado el orden de atención para hoy. Su turno es el #$i+1, hora estimada: $horaStr.',
          'leido': false,
        });
      }

      horaBase = horaBase.add(Duration(minutes: dur));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Turnos reordenados y pacientes notificados.'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _dialogoAjusteHorariosYCapacidad() {
    int limiteGeneral = _doctorInfo?.limitePacientesDia ?? 5;
    int duracionGeneral = _doctorInfo?.duracionCitaMinutos ?? 30;

    int limiteHoy = _obtenerLimiteParaDia(_selectedDay);
    int duracionHoy = _obtenerDuracionParaDia(_selectedDay);
    TimeOfDay horaFinHoy = _obtenerHoraFinParaDia(_selectedDay);

    final fechaStr =
        '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Capacidad y Horarios',
              style: GoogleFonts.mooli(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Ajustes específicos para el día seleccionado
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📅 Ajuste para este día ($fechaStr):',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
                              fontSize: 13)),
                      const SizedBox(height: 10),
                      const Text('Límite de pacientes para hoy:',
                          style: TextStyle(fontSize: 12)),
                      Wrap(
                        spacing: 6,
                        children: [3, 5, 8, 10, 15, 20].map((l) {
                          return ChoiceChip(
                            label: Text('$l'),
                            selected: limiteHoy == l,
                            selectedColor: Colors.teal.shade200,
                            onSelected: (val) {
                              if (val) setModalState(() => limiteHoy = l);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      const Text('Hora límite de salida hoy (Fin de consultas):',
                          style: TextStyle(fontSize: 12)),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(
                            'Hasta las ${horaFinHoy.format(context)} (No más citas)'),
                        onPressed: () async {
                          final h = await showTimePicker(
                            context: context,
                            initialTime: horaFinHoy,
                          );
                          if (h != null) {
                            setModalState(() => horaFinHoy = h);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Ajustes generales permanentes
                const Text('⚙️ Configuración General Permanente:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                const Text('Límite de pacientes base por día:',
                    style: TextStyle(fontSize: 12)),
                Wrap(
                  spacing: 6,
                  children: [5, 8, 10, 15, 20].map((l) {
                    return ChoiceChip(
                      label: Text('$l'),
                      selected: limiteGeneral == l,
                      onSelected: (val) {
                        if (val) setModalState(() => limiteGeneral = l);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                const Text('Duración estándar por consulta:',
                    style: TextStyle(fontSize: 12)),
                Wrap(
                  spacing: 6,
                  children: [15, 20, 30, 45, 60].map((d) {
                    return ChoiceChip(
                      label: Text('$d min'),
                      selected: duracionGeneral == d,
                      onSelected: (val) {
                        if (val) setModalState(() => duracionGeneral = d);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: FlutterFlowTheme.of(context).primary),
              onPressed: () async {
                final key = _fechaKey(_selectedDay);
                _limitePorFecha[key] = limiteHoy;
                _horaFinPorFecha[key] = horaFinHoy;
                _duracionPorFecha[key] = duracionHoy;

                try {
                  await DoctoresTable().update(
                    data: {
                      'duracion_cita_minutos': duracionGeneral,
                      'limite_pacientes_dia': limiteGeneral,
                    },
                    matchingRows: (q) => q.eq('id', widget.idDoctor),
                  );
                } catch (e) {
                  try {
                    await DoctoresTable().update(
                      data: {
                        'duracion_cita_minutos': duracionGeneral,
                      },
                      matchingRows: (q) => q.eq('id', widget.idDoctor),
                    );
                  } catch (_) {}
                }

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _cargarConfiguracionDoctor();
                _cargarCitasDia(_selectedDay);
              },
              child: const Text('Guardar Ajustes',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final limiteHoy = _obtenerLimiteParaDia(_selectedDay);
    final totalCitas = _citasDelDia.length;
    final cupoLleno = totalCitas >= limiteHoy;
    final horaFinHoy = _obtenerHoraFinParaDia(_selectedDay);

    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        title: Text(
          'Calendario y Bloques de Consulta',
          style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        foregroundColor: FlutterFlowTheme.of(context).primaryText,
        elevation: 1,
        actions: [
          IconButton(
            tooltip: 'Configurar cupos, horas de salida y duración',
            icon: const Icon(Icons.tune, color: Colors.teal),
            onPressed: _dialogoAjusteHorariosYCapacidad,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _cargarCitasDia(_selectedDay),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de Sede
          if (_sedes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: FlutterFlowTheme.of(context).secondaryBackground,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _sedeFiltroId,
                  hint: const Text('Consultorio / Sede'),
                  items: _sedes.map((s) {
                    return DropdownMenuItem(
                      value: s.id,
                      child: Text('📍 ${s.nombreSede} (${s.ciudad ?? ""})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _sedeFiltroId = val);
                    _cargarCitasDia(_selectedDay);
                  },
                ),
              ),
            ),

          // Calendario Superior
          Container(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            child: TableCalendar(
              firstDay: DateTime(2025, 1, 1),
              lastDay: DateTime(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _cargarCitasDia(selectedDay);
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.teal.shade200,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
              ),
            ),
          ),

          // Barra de Estado de Cupos y Hora Límite del Día
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: cupoLleno ? Colors.red.shade50 : Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      cupoLleno
                          ? Icons.warning_amber_rounded
                          : Icons.event_available,
                      color: cupoLleno ? Colors.red : Colors.teal,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pacientes: $totalCitas / $limiteHoy máx. hoy',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cupoLleno
                            ? Colors.red.shade900
                            : Colors.teal.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Salida: ${horaFinHoy.format(context)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade900,
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(top: 8, left: 16, right: 16),
            child: Row(
              children: [
                Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'Arrastra las citas para cambiar orden o toca el reloj para alargar/acortar:',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Lista Reordenable de Citas del Día
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _citasDelDia.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today,
                                size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text('No hay citas programadas para este día.'),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _citasDelDia.length,
                        onReorder: _reordenarCitas,
                        itemBuilder: (context, index) {
                          final cita = _citasDelDia[index];
                          final paciente = _pacientesMap[cita.idPaciente];
                          final duracion = cita.duracionMinutos ??
                              _obtenerDuracionParaDia(_selectedDay);
                          final hora = cita.fechaHoraEstimadaActual ??
                              cita.fechaHora ??
                              _selectedDay;
                          final horaStr =
                              '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
                          final esEmergencia = cita.esEmergencia ?? false;

                          return Card(
                            key: ValueKey(cita.id),
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: esEmergencia
                                  ? const BorderSide(color: Colors.red, width: 2)
                                  : BorderSide.none,
                            ),
                            child: ListTile(
                              leading: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    horaStr,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: esEmergencia
                                          ? Colors.red
                                          : Colors.teal.shade800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text('Turno #${index + 1}',
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                              title: Text(
                                paciente?.nombre ?? 'Paciente',
                                style: GoogleFonts.mooli(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Text(
                                '${cita.motivo ?? "Consulta"} • Bloque: $duracion min',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PopupMenuButton<int>(
                                    tooltip: 'Cambiar duración del bloque',
                                    icon: const Icon(Icons.timer_outlined,
                                        color: Colors.teal),
                                    onSelected: (nuevaDur) =>
                                        _cambiarDuracionCita(cita, nuevaDur),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                          value: 15, child: Text('15 minutos')),
                                      const PopupMenuItem(
                                          value: 30, child: Text('30 minutos')),
                                      const PopupMenuItem(
                                          value: 45, child: Text('45 minutos')),
                                      const PopupMenuItem(
                                          value: 60, child: Text('60 minutos')),
                                      const PopupMenuItem(
                                          value: 90, child: Text('90 minutos')),
                                    ],
                                  ),
                                  const Icon(Icons.drag_handle,
                                      color: Colors.grey),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

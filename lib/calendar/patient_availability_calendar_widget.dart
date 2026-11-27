import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../backend/supabase/supabase.dart';
import '../flutter_flow/flutter_flow_theme.dart';
import '../appointments/request_appointment/request_appointment_widget.dart';
import '../services/location_maps_service.dart';

class PatientAvailabilityCalendarWidget extends StatefulWidget {
  final String idDoctor;
  final String? nombreDoctor;
  final String? especialidadDoctor;

  const PatientAvailabilityCalendarWidget({
    super.key,
    required this.idDoctor,
    this.nombreDoctor,
    this.especialidadDoctor,
  });

  static String routeName = 'PatientAvailabilityCalendar';
  static String routePath = '/patientAvailabilityCalendar';

  @override
  State<PatientAvailabilityCalendarWidget> createState() =>
      _PatientAvailabilityCalendarWidgetState();
}

class _PatientAvailabilityCalendarWidgetState
    extends State<PatientAvailabilityCalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;

  List<CitasRow> _citasDelDia = [];
  DoctoresRow? _doctorInfo;
  List<DoctorSedesRow> _sedes = [];
  String? _sedeSeleccionadaId;
  List<HorariosDisponibilidadRow> _horarios = [];
  bool _isLoading = true;
  RealtimeChannel? _citasChannel;

  DoctorSedesRow? get _sedeActual {
    if (_sedeSeleccionadaId == null) return null;
    final matches = _sedes.where((s) => s.id == _sedeSeleccionadaId);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  void initState() {
    super.initState();
    _cargarDatosDoctor();
    _cargarDisponibilidadDia(_selectedDay);
    _suscribirRealtimeCitas();
  }

  void _suscribirRealtimeCitas() {
    if (widget.idDoctor.isEmpty) return;
    _citasChannel = SupaFlow.client
        .channel('pat-disp-${widget.idDoctor}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'citas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_doctor',
            value: widget.idDoctor,
          ),
          callback: (_) {
            if (mounted) _cargarDisponibilidadDia(_selectedDay);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_citasChannel != null) {
      SupaFlow.client.removeChannel(_citasChannel!);
      _citasChannel = null;
    }
    super.dispose();
  }

  Future<void> _cargarDatosDoctor() async {
    try {
      final docs = await DoctoresTable().querySingleRow(
        queryFn: (q) => q.eq('id', widget.idDoctor),
      );
      if (docs.isNotEmpty) _doctorInfo = docs.first;

      _sedes = await DoctorSedesTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', widget.idDoctor),
      );
      if (_sedes.isNotEmpty) {
        _sedeSeleccionadaId = _sedes.first.id;
      }

      _horarios = await HorariosDisponibilidadTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', widget.idDoctor),
      );
    } catch (e) {
      debugPrint('Error cargando doctor: $e');
    }
  }

  Future<void> _cargarDisponibilidadDia(DateTime dia) async {
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
          if (_sedeSeleccionadaId != null) {
            query = query.eq('id_sede', _sedeSeleccionadaId!);
          }
          return query.order('fecha_hora_estimada_actual', ascending: true);
        },
      );
    } catch (e) {
      debugPrint('Error cargando citas del día: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Genera los bloques de horario del día respetando la hora límite de trabajo del doctor
  List<Map<String, dynamic>> _generarBloquesHorarios() {
    final duracionEstandar = _doctorInfo?.duracionCitaMinutos ?? 30;
    final diaSemana = _selectedDay.weekday; // 1 = Lunes, 7 = Domingo

    final horariosDelDia = _horarios.where(
      (h) =>
          h.diaSemana == diaSemana &&
          (h.idSede == _sedeSeleccionadaId || _sedeSeleccionadaId == null) &&
          (h.activo ?? true),
    ).toList();

    if (horariosDelDia.isEmpty) {
      horariosDelDia.add(HorariosDisponibilidadRow({
        'hora_inicio': '08:00',
        'hora_fin': '13:00',
        'modalidad_atencion': 'hora_fija',
      }));
    }

    horariosDelDia.sort((a, b) {
      final aStr = a.horaInicio?.toString() ?? '08:00';
      final bStr = b.horaInicio?.toString() ?? '08:00';
      return aStr.compareTo(bStr);
    });

    final bloques = <Map<String, dynamic>>[];

    for (var i = 0; i < horariosDelDia.length; i++) {
      final horarioConfig = horariosDelDia[i];
      final inicioParts =
          (horarioConfig.horaInicio?.toString() ?? '08:00').split(':');
      final finParts = (horarioConfig.horaFin?.toString() ?? '13:00').split(':');

      final horaInicio = int.tryParse(inicioParts[0]) ?? 8;
      final minInicio =
          int.tryParse(inicioParts.length > 1 ? inicioParts[1] : '0') ?? 0;
      final horaFin = int.tryParse(finParts[0]) ?? 13;
      final minFin =
          int.tryParse(finParts.length > 1 ? finParts[1] : '0') ?? 0;

      var cursor = DateTime(_selectedDay.year, _selectedDay.month,
          _selectedDay.day, horaInicio, minInicio);
      final limiteHorarioTrabajo = DateTime(_selectedDay.year, _selectedDay.month,
          _selectedDay.day, horaFin, minFin);

      // Si hay un intervalo entre turnos (ej. Pausa de Almuerzo / Comida), marcar bloque visual
      if (i > 0) {
        final horarioAnterior = horariosDelDia[i - 1];
        final finAntParts = (horarioAnterior.horaFin?.toString() ?? '12:00').split(':');
        final hFinAnt = int.tryParse(finAntParts[0]) ?? 12;
        final mFinAnt = int.tryParse(finAntParts.length > 1 ? finAntParts[1] : '0') ?? 0;
        final finBloqueAnterior = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, hFinAnt, mFinAnt);

        if (cursor.isAfter(finBloqueAnterior)) {
          bloques.add({
            'horaInicio': finBloqueAnterior,
            'horaFin': cursor,
            'disponible': false,
            'esEmergencia': false,
            'esAlmuerzo': true,
            'duracion': cursor.difference(finBloqueAnterior).inMinutes,
          });
        }
      }

      // Generar bloques de consulta para este turno
      while (cursor.isBefore(limiteHorarioTrabajo)) {
        final slotInicio = cursor;
        final slotFin = cursor.add(Duration(minutes: duracionEstandar));

        if (slotFin.isAfter(limiteHorarioTrabajo)) {
          break;
        }

        final citaOcupada = _citasDelDia.where((c) {
          final f = c.fechaHoraEstimadaActual ?? c.fechaHora;
          if (f == null) return false;
          return f.year == slotInicio.year &&
              f.month == slotInicio.month &&
              f.day == slotInicio.day &&
              f.hour == slotInicio.hour &&
              (f.minute - slotInicio.minute).abs() < duracionEstandar;
        }).toList();

        if (citaOcupada.isNotEmpty) {
          final c = citaOcupada.first;
          final esEmergencia = c.esEmergencia ?? false;
          final durCita = c.duracionMinutos ?? duracionEstandar;

          bloques.add({
            'horaInicio': slotInicio,
            'horaFin': slotInicio.add(Duration(minutes: durCita)),
            'disponible': false,
            'esEmergencia': esEmergencia,
            'esAlmuerzo': false,
            'duracion': durCita,
          });

          cursor = cursor.add(Duration(minutes: durCita));
        } else {
          bloques.add({
            'horaInicio': slotInicio,
            'horaFin': slotFin,
            'disponible': true,
            'esEmergencia': false,
            'esAlmuerzo': false,
            'duracion': duracionEstandar,
          });

          cursor = slotFin;
        }
      }
    }

    return bloques;
  }

  @override
  Widget build(BuildContext context) {
    final diaSemana = _selectedDay.weekday;
    final horarioConfig = _horarios.firstWhere(
      (h) =>
          h.diaSemana == diaSemana &&
          (h.idSede == _sedeSeleccionadaId || _sedeSeleccionadaId == null) &&
          (h.activo ?? true),
      orElse: () => HorariosDisponibilidadRow({}),
    );
    final limiteDia = horarioConfig.cupoMaximo ?? _doctorInfo?.limitePacientesDia ?? 15;
    final totalCitasOcupadas = _citasDelDia.length;
    final cupoLleno = totalCitasOcupadas >= limiteDia;
    final bloques = _generarBloquesHorarios();

    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        title: Text(
          'Horarios Disponibles',
          style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        foregroundColor: FlutterFlowTheme.of(context).primaryText,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Selector de Sede y Detalles
          if (_sedes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: FlutterFlowTheme.of(context).secondaryBackground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _sedeSeleccionadaId,
                      hint: const Text('Seleccionar Consultorio / Sede'),
                      items: _sedes.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '📍 ${s.nombreSede} (${s.ciudad ?? ""})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _sedeSeleccionadaId = val);
                        _cargarDisponibilidadDia(_selectedDay);
                      },
                    ),
                  ),
                  if (_sedeActual != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${_sedeActual!.direccion ?? ""}${_sedeActual!.numeroConsultorio != null && _sedeActual!.numeroConsultorio!.isNotEmpty ? " (${_sedeActual!.numeroConsultorio})" : ""}',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if ((_sedeActual!.direccion != null && _sedeActual!.direccion!.isNotEmpty) ||
                            (_sedeActual!.latitud != null && _sedeActual!.longitud != null))
                          InkWell(
                            onTap: () => LocationMapsService.abrirGoogleMaps(
                              direccion: _sedeActual!.direccion,
                              ciudad: _sedeActual!.ciudad,
                              estado: _sedeActual!.estado,
                              latitud: _sedeActual!.latitud,
                              longitud: _sedeActual!.longitud,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.map, size: 14, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  'Ver Mapa',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          // Calendario
          Container(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            child: TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 90)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _cargarDisponibilidadDia(selectedDay);
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primary,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
          ),

          // Banner de Cupo Lleno
          if (cupoLleno)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.red.shade100,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Cupo máximo alcanzado para este día. Por favor elige otra fecha.',
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ],
              ),
            ),

          // Contenido: Orden de Llegada vs Hora Fija
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sedeActual?.modalidadAtencion == 'orden_llegada'
                    ? _buildOrdenLlegadaView(cupoLleno)
                    : () {
                        final bloquesVisibles = bloques
                            .where((b) => (b['disponible'] == true) && !(b['esAlmuerzo'] ?? false))
                            .toList();
                        if (bloquesVisibles.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy,
                                    size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                const Text(
                                  'No quedan horas disponibles para esta fecha o ya concluyó el horario de atención.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: bloquesVisibles.length,
                        itemBuilder: (context, index) {
                          final b = bloquesVisibles[index];
                          final DateTime inicio = b['horaInicio'];
                          final DateTime fin = b['horaFin'];
                          final bool esAlmuerzo = b['esAlmuerzo'] ?? false;
                          final bool disponible =
                              b['disponible'] && !cupoLleno && !esAlmuerzo;
                          final bool esEmergencia = b['esEmergencia'] ?? false;
                          final int duracion = b['duracion'];

                          final horaStr =
                              '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')} - ${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}';

                          return Card(
                            elevation: 1.5,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: esAlmuerzo
                                    ? Colors.amber.shade300
                                    : disponible
                                        ? Colors.teal.shade300
                                        : esEmergencia
                                            ? Colors.red.shade300
                                            : Colors.grey.shade300,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: esAlmuerzo
                                    ? Colors.amber.shade100
                                    : disponible
                                        ? Colors.green.shade50
                                        : esEmergencia
                                            ? Colors.red.shade50
                                            : Colors.grey.shade200,
                                child: Icon(
                                  esAlmuerzo
                                      ? Icons.restaurant
                                      : disponible
                                          ? Icons.event_available
                                          : esEmergencia
                                              ? Icons.warning
                                              : Icons.event_busy,
                                  color: esAlmuerzo
                                      ? Colors.amber.shade900
                                      : disponible
                                          ? Colors.green
                                          : esEmergencia
                                              ? Colors.red
                                              : Colors.grey,
                                ),
                              ),
                              title: Text(
                                horaStr,
                                style: GoogleFonts.mooli(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                esAlmuerzo
                                    ? '🍽️ Pausa Médica / Hora de Almuerzo (No disponible)'
                                    : disponible
                                        ? '🟢 Disponible para agendar ($duracion min)'
                                        : esEmergencia
                                            ? '🚨 Ocupado (Atención de Emergencia - $duracion min)'
                                            : '🔴 Ocupado (Consulta Médica - $duracion min)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: esAlmuerzo
                                      ? Colors.amber.shade900
                                      : disponible
                                          ? Colors.green.shade800
                                          : esEmergencia
                                              ? Colors.red.shade800
                                              : Colors.grey.shade700,
                                ),
                              ),
                              trailing: disponible
                                  ? ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            FlutterFlowTheme.of(context).primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                RequestAppointmentWidget(
                                              idDoctor: widget.idDoctor,
                                              nombreDoctor: widget.nombreDoctor,
                                              especialidadDoctor:
                                                  widget.especialidadDoctor,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('Agendar',
                                          style:
                                              TextStyle(color: Colors.white)),
                                    )
                                  : null,
                            ),
                          );
                        },
                      );
                      }(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdenLlegadaView(bool cupoLleno) {
    final diaSemana = _selectedDay.weekday;
    final horarioConfig = _horarios.firstWhere(
      (h) =>
          h.diaSemana == diaSemana &&
          (h.idSede == _sedeSeleccionadaId || _sedeSeleccionadaId == null) &&
          (h.activo ?? true),
      orElse: () => HorariosDisponibilidadRow({}),
    );
    final cupoMaximo = horarioConfig.cupoMaximo ?? _doctorInfo?.limitePacientesDia ?? 15;
    final totalCitasOcupadas = _citasDelDia.length;
    final cuposDisponibles = (cupoMaximo - totalCitasOcupadas).clamp(0, cupoMaximo);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.shade50.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_alt_outlined, color: Colors.amber, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                'Modalidad por Orden de Llegada',
                style: GoogleFonts.mooli(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'En este consultorio la atención es por turno de llegada en sala. Puedes reservar tu cupo para esta fecha y se te asignará un número en la lista de espera.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.3),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuotaBadge('Cupo Total', '$cupoMaximo', Colors.grey.shade800),
                  _buildQuotaBadge('Ocupados', '$totalCitasOcupadas', Colors.orange.shade800),
                  _buildQuotaBadge('Disponibles', '$cuposDisponibles', Colors.teal.shade800),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cuposDisponibles > 0
                        ? FlutterFlowTheme.of(context).primary
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.confirmation_number_outlined, color: Colors.white),
                  label: Text(
                    cuposDisponibles > 0
                        ? 'Solicitar Cupo / Turno (#${totalCitasOcupadas + 1})'
                        : 'Cupos Agotados para esta fecha',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: cuposDisponibles > 0
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RequestAppointmentWidget(
                                idDoctor: widget.idDoctor,
                                nombreDoctor: widget.nombreDoctor,
                                especialidadDoctor: widget.especialidadDoctor,
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotaBadge(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

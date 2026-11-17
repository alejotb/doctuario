import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../flutter_flow/flutter_flow_theme.dart';
import '../../../services/appointment_sync_service.dart';
import '../../../components/skeleton_shimmer.dart';

/// Componente interactivo para mostrar la disponibilidad del doctor:
/// - Selector deslizante de los próximos 7 días.
/// - Modalidad 1: Barra de cupos restantes por día (Orden de llegada) sin turno estimado.
/// - Modalidad 2: Bloques horarios inteligentes con detección de duración y solapamientos.
class DoctorAvailabilitySlotsWidget extends StatefulWidget {
  final String idDoctor;
  final List<DoctorSedesRow> sedes;
  final List<HorariosDisponibilidadRow> horarios;
  final int limitePacientesDia;
  final int duracionCitaMinutos;
  final Function({
    required DateTime fechaHora,
    required String idSede,
    required String modalidadAtencion,
  }) onSeleccionarCita;

  const DoctorAvailabilitySlotsWidget({
    super.key,
    required this.idDoctor,
    required this.sedes,
    required this.horarios,
    this.limitePacientesDia = 15,
    this.duracionCitaMinutos = 30,
    required this.onSeleccionarCita,
  });

  @override
  State<DoctorAvailabilitySlotsWidget> createState() =>
      _DoctorAvailabilitySlotsWidgetState();
}

class _DoctorAvailabilitySlotsWidgetState
    extends State<DoctorAvailabilitySlotsWidget> {
  int _diaSeleccionadoIdx = 0;
  String? _sedeSeleccionadaId;
  TimeSlotInfo? _slotSeleccionado;
  bool _isLoading = true;
  List<Map<String, dynamic>> _citasExistentes = [];

  late final List<DateTime> _proximosDias;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _proximosDias = List.generate(
      7,
      (i) => DateTime(hoy.year, hoy.month, hoy.day).add(Duration(days: i)),
    );

    if (widget.sedes.isNotEmpty) {
      _sedeSeleccionadaId = widget.sedes.first.id;
    }
    _cargarDisponibilidad();
  }

  Future<void> _cargarDisponibilidad() async {
    setState(() => _isLoading = true);
    try {
      final desde = _proximosDias.first;
      final hasta = _proximosDias.last.add(const Duration(days: 1));
      final citas = await AppointmentSyncService.instance
          .obtenerCitasDoctorParaRango(
        idDoctor: widget.idDoctor,
        fechaDesde: desde,
        fechaHasta: hasta,
      );
      if (mounted) {
        setState(() {
          _citasExistentes = citas;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando disponibilidad en widget: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DateTime get _diaActual => _proximosDias[_diaSeleccionadoIdx];

  DoctorSedesRow? get _sedeActual {
    if (_sedeSeleccionadaId == null && widget.sedes.isNotEmpty) {
      return widget.sedes.first;
    }
    final matches = widget.sedes.where((s) => s.id == _sedeSeleccionadaId);
    return matches.isNotEmpty ? matches.first : null;
  }

  HorariosDisponibilidadRow? get _horarioParaDiaActual {
    final diaSemana = _diaActual.weekday;
    final sedeId = _sedeActual?.id;
    final matches = widget.horarios.where((h) {
      final coincideDia = (h.diaSemana ?? 1) == diaSemana;
      final coincideSede = (sedeId == null || h.idSede == null || h.idSede == sedeId);
      return coincideDia && coincideSede;
    });
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final horario = _horarioParaDiaActual;
    final esOrdenLlegada = horario?.modalidadAtencion == 'orden_llegada' ||
        _sedeActual?.modalidadAtencion == 'orden_llegada';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.alternate),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.event_available_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Disponibilidad y Cupos en Vivo', style: GoogleFonts.mooli(fontSize: 15, fontWeight: FontWeight.bold, color: theme.primaryText)),
                    Text('Elige el día para ver cupos u horarios libres', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.sedes.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.sedes.map((sede) {
                  final isSelected = sede.id == _sedeActual?.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(sede.nombreSede ?? 'Consultorio', style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0284C7),
                      backgroundColor: const Color(0xFFF1F5F9),
                      onSelected: (_) => setState(() { _sedeSeleccionadaId = sede.id; _slotSeleccionado = null; }),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _proximosDias.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final dia = _proximosDias[idx];
                final isSelected = idx == _diaSeleccionadoIdx;
                final esHoy = idx == 0;
                final esManana = idx == 1;
                final nombreDia = esHoy ? 'HOY' : (esManana ? 'MAÑANA' : DateFormat('EEE', 'es').format(dia).toUpperCase());

                return InkWell(
                  onTap: () => setState(() { _diaSeleccionadoIdx = idx; _slotSeleccionado = null; }),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 66,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0), width: isSelected ? 1.8 : 1.0),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(nombreDia, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text(dia.day.toString(), style: GoogleFonts.mooli(fontSize: 17, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF0F172A))),
                        Text(DateFormat('MMM', 'es').format(dia), style: TextStyle(fontSize: 10, color: isSelected ? Colors.white.withValues(alpha: 0.9) : Colors.grey.shade500)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (_isLoading)
            const SkeletonSlotsGrid(count: 8)
          else if (horario == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.grey, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('El especialista no tiene consultas programadas para este día.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700))),
                ],
              ),
            )
          else if (esOrdenLlegada)
            _buildModalidadOrdenLlegada(horario)
          else
            _buildModalidadBloquesHorarios(horario),
        ],
      ),
    );
  }

  Widget _buildModalidadOrdenLlegada(HorariosDisponibilidadRow horario) {
    final quota = AppointmentSyncService.instance.calcularCuposDia(
      fecha: _diaActual,
      limitePacientesDia: widget.limitePacientesDia,
      citasExistentes: _citasExistentes,
    );
    final porcentajeOcupado = (quota.citasAgendadas / quota.limiteTotal).clamp(0.0, 1.0);
    final horaInicio = horario.horaInicio?.toString() ?? '08:00';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Modalidad: Orden de Llegada', style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: quota.estaAgotado ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                quota.estaAgotado ? 'Agotado' : '${quota.cuposDisponibles} cupos libres',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: quota.estaAgotado ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Atención por orden de llegada física en sala desde las $horaInicio.', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: porcentajeOcupado,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(
              quota.estaAgotado ? const Color(0xFFEF4444) : (porcentajeOcupado > 0.75 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('${quota.citasAgendadas} de ${quota.limiteTotal} cupos ocupados hoy', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: quota.estaAgotado ? Colors.grey.shade300 : const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: quota.estaAgotado
                ? null
                : () {
                    final partes = horaInicio.split(':');
                    final h = int.tryParse(partes[0]) ?? 8;
                    final m = partes.length > 1 ? (int.tryParse(partes[1]) ?? 0) : 0;
                    final fechaHoraCita = DateTime(_diaActual.year, _diaActual.month, _diaActual.day, h, m);
                    widget.onSeleccionarCita(fechaHora: fechaHoraCita, idSede: _sedeActual?.id ?? '', modalidadAtencion: 'orden_llegada');
                  },
            icon: Icon(quota.estaAgotado ? Icons.block : Icons.bookmark_add_rounded, size: 18),
            label: Text(quota.estaAgotado ? 'Cupos Agotados para este Día' : 'Apartar Cupo para este Día', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildModalidadBloquesHorarios(HorariosDisponibilidadRow horario) {
    final horaInicio = horario.horaInicio?.toString() ?? '08:00';
    final horaFin = horario.horaFin?.toString() ?? '13:00';

    final slots = AppointmentSyncService.instance.calcularBloquesHorarios(
      fecha: _diaActual,
      horaInicioStr: horaInicio,
      horaFinStr: horaFin,
      duracionBaseMinutos: widget.duracionCitaMinutos,
      citasExistentes: _citasExistentes,
    );
    final libres = slots.where((s) => !s.estaOcupado).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Modalidad: Cita con Horario Fijo', style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold)),
            Text('$libres horarios libres', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: libres > 0 ? const Color(0xFF0284C7) : Colors.red)),
          ],
        ),
        const SizedBox(height: 4),
        Text('Duración estimada por consulta: ${widget.duracionCitaMinutos} min', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            final isSelected = _slotSeleccionado?.horaTexto == slot.horaTexto;
            final isOccupied = slot.estaOcupado;

            Color bgColor = Colors.white;
            Color borderColor = const Color(0xFFCBD5E1);
            Color textColor = const Color(0xFF0F172A);

            if (isOccupied) {
              bgColor = const Color(0xFFF1F5F9);
              borderColor = const Color(0xFFE2E8F0);
              textColor = const Color(0xFF94A3B8);
            } else if (isSelected) {
              bgColor = const Color(0xFF0284C7);
              borderColor = const Color(0xFF0284C7);
              textColor = Colors.white;
            }

            return InkWell(
              onTap: isOccupied ? null : () => setState(() => _slotSeleccionado = slot),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOccupied) ...[const Icon(Icons.lock_outline, size: 12, color: Color(0xFF94A3B8)), const SizedBox(width: 4)],
                    Text(slot.horaTexto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor, decoration: isOccupied ? TextDecoration.lineThrough : null)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _slotSeleccionado == null ? Colors.grey.shade300 : const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: _slotSeleccionado == null
                ? null
                : () {
                    widget.onSeleccionarCita(
                      fechaHora: _slotSeleccionado!.fechaHoraCompleta,
                      idSede: _sedeActual?.id ?? '',
                      modalidadAtencion: 'hora_fija',
                    );
                  },
            icon: const Icon(Icons.calendar_today_rounded, size: 17),
            label: Text(
              _slotSeleccionado == null ? 'Toca un horario libre arriba' : 'Pedir Cita para las ${_slotSeleccionado!.horaTexto}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ),
      ],
    );
  }
}

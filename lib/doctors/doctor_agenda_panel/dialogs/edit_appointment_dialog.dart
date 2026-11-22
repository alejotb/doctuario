import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../flutter_flow/flutter_flow_theme.dart';
import '../../../services/appointment_cancellation_service.dart';
import '../../../services/queue_schedule_service.dart';

/// Modal bottom sheet para modificar el horario, estado y detalles de una cita médica.
class EditAppointmentDialog extends StatefulWidget {
  final CitasRow cita;
  final UsuariosRow? paciente;
  final VoidCallback onCitaActualizada;

  const EditAppointmentDialog({
    super.key,
    required this.cita,
    required this.paciente,
    required this.onCitaActualizada,
  });

  static Future<void> show(
    BuildContext context, {
    required CitasRow cita,
    required UsuariosRow? paciente,
    required VoidCallback onCitaActualizada,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => EditAppointmentDialog(
        cita: cita,
        paciente: paciente,
        onCitaActualizada: onCitaActualizada,
      ),
    );
  }

  @override
  State<EditAppointmentDialog> createState() => _EditAppointmentDialogState();
}

class _EditAppointmentDialogState extends State<EditAppointmentDialog> {
  late TimeOfDay _horaSeleccionada;
  late DateTime _fechaSeleccionada;
  late int _duracion;
  late String _estadoSeleccionado;
  late TextEditingController _notasController;
  final TextEditingController _motivoCambioController = TextEditingController();
  late bool _esEmergencia;
  late bool _tratoEspecial;
  late String _tipoExoneracion; // 'ninguno', 'exonerado', 'porcentaje', 'monto_fijo'
  late TextEditingController _montoExoneracionCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final horaOriginal = widget.cita.fechaHoraEstimadaActual ??
        widget.cita.fechaHora ??
        DateTime.now();
    _horaSeleccionada =
        TimeOfDay(hour: horaOriginal.hour, minute: horaOriginal.minute);
    _fechaSeleccionada = horaOriginal;
    _duracion = widget.cita.duracionMinutos ?? 30;
    _estadoSeleccionado = widget.cita.estado ?? 'pendiente';
    _notasController = TextEditingController(text: widget.cita.motivo ?? '');
    _esEmergencia = widget.cita.esEmergencia ?? false;
    _tratoEspecial = widget.cita.tratoEspecial ?? false;
    _tipoExoneracion = widget.cita.tipoExoneracion ?? 'ninguno';
    _montoExoneracionCtrl = TextEditingController(
      text: widget.cita.montoExoneracion != null ? widget.cita.montoExoneracion!.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _notasController.dispose();
    _motivoCambioController.dispose();
    _montoExoneracionCtrl.dispose();
    super.dispose();
  }

  bool get _huboCambioHorario {
    final horaOriginal = widget.cita.fechaHoraEstimadaActual ?? widget.cita.fechaHora;
    if (horaOriginal == null) return false;
    final nuevaFechaHora = DateTime(
      _fechaSeleccionada.year,
      _fechaSeleccionada.month,
      _fechaSeleccionada.day,
      _horaSeleccionada.hour,
      _horaSeleccionada.minute,
    );
    return nuevaFechaHora.difference(horaOriginal).inMinutes.abs() > 2;
  }

  Future<void> _guardarCambios() async {
    setState(() => _isSaving = true);
    try {
      final nuevaFechaHora = DateTime(
        _fechaSeleccionada.year,
        _fechaSeleccionada.month,
        _fechaSeleccionada.day,
        _horaSeleccionada.hour,
        _horaSeleccionada.minute,
      );

      if (_estadoSeleccionado == 'cancelada') {
        await AppointmentCancellationService.instance.cancelarCitaIndividual(
          idCita: widget.cita.id,
          motivo: _motivoCambioController.text.trim(),
          canceladoPorDoctor: true,
          idDoctor: widget.cita.idDoctor,
          idPaciente: widget.cita.idPaciente,
        );
      } else {
        final double? montoExo = _tipoExoneracion == 'ninguno'
            ? null
            : _tipoExoneracion == 'exonerado'
                ? 100.0
                : double.tryParse(_montoExoneracionCtrl.text.trim().replaceAll(',', '.'));

        await CitasTable().update(
          data: {
            'fecha_hora': supaSerialize<DateTime>(nuevaFechaHora),
            'fecha_hora_estimada_actual': supaSerialize<DateTime>(nuevaFechaHora),
            'duracion_minutos': _duracion,
            'estado': _estadoSeleccionado,
            'es_emergencia': _esEmergencia,
            'trato_especial': _tratoEspecial,
            'motivo': _notasController.text.trim(),
            'tipo_exoneracion': _tipoExoneracion == 'ninguno' ? null : _tipoExoneracion,
            'monto_exoneracion': montoExo,
          },
          matchingRows: (q) => q.eq('id', widget.cita.id),
        );
        if (widget.cita.idDoctor != null && widget.cita.idDoctor!.isNotEmpty) {
          await QueueScheduleService.instance.recalcularColaDelDia(
            idDoctor: widget.cita.idDoctor!,
            fecha: nuevaFechaHora,
            idSede: widget.cita.idSede,
          );
        }

        if (widget.cita.idDoctor != null && _huboCambioHorario) {
          await AppointmentCancellationService.instance.reprogramarCitaIndividual(
            idCita: widget.cita.id,
            nuevaFechaHora: nuevaFechaHora,
            motivo: _motivoCambioController.text.trim(),
            reprogramadoPorDoctor: true,
            idDoctor: widget.cita.idDoctor!,
            idPaciente: widget.cita.idPaciente,
            duracionMinutos: _duracion,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cita y horario actualizados exitosamente.'),
            backgroundColor: Colors.teal,
          ),
        );
        widget.onCitaActualizada();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar cita: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horaStr =
        '${_horaSeleccionada.hour.toString().padLeft(2, '0')}:${_horaSeleccionada.minute.toString().padLeft(2, '0')}';
    final fechaStr = DateFormat('dd/MM/yyyy').format(_fechaSeleccionada);

    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20.0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
        top: 20.0,
        left: 20.0,
        right: 20.0,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_calendar_rounded,
                        color: FlutterFlowTheme.of(context).primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Modificar Cita y Horario',
                      style: GoogleFonts.mooli(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              'Paciente: ${widget.paciente?.nombre ?? "Paciente Registrado"}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: FlutterFlowTheme.of(context).secondary,
                fontSize: 14,
              ),
            ),
            const Divider(height: 24),

            // Selector de Hora y Fecha
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: _horaSeleccionada,
                      );
                      if (pickedTime != null) {
                        setState(() => _horaSeleccionada = pickedTime);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 18,
                              color: FlutterFlowTheme.of(context).primary),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hora Cita',
                                  style:
                                      FlutterFlowTheme.of(context).labelSmall),
                              Text(horaStr,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _fechaSeleccionada,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        setState(() => _fechaSeleccionada = pickedDate);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded,
                              size: 18,
                              color: FlutterFlowTheme.of(context).primary),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fecha',
                                  style:
                                      FlutterFlowTheme.of(context).labelSmall),
                              Text(fechaStr,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Text('Duración del Bloque:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [15, 30, 45, 60, 90, 120].map((mins) {
                final isSel = _duracion == mins;
                return ChoiceChip(
                  label: Text('$mins min'),
                  selected: isSel,
                  selectedColor: FlutterFlowTheme.of(context)
                      .primary
                      .withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSel
                        ? FlutterFlowTheme.of(context).primary
                        : Colors.black87,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _duracion = mins);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            const Text('Estado de la Consulta:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                'pendiente',
                'confirmada',
                'en_consulta',
                'atendida',
                'cancelada'
              ].map((st) {
                final isSel = _estadoSeleccionado.toLowerCase() == st;
                String label = st.replaceAll('_', ' ').toUpperCase();
                Color color = Colors.blue;
                if (st == 'confirmada') color = Colors.teal;
                if (st == 'en_consulta') color = Colors.green;
                if (st == 'atendida') color = Colors.grey;
                if (st == 'cancelada') color = Colors.red;

                return FilterChip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  selected: isSel,
                  selectedColor: color.withValues(alpha: 0.25),
                  checkmarkColor: color,
                  onSelected: (val) {
                    if (val) setState(() => _estadoSeleccionado = st);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                FilterChip(
                  label: const Text('🚨 Urgencia / Emergencia'),
                  selected: _esEmergencia,
                  selectedColor: Colors.red.shade100,
                  onSelected: (val) => setState(() => _esEmergencia = val),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('⭐ Trato Especial'),
                  selected: _tratoEspecial,
                  selectedColor: Colors.amber.shade100,
                  onSelected: (val) => setState(() => _tratoEspecial = val),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              'Exoneración o Descuento en Consulta (visible para Secretaría)',
              style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Tarifa normal'),
                  selected: _tipoExoneracion == 'ninguno',
                  onSelected: (_) => setState(() => _tipoExoneracion = 'ninguno'),
                ),
                ChoiceChip(
                  label: const Text('💚 Exonerado (100%)'),
                  selected: _tipoExoneracion == 'exonerado',
                  selectedColor: Colors.green.shade100,
                  onSelected: (_) => setState(() => _tipoExoneracion = 'exonerado'),
                ),
                ChoiceChip(
                  label: const Text('Descuento (%)'),
                  selected: _tipoExoneracion == 'porcentaje',
                  selectedColor: Colors.teal.shade100,
                  onSelected: (_) => setState(() => _tipoExoneracion = 'porcentaje'),
                ),
                ChoiceChip(
                  label: const Text('Monto especial (\$)'),
                  selected: _tipoExoneracion == 'monto_fijo',
                  selectedColor: Colors.teal.shade100,
                  onSelected: (_) => setState(() => _tipoExoneracion = 'monto_fijo'),
                ),
              ],
            ),
            if (_tipoExoneracion == 'porcentaje' || _tipoExoneracion == 'monto_fijo') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _montoExoneracionCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: _tipoExoneracion == 'porcentaje'
                      ? 'Porcentaje de descuento (%)'
                      : 'Monto especial a cobrar (\$)',
                  hintText: _tipoExoneracion == 'porcentaje' ? 'Ej. 50' : 'Ej. 20',
                  suffixText: _tipoExoneracion == 'porcentaje' ? '%' : '\$',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const SizedBox(height: 14),

            TextField(
              controller: _notasController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notas o Instrucciones para la cita',
                hintText: 'Ej. Traer exámenes previos de laboratorio...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_estadoSeleccionado == 'cancelada' || _huboCambioHorario) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _motivoCambioController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _estadoSeleccionado == 'cancelada'
                      ? 'Motivo de cancelación (se enviará al paciente)'
                      : 'Motivo de reprogramación (se enviará al paciente)',
                  hintText: _estadoSeleccionado == 'cancelada'
                      ? 'Ej. Imprevisto médico o cierre de consultorio'
                      : 'Ej. Reajuste de horario en consultorio',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlutterFlowTheme.of(context).primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving ? null : _guardarCambios,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar Cambios',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

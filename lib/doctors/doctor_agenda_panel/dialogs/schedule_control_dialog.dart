import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';

/// Diálogo para programar una cita de control clínico (con opción de gratuita o cobrada).
class ScheduleControlDialog extends StatefulWidget {
  final String idDoctor;
  final CitasRow cita;
  final UsuariosRow? paciente;
  final String? idSede;
  final VoidCallback onControlAgendado;

  const ScheduleControlDialog({
    super.key,
    required this.idDoctor,
    required this.cita,
    required this.paciente,
    this.idSede,
    required this.onControlAgendado,
  });

  static Future<void> show(
    BuildContext context, {
    required String idDoctor,
    required CitasRow cita,
    required UsuariosRow? paciente,
    String? idSede,
    required VoidCallback onControlAgendado,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ScheduleControlDialog(
        idDoctor: idDoctor,
        cita: cita,
        paciente: paciente,
        idSede: idSede,
        onControlAgendado: onControlAgendado,
      ),
    );
  }

  @override
  State<ScheduleControlDialog> createState() => _ScheduleControlDialogState();
}

class _ScheduleControlDialogState extends State<ScheduleControlDialog> {
  late DateTime _fechaControl;
  TimeOfDay _horaControl = const TimeOfDay(hour: 9, minute: 0);
  bool _cobrarControl = false;
  final _notasCtrl = TextEditingController(text: 'Cita de Control Médico');
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fechaControl = DateTime.now().add(const Duration(days: 15));
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _agendarControl() async {
    setState(() => _isSaving = true);
    try {
      final fechaHoraControl = DateTime(
        _fechaControl.year,
        _fechaControl.month,
        _fechaControl.day,
        _horaControl.hour,
        _horaControl.minute,
      );

      final idSedeFinal = widget.cita.idSede ?? widget.idSede;

      await CitasTable().insert({
        'id_doctor': widget.idDoctor,
        'id_paciente': widget.cita.idPaciente,
        'id_sede': idSedeFinal,
        'fecha_hora': fechaHoraControl.toUtc().toIso8601String(),
        'fecha_hora_estimada_actual':
            fechaHoraControl.toUtc().toIso8601String(),
        'estado': 'confirmada',
        'motivo': _notasCtrl.text.trim().isNotEmpty
            ? _notasCtrl.text.trim()
            : 'Cita de Control Clínico',
        'es_control': true,
        'cobrar_control': _cobrarControl,
        'duracion_minutos': 20,
        'minutos_retraso_acumulados': 0,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🔄 Cita de control agendada para el ${DateFormat('dd/MM/yyyy').format(_fechaControl)} (${_cobrarControl ? "Cobrada" : "Gratuita"}).'),
            backgroundColor: Colors.teal,
          ),
        );
        widget.onControlAgendado();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agendar control: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sync_rounded,
                color: Color(0xFF0284C7), size: 22),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '¿Programar Cita de Control?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paciente: ${widget.paciente?.nombre ?? "Paciente"}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.teal),
            ),
            const SizedBox(height: 12),
            const Text('Fecha Sugerida:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [7, 15, 21, 30].map((dias) {
                final target = DateTime.now().add(Duration(days: dias));
                final isSel = _fechaControl.year == target.year &&
                    _fechaControl.month == target.month &&
                    _fechaControl.day == target.day;
                return ChoiceChip(
                  label: Text('En $dias días'),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _fechaControl = target);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _fechaControl,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _fechaControl = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(_fechaControl),
                              style: const TextStyle(fontSize: 12)),
                          const Icon(Icons.calendar_today, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _horaControl,
                      );
                      if (picked != null) {
                        setState(() => _horaControl = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_horaControl.format(context),
                              style: const TextStyle(fontSize: 12)),
                          const Icon(Icons.access_time, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Condición de Cobro:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    avatar: Icon(Icons.money_off,
                        size: 16,
                        color: !_cobrarControl
                            ? const Color(0xFF059669)
                            : Colors.grey),
                    label: const Text('Gratis / Incluida',
                        style: TextStyle(fontSize: 11)),
                    selected: !_cobrarControl,
                    selectedColor: const Color(0xFFD1FAE5),
                    onSelected: (val) {
                      if (val) setState(() => _cobrarControl = false);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ChoiceChip(
                    avatar: Icon(Icons.attach_money,
                        size: 16,
                        color: _cobrarControl
                            ? const Color(0xFF0284C7)
                            : Colors.grey),
                    label: const Text('Cobrar Consulta',
                        style: TextStyle(fontSize: 11)),
                    selected: _cobrarControl,
                    selectedColor: const Color(0xFFE0F2FE),
                    onSelected: (val) {
                      if (val) setState(() => _cobrarControl = true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notasCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo de Control / Indicaciones',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('No agendar ahora'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7)),
          icon:
              const Icon(Icons.event_available, size: 16, color: Colors.white),
          label: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Agendar Cita Control',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: _isSaving ? null : _agendarControl,
        ),
      ],
    );
  }
}

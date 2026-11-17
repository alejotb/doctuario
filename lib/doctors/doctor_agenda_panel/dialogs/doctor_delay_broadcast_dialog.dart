import 'package:flutter/material.dart';
import '../../../services/emergency_appointment_service.dart';

/// Diálogo para que el doctor notifique un retraso general a los pacientes citados hoy.
class DoctorDelayBroadcastDialog extends StatefulWidget {
  final String idDoctor;
  final VoidCallback onNotificado;

  const DoctorDelayBroadcastDialog({
    super.key,
    required this.idDoctor,
    required this.onNotificado,
  });

  static Future<void> show(
    BuildContext context, {
    required String idDoctor,
    required VoidCallback onNotificado,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => DoctorDelayBroadcastDialog(
        idDoctor: idDoctor,
        onNotificado: onNotificado,
      ),
    );
  }

  @override
  State<DoctorDelayBroadcastDialog> createState() =>
      _DoctorDelayBroadcastDialogState();
}

class _DoctorDelayBroadcastDialogState
    extends State<DoctorDelayBroadcastDialog> {
  int _minutosRetraso = 30;
  final _motivoCtrl = TextEditingController(text: 'Retraso de itinerario');
  bool _isSending = false;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarNotificacion() async {
    setState(() => _isSending = true);
    try {
      final afectadas =
          await EmergencyAppointmentService().notificarRetrasoGeneralDoctor(
        idDoctor: widget.idDoctor,
        minutosRetraso: _minutosRetraso,
        motivo: _motivoCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '📢 Se avisó el retraso a $afectadas paciente(s) y se actualizaron sus horarios.'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        widget.onNotificado();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al notificar retraso: $e'),
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
      title: const Row(
        children: [
          Icon(Icons.campaign, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Text('Avisar Retraso / Salida',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esta acción notificará a todos los pacientes con citas pendientes del día y correrá sus horarios estimados.',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 14),
          const Text('Minutos de Retraso Estimados:',
              style: TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 6,
            children: [15, 30, 45, 60, 90].map((mins) {
              return ChoiceChip(
                label: Text('$mins min'),
                selected: _minutosRetraso == mins,
                selectedColor: Colors.orange.shade200,
                onSelected: (val) {
                  if (val) setState(() => _minutosRetraso = mins);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motivoCtrl,
            decoration: const InputDecoration(
              labelText: 'Motivo del retraso',
              hintText: 'Ej. Tráfico pesado, salida médica urgente...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSending ? null : _enviarNotificacion,
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Notificar a Todos'),
        ),
      ],
    );
  }
}

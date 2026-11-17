import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/appointment_cancellation_service.dart';
import '../../../services/i18n_service.dart';

/// Modal para que doctores o secretarias puedan cancelar o mover/reprogramar
/// todas las citas de un día determinado, especificando el motivo formal para los pacientes.
class ManageDayAppointmentsDialog extends StatefulWidget {
  final String idDoctor;
  final DateTime fecha;
  final List<CitasRow> citasDelDia;
  final VoidCallback onActualizado;

  const ManageDayAppointmentsDialog({
    super.key,
    required this.idDoctor,
    required this.fecha,
    required this.citasDelDia,
    required this.onActualizado,
  });

  static Future<void> show(
    BuildContext context, {
    required String idDoctor,
    required DateTime fecha,
    required List<CitasRow> citasDelDia,
    required VoidCallback onActualizado,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ManageDayAppointmentsDialog(
        idDoctor: idDoctor,
        fecha: fecha,
        citasDelDia: citasDelDia,
        onActualizado: onActualizado,
      ),
    );
  }

  @override
  State<ManageDayAppointmentsDialog> createState() =>
      _ManageDayAppointmentsDialogState();
}

class _ManageDayAppointmentsDialogState
    extends State<ManageDayAppointmentsDialog> {
  int _modo = 0; // 0: Cancelar todas, 1: Reprogramar / Mover todas
  final _motivoCtrl = TextEditingController();
  DateTime? _fechaDestino;
  bool _procesando = false;

  final List<String> _motivosPredefinidos = [
    'Congreso / Capacitación Médica',
    'Imprevisto de Salud del Doctor',
    'Urgencia Médica en Quirófano',
    'Falla de Servicios en Consultorio',
    'Motivos Personales de Fuerza Mayor',
  ];

  @override
  void initState() {
    super.initState();
    _motivoCtrl.text = _motivosPredefinidos.first;
    _fechaDestino = widget.fecha.add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  List<CitasRow> get _citasActivas => widget.citasDelDia
      .where((c) => c.estado != 'cancelada' && c.estado != 'atendida')
      .toList();

  Future<void> _ejecutarAccion() async {
    final motivo = _motivoCtrl.text.trim();
    if (motivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor especifica el motivo que recibirán los pacientes.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_modo == 1 && _fechaDestino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona la fecha de destino para mover las citas.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _procesando = true);

    try {
      if (_modo == 0) {
        // Cancelación masiva
        final total = await AppointmentCancellationService.instance.cancelarCitasDelDia(
          idDoctor: widget.idDoctor,
          fecha: widget.fecha,
          motivo: motivo,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Se cancelaron $total citas y se notificó a los pacientes.'),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
      } else {
        // Reprogramación masiva
        final total = await AppointmentCancellationService.instance.reprogramarCitasDelDia(
          idDoctor: widget.idDoctor,
          fechaOrigen: widget.fecha,
          fechaDestino: _fechaDestino!,
          motivo: motivo,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Se movieron $total citas a la nueva fecha y se notificó a los pacientes.'),
              backgroundColor: Colors.teal,
            ),
          );
        }
      }

      widget.onActualizado();
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final fechaStr = DateFormat('EEEE d \'de\' MMMM', 'es').format(widget.fecha);
    final totalActivas = _citasActivas.length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _modo == 0 ? Colors.red.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _modo == 0 ? Icons.event_busy_rounded : Icons.next_plan_rounded,
              color: _modo == 0 ? Colors.red.shade700 : const Color(0xFF0284C7),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? 'Ajustar Citas del Día' : 'Manage Day Appointments',
                  style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  fechaStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Alerta de cantidad de citas
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: totalActivas > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: totalActivas > 0 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      totalActivas > 0 ? Icons.info_outline : Icons.check_circle_outline,
                      size: 20,
                      color: totalActivas > 0 ? const Color(0xFFB45309) : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        totalActivas > 0
                            ? 'Hay $totalActivas cita(s) activa(s) programada(s) para este día.'
                            : 'No hay citas activas pendientes para este día.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: totalActivas > 0 ? const Color(0xFF92400E) : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Selector de tipo de acción
              Text(
                'Selecciona la acción para todas las citas:',
                style: GoogleFonts.mooli(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildBotonModo(
                      titulo: 'Cancelar Todas',
                      icono: Icons.cancel_outlined,
                      index: 0,
                      colorActivo: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildBotonModo(
                      titulo: 'Mover de Fecha',
                      icono: Icons.sync_rounded,
                      index: 1,
                      colorActivo: const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Si es Mover de fecha, selector de fecha destino
              if (_modo == 1) ...[
                Text(
                  'Nueva fecha para reprogramar:',
                  style: GoogleFonts.mooli(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final sel = await showDatePicker(
                      context: context,
                      initialDate: _fechaDestino ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 120)),
                    );
                    if (sel != null) {
                      setState(() => _fechaDestino = sel);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _fechaDestino != null
                              ? DateFormat('EEEE d \'de\' MMMM, yyyy', 'es').format(_fechaDestino!)
                              : 'Toca para seleccionar fecha',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0284C7)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Razón / Motivo para el paciente
              Text(
                'Motivo que se enviará a los pacientes:',
                style: GoogleFonts.mooli(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _motivosPredefinidos.map((m) {
                  final isSel = _motivoCtrl.text == m;
                  return ChoiceChip(
                    label: Text(m, style: TextStyle(fontSize: 10.5, color: isSel ? Colors.white : Colors.black87)),
                    selected: isSel,
                    selectedColor: _modo == 0 ? Colors.red.shade700 : const Color(0xFF0284C7),
                    onSelected: (val) {
                      if (val) setState(() => _motivoCtrl.text = m);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _motivoCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Detalla el motivo para los pacientes...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _procesando ? null : () => Navigator.pop(context),
          child: Text(isEs ? 'Volver' : 'Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _modo == 0 ? Colors.red.shade700 : const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: (_procesando || totalActivas == 0) ? null : _ejecutarAccion,
          icon: _procesando
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(_modo == 0 ? Icons.delete_sweep_rounded : Icons.check_circle_rounded, size: 18),
          label: Text(
            _modo == 0 ? 'Confirmar Cancelación Masiva' : 'Mover Citas a Nueva Fecha',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildBotonModo({
    required String titulo,
    required IconData icono,
    required int index,
    required Color colorActivo,
  }) {
    final activo = _modo == index;
    return InkWell(
      onTap: () => setState(() => _modo = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: activo ? colorActivo.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo ? colorActivo : Colors.grey.shade300,
            width: activo ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 16, color: activo ? colorActivo : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                color: activo ? colorActivo : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

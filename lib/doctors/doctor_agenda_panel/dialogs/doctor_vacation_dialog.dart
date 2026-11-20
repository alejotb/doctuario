import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/doctor_vacation_service.dart';

/// Modal interactivo para configurar vacaciones y días no disponibles en la agenda del doctor.
/// Permite bloquear una fecha seleccionada o un rango de fechas, visualizar los días actualmente
/// marcados como inactivos y reactivarlos/desbloquearlos de forma inmediata.
class DoctorVacationDialog extends StatefulWidget {
  final String idDoctor;
  final VoidCallback onDiasActualizados;

  const DoctorVacationDialog({
    super.key,
    required this.idDoctor,
    required this.onDiasActualizados,
  });

  static Future<void> show(
    BuildContext context, {
    required String idDoctor,
    required VoidCallback onDiasActualizados,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DoctorVacationDialog(
        idDoctor: idDoctor,
        onDiasActualizados: onDiasActualizados,
      ),
    );
  }

  @override
  State<DoctorVacationDialog> createState() => _DoctorVacationDialogState();
}

class _DoctorVacationDialogState extends State<DoctorVacationDialog> {
  DateTime _fechaSeleccionada = DateTime.now();
  final TextEditingController _motivoController = TextEditingController(
    text: 'El doctor no estará disponible',
  );
  Set<String> _diasBloqueados = {};
  Map<String, String> _motivosBloqueo = {};
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarDias();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDias() async {
    setState(() => _cargando = true);
    final dias = await DoctorVacationService.instance
        .obtenerDiasBloqueados(widget.idDoctor);
    final motivos = await DoctorVacationService.instance
        .obtenerMotivosBloqueo(widget.idDoctor);
    if (mounted) {
      setState(() {
        _diasBloqueados = dias;
        _motivosBloqueo = motivos;
        _cargando = false;
      });
    }
  }

  Future<void> _bloquearFecha() async {
    setState(() => _guardando = true);
    final exito = await DoctorVacationService.instance.bloquearDia(
      idDoctor: widget.idDoctor,
      fecha: _fechaSeleccionada,
      motivo: _motivoController.text,
    );

    if (mounted) {
      setState(() => _guardando = false);
      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F766E),
            content: Text(
              'Día ${DateFormat('dd/MM/yyyy').format(_fechaSeleccionada)} marcado como no disponible.',
            ),
          ),
        );
        await _cargarDias();
        widget.onDiasActualizados();
      }
    }
  }

  Future<void> _desbloquearFecha(String fechaIso) async {
    final parsed = DoctorVacationService.parsearFecha(fechaIso);
    if (parsed == null) return;

    setState(() => _cargando = true);
    final exito = await DoctorVacationService.instance.desbloquearDia(
      idDoctor: widget.idDoctor,
      fecha: parsed,
    );

    if (mounted) {
      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0284C7),
            content: Text(
              'Día ${DateFormat('dd/MM/yyyy').format(parsed)} habilitado nuevamente.',
            ),
          ),
        );
        await _cargarDias();
        widget.onDiasActualizados();
      } else {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBloqueadoActual = DoctorVacationService.estaBloqueado(
      _fechaSeleccionada,
      _diasBloqueados,
    );

    final listaOrdenada = _diasBloqueados.toList()..sort();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.beach_access_rounded,
                    color: Color(0xFFD97706),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Días no disponibles',
                        style: GoogleFonts.mooli(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Los días bloqueados aparecerán en gris y no recibirán citas.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleccionar Fecha a Bloquear',
                    style: GoogleFonts.mooli(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          icon: const Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: Color(0xFF0284C7),
                          ),
                          label: Text(
                            DateFormat('EEEE d MMMM yyyy', 'es')
                                .format(_fechaSeleccionada),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fechaSeleccionada,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setState(() => _fechaSeleccionada = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _motivoController,
                    decoration: InputDecoration(
                      labelText: 'Motivo (opcional)',
                      hintText: 'Ej. Vacaciones anuales, Congreso, Libre',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.edit_note, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBloqueadoActual
                            ? Colors.grey.shade400
                            : const Color(0xFFD97706),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(
                        isBloqueadoActual
                            ? Icons.block
                            : Icons.add_circle_outline,
                        color: Colors.white,
                      ),
                      label: Text(
                        isBloqueadoActual
                            ? 'Este día ya está deshabilitado'
                            : 'Deshabilitar este día en Agenda',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: (_guardando || isBloqueadoActual)
                          ? null
                          : _bloquearFecha,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Días actualmente deshabilitados (${listaOrdenada.length})',
              style: GoogleFonts.mooli(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : listaOrdenada.isEmpty
                      ? Center(
                          child: Text(
                            'No hay días bloqueados actualmente.\nEl doctor está disponible todos los días activos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: listaOrdenada.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (ctx, i) {
                            final fechaStr = listaOrdenada[i];
                            final dt =
                                DoctorVacationService.parsearFecha(fechaStr) ??
                                    DateTime.now();
                            final motivo = _motivosBloqueo[fechaStr] ??
                                'El doctor no estará disponible';

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.event_busy_rounded,
                                    color: Color(0xFF64748B),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('EEEE dd/MM/yyyy', 'es')
                                              .format(dt),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                        Text(
                                          motivo,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Habilitar día',
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Color(0xFFEF4444),
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _desbloquearFecha(fechaStr),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

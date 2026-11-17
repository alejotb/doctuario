import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../backend/supabase/supabase.dart';

/// Diálogo interactivo para registrar o editar los signos vitales del paciente y su grupo sanguíneo.
class EditVitalsDialog extends StatefulWidget {
  final CitasRow cita;
  final String? idPaciente;
  final String? initialPA;
  final String? initialFC;
  final String? initialTemp;
  final String? initialSpO2;
  final String? initialTipoSangre;
  final VoidCallback onVitalsActualizados;

  const EditVitalsDialog({
    super.key,
    required this.cita,
    required this.idPaciente,
    this.initialPA,
    this.initialFC,
    this.initialTemp,
    this.initialSpO2,
    this.initialTipoSangre,
    required this.onVitalsActualizados,
  });

  static Future<void> show(
    BuildContext context, {
    required CitasRow cita,
    required String? idPaciente,
    String? initialPA,
    String? initialFC,
    String? initialTemp,
    String? initialSpO2,
    String? initialTipoSangre,
    required VoidCallback onVitalsActualizados,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditVitalsDialog(
        cita: cita,
        idPaciente: idPaciente,
        initialPA: initialPA,
        initialFC: initialFC,
        initialTemp: initialTemp,
        initialSpO2: initialSpO2,
        initialTipoSangre: initialTipoSangre,
        onVitalsActualizados: onVitalsActualizados,
      ),
    );
  }

  @override
  State<EditVitalsDialog> createState() => _EditVitalsDialogState();
}

class _EditVitalsDialogState extends State<EditVitalsDialog> {
  late final TextEditingController _paCtrl;
  late final TextEditingController _fcCtrl;
  late final TextEditingController _tempCtrl;
  late final TextEditingController _spo2Ctrl;
  String? _tipoSangre;
  bool _isSaving = false;

  static const List<String> _tiposSangre = [
    'Desconocido', 'O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'
  ];

  @override
  void initState() {
    super.initState();
    _paCtrl = TextEditingController(text: widget.initialPA ?? '');
    _fcCtrl = TextEditingController(text: widget.initialFC ?? '');
    _tempCtrl = TextEditingController(text: widget.initialTemp ?? '');
    _spo2Ctrl = TextEditingController(text: widget.initialSpO2 ?? '');
    _tipoSangre = widget.initialTipoSangre;
    if (_tipoSangre == null || !_tiposSangre.contains(_tipoSangre)) {
      _tipoSangre = 'Desconocido';
    }
  }

  @override
  void dispose() {
    _paCtrl.dispose();
    _fcCtrl.dispose();
    _tempCtrl.dispose();
    _spo2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _isSaving = true);
    try {
      final docClient = DualDatabaseConfig.instance.doctorClient;

      // 1. Armar payload de signos vitales
      Map<String, dynamic> vitalsMap = {};
      try {
        if (widget.cita.notasMedicas != null && widget.cita.notasMedicas!.isNotEmpty) {
          final decoded = jsonDecode(widget.cita.notasMedicas!);
          if (decoded is Map<String, dynamic>) vitalsMap = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}

      if (_paCtrl.text.trim().isNotEmpty) vitalsMap['pa'] = _paCtrl.text.trim();
      if (_fcCtrl.text.trim().isNotEmpty) vitalsMap['fc'] = _fcCtrl.text.trim();
      if (_tempCtrl.text.trim().isNotEmpty) vitalsMap['temp'] = _tempCtrl.text.trim();
      if (_spo2Ctrl.text.trim().isNotEmpty) vitalsMap['spo2'] = _spo2Ctrl.text.trim();

      // Guardar signos en la cita
      await docClient.from('citas').update({
        'notas_medicas': jsonEncode(vitalsMap),
      }).eq('id', widget.cita.id);

      // 2. Guardar grupo sanguíneo en el paciente
      final sangVal = _tipoSangre == 'Desconocido' ? null : _tipoSangre;
      if (widget.idPaciente != null && widget.idPaciente!.isNotEmpty) {
        try {
          await docClient.from('pacientes').update({
            'tipo_sangre': sangVal,
          }).eq('id', widget.idPaciente!);
        } catch (_) {}

        try {
          await docClient.from('usuarios').update({
            'tipo_sangre': sangVal,
          }).eq('id', widget.idPaciente!);
        } catch (_) {}
      }

      widget.onVitalsActualizados();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Signos vitales y grupo sanguíneo actualizados.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar signos: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String suffix,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF0284C7)),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.monitor_heart_outlined, color: Color(0xFF0284C7), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registrar Signos Vitales',
                          style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Ingresa los valores medidos en consulta para este paciente.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Campos en dos columnas
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _paCtrl,
                      label: 'Presión Arterial',
                      hint: '120/80',
                      suffix: 'mmHg',
                      icon: Icons.speed_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      controller: _fcCtrl,
                      label: 'Frec. Cardíaca',
                      hint: '75',
                      suffix: 'lpm',
                      icon: Icons.favorite_border_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _tempCtrl,
                      label: 'Temperatura',
                      hint: '36.5',
                      suffix: '°C',
                      icon: Icons.thermostat_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      controller: _spo2Ctrl,
                      label: 'Saturación SpO2',
                      hint: '98',
                      suffix: '%',
                      icon: Icons.air_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Selector de Grupo Sanguíneo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bloodtype_outlined, size: 18, color: Color(0xFFE11D48)),
                    const SizedBox(width: 10),
                    const Text('Grupo Sanguíneo:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _tipoSangre,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        items: _tiposSangre.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) => setState(() => _tipoSangre = val),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Botones de Acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade700)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    onPressed: _isSaving ? null : _guardar,
                    icon: _isSaving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(_isSaving ? 'Guardando...' : 'Guardar Signos', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

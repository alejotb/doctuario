import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../backend/supabase/supabase.dart';

/// Modal dialog for editing patient clinical & demographic information.
class EditPatientInfoDialog extends StatefulWidget {
  final UsuariosRow paciente;
  final VoidCallback onPacienteActualizado;

  const EditPatientInfoDialog({
    super.key,
    required this.paciente,
    required this.onPacienteActualizado,
  });

  static Future<void> show(
    BuildContext context, {
    required UsuariosRow paciente,
    required VoidCallback onPacienteActualizado,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditPatientInfoDialog(
        paciente: paciente,
        onPacienteActualizado: onPacienteActualizado,
      ),
    );
  }

  @override
  State<EditPatientInfoDialog> createState() => _EditPatientInfoDialogState();
}

class _EditPatientInfoDialogState extends State<EditPatientInfoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _cedulaCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _ciudadCtrl;
  late final TextEditingController _alergiasCtrl;
  late final TextEditingController _antecedentesCtrl;

  DateTime? _fechaNacimiento;
  String? _tipoSangre;
  bool _isSaving = false;

  static const List<String> _tiposSangre = [
    'O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'Desconocido'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.paciente;
    _nombreCtrl = TextEditingController(text: p.nombre ?? '');
    _cedulaCtrl = TextEditingController(text: p.cedula ?? '');
    _telefonoCtrl = TextEditingController(text: p.telefono ?? '');
    _emailCtrl = TextEditingController(text: p.email ?? '');
    _ciudadCtrl = TextEditingController(text: p.ciudadOrigen ?? '');
    _alergiasCtrl = TextEditingController(text: p.data['alergias']?.toString() ?? '');
    _antecedentesCtrl = TextEditingController(text: p.data['antecedentes']?.toString() ?? '');
    _fechaNacimiento = p.fechaNacimiento;
    _tipoSangre = p.data['tipo_sangre']?.toString();
    if (_tipoSangre != null && !_tiposSangre.contains(_tipoSangre)) {
      _tipoSangre = null;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _ciudadCtrl.dispose();
    _alergiasCtrl.dispose();
    _antecedentesCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechaNacimiento() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      locale: const Locale('es'),
      helpText: 'Fecha de Nacimiento del Paciente',
    );
    if (picked != null) {
      setState(() => _fechaNacimiento = picked);
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final docClient = DualDatabaseConfig.instance.doctorClient;
      final updateData = <String, dynamic>{
        'nombre': _nombreCtrl.text.trim(),
        'cedula': _cedulaCtrl.text.trim().isNotEmpty ? _cedulaCtrl.text.trim() : null,
        'telefono': _telefonoCtrl.text.trim().isNotEmpty ? _telefonoCtrl.text.trim() : null,
        'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        'ciudad_origen': _ciudadCtrl.text.trim().isNotEmpty ? _ciudadCtrl.text.trim() : null,
        'fecha_nacimiento': _fechaNacimiento?.toIso8601String().split('T').first,
        'tipo_sangre': _tipoSangre,
        'alergias': _alergiasCtrl.text.trim().isNotEmpty ? _alergiasCtrl.text.trim() : null,
        'antecedentes': _antecedentesCtrl.text.trim().isNotEmpty ? _antecedentesCtrl.text.trim() : null,
      };

      // 1. Actualizar tabla pacientes (base de datos clínica privada)
      await docClient.from('pacientes').update(updateData).eq('id', widget.paciente.id);

      // 2. Actualizar tabla usuarios en BD clínica si existe sincronizada
      try {
        final userData = Map<String, dynamic>.from(updateData)
          ..remove('alergias')
          ..remove('antecedentes');
        await docClient.from('usuarios').update(userData).eq('id', widget.paciente.id);
      } catch (_) {}

      widget.onPacienteActualizado();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF16A34A),
            content: Text('Información del paciente actualizada con éxito.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Error al actualizar paciente: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF0284C7)),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
        ),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Este campo es obligatorio' : null
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmtFechaNac = _fechaNacimiento != null
        ? DateFormat('dd/MM/yyyy').format(_fechaNacimiento!)
        : 'Seleccionar fecha';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFF0284C7), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editar Datos del Paciente',
                          style: GoogleFonts.mooli(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Modifica o complementa la ficha clínica y de contacto.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
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

              // Form fields
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      _buildTextField(
                        controller: _nombreCtrl,
                        label: 'Nombre Completo *',
                        icon: Icons.person_outline,
                        required: true,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cedulaCtrl,
                              label: 'Cédula / Documento',
                              icon: Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              controller: _telefonoCtrl,
                              label: 'Teléfono',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _emailCtrl,
                              label: 'Correo Electrónico',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              controller: _ciudadCtrl,
                              label: 'Ciudad de Origen',
                              icon: Icons.location_city_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Fecha de Nacimiento
                          Expanded(
                            child: InkWell(
                              onTap: _seleccionarFechaNacimiento,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.cake_outlined, size: 18, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Nacimiento', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                          Text(fmtFechaNac, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Tipo de Sangre
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _tipoSangre,
                                  isExpanded: true,
                                  hint: const Text('Tipo Sangre', style: TextStyle(fontSize: 12)),
                                  items: _tiposSangre.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                                  onChanged: (val) => setState(() => _tipoSangre = val),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _alergiasCtrl,
                        label: 'Alergias Conocidas',
                        icon: Icons.warning_amber_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _antecedentesCtrl,
                        label: 'Antecedentes Patológicos / Médicos',
                        icon: Icons.assignment_outlined,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 20),

              // Action buttons
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
                    onPressed: _isSaving ? null : _guardarCambios,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(_isSaving ? 'Guardando...' : 'Guardar Cambios', style: const TextStyle(fontWeight: FontWeight.bold)),
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

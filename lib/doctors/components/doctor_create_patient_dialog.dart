import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../backend/supabase/supabase.dart';
import '../../flutter_flow/flutter_flow_theme.dart';

/// Modal interactivo para que el médico o secretaria registre manualmente
/// a un nuevo paciente en la base de datos privada del consultorio.
class DoctorCreatePatientDialog extends StatefulWidget {
  final String idDoctor;

  const DoctorCreatePatientDialog({
    super.key,
    required this.idDoctor,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String idDoctor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DoctorCreatePatientDialog(idDoctor: idDoctor),
    );
  }

  @override
  State<DoctorCreatePatientDialog> createState() =>
      _DoctorCreatePatientDialogState();
}

class _DoctorCreatePatientDialogState extends State<DoctorCreatePatientDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _cedulaCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _ciudadCtrl = TextEditingController();
  final TextEditingController _antecedentesCtrl = TextEditingController();

  DateTime? _fechaNacimiento;
  String? _tipoSangre;
  bool _esForaneo = false;
  bool _isSaving = false;

  static const List<String> _tiposSangre = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _ciudadCtrl.dispose();
    _antecedentesCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechaNacimiento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
      helpText: 'Fecha de Nacimiento del Paciente',
    );
    if (picked != null) setState(() => _fechaNacimiento = picked);
  }

  Future<void> _guardarPaciente() async {
    if (!_formKey.currentState!.validate()) return;

    final nombre = _nombreCtrl.text.trim();
    final cedula = _cedulaCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final ciudad = _ciudadCtrl.text.trim();
    final antecedentes = _antecedentesCtrl.text.trim();

    setState(() => _isSaving = true);

    try {
      final docClient = DualDatabaseConfig.instance.doctorClient;

      // Verificar si ya existe para este doctor por cédula
      if (cedula.isNotEmpty) {
        final existing = await docClient
            .from('pacientes')
            .select('id, nombre')
            .eq('id_doctor', widget.idDoctor)
            .eq('cedula', cedula);
        if ((existing as List).isNotEmpty) {
          if (mounted) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ya tienes un paciente registrado con cédula $cedula (${existing.first['nombre']})'),
                backgroundColor: Colors.orange.shade800,
              ),
            );
            return;
          }
        }
      }

      final newPatientId = const Uuid().v4();
      final nowIso = DateTime.now().toUtc().toIso8601String();

      final fechaNacStr = _fechaNacimiento != null
          ? '${_fechaNacimiento!.year.toString().padLeft(4, '0')}-${_fechaNacimiento!.month.toString().padLeft(2, '0')}-${_fechaNacimiento!.day.toString().padLeft(2, '0')}'
          : null;

      // 1. Guardar ficha completa directamente en la tabla pacientes
      final pacientePayload = <String, dynamic>{
        'id': newPatientId,
        'id_doctor': widget.idDoctor,
        'nombre': nombre,
        if (cedula.isNotEmpty) 'cedula': cedula,
        if (telefono.isNotEmpty) 'telefono': telefono,
        if (email.isNotEmpty) 'email': email,
        if (ciudad.isNotEmpty) 'ciudad_origen': ciudad,
        if (fechaNacStr != null) 'fecha_nacimiento': fechaNacStr,
        if (_tipoSangre != null) 'tipo_sangre': _tipoSangre,
        'created_at': nowIso,
      };

      try {
        await docClient.from('pacientes').insert({
          ...pacientePayload,
          'es_foraneo': _esForaneo,
          if (antecedentes.isNotEmpty) 'antecedentes': antecedentes,
        });
      } catch (err) {
        debugPrint('Aviso guardando columnas extendidas en pacientes, insertando payload base: $err');
        await docClient.from('pacientes').insert(pacientePayload);
      }

      // 3. Crear primera historia clínica si ingresó antecedentes
      if (antecedentes.isNotEmpty) {
        await docClient.from('historias_clinicas').insert({
          'id': const Uuid().v4(),
          'id_paciente': newPatientId,
          'id_doctor': widget.idDoctor,
          'fecha': nowIso,
          'motivo_consulta': 'Registro y apertura de expediente clínico',
          'diagnostico': 'Antecedentes: $antecedentes',
        });
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Paciente $nombre registrado con éxito.'), backgroundColor: const Color(0xFF059669)),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar paciente: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.secondaryBackground,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF0284C7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Registrar Nuevo Paciente', style: GoogleFonts.mooli(fontSize: 17, fontWeight: FontWeight.bold)),
                          Text('Expediente privado en tu consultorio', style: TextStyle(fontSize: 11.5, color: theme.secondaryText)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(context).pop(false)),
                  ],
                ),
                const Divider(height: 20),

                Text('Nombre Completo *', style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _nombreCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre del paciente' : null,
                  style: GoogleFonts.mooli(fontSize: 13),
                  decoration: _buildInputDeco('Ej: Juan Carlos Pérez', Icons.person_outline, theme),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cédula / Identificación', style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextFormField(controller: _cedulaCtrl, style: GoogleFonts.mooli(fontSize: 13), decoration: _buildInputDeco('V-12.345.678', Icons.badge_outlined, theme)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Teléfono / WhatsApp', style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextFormField(controller: _telefonoCtrl, keyboardType: TextInputType.phone, style: GoogleFonts.mooli(fontSize: 13), decoration: _buildInputDeco('+58 414 1234567', Icons.phone_outlined, theme)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fecha de Nacimiento', style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: _seleccionarFechaNacimiento,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(color: theme.primaryBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.alternate)),
                              child: Row(
                                children: [
                                  Icon(Icons.cake_outlined, size: 17, color: theme.secondaryText),
                                  const SizedBox(width: 6),
                                  Text(
                                    _fechaNacimiento != null ? DateFormat('dd/MM/yyyy').format(_fechaNacimiento!) : 'Seleccionar fecha',
                                    style: GoogleFonts.mooli(fontSize: 12.5, color: _fechaNacimiento != null ? theme.primaryText : theme.secondaryText),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tipo de Sangre', style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _tipoSangre,
                            isDense: true,
                            style: GoogleFonts.mooli(fontSize: 12.5, color: theme.primaryText),
                            decoration: _buildInputDeco('Selecciona', Icons.bloodtype_outlined, theme),
                            items: _tiposSangre.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (val) => setState(() => _tipoSangre = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Correo Electrónico', style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, style: GoogleFonts.mooli(fontSize: 13), decoration: _buildInputDeco('paciente@correo.com', Icons.email_outlined, theme)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ciudad de Origen', style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextFormField(controller: _ciudadCtrl, style: GoogleFonts.mooli(fontSize: 13), decoration: _buildInputDeco('Ej: Valencia, Caracas', Icons.location_city_outlined, theme)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('Paciente foráneo (viaja desde otra ciudad o estado)', style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.w500)),
                  value: _esForaneo,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (val) => setState(() => _esForaneo = val ?? false),
                ),
                const SizedBox(height: 4),

                Text('Antecedentes Médicos / Motivo Inicial', style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _antecedentesCtrl,
                  maxLines: 2,
                  style: GoogleFonts.mooli(fontSize: 12),
                  decoration: _buildInputDeco('Alergias, intervenciones previas, patologías crónicas...', Icons.history_edu_outlined, theme),
                ),
                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('Cancelar', style: GoogleFonts.mooli(color: Colors.grey.shade600)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _guardarPaciente,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isSaving ? 'Guardando...' : 'Crear Paciente', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDeco(String hint, IconData icon, FlutterFlowTheme theme) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.mooli(fontSize: 12, color: theme.secondaryText),
      prefixIcon: Icon(icon, size: 17, color: theme.secondaryText),
      filled: true,
      fillColor: theme.primaryBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.alternate)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.alternate)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
    );
  }
}

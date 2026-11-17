import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/clinical_history_service.dart';
import 'schedule_control_dialog.dart';
import 'medical_print_preview_dialog.dart';
import '../../../services/gemini_ai_service.dart';
import '../../components/doctor_gemini_config_dialog.dart';

/// Modal para registrar órdenes, recetas, reposos médicos o ficha clínica,
/// con modos de llenado por formulario o texto completo en párrafos, y opción de impresión.
class ClinicalHistoryQuickModal extends StatefulWidget {
  final String idDoctor;
  final CitasRow cita;
  final UsuariosRow? paciente;
  final VoidCallback onConsultaFinalizada;
  final String tipoDocumentoInicial;

  const ClinicalHistoryQuickModal({
    super.key,
    required this.idDoctor,
    required this.cita,
    required this.paciente,
    required this.onConsultaFinalizada,
    this.tipoDocumentoInicial = 'receta',
  });

  static Future<void> show(
    BuildContext context, {
    required String idDoctor,
    required CitasRow cita,
    required UsuariosRow? paciente,
    required VoidCallback onConsultaFinalizada,
    String tipoDocumentoInicial = 'receta',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ClinicalHistoryQuickModal(
        idDoctor: idDoctor,
        cita: cita,
        paciente: paciente,
        onConsultaFinalizada: onConsultaFinalizada,
        tipoDocumentoInicial: tipoDocumentoInicial,
      ),
    );
  }

  @override
  State<ClinicalHistoryQuickModal> createState() =>
      _ClinicalHistoryQuickModalState();
}

class _ClinicalHistoryQuickModalState
    extends State<ClinicalHistoryQuickModal> {
  late String _tipoDocumento; // 'receta', 'orden', 'reposo', 'interconsulta'
  final _sintomasCtrl = TextEditingController();
  final _examenCtrl = TextEditingController();
  final _diagCtrl = TextEditingController();
  final _tratCtrl = TextEditingController();
  final _diasReposoCtrl = TextEditingController();
  final _medicamentosCtrl = TextEditingController();
  final _tiempoTratamientoCtrl = TextEditingController();
  final _resumenCompletoCtrl = TextEditingController();
  bool _modoResumen = false;
  String? _plantillaSeleccionada;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tipoDocumento = widget.tipoDocumentoInicial;
  }

  @override
  void dispose() {
    _sintomasCtrl.dispose();
    _examenCtrl.dispose();
    _diagCtrl.dispose();
    _tratCtrl.dispose();
    _diasReposoCtrl.dispose();
    _medicamentosCtrl.dispose();
    _tiempoTratamientoCtrl.dispose();
    _resumenCompletoCtrl.dispose();
    super.dispose();
  }

  String get _tituloSegunTipo {
    switch (_tipoDocumento) {
      case 'orden':
        return 'Orden Médica (Estudios / Lab)';
      case 'reposo':
        return 'Reposo Médico / Permiso';
      case 'interconsulta':
        return 'Interconsulta / Derivación';
      case 'receta':
      default:
        return 'Receta Médica y Ficha';
    }
  }

  Future<void> _procesarGuardado({required bool conImpresion}) async {
    if (widget.cita.idPaciente == null) return;
    setState(() => _isSaving = true);
    try {
      final String sintomasFinal, examenFinal, diagFinal, tratFinal, contenidoParaImprimir;
      if (_modoResumen) {
        final resTexto = _resumenCompletoCtrl.text.trim();
        contenidoParaImprimir = resTexto;
        sintomasFinal = resTexto;
        examenFinal = 'Registrado en texto completo';
        diagFinal = resTexto.isNotEmpty ? resTexto.split('\n').first : (widget.cita.motivo ?? _tituloSegunTipo);
        tratFinal = resTexto;
      } else {
        sintomasFinal = _sintomasCtrl.text.trim();
        examenFinal = _examenCtrl.text.trim();
        diagFinal = _diagCtrl.text.trim().isNotEmpty ? _diagCtrl.text.trim() : (widget.cita.motivo ?? 'Consulta Médica');
        final meds = _medicamentosCtrl.text.trim(), dur = _tiempoTratamientoCtrl.text.trim(), rec = _tratCtrl.text.trim();
        tratFinal = [if (meds.isNotEmpty) 'Medicamentos: $meds', if (dur.isNotEmpty) 'Duración: $dur', if (rec.isNotEmpty) 'Indicaciones: $rec'].join(' | ');
        contenidoParaImprimir = [if (sintomasFinal.isNotEmpty) 'Motivo / Cuadro: $sintomasFinal', if (meds.isNotEmpty) 'Medicamentos: $meds (Tiempo: $dur)', if (rec.isNotEmpty) 'Indicaciones: $rec'].join('\n\n');
      }

      await ClinicalHistoryService().guardarHistoriaClinica(
        idPaciente: widget.cita.idPaciente!, idDoctor: widget.idDoctor, idCita: widget.cita.id,
        motivoConsulta: widget.cita.motivo ?? _tituloSegunTipo, sintomas: sintomasFinal, examenFisico: examenFinal,
        diagnostico: diagFinal, tratamiento: tratFinal, idPlantilla: _plantillaSeleccionada,
        datosAdicionalesJson: {
          'tipo_documento': _tipoDocumento, 'dias_reposo': _diasReposoCtrl.text.trim(),
          'medicamentos': _medicamentosCtrl.text.trim(), 'tiempo_tratamiento': _tiempoTratamientoCtrl.text.trim(),
        },
      );

      await CitasTable().update(data: {'estado': 'atendida'}, matchingRows: (q) => q.eq('id', widget.cita.id));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $_tituloSegunTipo guardado con éxito.'), backgroundColor: Colors.teal));
        widget.onConsultaFinalizada();
        if (conImpresion) {
          MedicalPrintPreviewDialog.show(
            context, tituloDocumento: _tituloSegunTipo, doctorNombre: 'Dr. Médico Tratante', doctorEspecialidad: 'Medicina General',
            pacienteNombre: widget.paciente?.nombre ?? 'Paciente',
            pacienteIdentificacion: widget.paciente?.data['rut']?.toString() ?? widget.paciente?.data['cedula']?.toString(),
            diagnostico: diagFinal, contenidoPrincipal: contenidoParaImprimir.isEmpty ? 'Emisión de $_tituloSegunTipo autorizada.' : contenidoParaImprimir,
            medicamentos: _medicamentosCtrl.text.trim().isNotEmpty ? _medicamentosCtrl.text.trim() : null,
            tiempoTratamiento: _tiempoTratamientoCtrl.text.trim().isNotEmpty ? _tiempoTratamientoCtrl.text.trim() : null,
            diasReposo: _tipoDocumento == 'reposo' ? _diasReposoCtrl.text.trim() : null,
            indicacionesAdicionales: _tratCtrl.text.trim().isNotEmpty ? _tratCtrl.text.trim() : null,
          );
        } else {
          ScheduleControlDialog.show(context, idDoctor: widget.idDoctor, cita: widget.cita, paciente: widget.paciente, onControlAgendado: widget.onConsultaFinalizada);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar documento: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera del modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _tituloSegunTipo,
                    style: GoogleFonts.mooli(fontSize: 16.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                ),
                _buildIaButton(),
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            Text(
              'Paciente: ${widget.paciente?.nombre ?? "Paciente"}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 12),

            // Selector del tipo de documento médico
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDocTypeChip('receta', Icons.description_rounded, 'Receta / Ficha'),
                  const SizedBox(width: 6),
                  _buildDocTypeChip('orden', Icons.science_rounded, 'Orden Médica'),
                  const SizedBox(width: 6),
                  _buildDocTypeChip('reposo', Icons.hotel_rounded, 'Reposo / Permiso'),
                  const SizedBox(width: 6),
                  _buildDocTypeChip('interconsulta', Icons.alt_route_rounded, 'Interconsulta'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Selector de modo de ingreso (Formulario o Texto Completo)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTabOption('Formulario', !_modoResumen, () => setState(() => _modoResumen = false)),
                  _buildTabOption('Texto Completo', _modoResumen, () => setState(() => _modoResumen = true)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Contenido dinámico según el modo
            if (!_modoResumen) ...[
              if (_tipoDocumento == 'reposo') ...[
                TextField(controller: _diasReposoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Días de Reposo / Permiso', hintText: 'Ej: 3', border: OutlineInputBorder())),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _sintomasCtrl, maxLines: 2,
                decoration: InputDecoration(
                  labelText: _tipoDocumento == 'orden' ? 'Estudios Solicitados (Laboratorio / Imágenes)' : (_tipoDocumento == 'interconsulta' ? 'Especialidad y Destino' : 'Motivo y Síntomas'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _diagCtrl, maxLines: 2,
                decoration: InputDecoration(
                  labelText: _tipoDocumento == 'reposo' ? 'Diagnóstico que Justifica el Reposo' : 'Diagnóstico Clínico',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_tipoDocumento == 'receta') ...[
                const SizedBox(height: 10),
                TextField(controller: _medicamentosCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Medicamentos Prescritos (Nombre y Dosis)', hintText: 'Ej: Amoxicilina 875mg cada 12h', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _tiempoTratamientoCtrl, decoration: const InputDecoration(labelText: 'Por cuánto tiempo (Duración)', hintText: 'Ej: 7 días, 10 días', border: OutlineInputBorder())),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _tratCtrl, maxLines: 2,
                decoration: InputDecoration(
                  labelText: _tipoDocumento == 'orden' ? 'Indicaciones para el Laboratorio' : (_tipoDocumento == 'reposo' ? 'Recomendaciones durante el Reposo' : 'Indicaciones Adicionales / Pautas'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ] else ...[
              TextField(
                controller: _resumenCompletoCtrl, maxLines: 6,
                decoration: InputDecoration(labelText: 'Redacción de $_tituloSegunTipo', hintText: 'Escriba las indicaciones, diagnósticos y prescripciones...', alignLabelWithHint: true, border: const OutlineInputBorder()),
              ),
              if (_tipoDocumento == 'receta') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(flex: 3, child: TextField(controller: _medicamentosCtrl, decoration: const InputDecoration(labelText: 'Medicamento(s) prescrito(s)', border: OutlineInputBorder(), isDense: true))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextField(controller: _tiempoTratamientoCtrl, decoration: const InputDecoration(labelText: 'Por cuánto tiempo', border: OutlineInputBorder(), isDense: true))),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 18),

            // Botones de acción: Guardar y Guardar e Imprimir
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0F172A), side: const BorderSide(color: Color(0xFFCBD5E1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      icon: _isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Solo Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _isSaving ? null : () => _procesarGuardado(conImpresion: false),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Guardar e Imprimir', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _isSaving ? null : () => _procesarGuardado(conImpresion: true),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTabOption(String text, bool active, VoidCallback onTap) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: active ? const Color(0xFF0284C7) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: active ? Colors.white : Colors.grey.shade700)),
          ),
        ),
      );

  Widget _buildDocTypeChip(String tipo, IconData icon, String label) {
    final isSelected = _tipoDocumento == tipo;
    return ChoiceChip(
      selected: isSelected,
      selectedColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
      backgroundColor: Colors.grey.shade100,
      avatar: Icon(icon, size: 15, color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B)),
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF334155))),
      onSelected: (val) {
        if (val) setState(() => _tipoDocumento = tipo);
      },
    );
  }

  Widget _buildIaButton() {
    final hasKey = GeminiAiService.instance.hasKey;
    return InkWell(
      onTap: () async {
        if (!hasKey) {
          final res = await DoctorGeminiConfigDialog.show(context);
          if (res == true && mounted) setState(() {});
          return;
        }
        _mostrarOpcionesIa();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: hasKey ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: hasKey ? const Color(0xFF818CF8) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 13, color: hasKey ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(hasKey ? 'Gemini 3.8' : 'IA Apagada',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: hasKey ? const Color(0xFF4F46E5) : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcionesIa() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Text('Asistente IA (Gemini 3.8 Flash)', style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            ListTile(
              dense: true,
              leading: const Icon(Icons.edit_note_rounded, color: Color(0xFF0284C7)),
              title: const Text('Redactar Resumen Clínico con IA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _generarResumenIa();
              },
            ),
            if (_tipoDocumento == 'receta')
              ListTile(
                dense: true,
                leading: const Icon(Icons.medication_rounded, color: Color(0xFF16A34A)),
                title: const Text('Sugerir Medicamentos con IA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sugerirTratamientoIa();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarResumenIa() async {
    final diag = _diagCtrl.text.trim().isNotEmpty ? _diagCtrl.text.trim() : (widget.cita.motivo ?? 'Consulta Médica');
    final sint = _sintomasCtrl.text.trim().isNotEmpty ? _sintomasCtrl.text.trim() : 'Paciente en consulta';
    setState(() => _isSaving = true);
    final res = await GeminiAiService.instance.generateClinicalSummary(sintomas: sint, diagnostico: diag, examen: _examenCtrl.text.trim());
    if (mounted) {
      setState(() => _isSaving = false);
      if (res != null && res.isNotEmpty) {
        if (_modoResumen) {
          _resumenCompletoCtrl.text = res;
        } else {
          _tratCtrl.text = res;
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ Resumen generado con Gemini 3.8.'), backgroundColor: Color(0xFF4F46E5)));
      }
    }
  }

  Future<void> _sugerirTratamientoIa() async {
    final diag = _diagCtrl.text.trim().isNotEmpty ? _diagCtrl.text.trim() : (widget.cita.motivo ?? 'Consulta Médica');
    final sint = _sintomasCtrl.text.trim().isNotEmpty ? _sintomasCtrl.text.trim() : 'Malestar general';
    setState(() => _isSaving = true);
    final sug = await GeminiAiService.instance.suggestPrescription(diagnostico: diag, sintomas: sint);
    if (mounted) {
      setState(() => _isSaving = false);
      if (sug != null) {
        if (sug['medicamentos']!.isNotEmpty) _medicamentosCtrl.text = sug['medicamentos']!;
        if (sug['duracion']!.isNotEmpty) _tiempoTratamientoCtrl.text = sug['duracion']!;
        if (sug['indicaciones']!.isNotEmpty && _tratCtrl.text.isEmpty) _tratCtrl.text = sug['indicaciones']!;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ Sugerencia farmacológica aplicada.'), backgroundColor: Color(0xFF16A34A)));
      }
    }
  }
}

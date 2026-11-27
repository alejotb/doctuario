import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/clinical_history_service.dart';
import '../../../services/doctor_consultation_draft_service.dart';
import '../../../services/doctor_studies_service.dart';
import '../../../services/medical_exam_service.dart';
import '../../components/medical_exam_viewer_dialog.dart';
import '../../doctor_agenda_panel/dialogs/medical_print_preview_dialog.dart';

/// Pestaña 1: Consulta Actual (Atención de Hoy).
/// Permite redactar la evolución médica, diagnosticar, prescribir tratamiento,
/// seleccionar estudios clínicos de la cita, subir resultados al instante y guardar borrador.
class ConsultationActiveTab extends StatefulWidget {
  final String idDoctor;
  final CitasRow cita;
  final UsuariosRow? paciente;
  final VoidCallback onConsultaFinalizada;

  const ConsultationActiveTab({
    super.key,
    required this.idDoctor,
    required this.cita,
    required this.paciente,
    required this.onConsultaFinalizada,
  });

  @override
  State<ConsultationActiveTab> createState() => _ConsultationActiveTabState();
}

class _ConsultationActiveTabState extends State<ConsultationActiveTab> {
  final _motivoCtrl = TextEditingController(), _evolucionCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController(), _tratamientoCtrl = TextEditingController();
  final _paCtrl = TextEditingController(), _fcCtrl = TextEditingController();
  final _tempCtrl = TextEditingController(), _spo2Ctrl = TextEditingController();

  List<String> _estudiosDoctor = [], _estudiosSeleccionados = [];
  List<Map<String, dynamic>> _examenesSubidos = [];
  bool _isLoading = true, _isSavingDraft = false, _isFinalizing = false, _subiendoArchivo = false;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    for (final c in [_motivoCtrl, _evolucionCtrl, _diagnosticoCtrl, _tratamientoCtrl, _paCtrl, _fcCtrl, _tempCtrl, _spo2Ctrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _programarAutoGuardado() {
    if (_isLoading || _isFinalizing) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_isFinalizing) _guardarBorradorManual(mostrarSnack: false);
    });
  }

  void _restaurarSignosVitales(String? signosBorrador) {
    if (signosBorrador != null && signosBorrador.isNotEmpty) {
      for (final p in signosBorrador.split('|')) {
        final t = p.trim();
        if (t.startsWith('PA:')) _paCtrl.text = t.replaceFirst('PA:', '').trim();
        if (t.startsWith('FC:')) _fcCtrl.text = t.replaceFirst('FC:', '').trim();
        if (t.startsWith('T:')) _tempCtrl.text = t.replaceFirst('T:', '').trim();
        if (t.startsWith('SpO2:')) _spo2Ctrl.text = t.replaceFirst('SpO2:', '').trim();
      }
      return;
    }
    final notas = widget.cita.notasMedicas;
    if (notas != null && notas.isNotEmpty) {
      try {
        final d = jsonDecode(notas);
        if (d is Map) {
          _paCtrl.text = d['pa']?.toString() ?? ''; _fcCtrl.text = d['fc']?.toString() ?? '';
          _tempCtrl.text = d['temp']?.toString() ?? ''; _spo2Ctrl.text = d['spo2']?.toString() ?? '';
        }
      } catch (_) {}
    }
  }

  Future<void> _inicializarDatos() async {
    setState(() => _isLoading = true);
    final configs = await DoctorStudiesService.instance.obtenerEstudiosConfigurados(widget.idDoctor);
    final activos = configs.where((c) => c.activo).map((c) => c.titulo).toList();
    _estudiosDoctor = activos.isNotEmpty ? activos : [
      'Hemograma Completo', 'Perfil Lipídico', 'Química Sanguínea',
      'Ecografía Abdominal', 'Radiografía de Tórax', 'Electrocardiograma (ECG)',
    ];

    final borrador = await DoctorConsultationDraftService.instance.obtenerBorrador(widget.cita.id);
    if (borrador != null && borrador.tieneContenido) {
      _motivoCtrl.text = borrador.motivo; _evolucionCtrl.text = borrador.evolucion;
      _diagnosticoCtrl.text = borrador.diagnostico; _tratamientoCtrl.text = borrador.tratamiento;
      _estudiosSeleccionados = List.from(borrador.estudiosSeleccionados);
      _examenesSubidos = List.from(borrador.examenesSubidos);
    } else {
      _motivoCtrl.text = widget.cita.motivo ?? 'Consulta Médica';
    }
    _restaurarSignosVitales(borrador?.signosVitales);

    try {
      final examenesDb = await MedicalExamService().obtenerExamenesPorCita(widget.cita.id);
      for (final ex in examenesDb) {
        if (!_examenesSubidos.any((e) => e['id'] == ex.id)) {
          _examenesSubidos.add({'id': ex.id, 'titulo': ex.titulo ?? 'Estudio', 'tipo_examen': ex.tipoExamen ?? 'General', 'archivo_url': ex.archivoUrl ?? '', 'formato': ex.formato ?? 'pdf'});
          if (ex.tipoExamen != null && !_estudiosSeleccionados.contains(ex.tipoExamen)) _estudiosSeleccionados.add(ex.tipoExamen!);
        }
      }
    } catch (_) {}

    for (final c in [_motivoCtrl, _evolucionCtrl, _diagnosticoCtrl, _tratamientoCtrl, _paCtrl, _fcCtrl, _tempCtrl, _spo2Ctrl]) {
      c.addListener(_programarAutoGuardado);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _guardarBorradorManual({bool mostrarSnack = true}) async {
    if (_isSavingDraft || _isFinalizing) return;
    setState(() => _isSavingDraft = true);
    final vitalsStr = 'PA: ${_paCtrl.text.trim()} | FC: ${_fcCtrl.text.trim()} | T: ${_tempCtrl.text.trim()} | SpO2: ${_spo2Ctrl.text.trim()}';

    await DoctorConsultationDraftService.instance.guardarBorrador(
      idCita: widget.cita.id, idPaciente: widget.cita.idPaciente, idDoctor: widget.idDoctor,
      motivo: _motivoCtrl.text.trim(), evolucion: _evolucionCtrl.text.trim(),
      diagnostico: _diagnosticoCtrl.text.trim(), tratamiento: _tratamientoCtrl.text.trim(),
      signosVitales: vitalsStr, estudiosSeleccionados: _estudiosSeleccionados,
      examenesSubidos: _examenesSubidos,
    );

    if (mounted) {
      setState(() => _isSavingDraft = false);
      if (mostrarSnack) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('💾 Borrador guardado exitosamente. Puedes salir y continuar luego.'),
          backgroundColor: Color(0xFF0284C7), duration: Duration(seconds: 2),
        ));
      }
    }
  }

  Future<void> _subirArchivoParaEstudio(String nombreEstudio) async {
    final pacId = widget.cita.idPaciente;
    if (pacId == null || pacId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay paciente asociado para guardar el examen.')));
      return;
    }

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'dcm', 'dicom'], withData: true,
      );
      if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

      setState(() => _subiendoArchivo = true);
      final file = res.files.first;

      final nuevoExamen = await MedicalExamService().subirExamen(
        idPaciente: pacId, subidoPorUsuarioId: widget.idDoctor, idDoctor: widget.idDoctor, idCita: widget.cita.id,
        titulo: '$nombreEstudio - ${file.name}', tipoExamen: nombreEstudio, fileName: file.name,
        fileBytes: file.bytes!, fechaEstudio: DateTime.now(), estadoInicial: 'revisado',
        notas: 'Realizado en consulta del ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      );

      setState(() {
        _examenesSubidos.add({
          'id': nuevoExamen.id, 'titulo': nuevoExamen.titulo ?? nombreEstudio,
          'tipo_examen': nombreEstudio, 'archivo_url': nuevoExamen.archivoUrl ?? '', 'formato': nuevoExamen.formato ?? 'pdf',
        });
        _subiendoArchivo = false;
      });

      await _guardarBorradorManual(mostrarSnack: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $nombreEstudio subido y vinculado a esta consulta.'), backgroundColor: const Color(0xFF10B981),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _subiendoArchivo = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir examen: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _finalizarConsulta() async {
    final diag = _diagnosticoCtrl.text.trim(), evo = _evolucionCtrl.text.trim(), mot = _motivoCtrl.text.trim();
    if (mot.isEmpty && diag.isEmpty && evo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor ingresa al menos el motivo o diagnóstico de la consulta.'), backgroundColor: Colors.orange,
      ));
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Finalizar Consulta', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
        content: const Text('¿Deseas cerrar y guardar oficialmente esta atención médica? El borrador se consolidará en la historia clínica del paciente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar editando')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar y Finalizar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _isFinalizing = true);
    try {
      final pacId = widget.cita.idPaciente;
      if (pacId != null) {
        final vitalsStr = 'PA: ${_paCtrl.text.trim()} | FC: ${_fcCtrl.text.trim()} | T: ${_tempCtrl.text.trim()} | SpO2: ${_spo2Ctrl.text.trim()}';
        await ClinicalHistoryService().guardarHistoriaClinica(
          idPaciente: pacId, idDoctor: widget.idDoctor, idCita: widget.cita.id,
          motivoConsulta: mot.isNotEmpty ? mot : 'Consulta Médica', sintomas: evo,
          examenFisico: vitalsStr, diagnostico: diag.isNotEmpty ? diag : mot,
          tratamiento: _tratamientoCtrl.text.trim(),
        );
      }

      final docClient = DualDatabaseConfig.instance.doctorClient;
      await docClient.from('citas').update({
        'estado': 'completada', 'es_borrador': false, 'borrador_consulta': null,
        'notas_medicas': _diagnosticoCtrl.text.trim().isNotEmpty ? 'Dx: ${_diagnosticoCtrl.text.trim()}' : null,
      }).eq('id', widget.cita.id);

      await DoctorConsultationDraftService.instance.limpiarBorrador(widget.cita.id);

      if (mounted) {
        setState(() => _isFinalizing = false);
        _mostrarDialogoExitoImpresion();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFinalizing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al finalizar consulta: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _mostrarDialogoExitoImpresion() {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
          const SizedBox(width: 8),
          Text('Consulta Guardada', style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: const Text('La consulta ha sido guardada con éxito en la historia clínica del paciente y los exámenes han sido vinculados a esta fecha.'),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print_rounded, size: 16), label: const Text('Imprimir Récipe'),
            onPressed: () {
              Navigator.pop(ctx);
              MedicalPrintPreviewDialog.show(
                context, tituloDocumento: 'Receta Médica y Plan de Tratamiento', doctorNombre: 'Doctor',
                pacienteNombre: widget.paciente?.nombre ?? 'Paciente',
                contenidoPrincipal: _tratamientoCtrl.text.trim().isNotEmpty ? _tratamientoCtrl.text.trim() : 'Tratamiento indicado.',
                diagnostico: _diagnosticoCtrl.text.trim(), medicamentos: _tratamientoCtrl.text.trim(),
              );
              widget.onConsultaFinalizada();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(ctx); widget.onConsultaFinalizada(); },
            child: const Text('Volver a la Agenda'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(20), children: [_buildSeccionClinica(), const SizedBox(height: 20), _buildSeccionEstudios(), const SizedBox(height: 24), _buildBarraAccionesInferior()]);
  }

  Widget _buildSeccionClinica() => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.medical_information_rounded, color: Color(0xFF0284C7), size: 20), const SizedBox(width: 8), Text('Evolución y Diagnóstico de Hoy', style: GoogleFonts.mooli(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)))]),
        const SizedBox(height: 14),
        _buildInput('Motivo de Consulta', _motivoCtrl, 'Ej: Dolor abdominal recurrente, fiebre...', maxLines: 1),
        const SizedBox(height: 10),
        _buildInput('Evolución / Síntomas Actuales', _evolucionCtrl, 'Descripción del estado del paciente en la consulta de hoy...', maxLines: 3),
        const SizedBox(height: 10),
        _buildInput('Diagnóstico', _diagnosticoCtrl, 'Ej: Gastroenteritis aguda, Hipertensión arterial...', maxLines: 2),
        const SizedBox(height: 10),
        _buildInput('Tratamiento / Récipe Médico / Indicaciones', _tratamientoCtrl, 'Medicamentos, dosis, frecuencia y cuidados indicados...', maxLines: 4),
      ]),
    );

  Widget _buildSeccionEstudios() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE6FD)),
        boxShadow: [BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.biotech_rounded, color: Color(0xFF0D9488), size: 20),
                const SizedBox(width: 8),
                Text('Estudios y Exámenes de ESTA Consulta', style: GoogleFonts.mooli(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              ]),
              if (_subiendoArchivo) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Selecciona los estudios de esta cita y sube los resultados directamente para vincularlos.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _estudiosDoctor.map((est) {
              final sel = _estudiosSeleccionados.any((e) => e.toLowerCase() == est.toLowerCase());
              final yaSubido = _examenesSubidos.any(
                (e) =>
                    (e['tipo_examen']?.toString().toLowerCase() == est.toLowerCase()) ||
                    (e['titulo']?.toString().toLowerCase().contains(est.toLowerCase()) ?? false),
              );
              return FilterChip(
                label: Text(
                  yaSubido ? '$est (Ya agregado)' : est,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: (sel || yaSubido) ? FontWeight.bold : FontWeight.normal,
                    color: yaSubido
                        ? const Color(0xFF15803D)
                        : (sel ? const Color(0xFF0369A1) : const Color(0xFF334155)),
                  ),
                ),
                selected: sel || yaSubido,
                selectedColor: yaSubido ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE),
                backgroundColor: const Color(0xFFF8FAFC),
                checkmarkColor: yaSubido ? const Color(0xFF15803D) : const Color(0xFF0284C7),
                side: BorderSide(
                  color: yaSubido
                      ? const Color(0xFF86EFAC)
                      : (sel ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1)),
                ),
                onSelected: yaSubido
                    ? null
                    : (val) {
                        setState(() {
                          if (val) {
                            if (!_estudiosSeleccionados.any((e) => e.toLowerCase() == est.toLowerCase())) {
                              _estudiosSeleccionados.add(est);
                            }
                          } else {
                            _estudiosSeleccionados.removeWhere((e) => e.toLowerCase() == est.toLowerCase());
                          }
                        });
                        _guardarBorradorManual(mostrarSnack: false);
                      },
              );
            }).toList(),
          ),
          if (_estudiosSeleccionados.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 6),
            Text('Estudios elegidos para esta cita:', style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 8),
            Column(
              children: _estudiosSeleccionados.map((est) {
                final subido = _examenesSubidos.where((e) => e['tipo_examen'] == est || (e['titulo'] as String? ?? '').contains(est)).toList();
                final tieneArchivo = subido.isNotEmpty;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: tieneArchivo ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tieneArchivo ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(tieneArchivo ? Icons.task_alt_rounded : Icons.pending_actions_rounded, size: 18, color: tieneArchivo ? const Color(0xFF16A34A) : const Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(est, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(tieneArchivo ? 'Archivo adjunto vinculado a esta cita' : 'Pendiente por subir resultado', style: TextStyle(fontSize: 11, color: tieneArchivo ? const Color(0xFF15803D) : Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      if (tieneArchivo) ...[
                        IconButton(
                          tooltip: 'Previsualizar examen',
                          icon: const Icon(Icons.visibility_rounded, size: 18, color: Color(0xFF0284C7)),
                          onPressed: () => MedicalExamViewerDialog.show(
                            context,
                            examen: ExamenesMedicosRow({
                              'id': subido.first['id'],
                              'titulo': subido.first['titulo'],
                              'tipo_examen': subido.first['tipo_examen'],
                              'archivo_url': subido.first['archivo_url'],
                              'formato': subido.first['formato'],
                              'created_at': DateTime.now().toUtc().toIso8601String(),
                            }),
                            paciente: widget.paciente,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cambiar archivo',
                          icon: const Icon(Icons.upload_file_rounded, size: 18, color: Color(0xFF64748B)),
                          onPressed: () => _subirArchivoParaEstudio(est),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          icon: const Icon(Icons.attach_file_rounded, size: 14),
                          label: const Text('Subir Resultado'),
                          onPressed: () => _subirArchivoParaEstudio(est),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBarraAccionesInferior() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: Color(0xFF0284C7)),
              foregroundColor: const Color(0xFF0284C7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isSavingDraft
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSavingDraft ? 'Guardando...' : 'Guardar Borrador', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _guardarBorradorManual(mostrarSnack: true),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isFinalizing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.done_all_rounded, size: 20),
            label: Text(_isFinalizing ? 'Finalizando...' : 'Guardar y Finalizar Consulta', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onPressed: _finalizarConsulta,
          ),
        ),
      ],
    );
  }

  Widget _buildInput(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
        const SizedBox(height: 4),
        TextField(
          controller: controller, maxLines: maxLines, style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint, hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
          onChanged: (_) => _guardarBorradorManual(mostrarSnack: false),
        ),
      ],
    );
  }
}

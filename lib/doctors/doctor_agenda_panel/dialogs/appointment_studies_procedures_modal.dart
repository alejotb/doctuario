import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/emergency_appointment_service.dart';
import '../../../services/medical_exam_service.dart';
import '../../../services/doctor_studies_service.dart';
import '../../components/doctor_studies_config_dialog.dart';

/// Modelo para un procedimiento o estudio seleccionado en la consulta
class ProcedimientoEstudioItem {
  final String titulo;
  final String categoria;
  final int duracionMinutos;
  PlatformFile? archivo;
  bool subido = false;
  bool subiendo = false;

  ProcedimientoEstudioItem({
    required this.titulo,
    required this.categoria,
    required this.duracionMinutos,
    this.archivo,
    this.subido = false,
    this.subiendo = false,
  });
}

/// Modal que permite al doctor o secretaria agregar estudios/procedimientos
/// a la cita actual, recalcular en cascada los horarios de las citas siguientes
/// y subir de forma inmediata los documentos de cada estudio con su título exacto.
class AppointmentStudiesProceduresModal extends StatefulWidget {
  final CitasRow cita;
  final UsuariosRow? paciente;
  final String idDoctor;
  final String idUsuarioOperador;
  final VoidCallback onHorariosRecalculados;

  const AppointmentStudiesProceduresModal({
    super.key,
    required this.cita,
    required this.paciente,
    required this.idDoctor,
    required this.idUsuarioOperador,
    required this.onHorariosRecalculados,
  });

  static Future<void> show(
    BuildContext context, {
    required CitasRow cita,
    required UsuariosRow? paciente,
    required String idDoctor,
    required String idUsuarioOperador,
    required VoidCallback onHorariosRecalculados,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppointmentStudiesProceduresModal(
        cita: cita,
        paciente: paciente,
        idDoctor: idDoctor,
        idUsuarioOperador: idUsuarioOperador,
        onHorariosRecalculados: onHorariosRecalculados,
      ),
    );
  }

  @override
  State<AppointmentStudiesProceduresModal> createState() =>
      _AppointmentStudiesProceduresModalState();
}

class _AppointmentStudiesProceduresModalState
    extends State<AppointmentStudiesProceduresModal> {
  List<DoctorEstudioConfig> _estudiosDisponibles = [];
  bool _cargandoEstudios = true;

  final List<ProcedimientoEstudioItem> _seleccionados = [];
  bool _recalculandoHorarios = false;
  bool _horariosYaRecalculados = false;
  int _totalMinutosAgregados = 0;

  @override
  void initState() {
    super.initState();
    _cargarEstudiosDelDoctor();
  }

  Future<void> _cargarEstudiosDelDoctor() async {
    final activos = await DoctorStudiesService.instance.obtenerEstudiosActivos(widget.idDoctor);
    final yaRegistrados = await MedicalExamService().obtenerExamenesPorCita(widget.cita.id);
    if (mounted) {
      setState(() {
        _estudiosDisponibles = activos;
        for (final ex in yaRegistrados) {
          final tituloEx = (ex.titulo ?? ex.tipoExamen ?? '').trim();
          if (tituloEx.isEmpty) continue;
          final yaEnLista = _seleccionados.any(
            (item) => item.titulo.toLowerCase() == tituloEx.toLowerCase(),
          );
          if (!yaEnLista) {
            final matchConfig = activos.where((c) => c.titulo.toLowerCase() == tituloEx.toLowerCase()).toList();
            _seleccionados.add(ProcedimientoEstudioItem(
              titulo: matchConfig.isNotEmpty ? matchConfig.first.titulo : tituloEx,
              categoria: matchConfig.isNotEmpty ? matchConfig.first.categoria : (ex.tipoExamen ?? 'Estudio Médico'),
              duracionMinutos: matchConfig.isNotEmpty ? matchConfig.first.duracionMinutos : 0,
              subido: true,
            ));
          }
        }
        _cargandoEstudios = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pacienteNombre = widget.paciente?.nombre ?? 'Paciente';

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.biotech_rounded, color: Color(0xFF0284C7), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estudios y Procedimientos', style: GoogleFonts.mooli(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('Paciente: $pacienteNombre', style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Configurar mis estudios habituales',
                      icon: const Icon(Icons.tune_rounded, color: Color(0xFF0284C7), size: 20),
                      onPressed: () async {
                        await DoctorStudiesConfigDialog.show(context, idDoctor: widget.idDoctor);
                        _cargarEstudiosDelDoctor();
                      },
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Selecciona los estudios a realizar en esta consulta:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                InkWell(
                  onTap: () async {
                    await DoctorStudiesConfigDialog.show(context, idDoctor: widget.idDoctor);
                    _cargarEstudiosDelDoctor();
                  },
                  child: const Text('Editar lista', style: TextStyle(fontSize: 11.5, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_cargandoEstudios)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _estudiosDisponibles.map((p) {
                  final String titulo = p.titulo;
                  final int minutos = p.duracionMinutos;
                  final IconData icono = p.icono ?? Icons.biotech_rounded;
                  final existente = _seleccionados.where((item) => item.titulo.toLowerCase() == titulo.toLowerCase()).toList();
                  final bool estaSeleccionado = existente.isNotEmpty;
                  final bool yaSubido = estaSeleccionado && existente.first.subido;

                  return FilterChip(
                    avatar: Icon(
                      yaSubido ? Icons.task_alt_rounded : icono,
                      size: 16,
                      color: yaSubido
                          ? const Color(0xFF15803D)
                          : (estaSeleccionado ? Colors.white : const Color(0xFF0284C7)),
                    ),
                    label: Text(
                      yaSubido ? '$titulo (Ya agregado)' : '$titulo (+$minutos min)',
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: estaSeleccionado ? FontWeight.bold : FontWeight.normal,
                      color: yaSubido
                          ? const Color(0xFF15803D)
                          : (estaSeleccionado ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    selected: estaSeleccionado,
                    selectedColor: yaSubido ? const Color(0xFFDCFCE7) : const Color(0xFF0284C7),
                    backgroundColor: const Color(0xFFF1F5F9),
                    checkmarkColor: yaSubido ? const Color(0xFF15803D) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: yaSubido
                        ? null
                        : (bool selected) {
                            setState(() {
                              if (selected) {
                                if (!_seleccionados.any((item) => item.titulo.toLowerCase() == titulo.toLowerCase())) {
                                  _seleccionados.add(ProcedimientoEstudioItem(titulo: titulo, categoria: p.categoria, duracionMinutos: minutos));
                                }
                              } else {
                                _seleccionados.removeWhere((item) => item.titulo.toLowerCase() == titulo.toLowerCase());
                              }
                              _totalMinutosAgregados = _seleccionados
                                  .where((item) => !item.subido)
                                  .fold(0, (acc, item) => acc + item.duracionMinutos);
                            });
                          },
                  );
                }).toList(),
              ),

            const SizedBox(height: 16),

            if (_seleccionados.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _horariosYaRecalculados ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _horariosYaRecalculados ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_horariosYaRecalculados ? Icons.check_circle_rounded : Icons.schedule_rounded, color: _horariosYaRecalculados ? const Color(0xFF059669) : const Color(0xFFB45309), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _horariosYaRecalculados
                                ? '✅ Horarios recalculados: +$_totalMinutosAgregados min añadidos a las siguientes citas.'
                                : '⏱️ Tiempo extra estimado: +$_totalMinutosAgregados min en esta consulta.',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _horariosYaRecalculados ? const Color(0xFF065F46) : const Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_horariosYaRecalculados)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _recalculandoHorarios ? null : _ejecutarRecalculoCascada,
                          icon: _recalculandoHorarios
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.sync_rounded, size: 16),
                          label: const Text('Recalcular y Desplazar Horarios Siguientes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Subir Documentos / Resultados por Estudio:', style: GoogleFonts.mooli(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              const SizedBox(height: 10),
              ..._seleccionados.map((item) => _buildCardSubidaEstudio(item)),
            ],

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar Ventana', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ejecutarRecalculoCascada() async {
    if (_totalMinutosAgregados <= 0) return;
    setState(() => _recalculandoHorarios = true);

    try {
      final nombres = _seleccionados.map((e) => e.titulo).toList();
      final desplazadas = await EmergencyAppointmentService().aplicarRetrasoPorProcedimiento(
        idDoctor: widget.idDoctor,
        idCitaActual: widget.cita.id,
        minutosExtra: _totalMinutosAgregados,
        nombresProcedimientos: nombres,
      );

      if (mounted) {
        setState(() {
          _recalculandoHorarios = false;
          _horariosYaRecalculados = true;
        });
        widget.onHorariosRecalculados();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Se extendió la cita y se desplazaron $desplazadas cita(s) siguientes.'), backgroundColor: const Color(0xFF059669)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _recalculandoHorarios = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al recalcular horarios: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildCardSubidaEstudio(ProcedimientoEstudioItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.subido ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.subido ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(item.subido ? Icons.task_alt_rounded : Icons.description_outlined, color: item.subido ? const Color(0xFF16A34A) : const Color(0xFF0284C7), size: 18),
                  const SizedBox(width: 8),
                  Text(item.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                ],
              ),
              if (item.subido)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Subido', style: TextStyle(color: Color(0xFF15803D), fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Categoría: ${item.categoria}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 8),

          if (item.subido)
            Text('✅ Archivo registrado en la ficha del paciente.', style: TextStyle(fontSize: 11, color: Colors.green.shade800))
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () => _seleccionarArchivoParaEstudio(item),
                    icon: const Icon(Icons.attach_file_rounded, size: 15),
                    label: Text(item.archivo == null ? 'Adjuntar PDF / Foto' : item.archivo!.name, style: const TextStyle(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (item.archivo != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: item.subiendo ? null : () => _subirDocumentoDeEstudio(item),
                    icon: item.subiendo
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.cloud_upload_rounded, size: 15),
                    label: const Text('Subir', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _seleccionarArchivoParaEstudio(ProcedimientoEstudioItem item) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'], withData: true);
    if (result != null && result.files.isNotEmpty && result.files.first.bytes != null) {
      setState(() => item.archivo = result.files.first);
    }
  }

  Future<void> _subirDocumentoDeEstudio(ProcedimientoEstudioItem item) async {
    if (widget.cita.idPaciente == null || item.archivo == null || item.archivo!.bytes == null) return;
    setState(() => item.subiendo = true);

    try {
      final bytes = item.archivo!.bytes as Uint8List;
      await MedicalExamService().subirExamen(
        idPaciente: widget.cita.idPaciente!,
        subidoPorUsuarioId: widget.idUsuarioOperador,
        idDoctor: widget.idDoctor,
        idCita: widget.cita.id,
        titulo: item.titulo,
        tipoExamen: item.categoria,
        fileName: item.archivo!.name,
        fileBytes: bytes,
        notas: 'Estudio realizado durante la consulta médica presencial.',
        estadoInicial: 'por_revisar',
        compartirConPaciente: true,
      );

      if (mounted) {
        setState(() {
          item.subiendo = false;
          item.subido = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${item.titulo} guardado y subido correctamente.'), backgroundColor: const Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => item.subiendo = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error subiendo documento: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

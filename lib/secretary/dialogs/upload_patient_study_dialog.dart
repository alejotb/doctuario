import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/supabase/supabase.dart';
import '../../services/medical_exam_service.dart';
import '../../services/venezuela_locations.dart';

/// Modal dialog for selecting a patient, picking specific study category and name, and uploading file with status 'por_revisar'.
class UploadPatientStudyDialog extends StatefulWidget {
  final String idSecretaria;
  final String? idDoctor;
  final VoidCallback? onExamenSubido;

  const UploadPatientStudyDialog({
    super.key,
    required this.idSecretaria,
    this.idDoctor,
    this.onExamenSubido,
  });

  static Future<void> show({
    required BuildContext context,
    required String idSecretaria,
    String? idDoctor,
    VoidCallback? onExamenSubido,
  }) => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => UploadPatientStudyDialog(
      idSecretaria: idSecretaria,
      idDoctor: idDoctor,
      onExamenSubido: onExamenSubido,
    ),
  );

  @override
  State<UploadPatientStudyDialog> createState() => _UploadPatientStudyDialogState();
}

class _UploadPatientStudyDialogState extends State<UploadPatientStudyDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _tituloOtroCtrl = TextEditingController();
  final TextEditingController _notasCtrl = TextEditingController();
  final TextEditingController _correoFamiliarCtrl = TextEditingController();

  List<UsuariosRow> _pacientesEncontrados = [];
  UsuariosRow? _pacienteSeleccionado;
  bool _buscando = false;
  PlatformFile? _archivoSeleccionado;
  late String _categoriaSeleccionada;
  String? _estudioEspecificoSeleccionado;
  bool _esOtroEstudioPersonalizado = false;
  bool _guardando = false;
  bool _compartirConPaciente = true;

  @override
  void initState() {
    super.initState();
    final categorias = MedicalExamService.catalogoEstudiosPorTipo.keys.toList();
    _categoriaSeleccionada = categorias.first;
    final estudios = MedicalExamService.catalogoEstudiosPorTipo[_categoriaSeleccionada] ?? [];
    if (estudios.isNotEmpty) _estudioEspecificoSeleccionado = estudios.first;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tituloOtroCtrl.dispose();
    _notasCtrl.dispose();
    _correoFamiliarCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarPacientes(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (mounted) setState(() => _pacientesEncontrados = []);
      return;
    }
    setState(() => _buscando = true);
    try {
      final docClient = DualDatabaseConfig.instance.doctorClient;
      final qNorm = VenezuelaLocations.normalize(q);
      final Map<String, UsuariosRow> merged = {};
      bool matchesRow(UsuariosRow r) =>
          VenezuelaLocations.containsIgnoreAccents(r.nombre, qNorm) ||
          VenezuelaLocations.containsIgnoreAccents(r.cedula, qNorm) ||
          VenezuelaLocations.containsIgnoreAccents(r.telefono, qNorm);

      try {
        final resPac = await docClient.from('pacientes').select().limit(120);
        for (final d in (resPac as List)) {
          final r = UsuariosRow(Map<String, dynamic>.from(d));
          if (matchesRow(r)) {
            merged[r.id] = r;
            if (merged.length >= 10) break;
          }
        }
      } catch (_) {}

      try {
        final resUsr = await docClient.from('usuarios').select().limit(120);
        for (final d in (resUsr as List)) {
          final r = UsuariosRow(Map<String, dynamic>.from(d));
          if (matchesRow(r) && !merged.containsKey(r.id)) {
            merged[r.id] = r;
            if (merged.length >= 12) break;
          }
        }
      } catch (_) {}

      if (mounted) setState(() { _pacientesEncontrados = merged.values.take(10).toList(); _buscando = false; });
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty && result.files.first.bytes != null) {
      setState(() => _archivoSeleccionado = result.files.first);
    }
  }

  Future<void> _subirEstudio() async {
    if (_pacienteSeleccionado == null) {
      _mostrarAlerta('Por favor selecciona un paciente.');
      return;
    }
    if (_archivoSeleccionado == null || _archivoSeleccionado!.bytes == null) {
      _mostrarAlerta('Debes adjuntar un archivo (PDF o Imagen).');
      return;
    }

    String tituloFinal = _estudioEspecificoSeleccionado ?? 'Estudio Clínico';
    if (_esOtroEstudioPersonalizado) {
      final custom = _tituloOtroCtrl.text.trim();
      if (custom.isEmpty) {
        _mostrarAlerta('Ingresa el nombre específico del estudio.');
        return;
      }
      tituloFinal = custom;
    }

    setState(() => _guardando = true);
    try {
      final bytes = _archivoSeleccionado!.bytes as Uint8List;
      await MedicalExamService().subirExamen(
        idPaciente: _pacienteSeleccionado!.id,
        subidoPorUsuarioId: widget.idSecretaria,
        idDoctor: widget.idDoctor,
        titulo: tituloFinal,
        tipoExamen: _categoriaSeleccionada,
        fileName: _archivoSeleccionado!.name,
        fileBytes: bytes,
        notas: _notasCtrl.text.trim().isNotEmpty ? _notasCtrl.text.trim() : null,
        estadoInicial: 'por_revisar',
        compartirConPaciente: _compartirConPaciente,
        correoFamiliar: _correoFamiliarCtrl.text.trim().isNotEmpty ? _correoFamiliarCtrl.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Estudio registrado con estatus "Por revisar".'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onExamenSubido?.call();
      }
    } catch (e) {
      _mostrarAlerta('Error al subir el estudio: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarAlerta(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(mensaje), backgroundColor: const Color(0xFFEF4444)),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const Divider(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPacienteSelectorSection(),
                      const SizedBox(height: 14),
                      _buildEstudioSelectionSection(),
                      const SizedBox(height: 14),
                      _buildFileAttachmentSection(),
                      const SizedBox(height: 14),
                      _buildSharingConfigSection(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.upload_file_rounded, color: Color(0xFF0284C7), size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subir Estudio del Paciente', style: GoogleFonts.mooli(fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Selecciona el estudio (quedará por revisar)', style: GoogleFonts.mooli(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
        IconButton(onPressed: _guardando ? null : () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
      ],
    );
  }

  Widget _buildPacienteSelectorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('1. Seleccionar Paciente', style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (_pacienteSeleccionado != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_pacienteSeleccionado!.nombre ?? 'Sin nombre', style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('CI: ${_pacienteSeleccionado!.cedula ?? "N/D"} | Tel: ${_pacienteSeleccionado!.telefono ?? "N/D"}',
                          style: GoogleFonts.mooli(fontSize: 11, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                TextButton(onPressed: () => setState(() => _pacienteSeleccionado = null), child: const Text('Cambiar', style: TextStyle(fontSize: 12))),
              ],
            ),
          )
        else ...[
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar paciente por nombre o cédula...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _buscando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: _buscarPacientes,
          ),
          if (_pacientesEncontrados.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _pacientesEncontrados.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final p = _pacientesEncontrados[idx];
                  return ListTile(
                    dense: true,
                    title: Text(p.nombre ?? 'Sin nombre', style: GoogleFonts.mooli(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('CI: ${p.cedula ?? "N/D"} • ${p.telefono ?? "N/D"}', style: const TextStyle(fontSize: 11)),
                    onTap: () => setState(() { _pacienteSeleccionado = p; _pacientesEncontrados = []; _searchCtrl.clear(); }),
                  );
                },
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildEstudioSelectionSection() {
    final categorias = MedicalExamService.catalogoEstudiosPorTipo.keys.toList();
    final estudiosDisponibles = MedicalExamService.catalogoEstudiosPorTipo[_categoriaSeleccionada] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('2. Clasificación del Estudio Realizado', style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _categoriaSeleccionada,
          decoration: InputDecoration(
            labelText: 'Tipo de Estudio (Categoría)',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: categorias.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.mooli(fontSize: 12)))).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _categoriaSeleccionada = val;
                final lista = MedicalExamService.catalogoEstudiosPorTipo[val] ?? [];
                _estudioEspecificoSeleccionado = lista.isNotEmpty ? lista.first : null;
                _esOtroEstudioPersonalizado = _estudioEspecificoSeleccionado?.startsWith('Otro') ?? false;
              });
            }
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey(_categoriaSeleccionada),
          initialValue: _estudioEspecificoSeleccionado,
          decoration: InputDecoration(
            labelText: 'Estudio Específico Realizado *',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: estudiosDisponibles.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.mooli(fontSize: 12)))).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _estudioEspecificoSeleccionado = val;
                _esOtroEstudioPersonalizado = val.startsWith('Otro');
              });
            }
          },
        ),
        if (_esOtroEstudioPersonalizado) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _tituloOtroCtrl,
            decoration: InputDecoration(
              labelText: 'Especifica el Nombre del Estudio *',
              hintText: 'Ej. Panel Alergénico, Resonancia de Rodilla...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _notasCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Notas u Observaciones Iniciales (Opcional)',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildFileAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('3. Archivo Adjunto (PDF o Imagen)', style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _seleccionarArchivo,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _archivoSeleccionado != null ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: _archivoSeleccionado != null
                ? Row(
                    children: [
                      Icon(
                        _archivoSeleccionado!.extension?.toLowerCase() == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                        color: const Color(0xFF0284C7),
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_archivoSeleccionado!.name} (${((_archivoSeleccionado!.size) / 1024).toStringAsFixed(1)} KB)',
                          style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.edit, size: 16, color: Colors.grey),
                    ],
                  )
                : Column(
                    children: [
                      const Icon(Icons.cloud_upload_outlined, size: 28, color: Color(0xFF0284C7)),
                      const SizedBox(height: 4),
                      Text('Seleccionar archivo (PDF, JPG, PNG)',
                          style: GoogleFonts.mooli(fontSize: 12, color: const Color(0xFF334155), fontWeight: FontWeight.w500)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharingConfigSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('¿Compartir con el paciente?', style: GoogleFonts.mooli(fontSize: 12.5, fontWeight: FontWeight.w600)),
              Switch(
                value: _compartirConPaciente,
                activeThumbColor: const Color(0xFF0284C7),
                onChanged: (v) => setState(() => _compartirConPaciente = v),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('Asocia correo de familiar/tutor si es un paciente sin correo:',
              style: GoogleFonts.mooli(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TextField(
            controller: _correoFamiliarCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Correo familiar / tutor responsable',
              hintText: 'ej. tutor@correo.com',
              prefixIcon: const Icon(Icons.family_restroom, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.mooli(color: Colors.grey.shade700, fontSize: 13))),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _guardando ? null : _subirEstudio,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: _guardando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check_rounded, color: Colors.white, size: 16),
          label: Text(_guardando ? 'Subiendo...' : 'Guardar (Por Revisar)', style: GoogleFonts.mooli(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }
}

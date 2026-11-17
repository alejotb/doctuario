import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/services/gemini_ai_service.dart';
import '/services/i18n_service.dart';
import '/services/patient_import_service.dart';
import 'doctor_gemini_config_dialog.dart';

/// Modal interactivo de importación masiva de pacientes para la Suite Médica.
///
/// Soporta archivos CSV y documentos Word (.docx) mediante Gemini 3.8 Flash.
/// Muestra tabla de previsualización antes de guardar en la base de datos privada.
class DoctorPatientImportDialog extends StatefulWidget {
  const DoctorPatientImportDialog({
    super.key,
    required this.idDoctor,
  });

  final String idDoctor;

  static Future<bool?> show(BuildContext context, {required String idDoctor}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DoctorPatientImportDialog(idDoctor: idDoctor),
    );
  }

  @override
  State<DoctorPatientImportDialog> createState() =>
      _DoctorPatientImportDialogState();
}

class _DoctorPatientImportDialogState extends State<DoctorPatientImportDialog> {
  final List<ImportedPatientItem> _pacientesExtraidos = [];
  bool _isProcessing = false;
  bool _isSaving = false;
  String _currentStepText = '';
  double _progressValue = 0.0;

  @override
  void initState() {
    super.initState();
    GeminiAiService.instance.init();
  }

  Future<void> _seleccionarArchivos() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'docx'],
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _progressValue = 0.0;
      _currentStepText = 'Iniciando lectura de archivos...';
    });

    final files = result.files;
    final total = files.length;

    for (int i = 0; i < total; i++) {
      final file = files[i];
      final ext = (file.extension ?? '').toLowerCase();
      final bytes = file.bytes;

      setState(() {
        _progressValue = (i + 1) / total;
        _currentStepText = 'Procesando (${i + 1}/$total): ${file.name}';
      });

      if (bytes == null) continue;

      if (ext == 'csv' || ext == 'txt') {
        final text = String.fromCharCodes(bytes);
        if (ext == 'csv') {
          final items = PatientImportService.instance.parseCsvData(text, file.name);
          _pacientesExtraidos.addAll(items);
        } else {
          // Si es TXT, si tiene Gemini se extrae con IA
          if (GeminiAiService.instance.hasKey) {
            final item = await PatientImportService.instance
                .parseDocumentWithGemini(filename: file.name, textContent: text);
            _pacientesExtraidos.add(item);
          }
        }
      } else if (ext == 'docx') {
        final docText = PatientImportService.instance.extractTextFromDocx(bytes);
        if (GeminiAiService.instance.hasKey) {
          final item = await PatientImportService.instance
              .parseDocumentWithGemini(filename: file.name, textContent: docText);
          _pacientesExtraidos.add(item);
          // Pausa preventiva de 1.5s para respetar cuota gratuita
          await Future.delayed(const Duration(milliseconds: 1500));
        } else {
          _pacientesExtraidos.add(
            ImportedPatientItem(
              sourceFile: file.name,
              errorMessage:
                  'Requiere clave de Gemini 3.8 Flash para leer Word (.docx).',
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _currentStepText = '';
      });
    }
  }

  Future<void> _abrirConfigGemini() async {
    await DoctorGeminiConfigDialog.show(context);
    setState(() {});
  }

  Future<void> _guardarEnBasePrivada() async {
    if (_pacientesExtraidos.isEmpty) return;
    setState(() => _isSaving = true);

    final resultado = await PatientImportService.instance.insertPatientsBatch(
      idDoctor: widget.idDoctor,
      patients: _pacientesExtraidos,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      final insertados = resultado['insertados'] ?? 0;
      final isEs = I18nService.instance.isSpanish;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEs
                ? '¡Éxito! Se importaron $insertados pacientes a tu consultorio.'
                : 'Success! $insertados patients imported to your clinic.',
            style: GoogleFonts.mooli(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.isSpanish;
    final hasGemini = GeminiAiService.instance.hasKey;
    final validos = _pacientesExtraidos.where((p) => p.isValid).length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      backgroundColor: theme.secondaryBackground,
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: const Icon(Icons.drive_folder_upload_rounded,
                color: Color(0xFF0284C7), size: 24.0),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? 'Importar Pacientes' : 'Import Patients',
                  style: theme.titleMedium.override(
                    font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Archivos Excel (CSV) y Word (.docx)',
                  style: GoogleFonts.mooli(
                    fontSize: 12.0,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600.0,
        height: 480.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasGemini) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Color(0xFF4F46E5), size: 22.0),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        isEs
                            ? 'Para leer documentos Word (.docx) con historias clínicas, configura tu clave de Gemini 3.8 Flash (o hazlo desde tu Perfil).'
                            : 'To read Word (.docx) documents, configure your Gemini 3.8 Flash key (or configure it in Profile).',
                        style: GoogleFonts.mooli(
                          fontSize: 12.0,
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _abrirConfigGemini,
                      child: Text(
                        isEs ? 'Configurar' : 'Configure',
                        style: GoogleFonts.mooli(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12.0),
            ],
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _seleccionarArchivos,
                  icon: const Icon(Icons.folder_open_rounded, size: 18.0),
                  label: Text(
                    isEs ? 'Seleccionar Archivos' : 'Select Files',
                    style: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Text(
                  _pacientesExtraidos.isNotEmpty
                      ? '$validos pacientes listos'
                      : 'Formatos: .csv, .docx, .txt',
                  style: GoogleFonts.mooli(
                    fontSize: 12.5,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 12.0),
              LinearProgressIndicator(
                value: _progressValue,
                backgroundColor: theme.alternate,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
              ),
              const SizedBox(height: 6.0),
              Text(
                _currentStepText,
                style: GoogleFonts.mooli(
                  fontSize: 12.0,
                  color: theme.secondaryText,
                ),
              ),
            ],
            const SizedBox(height: 12.0),
            Expanded(
              child: _pacientesExtraidos.isEmpty
                  ? Center(
                      child: Text(
                        isEs
                            ? 'No has cargado archivos aún.\nSelecciona tu archivo de Excel (.csv) o carpetas con documentos Word.'
                            : 'No files loaded yet.\nSelect your Excel (.csv) or Word documents.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.mooli(
                          color: theme.secondaryText,
                          fontSize: 13.0,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _pacientesExtraidos.length,
                      separatorBuilder: (_, __) => const Divider(height: 1.0),
                      itemBuilder: (context, index) {
                        final item = _pacientesExtraidos[index];
                        final isOk = item.isValid;

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isOk
                                ? Icons.check_circle_rounded
                                : Icons.warning_amber_rounded,
                            color: isOk ? Colors.green : Colors.orange,
                            size: 20.0,
                          ),
                          title: Text(
                            item.nombre ?? 'Sin nombre detectado',
                            style: GoogleFonts.mooli(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          subtitle: Text(
                            'Cédula: ${item.cedula ?? "N/A"} | Tlf: ${item.telefono ?? "N/A"} (${item.sourceFile})',
                            style: GoogleFonts.mooli(
                              fontSize: 11.5,
                              color: theme.secondaryText,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18.0),
                            onPressed: () {
                              setState(() {
                                _pacientesExtraidos.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            isEs ? 'Cancelar' : 'Cancel',
            style: GoogleFonts.mooli(color: Colors.grey.shade600),
          ),
        ),
        ElevatedButton(
          onPressed:
              _isSaving || validos == 0 ? null : _guardarEnBasePrivada,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16.0,
                  height: 16.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  isEs
                      ? 'Importar $validos Pacientes'
                      : 'Import $validos Patients',
                  style: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}

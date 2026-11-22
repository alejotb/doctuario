import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../backend/supabase/supabase.dart';
import '../flutter_flow/flutter_flow_theme.dart';
import '../services/doctor_subscription_service.dart';
import '../services/medical_exam_service.dart';
import '../services/venezuela_locations.dart';

class PatientExamsWidget extends StatefulWidget {
  final String idPaciente;
  final String? nombrePaciente;
  final bool puedeSubir;

  const PatientExamsWidget({
    super.key,
    required this.idPaciente,
    this.nombrePaciente,
    this.puedeSubir = true,
  });

  static String routeName = 'PatientExams';
  static String routePath = '/patientExams';

  @override
  State<PatientExamsWidget> createState() => _PatientExamsWidgetState();
}

class _PatientExamsWidgetState extends State<PatientExamsWidget> {
  List<ExamenesMedicosRow> _examenes = [];
  bool _isLoading = true;
  bool _isUploading = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _tipoFiltro = 'todos';
  String _orden = 'fecha_desc'; // 'fecha_desc', 'fecha_asc', 'nombre_asc', 'tipo_asc'

  @override
  void initState() {
    super.initState();
    _cargarExamenes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ExamenesMedicosRow> get _examenesFiltrados {
    final q = VenezuelaLocations.normalize(_searchCtrl.text);
    final list = _examenes.where((ex) {
      if (_tipoFiltro != 'todos') {
        final t = VenezuelaLocations.normalize(ex.tipoExamen ?? '');
        if (!t.contains(VenezuelaLocations.normalize(_tipoFiltro))) return false;
      }
      if (q.isEmpty) return true;
      final tit = VenezuelaLocations.normalize(ex.titulo ?? '');
      final tipo = VenezuelaLocations.normalize(ex.tipoExamen ?? '');
      final esp = VenezuelaLocations.normalize(ex.especialidad ?? '');
      return tit.contains(q) || tipo.contains(q) || esp.contains(q);
    }).toList();

    list.sort((a, b) {
      if (_orden == 'fecha_asc') {
        return (a.fechaEstudio ?? a.createdAt)
            .compareTo(b.fechaEstudio ?? b.createdAt);
      }
      if (_orden == 'nombre_asc') {
        return (a.titulo ?? '').toLowerCase().compareTo((b.titulo ?? '').toLowerCase());
      }
      if (_orden == 'tipo_asc') {
        return (a.tipoExamen ?? '').toLowerCase().compareTo((b.tipoExamen ?? '').toLowerCase());
      }
      return (b.fechaEstudio ?? b.createdAt)
          .compareTo(a.fechaEstudio ?? a.createdAt);
    });
    return list;
  }

  Future<void> _cargarExamenes() async {
    setState(() => _isLoading = true);
    try {
      final currentUserEmail = SupaFlow.client.auth.currentUser?.email;
      _examenes = await MedicalExamService().obtenerExamenesPaciente(
        widget.idPaciente,
        correoUsuario: currentUserEmail,
        soloCompartidos: !widget.puedeSubir,
      );
    } catch (e) {
      debugPrint('Error cargando exámenes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _subirNuevoExamen() async {
    if (DoctorSubscriptionService.instance.isReadOnly) {
      DoctorSubscriptionService.instance.mostrarModalRestriccionPago(context);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final tituloController =
        TextEditingController(text: file.name.split('.').first);
    String tipoExamen = 'Laboratorio';

    if (!mounted) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: Colors.teal),
              SizedBox(width: 8),
              Text('Subir Examen Médico',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título del Estudio / Examen',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tipoExamen,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Examen',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'Laboratorio',
                  'Imagenología (Rayos X / TAC / RMN)',
                  'Cardiología (ECG / Ecocardiograma)',
                  'Ecografía / Ultrasonido',
                  'Biopsia / Patología',
                  'Otro',
                ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => tipoExamen = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Subir Archivo',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true) return;

    setState(() => _isUploading = true);
    try {
      final currentUserId = SupaFlow.client.auth.currentUser?.id;
      await MedicalExamService().subirExamen(
        idPaciente: widget.idPaciente,
        subidoPorUsuarioId: currentUserId,
        titulo: tituloController.text.trim(),
        tipoExamen: tipoExamen,
        fileName: file.name,
        fileBytes: file.bytes!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Examen médico subido exitosamente en PDF/imagen.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _cargarExamenes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _abrirDescargarExamen(String url) async {
    try {
      final secureUrl = await MedicalExamService.getSecureExamUrl(url);
      final uri = Uri.parse(secureUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el archivo PDF.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al acceder al archivo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isModalOrSubpage = widget.nombrePaciente != null || Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: isModalOrSubpage
          ? AppBar(
              title: Text(
                widget.nombrePaciente != null
                    ? 'Exámenes de ${widget.nombrePaciente}'
                    : 'Mis Exámenes y Estudios Médicos',
                style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              backgroundColor: theme.secondaryBackground,
              foregroundColor: theme.primaryText,
              elevation: 0.5,
            )
          : null,
      body: _isLoading || _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(_isUploading
                      ? 'Subiendo y optimizando archivo...'
                      : 'Cargando estudios médicos...'),
                ],
              ),
            )
          : _examenes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.picture_as_pdf_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No hay exámenes ni estudios médicos registrados.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      if (widget.puedeSubir)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Subir Primer Examen PDF'),
                          onPressed: _subirNuevoExamen,
                        ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Buscar por nombre, tipo o especialidad...',
                                prefixIcon: const Icon(Icons.search, size: 19),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _orden,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                  value: 'fecha_desc',
                                  child: Text('Más recientes',
                                      style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(
                                  value: 'fecha_asc',
                                  child: Text('Más antiguos',
                                      style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(
                                  value: 'nombre_asc',
                                  child: Text('Nombre (A-Z)',
                                      style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(
                                  value: 'tipo_asc',
                                  child: Text('Por tipo',
                                      style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _orden = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _examenesFiltrados.length,
                        itemBuilder: (context, index) {
                          final ex = _examenesFiltrados[index];
                          final esPdf = ex.formato == 'pdf' ||
                              (ex.archivoUrl?.toLowerCase().endsWith('.pdf') ??
                                  false);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              esPdf ? Colors.red.shade100 : Colors.blue.shade100,
                          child: Icon(
                            esPdf ? Icons.picture_as_pdf : Icons.image,
                            color: esPdf ? Colors.red : Colors.blue,
                          ),
                        ),
                        title: Text(
                          ex.titulo ?? 'Estudio Médico',
                          style: GoogleFonts.mooli(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ex.tipoExamen ?? "Examen"} • Fecha: ${ex.fechaEstudio?.toString().split(" ").first ?? "Reciente"}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (ex.getField<String>('correo_familiar') != null &&
                                ex.getField<String>('correo_familiar')!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.family_restroom,
                                        size: 13, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Familiar: ${ex.getField<String>('correo_familiar')}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF0369A1),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (!(ex.getField<bool>('compartir_con_paciente') ?? true))
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  '🔒 No compartido con el paciente',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Ver / Descargar PDF',
                              icon: const Icon(Icons.download_rounded,
                                  color: Colors.teal),
                              onPressed: () {
                                if (ex.archivoUrl != null) {
                                  _abrirDescargarExamen(ex.archivoUrl!);
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          if (ex.archivoUrl != null) {
                            _abrirDescargarExamen(ex.archivoUrl!);
                          }
                        },
                      ),
                    );
                  },
                ),
                    ),
                  ],
                ),
      floatingActionButton: widget.puedeSubir
          ? FloatingActionButton.extended(
              backgroundColor: FlutterFlowTheme.of(context).primary,
              icon: const Icon(Icons.upload_file, color: Colors.white),
              label: const Text('Subir Examen',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _subirNuevoExamen,
            )
          : null,
    );
  }
}

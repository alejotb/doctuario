import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/medical_exam_viewer_dialog.dart';
import '../../backend/supabase/supabase.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../flutter_flow/flutter_flow_util.dart';
import '../../services/clinical_history_service.dart';
import '../../services/ai_clinical_summary_service.dart';
import '../../services/medical_exam_service.dart';

// Componentes modulares
import 'components/patient_header_card.dart';
import 'components/ai_clinical_summary_card.dart';
import 'components/patient_history_tab.dart';
import 'components/patient_studies_tab.dart';
import 'components/patient_consultas_tab.dart';
import 'components/patient_vitals_tab.dart';

// Diálogos modulares
import 'dialogs/edit_familiar_colega_dialog.dart';
import 'dialogs/new_evolution_dialog.dart';
import 'dialogs/edit_patient_info_dialog.dart';
import '../../secretary/dialogs/upload_patient_study_dialog.dart';

class DoctorPatientDetailWidget extends StatefulWidget {
  final String idDoctor;
  final String idPaciente;

  const DoctorPatientDetailWidget({
    super.key,
    required this.idDoctor,
    required this.idPaciente,
  });

  static String routeName = 'DoctorPatientDetail';
  static String routePath = '/doctorPatientDetail';

  @override
  State<DoctorPatientDetailWidget> createState() =>
      _DoctorPatientDetailWidgetState();
}

class _DoctorPatientDetailWidgetState extends State<DoctorPatientDetailWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  UsuariosRow? _usuarioPaciente;
  UsuariosRow? _doctorActualUsuario;
  DoctoresRow? _doctorActualInfo;
  List<HistoriasClinicasRow> _historiasClinicas = [];
  List<ExamenesMedicosRow> _examenesMedicos = [];
  List<CitasRow> _citas = [];
  Map<String, TriageConsultasRow> _triageMap = {};
  Map<String, UsuariosRow> _doctoresMap = {};
  Map<String, DoctoresRow> _doctoresInfoMap = {};

  // Estado del Resumen Clínico Privado con IA
  final TextEditingController _resumenPrivadoCtrl = TextEditingController();
  bool _guardandoResumen = false;
  bool _generandoConIA = false;
  bool _resumenModificado = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarDetalles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _resumenPrivadoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDetalles() async {
    setState(() => _isLoading = true);
    try {
      // 1. Cargar datos del paciente (tabla pacientes con fallback a usuarios)
      final docClient = DualDatabaseConfig.instance.doctorClient;
      try {
        final resPac = await docClient.from('pacientes').select().eq('id', widget.idPaciente).limit(1);
        if ((resPac as List).isNotEmpty) {
          _usuarioPaciente = UsuariosRow(Map<String, dynamic>.from(resPac.first));
        }
      } catch (_) {}
      if (_usuarioPaciente == null) {
        final userRows = await UsuariosTable().queryRows(queryFn: (q) => q.eq('id', widget.idPaciente));
        if (userRows.isNotEmpty) _usuarioPaciente = userRows.first;
      }

      // 2. Cargar datos del doctor actual
      final docUserRows = await UsuariosTable().queryRows(
        queryFn: (q) => q.eq('id', widget.idDoctor),
      );
      if (docUserRows.isNotEmpty) {
        _doctorActualUsuario = docUserRows.first;
      }

      final docRows = await DoctoresTable().queryRows(
        queryFn: (q) => q.eq('id', widget.idDoctor),
      );
      if (docRows.isNotEmpty) {
        _doctorActualInfo = docRows.first;
      }

      // 3. Cargar TODAS las historias clínicas de este paciente
      _historiasClinicas = await HistoriasClinicasTable().queryRows(
        queryFn: (q) => q
            .eq('id_paciente', widget.idPaciente)
            .order('created_at', ascending: false),
      );

      // Cargar resumen privado actual del doctor si ya existe
      final miUltimaHistoria = _historiasClinicas
          .where((h) => h.idDoctor == widget.idDoctor)
          .toList();
      if (miUltimaHistoria.isNotEmpty &&
          miUltimaHistoria.first.notasPrivadas != null &&
          miUltimaHistoria.first.notasPrivadas!.isNotEmpty) {
        _resumenPrivadoCtrl.text = miUltimaHistoria.first.notasPrivadas!;
      }

      // 4. Cargar TODOS los exámenes médicos del paciente
      _examenesMedicos = await ExamenesMedicosTable().queryRows(
        queryFn: (q) => q
            .eq('id_paciente', widget.idPaciente)
            .order('fecha_estudio', ascending: false),
      );

      // 5. Cargar TODAS las citas que ha tenido el paciente
      _citas = await CitasTable().queryRows(
        queryFn: (q) => q
            .eq('id_paciente', widget.idPaciente)
            .order('fecha_hora', ascending: false),
      );

      // 6. Cargar triaje de las citas
      if (_citas.isNotEmpty) {
        final idsCitas = _citas.map((c) => c.id).toList();
        final triages = await TriageConsultasTable().queryRows(
          queryFn: (q) => q.inFilter('id_cita', idsCitas),
        );
        _triageMap = {
          for (var t in triages)
            if (t.idCita != null) t.idCita!: t
        };
      }

      // 7. Cargar nombres y especialidades de los doctores involucrados
      final Set<String> idsDoctores = {widget.idDoctor};
      for (final h in _historiasClinicas) {
        if (h.idDoctor != null) idsDoctores.add(h.idDoctor!);
      }
      for (final e in _examenesMedicos) {
        if (e.idDoctor != null) idsDoctores.add(e.idDoctor!);
      }
      for (final c in _citas) {
        if (c.idDoctor != null) idsDoctores.add(c.idDoctor!);
      }

      final docsUsuarios = await UsuariosTable().queryRows(
        queryFn: (q) => q.inFilter('id', idsDoctores.toList()),
      );
      _doctoresMap = {for (var u in docsUsuarios) u.id: u};

      final docsEspec = await DoctoresTable().queryRows(
        queryFn: (q) => q.inFilter('id', idsDoctores.toList()),
      );
      _doctoresInfoMap = {for (var d in docsEspec) d.id: d};
    } catch (e) {
      debugPrint('Error cargando expediente del paciente: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generarResumenConIA() async {
    setState(() => _generandoConIA = true);
    try {
      final resumen = AiClinicalSummaryService().generarResumenClinico(
        paciente: _usuarioPaciente,
        historias: _historiasClinicas,
        citas: _citas,
        examenes: _examenesMedicos,
        especialidadDoctor: _doctorActualInfo?.especialidad,
      );

      setState(() {
        _resumenPrivadoCtrl.text = resumen;
        _resumenModificado = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✨ Resumen clínico generado con éxito.'), backgroundColor: Color(0xFF0284C7)),
      );
    } catch (e) {
      debugPrint('Error generando resumen con IA: $e');
    } finally {
      if (mounted) setState(() => _generandoConIA = false);
    }
  }

  Future<void> _guardarResumenPrivado() async {
    final texto = _resumenPrivadoCtrl.text.trim();
    if (texto.isEmpty) return;

    setState(() => _guardandoResumen = true);
    try {
      final miUltima = _historiasClinicas.where((h) => h.idDoctor == widget.idDoctor).toList();
      await AiClinicalSummaryService().guardarResumenPrivado(
        idPaciente: widget.idPaciente,
        idDoctor: widget.idDoctor,
        resumenTexto: texto,
        idUltimaHistoria: miUltima.isNotEmpty ? miUltima.first.id : null,
      );
      setState(() => _resumenModificado = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔒 Resumen clínico privado guardado.'), backgroundColor: Color(0xFF059669)),
      );
    } catch (e) {
      debugPrint('Error guardando resumen privado: $e');
    } finally {
      if (mounted) setState(() => _guardandoResumen = false);
    }
  }

  void _abrirModalEditarFamiliarColega() {
    EditFamiliarColegaDialog.show(
      context,
      paciente: _usuarioPaciente,
      onGuardar: ({required bool esFamiliar, required String? lazo, required String? colegaNombre, required String? tipoExoneracion, required double? montoExoneracion}) async {
        try {
          final docClient = DualDatabaseConfig.instance.doctorClient;
          final updateData = {'es_familiar_medico': esFamiliar, 'lazo_familiar': lazo, 'nombre_doctor_colega': colegaNombre};
          try {
            await docClient.from('pacientes').update(updateData).eq('id', widget.idPaciente);
          } catch (_) {}
          try {
            await docClient.from('usuarios').update({...updateData, 'tipo_exoneracion': tipoExoneracion, 'monto_exoneracion': montoExoneracion}).eq('id', widget.idPaciente);
          } catch (_) {}
          _cargarDetalles();
        } catch (e) {
          debugPrint('Error actualizando familiar de colega: $e');
        }
      },
    );
  }

  void _abrirDialogoNuevaHistoria() {
    NewEvolutionDialog.show(
      context,
      onGuardar: ({
        required String motivo,
        required String sintomas,
        required String examenFisico,
        required String diagnostico,
        required String tratamiento,
        required String notasPrivadas,
      }) async {
        try {
          await ClinicalHistoryService().guardarHistoriaClinica(
            idPaciente: widget.idPaciente,
            idDoctor: widget.idDoctor,
            motivoConsulta: motivo,
            sintomas: sintomas,
            examenFisico: examenFisico,
            diagnostico: diagnostico,
            tratamiento: tratamiento,
            notasPrivadas: notasPrivadas,
          );
          _cargarDetalles();
        } catch (e) {
          debugPrint('Error guardando nueva evolución: $e');
        }
      },
    );
  }

  void _abrirModalEditarPaciente() {
    if (_usuarioPaciente != null) {
      EditPatientInfoDialog.show(
        context,
        paciente: _usuarioPaciente!,
        onPacienteActualizado: _cargarDetalles,
      );
    }
  }

  void _abrirModalEditarHallazgo(ExamenesMedicosRow ex) {
    final hallazgoCtrl = TextEditingController(text: ex.hallazgos ?? ex.notas ?? '');
    DateTime? fechaEntrega = ex.fechaEntrega;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Editar Hallazgos del Estudio', style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: hallazgoCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Hallazgos Clínicos', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(fechaEntrega != null ? 'Fecha Entrega: ${DateFormat('dd/MM/yyyy').format(fechaEntrega!)}' : 'Definir Fecha de Entrega'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: fechaEntrega ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (picked != null) setModalState(() => fechaEntrega = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                await MedicalExamService().guardarHallazgosYRevisar(
                  idExamen: ex.id,
                  hallazgos: hallazgoCtrl.text.trim(),
                  fechaEntrega: fechaEntrega,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _cargarDetalles();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _marcarEstudioRevisado(ExamenesMedicosRow ex) async {
    await MedicalExamService().marcarComoRevisado(idExamen: ex.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Estudio marcado como revisado.'), backgroundColor: Color(0xFF10B981)));
    _cargarDetalles();
  }

  void _abrirModalSubirEstudio() {
    UploadPatientStudyDialog.show(context: context, idSecretaria: widget.idDoctor, idDoctor: widget.idDoctor, onExamenSubido: _cargarDetalles);
  }

  void _abrirArchivoEstudio(String url, String titulo) {
    final ex = _examenesMedicos.firstWhere(
      (e) => e.archivoUrl == url,
      orElse: () => ExamenesMedicosRow({'archivo_url': url, 'titulo': titulo}),
    );
    MedicalExamViewerDialog.show(
      context,
      examen: ex,
      paciente: _usuarioPaciente,
      onActualizado: _cargarDetalles,
    );
  }

  @override
  Widget build(BuildContext context) {
    final esPrimeraConsulta = _citas.length <= 1;
    final ahora = DateTime.now();
    CitasRow? ultConsulta;
    CitasRow? proxConsulta;

    final citasFuturas = _citas.where((c) {
      final f = c.fechaHora?.toLocal();
      return f != null && f.isAfter(ahora) && c.estado != 'cancelada';
    }).toList();
    if (citasFuturas.isNotEmpty) {
      citasFuturas.sort((a, b) => a.fechaHora!.compareTo(b.fechaHora!));
      proxConsulta = citasFuturas.first;
    }

    final citasPasadas = _citas.where((c) {
      final f = c.fechaHora?.toLocal();
      return f != null && (f.isBefore(ahora) || c.estado == 'atendida');
    }).toList();
    if (citasPasadas.isNotEmpty) {
      ultConsulta = citasPasadas.first;
    }

    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        title: Text(
          'Expediente del Paciente',
          style: GoogleFonts.mooli(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: FlutterFlowTheme.of(context).primaryText,
          ),
        ),
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: FlutterFlowTheme.of(context).primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
            )
          : Column(
              children: [
                // 1. Cabecera con datos del paciente (Componente modular)
                PatientHeaderCard(
                  paciente: _usuarioPaciente,
                  esPrimeraConsulta: esPrimeraConsulta,
                  onEditarFamiliarColega: _abrirModalEditarFamiliarColega,
                  onEditarPaciente: _abrirModalEditarPaciente,
                  ultimaConsulta: ultConsulta,
                  proximaConsulta: proxConsulta,
                ),

                // 2. Resumen privado con IA (Componente modular)
                AiClinicalSummaryCard(
                  controller: _resumenPrivadoCtrl,
                  generandoConIA: _generandoConIA,
                  guardandoResumen: _guardandoResumen,
                  resumenModificado: _resumenModificado,
                  onGenerarConIA: _generarResumenConIA,
                  onGuardarResumen: _guardarResumenPrivado,
                ),

                // 3. Barra de pestañas
                Container(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF0284C7),
                    unselectedLabelColor: FlutterFlowTheme.of(context).secondaryText,
                    indicatorColor: const Color(0xFF0284C7),
                    indicatorWeight: 3,
                    isScrollable: true,
                    labelStyle: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 12.5),
                    tabs: [
                      Tab(icon: const Icon(Icons.history_edu, size: 18), text: 'Historia (${_historiasClinicas.length})'),
                      Tab(icon: const Icon(Icons.biotech_outlined, size: 18), text: 'Estudios (${_examenesMedicos.length})'),
                      Tab(icon: const Icon(Icons.calendar_month, size: 18), text: 'Consultas (${_citas.length})'),
                      const Tab(icon: Icon(Icons.monitor_heart_outlined, size: 18), text: 'Signos & Antecedentes'),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // 4. Vistas de cada pestaña (Componentes modulares)
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      PatientHistoryTab(
                        historias: _historiasClinicas,
                        paciente: _usuarioPaciente,
                        doctorActualUsuario: _doctorActualUsuario,
                        doctorActualInfo: _doctorActualInfo,
                        doctoresMap: _doctoresMap,
                        doctoresInfoMap: _doctoresInfoMap,
                        idDoctorActual: widget.idDoctor,
                        onNuevaHistoria: _abrirDialogoNuevaHistoria,
                      ),
                      PatientStudiesTab(
                        examenes: _examenesMedicos,
                        paciente: _usuarioPaciente,
                        doctorActualUsuario: _doctorActualUsuario,
                        doctorActualInfo: _doctorActualInfo,
                        doctoresMap: _doctoresMap,
                        onSubirEstudio: _abrirModalSubirEstudio,
                        onEditarHallazgo: _abrirModalEditarHallazgo,
                        onVerArchivo: _abrirArchivoEstudio,
                        onMarcarRevisado: _marcarEstudioRevisado,
                      ),
                      PatientConsultasTab(
                        citas: _citas,
                        triageMap: _triageMap,
                        doctoresMap: _doctoresMap,
                      ),
                      PatientVitalsTab(
                        ultimoTriage: _triageMap.values.isNotEmpty ? _triageMap.values.first : null,
                        onActualizarSignos: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

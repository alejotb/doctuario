import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../backend/supabase/supabase.dart';
import '../../flutter_flow/flutter_flow_util.dart';
import '../../index.dart';
import '../../services/medical_centers_service.dart';
import '../../services/venezuela_locations.dart';
import 'components/create_medical_center_modal.dart';
import 'components/doctor_setup_ui_helpers.dart';
import 'components/doctor_setup_sede_item_model.dart';
import 'components/doctor_setup_sede_card.dart';
import 'services/doctor_setup_service.dart';
import 'steps/doctor_capacity_preferences_step.dart';

class DoctorSetupWidget extends StatefulWidget {
  final String idDoctor;

  const DoctorSetupWidget({
    super.key,
    required this.idDoctor,
  });

  static String routeName = 'DoctorSetup';
  static String routePath = '/doctorSetup';

  @override
  State<DoctorSetupWidget> createState() => _DoctorSetupWidgetState();
}

class _DoctorSetupWidgetState extends State<DoctorSetupWidget> {
  final _formKey = GlobalKey<FormState>();

  String _doctorNombre = '';
  List<CentroMedicoItem> _centrosMedicos = [];
  bool _cargandoCentros = false;
  List<DoctorSetupSedeEntry> _sedes = [];

  // Capacidad de pacientes al día y preferencias
  int _pacientesPorDia = 12;
  bool _aceptaTelemedicina = false;
  bool _aceptaEmergencias = true;
  String? _logoUrl;
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  @override
  void dispose() {
    for (final s in _sedes) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _inicializarDatos() async {
    setState(() => _isLoading = true);
    final ciudadesValera = VenezuelaLocations.getCiudadesPorEstado('Trujillo');

    try {
      final sedesExistentes = await DoctorSedesTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', widget.idDoctor).limit(1),
      );
      if (sedesExistentes.isNotEmpty && mounted) {
        context.goNamed(DoctorAgendaPanelWidget.routeName);
        return;
      }

      final userRows = await UsuariosTable().queryRows(
        queryFn: (table) => table.eq('id', widget.idDoctor).limit(1),
      );

      if (userRows.isNotEmpty) {
        final doc = userRows.first;
        _doctorNombre = doc.nombre ?? '';
      }

      await _cargarCentrosMedicos('Valera', 'Trujillo');

      final doctorRows = await DoctoresTable().queryRows(
        queryFn: (q) => q.eq('id', widget.idDoctor).limit(1),
      );
      if (doctorRows.isNotEmpty) {
        _logoUrl = doctorRows.first.logoUrl;
      }

      // Inicializar la primera sede (Sede Principal)
      _sedes = [
        DoctorSetupSedeEntry(
          id: const Uuid().v4(),
          tipoLugar: 'clinica',
          estado: 'Trujillo',
          ciudad: 'Valera',
          ciudadesDisponibles: ciudadesValera,
          centroSeleccionado: _centrosMedicos.isNotEmpty ? _centrosMedicos.first : null,
          diasSeleccionados: {1, 2, 3, 4, 5},
          horaInicio: const TimeOfDay(hour: 8, minute: 0),
          horaFin: const TimeOfDay(hour: 17, minute: 0),
        ),
      ];
    } catch (e) {
      debugPrint('Error inicializando datos en setup: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarCentrosMedicos(String ciudad, String estado) async {
    setState(() => _cargandoCentros = true);
    try {
      final centros = await MedicalCentersService.getCentrosMedicos(
        ciudad: ciudad,
        estado: estado,
      );
      if (mounted) {
        setState(() {
          _centrosMedicos = centros;
          _cargandoCentros = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoCentros = false);
    }
  }

  void _agregarOtraSede() {
    final diasLibres = DoctorSetupSedeEntry.getDiasLibresRestantes(_sedes);
    final nuevosDias = diasLibres.isNotEmpty ? {diasLibres.first} : <int>{1};
    final estadoPrevio = _sedes.isNotEmpty ? _sedes.last.estado : 'Trujillo';
    final ciudadPrevia = _sedes.isNotEmpty ? _sedes.last.ciudad : 'Valera';
    final ciudades = VenezuelaLocations.getCiudadesPorEstado(estadoPrevio);

    setState(() {
      _sedes.add(
        DoctorSetupSedeEntry(
          id: const Uuid().v4(),
          tipoLugar: 'clinica',
          estado: estadoPrevio,
          ciudad: ciudadPrevia,
          ciudadesDisponibles: ciudades,
          diasSeleccionados: nuevosDias,
          horaInicio: const TimeOfDay(hour: 8, minute: 0),
          horaFin: const TimeOfDay(hour: 13, minute: 0),
          tienePausaAlmuerzo: false,
        ),
      );
    });
  }

  void _eliminarSede(int index) {
    if (_sedes.length <= 1) return;
    setState(() {
      _sedes[index].dispose();
      _sedes.removeAt(index);
    });
  }

  Future<void> _mostrarModalCrearCentro(int sedeIndex) async {
    final sede = _sedes[sedeIndex];
    final nuevoCentro = await CreateMedicalCenterModal.show(
      context,
      ciudad: sede.ciudad,
      estado: sede.estado,
      idDoctor: widget.idDoctor,
    );
    if (nuevoCentro != null && mounted) {
      await _cargarCentrosMedicos(sede.ciudad, sede.estado);
      setState(() {
        sede.centroSeleccionado = nuevoCentro;
      });
    }
  }

  Future<void> _guardarConfiguracionInicial() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Validar que cada sede tenga días y horarios válidos
    for (int i = 0; i < _sedes.length; i++) {
      final s = _sedes[i];
      final nombreSede = s.getNombreVisual(i);

      if (s.diasSeleccionados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ La "$nombreSede" debe tener al menos un día asignado.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final hIni = s.horaInicio.hour * 60 + s.horaInicio.minute;
      final hFin = s.horaFin.hour * 60 + s.horaFin.minute;
      if (hFin <= hIni) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ En "$nombreSede" la hora fin debe ser posterior a la de inicio.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Validar colisiones con otras sedes
      for (final dia in s.diasSeleccionados) {
        final conflicto = DoctorSetupSedeEntry.verificarConflictoHorario(
          todasLasSedes: _sedes,
          indexSedeActual: i,
          dia: dia,
          inicio: s.horaInicio,
          fin: s.horaFin,
        );
        if (conflicto != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Conflicto de horario: $conflicto'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);

    final ok = await DoctorSetupService.guardarConfiguracionMultiple(
      context: context,
      idDoctor: widget.idDoctor,
      doctorNombre: _doctorNombre,
      sedes: _sedes,
      pacientesPorDia: _pacientesPorDia,
      logoUrl: _logoUrl,
      aceptaTelemedicina: _aceptaTelemedicina,
      aceptaEmergencias: _aceptaEmergencias,
    );

    if (mounted && !ok) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Configuración de Consultorios y Sedes',
              style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 16,
                      vertical: 20,
                    ),
                    children: [
                      const DoctorSetupWelcomeBanner(),
                      const SizedBox(height: 20),

                      // TÍTULO DE LA SECCIÓN DE SEDES
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '1. Sedes y Consultorios Médicos (${_sedes.length})',
                                  style: GoogleFonts.mooli(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const Text(
                                  'Indica los consultorios donde trabajas y los días/horas en cada uno.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // LISTA DE SEDES
                      ...List.generate(_sedes.length, (idx) {
                        final sede = _sedes[idx];
                        return DoctorSetupSedeCard(
                          key: ValueKey(sede.id),
                          index: idx,
                          sede: sede,
                          doctorNombre: _doctorNombre,
                          todasLasSedes: _sedes,
                          centrosMedicos: _centrosMedicos,
                          cargandoCentros: _cargandoCentros,
                          onMostrarModalCrearCentro: () => _mostrarModalCrearCentro(idx),
                          onEstadoChanged: () {
                            _cargarCentrosMedicos(sede.ciudad, sede.estado);
                            setState(() {});
                          },
                          onCiudadChanged: () {
                            _cargarCentrosMedicos(sede.ciudad, sede.estado);
                            setState(() {});
                          },
                          onEliminarSede: () => _eliminarSede(idx),
                          onActualizarUI: () => setState(() {}),
                        );
                      }),

                      // BOTÓN PARA AGREGAR OTRA SEDE
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: const Color(0xFFF0F9FF),
                          ),
                          icon: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF0284C7), size: 20),
                          label: Text(
                            '+ Agregar otra Sede / Consultorio',
                            style: GoogleFonts.mooli(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          onPressed: _agregarOtraSede,
                        ),
                      ),

                      // PASO FINAL: PREFERENCIAS Y CAPACIDAD
                      DoctorCapacityPreferencesStep(
                        pacientesPorDia: _pacientesPorDia,
                        onPacientesPorDiaChanged: (val) => setState(() => _pacientesPorDia = val),
                        aceptaTelemedicina: _aceptaTelemedicina,
                        onAceptaTelemedicinaChanged: (val) => setState(() => _aceptaTelemedicina = val),
                        aceptaEmergencias: _aceptaEmergencias,
                        onAceptaEmergenciasChanged: (val) => setState(() => _aceptaEmergencias = val),
                        logoUrl: _logoUrl,
                        idDoctor: widget.idDoctor,
                        onLogoUpdated: (url) => setState(() => _logoUrl = url),
                      ),
                      const SizedBox(height: 28),

                      DoctorSetupSubmitButton(
                        isSaving: _isSaving,
                        onPressed: _guardarConfiguracionInicial,
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../backend/supabase/supabase.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../services/doctor_subscription_service.dart';
import '../../services/special_treatment_service.dart';
import '../components/doctor_create_patient_dialog.dart';
import '../components/doctor_patient_import_dialog.dart';
import '../doctor_patient_detail/doctor_patient_detail_widget.dart';
import 'components/doctor_patient_card.dart';
import 'components/patient_filter_bar.dart';

/// Pantalla del directorio de pacientes para el médico.
///
/// Permite buscar por nombre/cédula/teléfono/email, filtrar por categorías
/// (Todos, Preferenciales, Foráneos) y por fecha de última cita, además de
/// ordenar alfabéticamente (A-Z / Z-A), por número de cédula o por última cita.
class DoctorPacientesListWidget extends StatefulWidget {
  final String idDoctor;

  const DoctorPacientesListWidget({
    super.key,
    required this.idDoctor,
  });

  static String routeName = 'DoctorPacientesList';
  static String routePath = '/doctorPacientesList';

  @override
  State<DoctorPacientesListWidget> createState() =>
      _DoctorPacientesListWidgetState();
}

class _DoctorPacientesListWidgetState extends State<DoctorPacientesListWidget> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<UsuariosRow> _pacientes = [];
  final Map<String, int> _conteoCitasPorPaciente = {};
  final Map<String, DateTime?> _ultimaCitaPorPaciente = {};
  final Map<String, bool> _esPreferencialMap = {};

  // Filtros y ordenamiento activos
  String _filtroActivo = 'todos';
  String _ordenSeleccionado = 'alfabetico_asc';
  DateTimeRange? _filtroRangoFechas;

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Carga la lista completa de pacientes asociados al doctor
  Future<void> _cargarPacientes() async {
    setState(() => _isLoading = true);
    try {
      final docClient = DualDatabaseConfig.instance.doctorClient;

      // 1. Obtener todas las citas del doctor
      final citas = await CitasTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', widget.idDoctor),
      );

      // 2. Obtener historias clínicas del doctor
      final historias = await HistoriasClinicasTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', widget.idDoctor),
      );

      // 3. Obtener pacientes registrados directamente en la base privada
      final pacientesPrivados = await PacientesTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', widget.idDoctor),
      );

      final Set<String> pacienteIds = {};
      for (final p in pacientesPrivados) {
        if (p.id.isNotEmpty && p.id != widget.idDoctor) {
          pacienteIds.add(p.id);
        }
      }

      for (final c in citas) {
        if (c.idPaciente != null &&
            c.idPaciente!.isNotEmpty &&
            c.idPaciente != widget.idDoctor) {
          pacienteIds.add(c.idPaciente!);
          _conteoCitasPorPaciente[c.idPaciente!] =
              (_conteoCitasPorPaciente[c.idPaciente!] ?? 0) + 1;

          final f = c.fechaHora;
          if (f != null) {
            final prev = _ultimaCitaPorPaciente[c.idPaciente!];
            if (prev == null || f.isAfter(prev)) {
              _ultimaCitaPorPaciente[c.idPaciente!] = f;
            }
          }
        }
      }

      for (final h in historias) {
        if (h.idPaciente != null &&
            h.idPaciente!.isNotEmpty &&
            h.idPaciente != widget.idDoctor) {
          pacienteIds.add(h.idPaciente!);
        }
      }

      // 4. Consultar únicamente los pacientes asociados a este doctor (aislamiento estricto)
      final Map<String, Map<String, dynamic>> pacienteMap = {};
      if (pacienteIds.isNotEmpty) {
        final idsList = pacienteIds.toList();
        try {
          final resPac = await docClient
              .from('pacientes')
              .select()
              .inFilter('id', idsList);
          for (final item in (resPac as List)) {
            final m = Map<String, dynamic>.from(item);
            final pid = m['id']?.toString() ?? '';
            if (pid.isNotEmpty && pid != widget.idDoctor) {
              pacienteMap[pid] = m;
            }
          }
        } catch (e) {
          debugPrint('Error leyendo pacientes filtrados: $e');
        }

        try {
          final usrs = await UsuariosTable().queryRows(
            queryFn: (q) => q.inFilter('id', idsList),
          );
          for (final u in usrs) {
            if (u.id == widget.idDoctor) continue;
            if (pacienteMap.containsKey(u.id)) {
              final existing = pacienteMap[u.id]!;
              if ((existing['nombre']?.toString().trim().isEmpty ?? true) &&
                  (u.nombre?.trim().isNotEmpty ?? false)) {
                existing['nombre'] = u.nombre;
              }
              if ((existing['cedula']?.toString().trim().isEmpty ?? true) &&
                  (u.cedula?.trim().isNotEmpty ?? false)) {
                existing['cedula'] = u.cedula;
              }
              if ((existing['telefono']?.toString().trim().isEmpty ?? true) &&
                  (u.telefono?.trim().isNotEmpty ?? false)) {
                existing['telefono'] = u.telefono;
              }
              if ((existing['ciudad_origen']?.toString().trim().isEmpty ?? true) &&
                  (u.ciudadOrigen?.trim().isNotEmpty ?? false)) {
                existing['ciudad_origen'] = u.ciudadOrigen;
              }
              if ((existing['foto_url']?.toString().trim().isEmpty ?? true) &&
                  (u.fotoUrl?.trim().isNotEmpty ?? false)) {
                existing['foto_url'] = u.fotoUrl;
              }
            } else {
              pacienteMap[u.id] = Map<String, dynamic>.from(u.data);
            }
          }
        } catch (_) {}
      }

      final List<UsuariosRow> usuarios =
          pacienteMap.values.map((d) => UsuariosRow(d)).toList();
      usuarios.removeWhere((u) => u.id == widget.idDoctor);

      // 5. Determinar pacientes preferenciales
      for (final u in usuarios) {
        final esPref = await SpecialTreatmentService()
            .esPacientePreferencialDelDoctor(
          idDoctor: widget.idDoctor,
          idPaciente: u.id,
        );
        _esPreferencialMap[u.id] = esPref;
      }

      _pacientes = usuarios;
    } catch (e) {
      debugPrint('Error al cargar pacientes del doctor: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Retorna la lista de pacientes filtrada por búsqueda, estado, fechas y orden
  List<UsuariosRow> get _pacientesFiltrados {
    final query = _searchController.text.trim().toLowerCase();
    final filtrados = _pacientes.where((p) {
      if (_filtroActivo == 'preferenciales' &&
          _esPreferencialMap[p.id] != true) {
        return false;
      }
      if (_filtroActivo == 'foraneos' && p.esForaneo != true) {
        return false;
      }

      // Filtro por fecha de última cita
      if (_filtroRangoFechas != null) {
        final f = _ultimaCitaPorPaciente[p.id];
        if (f == null) return false;
        final start = DateTime(
          _filtroRangoFechas!.start.year,
          _filtroRangoFechas!.start.month,
          _filtroRangoFechas!.start.day,
        );
        final end = DateTime(
          _filtroRangoFechas!.end.year,
          _filtroRangoFechas!.end.month,
          _filtroRangoFechas!.end.day,
          23,
          59,
          59,
        );
        if (f.isBefore(start) || f.isAfter(end)) {
          return false;
        }
      }

      if (query.isEmpty) return true;
      final nom = (p.nombre ?? '').toLowerCase();
      final ced = (p.cedula ?? '').toLowerCase();
      final tlf = (p.telefono ?? '').toLowerCase();
      final eml = (p.email ?? '').toLowerCase();
      return nom.contains(query) ||
          ced.contains(query) ||
          tlf.contains(query) ||
          eml.contains(query);
    }).toList();

    // Ordenamiento dinámico
    switch (_ordenSeleccionado) {
      case 'alfabetico_asc':
        filtrados.sort((a, b) =>
            (a.nombre ?? '').toLowerCase().compareTo((b.nombre ?? '').toLowerCase()));
        break;
      case 'alfabetico_desc':
        filtrados.sort((a, b) =>
            (b.nombre ?? '').toLowerCase().compareTo((a.nombre ?? '').toLowerCase()));
        break;
      case 'cedula':
        filtrados.sort((a, b) {
          final cA = (a.cedula ?? '').replaceAll(RegExp(r'[^0-9]'), '');
          final cB = (b.cedula ?? '').replaceAll(RegExp(r'[^0-9]'), '');
          final numA = int.tryParse(cA);
          final numB = int.tryParse(cB);
          if (numA != null && numB != null) {
            return numA.compareTo(numB);
          }
          return (a.cedula ?? '').compareTo(b.cedula ?? '');
        });
        break;
      case 'ultima_cita':
        filtrados.sort((a, b) {
          final fA = _ultimaCitaPorPaciente[a.id];
          final fB = _ultimaCitaPorPaciente[b.id];
          if (fA == null && fB == null) return 0;
          if (fA == null) return 1;
          if (fB == null) return -1;
          return fB.compareTo(fA);
        });
        break;
    }

    return filtrados;
  }

  /// Despliega el selector de rango de fecha para filtrar por última cita
  Future<void> _seleccionarRangoFechas() async {
    final DateTime now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _filtroRangoFechas ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      helpText: 'Filtrar por fecha de última cita',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (picked != null) {
      setState(() => _filtroRangoFechas = picked);
    }
  }

  void _limpiarFiltroFechas() {
    setState(() => _filtroRangoFechas = null);
  }

  @override
  Widget build(BuildContext context) {
    final lista = _pacientesFiltrados;
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const DoctorReadOnlyBannerWidget(),
                // Barra de Búsqueda y Acciones Rápidas
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: theme.secondaryBackground,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, cédula o teléfono...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: theme.primaryBackground,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 0, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.alternate),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.alternate),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Importar Pacientes (Excel / Word)',
                        icon: Icon(Icons.drive_folder_upload_rounded, color: theme.primary),
                        onPressed: () async {
                          if (DoctorSubscriptionService.instance.isReadOnly) {
                            DoctorSubscriptionService.instance
                                .mostrarModalRestriccionPago(context);
                            return;
                          }
                          final res = await DoctorPatientImportDialog.show(
                            context,
                            idDoctor: widget.idDoctor,
                          );
                          if (res == true) _cargarPacientes();
                        },
                      ),
                    ],
                  ),
                ),
                // Barra Modularizada de Ordenamiento y Filtros
                PatientFilterBar(
                  filtroActivo: _filtroActivo,
                  onFiltroActivoChanged: (val) =>
                      setState(() => _filtroActivo = val),
                  ordenSeleccionado: _ordenSeleccionado,
                  onOrdenChanged: (val) =>
                      setState(() => _ordenSeleccionado = val),
                  filtroRangoFechas: _filtroRangoFechas,
                  onSelectRangoFechas: _seleccionarRangoFechas,
                  onClearRangoFechas: _limpiarFiltroFechas,
                  totalPacientes: _pacientes.length,
                ),
                const Divider(height: 1),
                Expanded(
                  child: lista.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          itemCount: lista.length,
                          itemBuilder: (context, index) {
                            final p = lista[index];
                            final esPref = _esPreferencialMap[p.id] == true;
                            final totalConsultas =
                                _conteoCitasPorPaciente[p.id] ?? 0;
                            final ultimaCita = _ultimaCitaPorPaciente[p.id];

                            return DoctorPatientCard(
                              paciente: p,
                              esPreferencial: esPref,
                              totalConsultas: totalConsultas,
                              ultimaCita: ultimaCita,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        DoctorPatientDetailWidget(
                                      idDoctor: widget.idDoctor,
                                      idPaciente: p.id,
                                    ),
                                  ),
                                );
                                _cargarPacientes();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final creado = await DoctorCreatePatientDialog.show(
            context,
            idDoctor: widget.idDoctor,
          );
          if (creado == true) _cargarPacientes();
        },
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(Icons.person_add_alt_1_rounded,
            color: Colors.white, size: 20),
        label: Text(
          'Nuevo Paciente',
          style: GoogleFonts.mooli(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Vista cuando la lista de pacientes está vacía o sin coincidencias
  Widget _buildEmptyState(FlutterFlowTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: Icon(
                _pacientes.isEmpty
                    ? Icons.person_search_rounded
                    : Icons.search_off_rounded,
                size: 56,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _pacientes.isEmpty
                  ? 'Aún no tienes pacientes registrados'
                  : 'No se encontraron pacientes para tu búsqueda o filtros',
              textAlign: TextAlign.center,
              style: GoogleFonts.mooli(
                fontSize: 16,
                color: theme.primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _pacientes.isEmpty
                  ? 'Puedes pulsar el botón superior para importar tus listas desde Excel o documentos Word, o registrar pacientes desde la agenda.'
                  : 'Prueba cambiando el término de búsqueda, limpiando el filtro de fechas o seleccionando otro orden.',
              textAlign: TextAlign.center,
              style: GoogleFonts.mooli(
                  fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

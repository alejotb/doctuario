import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../backend/supabase/supabase.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../services/medical_centers_service.dart';
import '../../services/venezuela_locations.dart';
import '../../services/location_maps_service.dart';
import '../../components/map_location_picker_dialog.dart';
import '../doctor_share_helper.dart';

class DoctorSedesConfigWidget extends StatefulWidget {
  final String idDoctor;

  const DoctorSedesConfigWidget({super.key, required this.idDoctor});

  static String routeName = 'DoctorSedesConfig';
  static String routePath = '/doctorSedesConfig';

  @override
  State<DoctorSedesConfigWidget> createState() =>
      _DoctorSedesConfigWidgetState();
}

class _DoctorSedesConfigWidgetState extends State<DoctorSedesConfigWidget> {
  List<DoctorSedesRow> _sedes = [];
  List<HorariosDisponibilidadRow> _horarios = [];
  UsuariosRow? _doctorUsuario;
  DoctoresRow? _doctorInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      var sedes = await DoctorSedesTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', widget.idDoctor),
      );
      if (sedes.isEmpty) {
        sedes = await DoctorSedesTable().queryRows(
          queryFn: (q) => q,
        );
      }
      _sedes = sedes;

      var horarios = await HorariosDisponibilidadTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', widget.idDoctor),
      );
      if (horarios.isEmpty) {
        horarios = await HorariosDisponibilidadTable().queryRows(
          queryFn: (q) => q,
        );
      }
      _horarios = horarios;

      final u = await UsuariosTable().querySingleRow(
        queryFn: (q) => q.eq('id', widget.idDoctor),
      );
      if (u.isNotEmpty) _doctorUsuario = u.first;

      final d = await DoctoresTable().querySingleRow(
        queryFn: (q) => q.eq('id', widget.idDoctor),
      );
      if (d.isNotEmpty) {
        _doctorInfo = d.first;
      } else {
        final dClinica = await DoctoresTable().queryRows(
          queryFn: (q) => q.limit(1),
        );
        if (dClinica.isNotEmpty) _doctorInfo = dClinica.first;
      }
    } catch (e) {
      debugPrint('Error cargando sedes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarSede(DoctorSedesRow sede) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Eliminar Consultorio'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${sede.nombreSede}"? También se eliminarán los horarios asociados a esta sede.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      // Eliminar horarios asociados
      await HorariosDisponibilidadTable().delete(
        matchingRows: (q) => q.eq('id_sede', sede.id),
      );
      // Eliminar la sede
      await DoctorSedesTable().delete(
        matchingRows: (q) => q.eq('id', sede.id),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consultorio eliminado con éxito.'),
            backgroundColor: Colors.teal,
          ),
        );
      }
      _cargarDatos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar consultorio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirModalSede({DoctorSedesRow? sedeExistente}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalFormularioSede(
        idDoctor: widget.idDoctor,
        doctorUsuario: _doctorUsuario,
        sedeExistente: sedeExistente,
        horariosExistentes: sedeExistente == null
            ? []
            : _horarios.where((h) => h.idSede == sedeExistente.id).toList(),
        onGuardado: () {
          _cargarDatos();
        },
      ),
    );
  }

  void _compartirPerfil() async {
    if (_doctorUsuario == null || _doctorInfo == null) return;
    final texto = await DoctorShareHelper.generarTextoCompartirDoctor(
      doctorUsuario: _doctorUsuario!,
      doctorInfo: _doctorInfo!,
      sedes: _sedes,
      horarios: _horarios,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compartir Perfil y Horarios',
                style: GoogleFonts.mooli(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Comparte tus sedes de atención y horarios con pacientes para que agenden sus consultas presenciales fácilmente.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.chat, color: Colors.white),
              ),
              title: const Text('Enviar por WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                DoctorShareHelper.compartirPorWhatsApp(texto);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueGrey,
                child: Icon(Icons.copy, color: Colors.white),
              ),
              title: const Text('Copiar al Portapapeles'),
              onTap: () async {
                Navigator.pop(ctx);
                await DoctorShareHelper.copiarAlPortapapeles(texto);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 Perfil copiado al portapapeles.'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        title: Text(
          'Mis Consultorios y Horarios',
          style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 1,
        actions: [
          IconButton(
            tooltip: 'Compartir Perfil y Horarios',
            icon: const Icon(Icons.share, color: Colors.teal),
            onPressed: _compartirPerfil,
          ),
          IconButton(
            tooltip: 'Nuevo Consultorio / Sede',
            icon: const Icon(Icons.add_location_alt, color: Color(0xFF00796B)),
            onPressed: () => _abrirModalSede(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sedes.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildInfoBanner(),
                      const SizedBox(height: 16),
                      ..._sedes.map((sede) => _buildSedeCard(sede)),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirModalSede(),
        backgroundColor: theme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Agregar Consultorio',
          style: GoogleFonts.mooli(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF80CBC4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF00796B), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Puedes configurar múltiples consultorios privados o sedes en clínicas y hospitales de Valera y el país, cada uno con sus propios días y turnos de atención.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.teal.shade900,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_business_rounded,
                size: 56,
                color: Color(0xFF00796B),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aún no tienes consultorios registrados',
              textAlign: TextAlign.center,
              style: GoogleFonts.mooli(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra tu consultorio privado o selecciona la clínica / hospital donde consultas para que tus pacientes puedan agendar citas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: FlutterFlowTheme.of(context).primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Registrar Primer Consultorio',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _abrirModalSede(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSedeCard(DoctorSedesRow sede) {
    final theme = FlutterFlowTheme.of(context);
    final esPrivado = sede.tipoLugar == 'privado';
    final horariosSede = _horarios.where((h) => h.idSede == sede.id).toList();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: esPrivado ? Colors.teal.shade200 : Colors.indigo.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con tipo de lugar y opciones
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: esPrivado
                        ? const Color(0xFFE0F2F1)
                        : const Color(0xFFE8EAF6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    esPrivado ? Icons.home_work_rounded : Icons.local_hospital,
                    color: esPrivado
                        ? const Color(0xFF00796B)
                        : const Color(0xFF3949AB),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: esPrivado
                                  ? Colors.teal.shade100
                                  : Colors.indigo.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              esPrivado ? 'CONSULTORIO PRIVADO' : 'CLÍNICA / HOSPITAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: esPrivado
                                    ? Colors.teal.shade900
                                    : Colors.indigo.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sede.nombreSede ?? 'Consultorio',
                        style: GoogleFonts.mooli(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryText,
                        ),
                      ),
                      if (sede.numeroConsultorio != null &&
                          sede.numeroConsultorio!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '🚪 ${sede.numeroConsultorio}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (val) {
                    if (val == 'editar') {
                      _abrirModalSede(sedeExistente: sede);
                    } else if (val == 'eliminar') {
                      _eliminarSede(sede);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Editar Consultorio'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar Consultorio',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            // Detalles de ubicación y teléfono
            if (sede.direccion != null && sede.direccion!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sede.direccion!,
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                if (sede.ciudad != null && sede.ciudad!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.location_city,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${sede.ciudad}${sede.estado != null ? ', ${sede.estado}' : ''}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                if (sede.telefonoContacto != null &&
                    sede.telefonoContacto!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(
                          sede.telefonoVisible ?? true
                              ? Icons.phone
                              : Icons.phone_locked,
                          size: 14,
                          color: sede.telefonoVisible ?? true
                              ? Colors.teal
                              : Colors.blueGrey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${sede.telefonoContacto!} ${sede.telefonoVisible ?? true ? "" : "(Oculto)"}',
                          style: TextStyle(
                              fontSize: 12,
                              color: sede.telefonoVisible ?? true
                                  ? Colors.teal
                                  : Colors.blueGrey,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if ((sede.direccion != null && sede.direccion!.isNotEmpty) ||
                (sede.latitud != null && sede.longitud != null))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  onTap: () => LocationMapsService.abrirGoogleMaps(
                    direccion: sede.direccion,
                    ciudad: sede.ciudad,
                    estado: sede.estado,
                    latitud: sede.latitud,
                    longitud: sede.longitud,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_outlined, size: 16, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          'Ver ubicación en Google Maps',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const Divider(height: 22),

            // Sección de Horarios Configurados
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '⏰ Horarios y Turnos:',
                  style: GoogleFonts.mooli(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.primary,
                  ),
                ),
                if (sede.duracionConsultaMinutos != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      '⏱️ ${sede.duracionConsultaMinutos} min / consulta',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (horariosSede.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Sin horarios activos definidos. Toca en los 3 puntos para editar.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: horariosSede.map((h) {
                  final dia = _nombreDia(h.diaSemana ?? 1);
                  final mod = h.modalidadAtencion == 'orden_llegada'
                      ? 'Llegada'
                      : 'Cita';
                  final inicio = h.horaInicio != null
                      ? _formatearHora(h.horaInicio!)
                      : '08:00 AM';
                  final fin =
                      h.horaFin != null ? _formatearHora(h.horaFin!) : '12:00 PM';

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$dia: ',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00796B),
                          ),
                        ),
                        Text(
                          '$inicio - $fin ($mod)',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _formatearHora(PostgresTime time) {
    final dt = time.time;
    if (dt == null) return '08:00 AM';
    final hora = dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = hora >= 12 ? 'PM' : 'AM';
    final hora12 = hora == 0 ? 12 : (hora > 12 ? hora - 12 : hora);
    return '$hora12:$min $ampm';
  }

  String _nombreDia(int dia) {
    switch (dia) {
      case 1:
        return 'Lun';
      case 2:
        return 'Mar';
      case 3:
        return 'Mié';
      case 4:
        return 'Jue';
      case 5:
        return 'Vie';
      case 6:
        return 'Sáb';
      case 7:
        return 'Dom';
      default:
        return 'Día $dia';
    }
  }
}

// ---------------------------------------------------------------------------
// MODAL PARA CREAR / EDITAR SEDE Y HORARIOS
// ---------------------------------------------------------------------------

class _ModalFormularioSede extends StatefulWidget {
  final String idDoctor;
  final UsuariosRow? doctorUsuario;
  final DoctorSedesRow? sedeExistente;
  final List<HorariosDisponibilidadRow> horariosExistentes;
  final VoidCallback onGuardado;

  const _ModalFormularioSede({
    required this.idDoctor,
    this.doctorUsuario,
    this.sedeExistente,
    required this.horariosExistentes,
    required this.onGuardado,
  });

  @override
  State<_ModalFormularioSede> createState() => _ModalFormularioSedeState();
}

class _ModalFormularioSedeState extends State<_ModalFormularioSede> {
  String _tipoLugar = 'centro_medico'; // 'privado' | 'centro_medico'
  String _estadoSeleccionado = 'Trujillo';
  String _ciudadSeleccionada = 'Valera';
  List<CentroMedicoItem> _centrosDisponibles = [];
  CentroMedicoItem? _centroSeleccionado;
  bool _cargandoCentros = false;

  final TextEditingController _nombrePrivadoCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();
  final TextEditingController _pisoCtrl = TextEditingController(); // Piso / Nivel
  final TextEditingController _numeroLocalCtrl = TextEditingController(); // N° / Letra consultorio
  final TextEditingController _telefonoCtrl = TextEditingController();

  bool _telefonoVisible = true;
  double? _latitud;
  double? _longitud;

  // Configuración de Horarios
  final Set<int> _diasSeleccionados = {1, 2, 3, 4, 5}; // Lun-Vie por defecto
  TimeOfDay _horaInicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 17, minute: 0);
  bool _tienePausaAlmuerzo = false;
  TimeOfDay _horaInicioAlmuerzo = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _horaFinAlmuerzo = const TimeOfDay(hour: 13, minute: 0);
  String _modalidad = 'hora_fija'; // 'hora_fija' | 'orden_llegada'
  int _duracionMinutos = 30;
  int _cupoMaximo = 15;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _inicializarValores();
  }

  @override
  void dispose() {
    _nombrePrivadoCtrl.dispose();
    _direccionCtrl.dispose();
    _pisoCtrl.dispose();
    _numeroLocalCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  /// Construye el texto formateado de la ubicación interna (Piso y N° Consultorio)
  String _getUbicacionEspecificaTexto() {
    final piso = _pisoCtrl.text.trim();
    final local = _numeroLocalCtrl.text.trim();

    if (piso.isNotEmpty && local.isNotEmpty) {
      final pisoFmt = (piso.toLowerCase().startsWith('piso') ||
              piso.toLowerCase().startsWith('nivel') ||
              piso.toUpperCase() == 'PB' ||
              piso.toLowerCase().startsWith('planta'))
          ? piso
          : 'Piso $piso';
      final localFmt = (local.toLowerCase().startsWith('consultorio') ||
              local.toLowerCase().startsWith('local') ||
              local.toLowerCase().startsWith('oficina'))
          ? local
          : 'Consultorio $local';
      return '$pisoFmt, $localFmt';
    } else if (piso.isNotEmpty) {
      return (piso.toLowerCase().startsWith('piso') || piso.toUpperCase() == 'PB')
          ? piso
          : 'Piso $piso';
    } else if (local.isNotEmpty) {
      return (local.toLowerCase().startsWith('consultorio') || local.toLowerCase().startsWith('local'))
          ? local
          : 'Consultorio $local';
    }
    return '';
  }

  void _inicializarValores() {
    // Si el doctor tiene ciudadOrigen registrada en su perfil, intentar asociarla
    if (widget.doctorUsuario?.ciudadOrigen != null &&
        widget.doctorUsuario!.ciudadOrigen!.isNotEmpty) {
      final origen = widget.doctorUsuario!.ciudadOrigen!;
      if (origen.contains(',')) {
        final partes = origen.split(',');
        _ciudadSeleccionada = partes[0].trim();
        _estadoSeleccionado = partes[1].trim();
      } else {
        _ciudadSeleccionada = origen.trim();
        // Buscar el estado correspondiente
        for (final loc in VenezuelaLocations.list) {
          if (loc.ciudades.map(VenezuelaLocations.normalize).contains(VenezuelaLocations.normalize(_ciudadSeleccionada))) {
            _estadoSeleccionado = loc.estado;
            break;
          }
        }
      }
    }

    final docNombre = (widget.doctorUsuario?.nombre != null && widget.doctorUsuario!.nombre!.isNotEmpty)
        ? widget.doctorUsuario!.nombre!
        : 'Doctor';

    if (widget.sedeExistente != null) {
      final s = widget.sedeExistente!;
      _tipoLugar = s.tipoLugar ?? 'centro_medico';
      _nombrePrivadoCtrl.text = s.nombreSede ?? '';
      _direccionCtrl.text = s.direccion ?? '';
      if (s.numeroConsultorio != null && s.numeroConsultorio!.isNotEmpty) {
        final raw = s.numeroConsultorio!;
        if (raw.contains(',')) {
          final parts = raw.split(',');
          _pisoCtrl.text = parts[0].replaceAll(RegExp(r'piso|nivel', caseSensitive: false), '').trim();
          _numeroLocalCtrl.text = parts.sublist(1).join(',').replaceAll(RegExp(r'consultorio|local|oficina', caseSensitive: false), '').trim();
        } else {
          _numeroLocalCtrl.text = raw;
        }
      }
      _telefonoCtrl.text = s.telefonoContacto ?? '';
      _telefonoVisible = s.telefonoVisible ?? true;
      _latitud = s.latitud;
      _longitud = s.longitud;
      if (s.estado != null && s.estado!.isNotEmpty) {
        _estadoSeleccionado = s.estado!;
      }
      if (s.ciudad != null && s.ciudad!.isNotEmpty) {
        _ciudadSeleccionada = s.ciudad!;
      }
      if (s.duracionConsultaMinutos != null) {
        _duracionMinutos = s.duracionConsultaMinutos!;
      }

      if (s.horarioTexto != null && s.horarioTexto!.contains('Almuerzo')) {
        _tienePausaAlmuerzo = true;
      }

      // Inicializar días y horas desde horarios existentes
      if (widget.horariosExistentes.isNotEmpty) {
        _diasSeleccionados.clear();
        for (final h in widget.horariosExistentes) {
          if (h.diaSemana != null) _diasSeleccionados.add(h.diaSemana!);
        }

        final sorted = List.of(widget.horariosExistentes)
          ..sort((a, b) => (a.horaInicio?.time?.hour ?? 0).compareTo(b.horaInicio?.time?.hour ?? 0));

        final primerHorario = sorted.first;
        if (primerHorario.horaInicio?.time != null) {
          _horaInicio = TimeOfDay(
            hour: primerHorario.horaInicio!.time!.hour,
            minute: primerHorario.horaInicio!.time!.minute,
          );
        }
        if (primerHorario.horaFin?.time != null) {
          _horaFin = TimeOfDay(
            hour: primerHorario.horaFin!.time!.hour,
            minute: primerHorario.horaFin!.time!.minute,
          );
        }

        // Si existen bloques divididos para un mismo día, restaurar almuerzo
        if (sorted.length >= 2 && sorted[0].diaSemana == sorted[1].diaSemana) {
          _tienePausaAlmuerzo = true;
          if (sorted[0].horaFin?.time != null) {
            _horaInicioAlmuerzo = TimeOfDay(
              hour: sorted[0].horaFin!.time!.hour,
              minute: sorted[0].horaFin!.time!.minute,
            );
          }
          if (sorted[1].horaInicio?.time != null) {
            _horaFinAlmuerzo = TimeOfDay(
              hour: sorted[1].horaInicio!.time!.hour,
              minute: sorted[1].horaInicio!.time!.minute,
            );
          }
          if (sorted[1].horaFin?.time != null) {
            _horaFin = TimeOfDay(
              hour: sorted[1].horaFin!.time!.hour,
              minute: sorted[1].horaFin!.time!.minute,
            );
          }
        }

        if (primerHorario.modalidadAtencion != null) {
          _modalidad = primerHorario.modalidadAtencion!;
        }
        if (primerHorario.cupoMaximo != null) {
          _cupoMaximo = primerHorario.cupoMaximo!;
        }
      }
    } else {
      _nombrePrivadoCtrl.text = 'Consultorio de $docNombre';
      if (widget.doctorUsuario?.telefono != null && widget.doctorUsuario!.telefono!.isNotEmpty) {
        _telefonoCtrl.text = widget.doctorUsuario!.telefono!;
      }
    }

    _cargarCentros();
  }

  Future<void> _cargarCentros() async {
    setState(() => _cargandoCentros = true);
    final centros = await MedicalCentersService.getCentrosMedicos(
      estado: _estadoSeleccionado,
      ciudad: _ciudadSeleccionada,
    );
    if (mounted) {
      setState(() {
        _centrosDisponibles = centros;
        _cargandoCentros = false;

        // Intentar seleccionar si ya coincidía con la sede existente
        if (widget.sedeExistente != null) {
          final existente = centros.where((c) =>
              c.nombre.toLowerCase() ==
                  (widget.sedeExistente!.nombreSede ?? '').toLowerCase() ||
              c.id == widget.sedeExistente!.idCentroMedico);
          if (existente.isNotEmpty) {
            _centroSeleccionado = existente.first;
          }
        } else if (_centroSeleccionado == null && centros.isNotEmpty) {
          _centroSeleccionado = centros.first;
          _direccionCtrl.text = _centroSeleccionado?.direccion ?? '';
        }
      });
    }
  }

  void _abrirDialogoNuevoCentro() {
    final nombreCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    String tipoSeleccionado = 'Clínica';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.add_business, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                'Agregar Centro / Clínica',
                style: GoogleFonts.mooli(
                    fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Este centro quedará guardado para que tú y otros doctores de esta ciudad puedan seleccionarlo.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Centro Médico / Clínica *',
                    hintText: 'Ej. Centro Médico San José',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipoSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Centro *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: MedicalCentersService.tiposDeCentro
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => tipoSeleccionado = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dirCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección (Calle, Sector)',
                    hintText: 'Ej. Av. 5 con Calle 12',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de Contacto (Opcional)',
                    hintText: 'Ej. 0271-2210000',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                if (nombreCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa el nombre del centro.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);

                // Guardar en tabla centros_medicos
                final nuevo = await MedicalCentersService.registrarNuevoCentro(
                  nombre: nombreCtrl.text.trim(),
                  tipo: tipoSeleccionado,
                  estado: _estadoSeleccionado,
                  ciudad: _ciudadSeleccionada,
                  direccion: dirCtrl.text.trim().isEmpty ? null : dirCtrl.text.trim(),
                  telefono: telCtrl.text.trim().isEmpty ? null : telCtrl.text.trim(),
                  registradoPorDoctorId: widget.idDoctor,
                );

                if (nuevo != null && mounted) {
                  await _cargarCentros();
                  setState(() {
                    _centroSeleccionado = nuevo;
                    _direccionCtrl.text = nuevo.direccion ?? '';
                    if (nuevo.telefono != null && nuevo.telefono!.isNotEmpty) {
                      _telefonoCtrl.text = nuevo.telefono!;
                    }
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ "${nuevo.nombre}" agregado con éxito.'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  }
                }
              },
              child: const Text('Guardar Centro',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _resolverIdDoctorClinico() async {
    final currentUid = widget.idDoctor.isNotEmpty
        ? widget.idDoctor
        : (SupaFlow.client.auth.currentUser?.id ?? '');
    if (currentUid.isEmpty) return null;
    try {
      final doc = await DoctoresTable().queryRows(
        queryFn: (q) => q.eq('id', currentUid).limit(1),
      );
      if (doc.isEmpty) {
        await DoctoresTable().upsert({
          'id': currentUid,
          'esta_aprobado': false,
          'estado_verificacion': 'pendiente',
        });
      }
      return currentUid;
    } catch (e) {
      debugPrint('Error asegurando idDoctor para FK clínica: $e');
    }
    return currentUid;
  }

  Future<void> _guardarTodo() async {
    final nombreSede = _tipoLugar == 'privado'
        ? _nombrePrivadoCtrl.text.trim()
        : (_centroSeleccionado?.nombre ?? '');

    if (nombreSede.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor especifica el nombre del consultorio o centro médico.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_diasSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar al menos un día de atención para este consultorio.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      List<int> diasOrdenados = _diasSeleccionados.toList()..sort();
      String diasTexto = diasOrdenados.map((d) => _nombreDiaCorto(d)).join(', ');
      String horarioTexto =
          '$diasTexto: ${_formatearTimeOfDay(_horaInicio)} - ${_formatearTimeOfDay(_horaFin)}';
      if (_tienePausaAlmuerzo) {
        horarioTexto += ' (Almuerzo: ${_formatearTimeOfDay(_horaInicioAlmuerzo)} - ${_formatearTimeOfDay(_horaFinAlmuerzo)})';
      }

      // Sanitizar id_centro_medico: debe ser UUID válido o null
      String? idCentroMedicoSanitizado;
      if (_tipoLugar == 'centro_medico' && _centroSeleccionado != null) {
        final idRaw = _centroSeleccionado!.id;
        final isUuid = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(idRaw);
        if (isUuid) {
          idCentroMedicoSanitizado = idRaw;
        }
      }

      // Resolver ID del doctor compatible con la FK de la base clínica
      final idDoctorFk = await _resolverIdDoctorClinico();

      // Validar colisión de días y horarios con otras sedes existentes del mismo doctor
      if (idDoctorFk != null && idDoctorFk.isNotEmpty) {
        final sedeActualId = widget.sedeExistente?.id;
        final horaInicioMin = _horaInicio.hour * 60 + _horaInicio.minute;
        final horaFinMin = _horaFin.hour * 60 + _horaFin.minute;

        int parseMinutos(dynamic raw) {
          final s = raw?.toString() ?? '';
          final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
          if (m == null) return -1;
          return (int.tryParse(m.group(1)!) ?? 0) * 60 + (int.tryParse(m.group(2)!) ?? 0);
        }

        try {
          final sedesDoc = await DoctorSedesTable().queryRows(
            queryFn: (q) => q.eq('id_doctor', idDoctorFk),
          );
          final sedesMap = {for (final s in sedesDoc) s.id: s.nombreSede ?? 'Otra sede'};
          final horariosDoc = await HorariosDisponibilidadTable().queryRows(
            queryFn: (q) => q.eq('id_doctor', idDoctorFk).eq('activo', true),
          );

          final conflictos = <String>[];
          final diasEnConflicto = <int>{};
          final idsHorariosConflicto = <String>[];

          for (final h in horariosDoc) {
            if (sedeActualId != null && h.idSede == sedeActualId) continue;
            final dia = h.diaSemana ?? 0;
            if (!diasOrdenados.contains(dia)) continue;
            final iniEx = parseMinutos(h.horaInicio);
            final finEx = parseMinutos(h.horaFin);
            if (iniEx >= 0 && finEx > iniEx && horaInicioMin < finEx && horaFinMin > iniEx) {
              diasEnConflicto.add(dia);
              idsHorariosConflicto.add(h.id);
              final nomSede = sedesMap[h.idSede] ?? 'Otra sede';
              final iniTxt = h.horaInicio?.toString().substring(0, 5) ?? '';
              final finTxt = h.horaFin?.toString().substring(0, 5) ?? '';
              conflictos.add('• ${_nombreDiaCorto(dia)} ($iniTxt - $finTxt) en "$nomSede"');
            }
          }

          if (conflictos.isNotEmpty && mounted) {
            final decision = await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Expanded(child: Text('Horario en Conflicto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Este horario coincide con días y horas ya configurados en otra sede:',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      ...conflictos.toSet().map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                          )),
                      const SizedBox(height: 12),
                      const Text('¿Qué deseas hacer con los días que coinciden?', style: TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop('cancelar'),
                    child: const Text('Cancelar'),
                  ),
                  if (diasOrdenados.length > diasEnConflicto.length)
                    OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop('omitir'),
                      child: const Text('Omitir días repetidos'),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop('sobreescribir'),
                    child: const Text('Sobreescribir'),
                  ),
                ],
              ),
            );

            if (decision == null || decision == 'cancelar') {
              if (mounted) setState(() => _guardando = false);
              return;
            } else if (decision == 'omitir') {
              diasOrdenados = diasOrdenados.where((d) => !diasEnConflicto.contains(d)).toList();
              if (diasOrdenados.isEmpty) {
                if (mounted) setState(() => _guardando = false);
                return;
              }
              diasTexto = diasOrdenados.map((d) => _nombreDiaCorto(d)).join(', ');
              horarioTexto =
                  '$diasTexto: ${_formatearTimeOfDay(_horaInicio)} - ${_formatearTimeOfDay(_horaFin)}';
              if (_tienePausaAlmuerzo) {
                horarioTexto += ' (Almuerzo: ${_formatearTimeOfDay(_horaInicioAlmuerzo)} - ${_formatearTimeOfDay(_horaFinAlmuerzo)})';
              }
            } else if (decision == 'sobreescribir') {
              for (final hid in idsHorariosConflicto) {
                try {
                  await HorariosDisponibilidadTable().delete(matchingRows: (q) => q.eq('id', hid));
                } catch (_) {}
              }
            }
          }
        } catch (_) {}
      }

      String sedeId;

      final dataSede = {
        if (idDoctorFk != null) 'id_doctor': idDoctorFk,
        'nombre_sede': nombreSede,
        'tipo_lugar': _tipoLugar,
        'id_centro_medico': idCentroMedicoSanitizado,
        'numero_consultorio': _getUbicacionEspecificaTexto().isNotEmpty ? _getUbicacionEspecificaTexto() : null,
        'direccion': _direccionCtrl.text.trim().isNotEmpty ? _direccionCtrl.text.trim() : null,
        'ciudad': _ciudadSeleccionada.isNotEmpty ? _ciudadSeleccionada : null,
        'estado': _estadoSeleccionado.isNotEmpty ? _estadoSeleccionado : null,
        'telefono_contacto': _telefonoCtrl.text.trim().isNotEmpty ? _telefonoCtrl.text.trim() : null,
        'telefono_visible': _telefonoVisible,
        'latitud': _latitud,
        'longitud': _longitud,
        'duracion_consulta_minutos': _duracionMinutos,
        'modalidad_atencion': _modalidad,
        'dias_atencion': diasTexto,
        'horario_texto': horarioTexto,
      };

      if (widget.sedeExistente == null) {
        try {
          final res = await DoctorSedesTable().insert(dataSede);
          sedeId = res.id;
        } catch (e) {
          debugPrint('Guardando nueva sede con columnas base: $e');
          String direccionRespaldo = _direccionCtrl.text.trim();
          final ubiDetallada = _getUbicacionEspecificaTexto();
          if (ubiDetallada.isNotEmpty) {
            direccionRespaldo = direccionRespaldo.isNotEmpty
                ? '$direccionRespaldo ($ubiDetallada)'
                : ubiDetallada;
          }
          if (_estadoSeleccionado.isNotEmpty && !direccionRespaldo.contains(_estadoSeleccionado)) {
            direccionRespaldo = direccionRespaldo.isNotEmpty
                ? '$direccionRespaldo, $_estadoSeleccionado'
                : _estadoSeleccionado;
          }

          final baseDataSede = <String, dynamic>{
            if (idDoctorFk != null) 'id_doctor': idDoctorFk,
            'nombre_sede': nombreSede,
            'direccion': direccionRespaldo.isNotEmpty ? direccionRespaldo : null,
            'ciudad': _ciudadSeleccionada.isNotEmpty ? _ciudadSeleccionada : null,
            'telefono_contacto': _telefonoCtrl.text.trim().isNotEmpty ? _telefonoCtrl.text.trim() : null,
          };

          final res = await DoctorSedesTable().insert(baseDataSede);
          sedeId = res.id;
        }
      } else {
        sedeId = widget.sedeExistente!.id;
        try {
          await DoctorSedesTable().update(
            data: dataSede,
            matchingRows: (q) => q.eq('id', sedeId),
          );
        } catch (e) {
          debugPrint('Actualizando sede con columnas base: $e');
          String direccionRespaldo = _direccionCtrl.text.trim();
          final ubiDetallada = _getUbicacionEspecificaTexto();
          if (ubiDetallada.isNotEmpty) {
            direccionRespaldo = direccionRespaldo.isNotEmpty
                ? '$direccionRespaldo ($ubiDetallada)'
                : ubiDetallada;
          }
          if (_estadoSeleccionado.isNotEmpty && !direccionRespaldo.contains(_estadoSeleccionado)) {
            direccionRespaldo = direccionRespaldo.isNotEmpty
                ? '$direccionRespaldo, $_estadoSeleccionado'
                : _estadoSeleccionado;
          }

          final baseDataSede = <String, dynamic>{
            'nombre_sede': nombreSede,
            'direccion': direccionRespaldo.isNotEmpty ? direccionRespaldo : null,
            'ciudad': _ciudadSeleccionada.isNotEmpty ? _ciudadSeleccionada : null,
            'telefono_contacto': _telefonoCtrl.text.trim().isNotEmpty ? _telefonoCtrl.text.trim() : null,
          };

          await DoctorSedesTable().update(
            data: baseDataSede,
            matchingRows: (q) => q.eq('id', sedeId),
          );
        }
      }

      // Sincronizar horarios de disponibilidad si tenemos un ID de sede válido
      if (sedeId.isNotEmpty) {
        // Eliminar horarios anteriores de esta sede
        try {
          await HorariosDisponibilidadTable().delete(
            matchingRows: (q) => q.eq('id_sede', sedeId),
          );
        } catch (_) {}

        final horaInicioMin = _horaInicio.hour * 60 + _horaInicio.minute;
        final horaFinMin = _horaFin.hour * 60 + _horaFin.minute;
        final almuerzoInicioMin = _horaInicioAlmuerzo.hour * 60 + _horaInicioAlmuerzo.minute;
        final almuerzoFinMin = _horaFinAlmuerzo.hour * 60 + _horaFinAlmuerzo.minute;

        final bool dividirPorAlmuerzo = _tienePausaAlmuerzo &&
            almuerzoInicioMin > horaInicioMin &&
            almuerzoFinMin < horaFinMin &&
            almuerzoFinMin > almuerzoInicioMin;

        String formatoHoraDb(TimeOfDay t) =>
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

        for (final dia in diasOrdenados) {
          if (dividirPorAlmuerzo) {
            // Bloque 1 (Mañana / Pre-almuerzo)
            await HorariosDisponibilidadTable().insert({
              if (idDoctorFk != null) 'id_doctor': idDoctorFk,
              'id_sede': sedeId,
              'dia_semana': dia,
              'hora_inicio': formatoHoraDb(_horaInicio),
              'hora_fin': formatoHoraDb(_horaInicioAlmuerzo),
              'modalidad_atencion': _modalidad,
              'cupo_maximo': _cupoMaximo,
              'activo': true,
            });

            // Bloque 2 (Tarde / Post-almuerzo)
            await HorariosDisponibilidadTable().insert({
              if (idDoctorFk != null) 'id_doctor': idDoctorFk,
              'id_sede': sedeId,
              'dia_semana': dia,
              'hora_inicio': formatoHoraDb(_horaFinAlmuerzo),
              'hora_fin': formatoHoraDb(_horaFin),
              'modalidad_atencion': _modalidad,
              'cupo_maximo': _cupoMaximo,
              'activo': true,
            });
          } else {
            // Bloque continuo
            await HorariosDisponibilidadTable().insert({
              if (idDoctorFk != null) 'id_doctor': idDoctorFk,
              'id_sede': sedeId,
              'dia_semana': dia,
              'hora_inicio': formatoHoraDb(_horaInicio),
              'hora_fin': formatoHoraDb(_horaFin),
              'modalidad_atencion': _modalidad,
              'cupo_maximo': _cupoMaximo,
              'activo': true,
            });
          }
        }
      }

      widget.onGuardado();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.sedeExistente == null
                ? '✅ Consultorio registrado exitosamente.'
                : '✅ Consultorio actualizado exitosamente.'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando consultorio/sede: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Error al Guardar'),
              ],
            ),
            content: Text(
              'No se pudo registrar el consultorio:\n$e\n\nPor favor intenta nuevamente o verifica los datos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.sedeExistente == null
                      ? 'Registrar Consultorio'
                      : 'Editar Consultorio',
                  style: GoogleFonts.mooli(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Contenido con Scroll
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Selector de Tipo de Lugar
                Text(
                  '1. Tipo de Consultorio / Ubicación',
                  style: GoogleFonts.mooli(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildTipoCard(
                        id: 'centro_medico',
                        titulo: 'Clínica / Hospital',
                        subtitulo: 'Centro Asistencial Compartido',
                        icon: Icons.local_hospital,
                        color: const Color(0xFF3949AB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTipoCard(
                        id: 'privado',
                        titulo: 'Consultorio Privado',
                        subtitulo: 'Oficina / Local Personal',
                        icon: Icons.home_work_rounded,
                        color: const Color(0xFF00796B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. Ubicación Geográfica (Estado y Ciudad)
                Text(
                  '2. Ubicación en Venezuela',
                  style: GoogleFonts.mooli(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Estado
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: VenezuelaLocations.getEstados().contains(_estadoSeleccionado)
                            ? _estadoSeleccionado
                            : (VenezuelaLocations.getEstados().isNotEmpty ? VenezuelaLocations.getEstados().first : null),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: VenezuelaLocations.getEstados()
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (nuevoEstado) {
                          if (nuevoEstado != null && nuevoEstado != _estadoSeleccionado) {
                            setState(() {
                              _estadoSeleccionado = nuevoEstado;
                              final ciudades =
                                  VenezuelaLocations.getCiudadesPorEstado(nuevoEstado);
                              _ciudadSeleccionada =
                                  ciudades.isNotEmpty ? ciudades.first : '';
                              _centroSeleccionado = null;
                            });
                            _cargarCentros();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Ciudad
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _ciudadSeleccionada.isNotEmpty &&
                                VenezuelaLocations.getCiudadesPorEstado(_estadoSeleccionado)
                                    .contains(_ciudadSeleccionada)
                            ? _ciudadSeleccionada
                            : (VenezuelaLocations.getCiudadesPorEstado(_estadoSeleccionado).isNotEmpty
                                ? VenezuelaLocations.getCiudadesPorEstado(_estadoSeleccionado).first
                                : null),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Ciudad',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: VenezuelaLocations.getCiudadesPorEstado(_estadoSeleccionado)
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (nuevaCiudad) {
                          if (nuevaCiudad != null) {
                            setState(() {
                              _ciudadSeleccionada = nuevaCiudad;
                              _centroSeleccionado = null;
                            });
                            _cargarCentros();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Selección de Centro o Nombre Privado
                if (_tipoLugar == 'centro_medico') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '3. Centro Médico / Clínica',
                        style: GoogleFonts.mooli(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.primary,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('+ Agregar Centro',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _abrirDialogoNuevoCentro,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_cargandoCentros)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_centrosDisponibles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No hay clínicas registradas aún en esta ciudad.',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Toca "+ Agregar Centro" para registrar la clínica u hospital.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal),
                            icon: const Icon(Icons.add, size: 16, color: Colors.white),
                            label: const Text('Agregar Clínica / Hospital',
                                style: TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: _abrirDialogoNuevoCentro,
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<CentroMedicoItem>(
                      initialValue: _centroSeleccionado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Selecciona la Clínica u Hospital *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_hospital, color: Colors.teal),
                      ),
                      items: _centrosDisponibles
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  '${c.nombre} (${c.tipo})',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                              ))
                          .toList(),
                      onChanged: (nuevo) {
                        setState(() {
                          _centroSeleccionado = nuevo;
                          if (nuevo?.direccion != null) {
                            _direccionCtrl.text = nuevo!.direccion!;
                          }
                          if (nuevo?.telefono != null && nuevo!.telefono!.isNotEmpty) {
                            _telefonoCtrl.text = nuevo.telefono!;
                          }
                        });
                      },
                    ),
                  if (_centroSeleccionado != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFF16A34A), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _centroSeleccionado!.direccion?.isNotEmpty == true
                                  ? _centroSeleccionado!.direccion!
                                  : '$_ciudadSeleccionada, $_estadoSeleccionado',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF00796B)),
                            label: const Text('Google Maps', style: TextStyle(fontSize: 11.5, color: Color(0xFF00796B), fontWeight: FontWeight.bold)),
                            onPressed: () {
                              LocationMapsService.abrirEnGoogleMaps(
                                nombreLugar: _centroSeleccionado!.nombre,
                                direccion: _centroSeleccionado!.direccion,
                                ciudad: _ciudadSeleccionada,
                                estado: _estadoSeleccionado,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Piso y Número de consultorio / local
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: _pisoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Piso / Nivel *',
                            hintText: 'Ej. 2, PB, 1',
                            helperText: 'Piso o planta',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.layers_rounded, color: Colors.teal),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: _numeroLocalCtrl,
                          decoration: const InputDecoration(
                            labelText: 'N° / Letra Consultorio *',
                            hintText: 'Ej. 4B, 102, A',
                            helperText: 'Número o letra',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.meeting_room, color: Colors.teal),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Consultorio Personal Privado
                  Text(
                    '3. Datos del Consultorio Privado',
                    style: GoogleFonts.mooli(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nombrePrivadoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Consultorio / Oficina *',
                      hintText: 'Ej. Consultorio Privado Dr. Rodríguez',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business, color: Colors.teal),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _direccionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Dirección o Punto de Referencia *',
                            hintText: 'Ej. Av. Bolívar entre Calles 8 y 9, Valera',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.pin_drop, color: Colors.teal),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00796B).withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          tooltip: 'Ubicar en el mapa interactivo',
                          icon: const Icon(Icons.edit_location_alt_rounded, color: Colors.white, size: 24),
                          onPressed: () async {
                            final result = await MapLocationPickerDialog.mostrar(
                              context,
                              direccionInicial: _direccionCtrl.text.trim().isNotEmpty
                                  ? _direccionCtrl.text.trim()
                                  : _nombrePrivadoCtrl.text.trim(),
                              ciudadInicial: _ciudadSeleccionada,
                              estadoInicial: _estadoSeleccionado,
                              latitudInicial: _latitud,
                              longitudInicial: _longitud,
                            );

                            if (result == null) return;
                            if (!mounted) return;

                            final matchedEstado = VenezuelaLocations.matchEstado(result.estado);
                            final matchedCiudad = VenezuelaLocations.matchCiudad(result.ciudad, matchedEstado ?? _estadoSeleccionado);

                            setState(() {
                              _direccionCtrl.text = result.direccion;
                              _latitud = result.latitud;
                              _longitud = result.longitud;
                              if (matchedEstado != null) {
                                _estadoSeleccionado = matchedEstado;
                              }
                              final ciudades = VenezuelaLocations.getCiudadesPorEstado(_estadoSeleccionado);
                              if (matchedCiudad != null && ciudades.contains(matchedCiudad)) {
                                _ciudadSeleccionada = matchedCiudad;
                              } else if (ciudades.isNotEmpty && !ciudades.contains(_ciudadSeleccionada)) {
                                _ciudadSeleccionada = ciudades.first;
                              }
                            });

                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('📍 Ubicación fijada: ${result.direccion}'),
                                  backgroundColor: const Color(0xFF00796B),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: _pisoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Piso / Nivel (Opcional)',
                            hintText: 'Ej. 2, PB, 1',
                            helperText: 'Piso o planta',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.layers_rounded, color: Colors.teal),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: _numeroLocalCtrl,
                          decoration: const InputDecoration(
                            labelText: 'N° / Letra Consultorio (Opcional)',
                            hintText: 'Ej. 4B, 102, A',
                            helperText: 'Número o letra',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.meeting_room, color: Colors.teal),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_latitud != null && _longitud != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: InkWell(
                      onTap: () {
                        LocationMapsService.abrirGoogleMaps(
                          direccion: _direccionCtrl.text.trim(),
                          ciudad: _ciudadSeleccionada,
                          estado: _estadoSeleccionado,
                          latitud: _latitud,
                          longitud: _longitud,
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Coordenadas (${_latitud!.toStringAsFixed(4)}, ${_longitud!.toStringAsFixed(4)}). Toca para ver en Google Maps.',
                              style: TextStyle(fontSize: 11, color: Colors.teal.shade800, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de Contacto del Consultorio',
                    hintText: 'Ej. 0271-2210000 o 0414-1234567',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone, color: Colors.teal),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade100),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      '¿Mostrar este teléfono a los pacientes en la app?',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _telefonoVisible
                          ? 'Visible públicamente para citas y dudas de pacientes.'
                          : 'Oculto para pacientes. Solo tú y tu personal lo verán.',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                    ),
                    value: _telefonoVisible,
                    activeThumbColor: const Color(0xFF00796B),
                    activeTrackColor: const Color(0xFF80CBC4),
                    dense: true,
                    onChanged: (val) => setState(() => _telefonoVisible = val),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),

                // 4. Configuración de Horario para esta Sede
                Text(
                  '4. Horarios y Días de Atención en esta Sede',
                  style: GoogleFonts.mooli(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Selecciona los días de la semana en que atiendes en esta ubicación:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),

                // Chips de días
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDiaChip(1, 'Lunes'),
                    _buildDiaChip(2, 'Martes'),
                    _buildDiaChip(3, 'Miércoles'),
                    _buildDiaChip(4, 'Jueves'),
                    _buildDiaChip(5, 'Viernes'),
                    _buildDiaChip(6, 'Sábado'),
                    _buildDiaChip(7, 'Domingo'),
                  ],
                ),
                const SizedBox(height: 16),

                // Selector de Horas Inicio y Fin
                Row(
                  children: [
                    Expanded(
                      child: _buildTimePickerTile(
                        label: 'Hora Inicio',
                        time: _horaInicio,
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _horaInicio,
                          );
                          if (t != null) setState(() => _horaInicio = t);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimePickerTile(
                        label: 'Hora Fin',
                        time: _horaFin,
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _horaFin,
                          );
                          if (t != null) setState(() => _horaFin = t);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Pausa de Almuerzo / Hora de Comer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Row(
                          children: [
                            Icon(Icons.restaurant_rounded, size: 18, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('Pausa de Almuerzo / Comida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        subtitle: const Text('Bloquea citas de pacientes durante tu horario de comida.', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                        value: _tienePausaAlmuerzo,
                        activeTrackColor: Colors.teal,
                        onChanged: (v) => setState(() => _tienePausaAlmuerzo = v),
                      ),
                      if (_tienePausaAlmuerzo) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimePickerTile(
                                label: 'Inicio Almuerzo',
                                time: _horaInicioAlmuerzo,
                                onTap: () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: _horaInicioAlmuerzo,
                                    helpText: 'INICIO DE ALMUERZO',
                                  );
                                  if (t != null) setState(() => _horaInicioAlmuerzo = t);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTimePickerTile(
                                label: 'Fin Almuerzo',
                                time: _horaFinAlmuerzo,
                                onTap: () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: _horaFinAlmuerzo,
                                    helpText: 'FIN DE ALMUERZO',
                                  );
                                  if (t != null) setState(() => _horaFinAlmuerzo = t);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Modalidad de Atención
                DropdownButtonFormField<String>(
                  initialValue: _modalidad,
                  decoration: const InputDecoration(
                    labelText: 'Modalidad de Atención',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.schedule, color: Colors.teal),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'hora_fija',
                      child: Text('Hora Fija (Cita Agendada)'),
                    ),
                    DropdownMenuItem(
                      value: 'orden_llegada',
                      child: Text('Por Orden de Llegada'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _modalidad = val);
                  },
                ),
                const SizedBox(height: 14),

                // Duración y Cupo
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _duracionMinutos,
                        decoration: const InputDecoration(
                          labelText: 'Duración Cita',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 min')),
                          DropdownMenuItem(value: 20, child: Text('20 min')),
                          DropdownMenuItem(value: 30, child: Text('30 min')),
                          DropdownMenuItem(value: 45, child: Text('45 min')),
                          DropdownMenuItem(value: 60, child: Text('60 min')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _duracionMinutos = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _cupoMaximo,
                        decoration: const InputDecoration(
                          labelText: 'Cupo Máx / Día',
                          border: OutlineInputBorder(),
                        ),
                        items: [5, 10, 15, 20, 25, 30, 40, 50]
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text('$c pac.')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _cupoMaximo = val);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                // Botón Guardar
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _guardando ? null : _guardarTodo,
                    child: _guardando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            widget.sedeExistente == null
                                ? 'Guardar Consultorio y Horario'
                                : 'Actualizar Consultorio',
                            style: GoogleFonts.mooli(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoCard({
    required String id,
    required String titulo,
    required String subtitulo,
    required IconData icon,
    required Color color,
  }) {
    final seleccionado = _tipoLugar == id;
    return InkWell(
      onTap: () => setState(() => _tipoLugar = id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionado ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? color : Colors.grey.shade300,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: seleccionado ? color : Colors.grey, size: 24),
                if (seleccionado)
                  Icon(Icons.check_circle, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: seleccionado ? color : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaChip(int dia, String label) {
    final activo = _diasSeleccionados.contains(dia);
    return FilterChip(
      label: Text(label),
      selected: activo,
      selectedColor: const Color(0xFF00796B),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: activo ? Colors.white : Colors.black87,
        fontSize: 12,
        fontWeight: activo ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (val) {
        setState(() {
          if (val) {
            _diasSeleccionados.add(dia);
          } else {
            _diasSeleccionados.remove(dia);
          }
        });
      },
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatearTimeOfDay(time),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.access_time, size: 18, color: Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatearTimeOfDay(TimeOfDay t) {
    final hora = t.hour;
    final min = t.minute.toString().padLeft(2, '0');
    final ampm = hora >= 12 ? 'PM' : 'AM';
    final hora12 = hora == 0 ? 12 : (hora > 12 ? hora - 12 : hora);
    return '$hora12:$min $ampm';
  }

  String _nombreDiaCorto(int dia) {
    switch (dia) {
      case 1:
        return 'Lun';
      case 2:
        return 'Mar';
      case 3:
        return 'Mié';
      case 4:
        return 'Jue';
      case 5:
        return 'Vie';
      case 6:
        return 'Sáb';
      case 7:
        return 'Dom';
      default:
        return 'Día $dia';
    }
  }
}

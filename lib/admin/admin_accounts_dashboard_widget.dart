import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/admin_accounts_service.dart';
import '/services/admin_tenant_service.dart';
import '/services/i18n_service.dart';
import 'admin_doctor_tenants_modal_widget.dart';

/// Panel Administrativo para gestión integral de cuentas, estados y estadísticas.
class AdminAccountsDashboardWidget extends StatefulWidget {
  const AdminAccountsDashboardWidget({super.key});

  static const String routeName = 'AdminAccountsDashboard';
  static const String routePath = '/adminAccountsDashboard';

  @override
  State<AdminAccountsDashboardWidget> createState() => _AdminAccountsDashboardWidgetState();
}

class _AdminAccountsDashboardWidgetState extends State<AdminAccountsDashboardWidget> {
  bool _isLoading = true;
  AdminPlatformStats _stats = AdminPlatformStats.vacio();
  List<AdminAccountItem> _todasLasCuentas = [];
  String _filtroRol = 'todos';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    I18nService.instance.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    I18nService.instance.removeListener(_onLocaleChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    final stats = await AdminAccountsService.instance.obtenerEstadisticas();
    final cuentas = await AdminAccountsService.instance.listarCuentas();
    if (mounted) setState(() { _stats = stats; _todasLasCuentas = cuentas; _isLoading = false; });
  }

  List<AdminAccountItem> get _cuentasFiltradas {
    return _todasLasCuentas.where((c) {
      final q = _searchQuery.toLowerCase();
      final matchesQuery = q.isEmpty ||
          c.nombre.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.telefono.toLowerCase().contains(q) ||
          (c.especialidad?.toLowerCase().contains(q) ?? false);
      if (!matchesQuery) return false;
      switch (_filtroRol) {
        case 'doctores': return c.esDoctor;
        case 'pacientes': return c.esPaciente && !c.estaSuspendido;
        case 'secretarias': return c.esSecretaria;
        case 'admins': return c.esAdmin;
        case 'suspendidos': return c.estaSuspendido;
        case 'solo_lectura': return c.esDoctor && c.esSoloLectura;
        default: return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.isSpanish;
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF249689)))
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              color: const Color(0xFF249689),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32.0 : 16.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(theme, isEs, isDesktop),
                    const SizedBox(height: 18.0),
                    _buildSearchAndFilters(theme, isEs),
                    const SizedBox(height: 16.0),
                    _buildAccountsHeader(theme, isEs),
                    const SizedBox(height: 12.0),
                    _buildAccountsList(theme, isEs),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid(FlutterFlowTheme theme, bool isEs, bool isDesktop) {
    final cards = [
      _buildStatCard(title: isEs ? 'Total Usuarios' : 'Total Users', value: '${_stats.totalUsuarios}', icon: Icons.people_alt_rounded, color: const Color(0xFF3B82F6), subtitle: isEs ? 'Registrados' : 'Registered'),
      _buildStatCard(title: isEs ? 'Pacientes' : 'Patients', value: '${_stats.totalPacientes}', icon: Icons.personal_injury_rounded, color: const Color(0xFF06B6D4), subtitle: isEs ? 'En catálogo' : 'In directory'),
      _buildStatCard(
        title: isEs ? 'Doctores' : 'Doctors',
        value: '${_stats.totalDoctores}',
        icon: Icons.medical_services_rounded,
        color: const Color(0xFF10B981),
        subtitle: '${_stats.doctoresAprobados} ${isEs ? 'aprobados' : 'app.'} · ${_stats.doctoresPendientes} pend.',
        onTap: () => AdminDoctorTenantsModalWidget.show(context, onUpdated: _cargarDatos),
      ),
      _buildStatCard(
        title: isEs ? 'Clínicas / Grupos' : 'Clinics / Groups',
        value: '${_stats.totalGruposMedicos > 0 ? _stats.totalGruposMedicos : _stats.tenantsActivos}',
        icon: Icons.domain_rounded,
        color: const Color(0xFF8B5CF6),
        subtitle: isEs ? 'Grupos de doctores' : 'Doctor groups',
      ),
    ];
    if (isDesktop) return Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5.0), child: c))).toList());
    return Column(children: [
      Row(children: [Expanded(child: cards[0]), const SizedBox(width: 8.0), Expanded(child: cards[1])]),
      const SizedBox(height: 8.0),
      Row(children: [Expanded(child: cards[2]), const SizedBox(width: 8.0), Expanded(child: cards[3])]),
    ]);
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color, required String subtitle, VoidCallback? onTap}) {
    final theme = FlutterFlowTheme.of(context);
    final cardContent = Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: theme.secondaryBackground, borderRadius: BorderRadius.circular(12.0), border: Border.all(color: theme.alternate, width: 1.0)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: GoogleFonts.mooli(fontSize: 12.0, color: theme.secondaryText, fontWeight: FontWeight.w600)),
          Container(padding: const EdgeInsets.all(5.0), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(icon, color: color, size: 16.0)),
        ]),
        const SizedBox(height: 4.0),
        Text(value, style: GoogleFonts.mooli(fontSize: 20.0, fontWeight: FontWeight.bold, color: theme.primaryText)),
        const SizedBox(height: 2.0),
        Text(subtitle, style: GoogleFonts.mooli(fontSize: 11.0, color: theme.secondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12.0), child: cardContent);
    }
    return cardContent;
  }

  Widget _buildSearchAndFilters(FlutterFlowTheme theme, bool isEs) {
    final numTodos = _todasLasCuentas.length;
    final numDoctores = _todasLasCuentas.where((c) => c.esDoctor).length;
    final numPacientes = _todasLasCuentas.where((c) => c.esPaciente).length;
    final numSecretarias = _todasLasCuentas.where((c) => c.esSecretaria).length;
    final numAdmins = _todasLasCuentas.where((c) => c.esAdmin).length;
    final numSuspendidos = _todasLasCuentas.where((c) => c.estaSuspendido).length;
    final numSoloLectura = _todasLasCuentas.where((c) => c.esDoctor && c.esSoloLectura).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _searchCtrl,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        decoration: InputDecoration(
          hintText: isEs ? 'Buscar por nombre, email, teléfono o especialidad...' : 'Search by name, email, phone...',
          hintStyle: GoogleFonts.mooli(fontSize: 13.0, color: theme.secondaryText),
          prefixIcon: const Icon(Icons.search_rounded, size: 20.0),
          suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18.0), onPressed: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; })) : null,
          filled: true,
          fillColor: theme.secondaryBackground,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: theme.alternate)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: theme.alternate)),
        ),
      ),
      const SizedBox(height: 8.0),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _buildFilterChip('todos', isEs ? 'Todos ($numTodos)' : 'All ($numTodos)'),
          const SizedBox(width: 6.0),
          _buildFilterChip('doctores', isEs ? 'Doctores ($numDoctores)' : 'Doctors ($numDoctores)'),
          const SizedBox(width: 6.0),
          _buildFilterChip('pacientes', isEs ? 'Pacientes ($numPacientes)' : 'Patients ($numPacientes)'),
          const SizedBox(width: 6.0),
          _buildFilterChip('secretarias', isEs ? 'Secretarias ($numSecretarias)' : 'Secretaries ($numSecretarias)'),
          const SizedBox(width: 6.0),
          _buildFilterChip('admins', isEs ? 'Admins ($numAdmins)' : 'Admins ($numAdmins)'),
          const SizedBox(width: 6.0),
          _buildFilterChip('suspendidos', isEs ? 'Suspendidos ($numSuspendidos)' : 'Suspended ($numSuspendidos)'),
          const SizedBox(width: 6.0),
          _buildFilterChip('solo_lectura', isEs ? 'Solo Lectura ($numSoloLectura)' : 'Read-Only ($numSoloLectura)'),
        ]),
      ),
    ]);
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _filtroRol == key;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.mooli(fontSize: 12.0, fontWeight: selected ? FontWeight.bold : FontWeight.w500, color: selected ? Colors.white : null)),
      selected: selected,
      selectedColor: const Color(0xFF249689),
      onSelected: (_) => setState(() => _filtroRol = key),
    );
  }

  Widget _buildAccountsHeader(FlutterFlowTheme theme, bool isEs) {
    final total = _cuentasFiltradas.length;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(isEs ? 'Listado de Cuentas ($total)' : 'Account Directory ($total)', style: GoogleFonts.mooli(fontSize: 15.0, fontWeight: FontWeight.bold, color: theme.primaryText)),
      if (_stats.doctoresPendientes > 0)
        GestureDetector(
          onTap: () => AdminDoctorTenantsModalWidget.show(context, onUpdated: _cargarDatos),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8.0)),
            child: Text(isEs ? '${_stats.doctoresPendientes} por activar' : '${_stats.doctoresPendientes} pending', style: GoogleFonts.mooli(fontSize: 11.0, color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ),
    ]);
  }

  Widget _buildAccountsList(FlutterFlowTheme theme, bool isEs) {
    final lista = _cuentasFiltradas;
    if (lista.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(children: [
            Icon(Icons.person_search_rounded, size: 48.0, color: theme.secondaryText),
            const SizedBox(height: 8.0),
            Text(isEs ? 'No se encontraron cuentas con los filtros actuales.' : 'No accounts found.', style: GoogleFonts.mooli(color: theme.secondaryText)),
          ]),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10.0),
      itemBuilder: (_, i) => _buildAccountCard(theme, isEs, lista[i]),
    );
  }

  Widget _buildAccountCard(FlutterFlowTheme theme, bool isEs, AdminAccountItem account) {
    final badgeColor = account.estaSuspendido ? Colors.redAccent : (account.esDoctor ? const Color(0xFF10B981) : (account.esAdmin ? const Color(0xFF8B5CF6) : (account.esSecretaria ? const Color(0xFF0D9488) : const Color(0xFF3B82F6))));
    final rolNombre = account.estaSuspendido ? (isEs ? 'SUSPENDIDO' : 'SUSPENDED') : (account.esDoctor ? 'DOCTOR' : (account.esAdmin ? 'ADMIN' : (account.esSecretaria ? (isEs ? 'SECRETARIA' : 'SECRETARY') : (isEs ? 'PACIENTE' : 'PATIENT'))));

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: account.estaSuspendido ? Colors.redAccent.withValues(alpha: 0.4) : theme.alternate, width: 1.0),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 19.0,
            backgroundColor: badgeColor.withValues(alpha: 0.15),
            backgroundImage: account.fotoUrl != null && account.fotoUrl!.isNotEmpty ? NetworkImage(account.fotoUrl!) : null,
            child: account.fotoUrl == null || account.fotoUrl!.isEmpty ? Text(account.nombre.isNotEmpty ? account.nombre[0].toUpperCase() : 'U', style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 13.0)) : null,
          ),
          const SizedBox(width: 10.0),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(account.nombre, style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.primaryText)),
            Text(account.email, style: GoogleFonts.mooli(fontSize: 11.5, color: theme.secondaryText)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
            decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6.0)),
            child: Text(rolNombre, style: GoogleFonts.mooli(fontSize: 10.0, fontWeight: FontWeight.bold, color: badgeColor)),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20.0),
            onSelected: (val) => _handleAction(val, account, isEs),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'suspender',
                child: Row(children: [
                  Icon(account.estaSuspendido ? Icons.check_circle_outline_rounded : Icons.block_rounded, color: account.estaSuspendido ? Colors.green : Colors.orange, size: 18.0),
                  const SizedBox(width: 8.0),
                  Text(account.estaSuspendido ? (isEs ? 'Reactivar cuenta' : 'Reactivate') : (isEs ? 'Suspender cuenta' : 'Suspend')),
                ]),
              ),
              PopupMenuItem(
                value: 'rol',
                child: Row(children: [
                  const Icon(Icons.manage_accounts_rounded, size: 18.0, color: Color(0xFF249689)),
                  const SizedBox(width: 8.0),
                  Text(isEs ? 'Cambiar Rol' : 'Change Role'),
                ]),
              ),
              if (account.esDoctor)
                PopupMenuItem(
                  value: 'pago',
                  child: Row(children: [
                    Icon(account.esSoloLectura ? Icons.price_check_rounded : Icons.pause_circle_outline_rounded, size: 18.0, color: account.esSoloLectura ? Colors.green : Colors.orange),
                    const SizedBox(width: 8.0),
                    Text(account.esSoloLectura ? (isEs ? 'Poner Al Día (Activo)' : 'Mark Paid (Full)') : (isEs ? 'Solo Lectura (Falta Pago)' : 'Read-Only (Unpaid)')),
                  ]),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'eliminar',
                child: Row(children: [
                  const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18.0),
                  const SizedBox(width: 8.0),
                  Text(isEs ? 'Eliminar cuenta' : 'Delete account', style: const TextStyle(color: Colors.redAccent)),
                ]),
              ),
            ],
          ),
        ]),
        if (account.esDoctor) ...[
          const SizedBox(height: 6.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(color: theme.primaryBackground, borderRadius: BorderRadius.circular(6.0)),
            child: Row(children: [
              const Icon(Icons.medical_information_outlined, size: 15.0, color: Color(0xFF10B981)),
              const SizedBox(width: 6.0),
              Text(account.especialidad ?? (isEs ? 'Medicina General' : 'General Practice'), style: GoogleFonts.mooli(fontSize: 11.5, fontWeight: FontWeight.w600)),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(6.0),
                onTap: () => AdminDoctorTenantsModalWidget.showConfigForDoctor(
                  context,
                  DoctorPendingRequest(
                    idDoctor: account.id,
                    nombre: account.nombre,
                    email: account.email,
                    telefono: account.telefono,
                    especialidad: account.especialidad ?? (isEs ? 'Medicina General' : 'General Practice'),
                    estado: account.estaAprobado ? 'aprobado' : (account.estadoVerificacion ?? 'pendiente'),
                    createdAt: account.createdAt,
                    dbUrl: account.tenantDbUrl,
                    dbAnonKey: account.tenantDbAnonKey,
                    estaAprobado: account.estaAprobado,
                    tenantActivo: account.tenantActivo ?? account.estaAprobado,
                  ),
                  onUpdated: _cargarDatos,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  child: Text(
                    account.esSoloLectura
                        ? (isEs ? 'Solo Lectura (Pago Pendiente)' : 'Read-Only (Pending)')
                        : (account.estaAprobado ? (isEs ? 'Activo' : 'Active') : (isEs ? 'Pendiente' : 'Pending')),
                    style: GoogleFonts.mooli(
                      fontSize: 11.0,
                      color: account.esSoloLectura ? Colors.orange.shade800 : (account.estaAprobado ? Colors.green : Colors.orange),
                      fontWeight: FontWeight.bold,
                      decoration: account.estaAprobado ? TextDecoration.none : TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Future<void> _handleAction(String action, AdminAccountItem account, bool isEs) async {
    if (action == 'pago') {
      final nuevoEstado = account.esSoloLectura ? 'al_dia' : 'solo_lectura';
      final ok = await AdminAccountsService.instance.cambiarEstadoPago(idDoctor: account.id, nuevoEstadoPago: nuevoEstado);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: nuevoEstado == 'al_dia' ? Colors.green : Colors.orange,
          content: Text(nuevoEstado == 'al_dia'
              ? (isEs ? 'Consultorio de ${account.nombre} puesto Al Día (Acceso Total).' : 'Account marked Paid.')
              : (isEs ? 'Consultorio de ${account.nombre} en Solo Lectura (Contingencia).' : 'Account in Read-Only Mode.')),
        ));
        _cargarDatos();
      }
    } else if (action == 'suspender') {
      final nuevoEstado = !account.estaSuspendido;
      final ok = await AdminAccountsService.instance.alternarSuspension(idUsuario: account.id, rolActual: account.rol, suspender: nuevoEstado);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: nuevoEstado ? Colors.orange : Colors.green,
          content: Text(nuevoEstado ? (isEs ? 'Cuenta suspendida.' : 'Account suspended.') : (isEs ? 'Cuenta reactivada.' : 'Account reactivated.')),
        ));
        _cargarDatos();
      }
    } else if (action == 'rol') {
      _mostrarModalCambioRol(account, isEs);
    } else if (action == 'eliminar') {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isEs ? '¿Eliminar Cuenta?' : 'Delete Account?'),
          content: Text(isEs ? 'Esta acción eliminará el perfil de "${account.nombre}" y sus datos.' : 'This will delete "${account.nombre}" and data.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(isEs ? 'Cancelar' : 'Cancel')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), onPressed: () => Navigator.of(ctx).pop(true), child: Text(isEs ? 'Eliminar Definitivamente' : 'Delete Permanently')),
          ],
        ),
      );
      if (confirmar == true && mounted) {
        final ok = await AdminAccountsService.instance.eliminarCuenta(idUsuario: account.id, esDoctor: account.esDoctor);
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text(isEs ? 'Cuenta eliminada.' : 'Account deleted.')));
          _cargarDatos();
        }
      }
    }
  }

  void _mostrarModalCambioRol(AdminAccountItem account, bool isEs) {
    String nuevoRol = account.rol.toLowerCase() == 'doctor' ? 'doctor' : (account.esAdmin ? 'admin' : (account.esSecretaria ? 'secretaria' : 'paciente'));
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isEs ? 'Cambiar Rol de Usuario' : 'Change User Role', style: GoogleFonts.mooli(fontSize: 16.0, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4.0),
            Text('${account.nombre} (${account.email})', style: GoogleFonts.mooli(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 14.0),
            DropdownButtonFormField<String>(
              initialValue: nuevoRol,
              items: [
                DropdownMenuItem(value: 'paciente', child: Text(isEs ? 'Paciente' : 'Patient')),
                DropdownMenuItem(value: 'doctor', child: Text(isEs ? 'Doctor / Especialista' : 'Doctor')),
                DropdownMenuItem(value: 'secretaria', child: Text(isEs ? 'Secretaria / Asistente' : 'Secretary / Assistant')),
                DropdownMenuItem(value: 'admin', child: Text(isEs ? 'Administrador' : 'Administrator')),
              ],
              onChanged: (val) { if (val != null) setModalState(() => nuevoRol = val); },
              decoration: InputDecoration(labelText: isEs ? 'Nuevo Rol' : 'New Role', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0))),
            ),
            const SizedBox(height: 18.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF249689), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final ok = await AdminAccountsService.instance.cambiarRol(idUsuario: account.id, nuevoRol: nuevoRol);
                  if (ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFF249689), content: Text(isEs ? 'Rol actualizado exitosamente.' : 'Role updated.')));
                    _cargarDatos();
                  }
                },
                child: Text(isEs ? 'Guardar Cambio de Rol' : 'Save Role Change'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

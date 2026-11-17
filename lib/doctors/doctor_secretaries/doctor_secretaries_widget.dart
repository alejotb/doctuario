import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../backend/supabase/supabase.dart';
import '../../services/i18n_service.dart';
import '../../services/secretary_management_service.dart';

class DoctorSecretariesWidget extends StatefulWidget {
  final String idDoctor;
  const DoctorSecretariesWidget({super.key, required this.idDoctor});

  static String routeName = 'DoctorSecretaries';
  static String routePath = '/doctorSecretaries';

  @override
  State<DoctorSecretariesWidget> createState() => _DoctorSecretariesWidgetState();
}

class _DoctorSecretariesWidgetState extends State<DoctorSecretariesWidget> {
  final _searchController = TextEditingController();
  List<DoctorSedesRow> _sedes = [];
  List<SecretaryAssignment> _secretarias = [];
  List<SecretaryAssignment> _pendientes = [];
  List<SecretaryCandidate> _candidatos = [];
  SecretaryCandidate? _selectedCandidate;
  String? _selectedSedeId;
  final Map<String, String> _pendingSedeSelection = {};
  bool _isLoading = true, _isSearching = false, _isSaving = false;

  @override
  void initState() {
    super.initState();
    I18nService.instance.addListener(_onLocaleChanged);
    _cargarDatos();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    I18nService.instance.removeListener(_onLocaleChanged);
    _searchController.dispose();
    super.dispose();
  }

  String _getEffectiveDoctorId() {
    final cur = SupaFlow.client.auth.currentUser?.id ?? '';
    return widget.idDoctor.trim().isNotEmpty ? widget.idDoctor.trim() : cur;
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    final docId = _getEffectiveDoctorId();
    List<DoctorSedesRow> sedes = [];
    try {
      if (docId.isNotEmpty) sedes = await DoctorSedesTable().queryRows(queryFn: (q) => q.eq('id_doctor', docId));
      if (sedes.isEmpty) sedes = await DoctorSedesTable().queryRows(queryFn: (q) => q);
    } catch (_) {}
    if (sedes.isEmpty) {
      try {
        final res = await DualDatabaseConfig.instance.doctorClient.from('doctor_sedes').select();
        sedes = (res as List).map((r) => DoctorSedesRow(Map<String, dynamic>.from(r))).toList();
      } catch (_) {}
    }

    List<SecretaryAssignment> activas = [], pendientes = [];
    try {
      if (docId.isNotEmpty) {
        activas = await SecretaryManagementService().obtenerSecretariasDelDoctor(docId);
        pendientes = await SecretaryManagementService().obtenerSolicitudesPendientesDelDoctor(docId);
      }
    } catch (e) {
      debugPrint('Error cargando listas: $e');
    }

    if (mounted) {
      setState(() {
        _sedes = sedes;
        if (_sedes.isNotEmpty) {
          if (_selectedSedeId == null || !_sedes.any((s) => s.id == _selectedSedeId)) _selectedSedeId = _sedes.first.id;
          for (final p in pendientes) { _pendingSedeSelection.putIfAbsent(p.linkId, () => _selectedSedeId!); }
        } else {
          _selectedSedeId = null;
        }
        _secretarias = activas;
        _pendientes = pendientes;
        _isLoading = false;
      });
    }
  }

  Future<void> _ejecutarBusqueda(String q) async {
    final clean = q.trim();
    if (clean.length < 2) { setState(() => _candidatos = []); return; }
    setState(() => _isSearching = true);
    final results = await SecretaryManagementService().buscarSecretarias(idDoctor: _getEffectiveDoctorId(), query: clean);
    if (mounted) setState(() { _candidatos = results; _isSearching = false; });
  }

  Future<void> _vincularCandidata() async {
    final isEs = I18nService.instance.isSpanish;
    if (_selectedCandidate == null || _selectedSedeId == null) return;
    setState(() => _isSaving = true);
    try {
      await SecretaryManagementService().invitarOAsignarSecretaria(
        idDoctor: _getEffectiveDoctorId(), email: _selectedCandidate!.email,
        idSecretaria: _selectedCandidate!.id, idSede: _selectedSedeId!,
      );
      _selectedCandidate = null;
      _searchController.clear();
      _candidatos = [];
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFF0284C7), content: Text(isEs ? 'Secretaria asignada exitosamente.' : 'Secretary assigned successfully.')));
      await _cargarDatos();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFFE11D48), content: Text(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _aprobarSolicitud(SecretaryAssignment sec) async {
    final isEs = I18nService.instance.isSpanish;
    final sedeId = _pendingSedeSelection[sec.linkId] ?? _selectedSedeId;
    if (sedeId == null) return;
    setState(() => _isSaving = true);
    try {
      await SecretaryManagementService().aprobarSolicitudSecretaria(linkId: sec.linkId, idSede: sedeId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFF16A34A), content: Text(isEs ? 'Solicitud de ${sec.nombre} aprobada.' : 'Request from ${sec.nombre} approved.')));
      await _cargarDatos();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _rechazarSolicitud(SecretaryAssignment sec) async {
    final isEs = I18nService.instance.isSpanish;
    final conf = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(isEs ? 'Rechazar Solicitud' : 'Reject Request'),
      content: Text(isEs ? '¿Deseas rechazar a ${sec.nombre}?' : 'Reject link request from ${sec.nombre}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEs ? 'Cancelar' : 'Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)), onPressed: () => Navigator.pop(ctx, true), child: Text(isEs ? 'Rechazar' : 'Reject', style: const TextStyle(color: Colors.white))),
      ],
    ));
    if (conf == true) {
      await SecretaryManagementService().rechazarSolicitudSecretaria(sec.linkId);
      await _cargarDatos();
    }
  }

  Future<void> _desvincular(SecretaryAssignment sec) async {
    final isEs = I18nService.instance.isSpanish;
    final conf = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(isEs ? 'Desvincular Secretaria' : 'Unlink Secretary'),
      content: Text(isEs ? '¿Desea desvincular a ${sec.nombre} (${sec.email})?' : 'Unlink ${sec.nombre}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEs ? 'Cancelar' : 'Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)), onPressed: () => Navigator.pop(ctx, true), child: Text(isEs ? 'Desvincular' : 'Unlink', style: const TextStyle(color: Colors.white))),
      ],
    ));
    if (conf == true) {
      await SecretaryManagementService().desvincularSecretaria(idDoctor: _getEffectiveDoctorId(), idSecretaria: sec.idSecretaria);
      await _cargarDatos();
    }
  }

  String _nombreDeSede(DoctorSedesRow s) {
    if (s.nombreSede != null && s.nombreSede!.trim().isNotEmpty) return s.nombreSede!.trim();
    if (s.numeroConsultorio != null && s.numeroConsultorio!.trim().isNotEmpty) return s.numeroConsultorio!.trim();
    if (s.ciudad != null && s.ciudad!.trim().isNotEmpty) return 'Consultorio en ${s.ciudad}';
    return 'Consultorio Principal';
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _cargarDatos,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          _buildHeaderCard(isEs),
          const SizedBox(height: 18),
          if (_pendientes.isNotEmpty) ...[_buildPendingSection(isEs), const SizedBox(height: 20)],
          _buildSearchAndAssignCard(isEs),
          const SizedBox(height: 22),
          _buildSecretariesListSection(isEs),
        ]),
      ),
    );
  }

  Widget _buildHeaderCard(bool isEs) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.support_agent_rounded, color: Color(0xFF0284C7), size: 28)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isEs ? 'Gestión de Secretarias' : 'Secretary Management', style: GoogleFonts.mooli(fontSize: 19, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        const SizedBox(height: 3),
        Text(isEs ? 'Busca y asigna recepcionistas o aprueba solicitudes pendientes de tus sedes.' : 'Search and assign receptionists or approve pending requests.', style: GoogleFonts.mooli(fontSize: 12.5, color: const Color(0xFF64748B))),
      ])),
    ]),
  );

  Widget _buildPendingSection(bool isEs) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 20),
        const SizedBox(width: 8),
        Text(isEs ? 'Solicitudes Pendientes de Aprobación' : 'Pending Approval Requests', style: GoogleFonts.mooli(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF92400E))),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(10)), child: Text('${_pendientes.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
      ]),
      const SizedBox(height: 5),
      Text(isEs ? 'Secretarias que solicitaron vincularse contigo. Selecciona la sede y acéptalas:' : 'Secretaries requesting to link with you. Select clinic and approve:', style: const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
      const SizedBox(height: 10),
      ..._pendientes.map((sec) => _buildPendingCard(sec, isEs)),
    ]),
  );

  Widget _buildPendingCard(SecretaryAssignment sec, bool isEs) {
    final curSede = _pendingSedeSelection[sec.linkId] ?? _selectedSedeId;
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: const Color(0xFFFEF3C7), backgroundImage: (sec.fotoUrl != null && sec.fotoUrl!.isNotEmpty) ? NetworkImage(sec.fotoUrl!) : null, child: (sec.fotoUrl == null || sec.fotoUrl!.isEmpty) ? const Icon(Icons.person, color: Color(0xFFD97706), size: 20) : null),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sec.nombre, style: GoogleFonts.mooli(fontSize: 14, fontWeight: FontWeight.bold)),
            Text(sec.email, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          ])),
        ]),
        const SizedBox(height: 8),
        if (_sedes.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey('pend_sede_${sec.linkId}_$curSede'),
            initialValue: curSede,
            decoration: InputDecoration(labelText: isEs ? 'Asignar a Sede' : 'Assign to Clinic', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            items: _sedes.map((s) => DropdownMenuItem(value: s.id, child: Text(_nombreDeSede(s), style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (val) { if (val != null) setState(() => _pendingSedeSelection[sec.linkId] = val); },
          ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton.icon(onPressed: _isSaving ? null : () => _rechazarSolicitud(sec), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE11D48), side: const BorderSide(color: Color(0xFFFECDD3))), icon: const Icon(Icons.close_rounded, size: 14), label: Text(isEs ? 'Rechazar' : 'Reject')),
          const SizedBox(width: 8),
          ElevatedButton.icon(onPressed: _isSaving ? null : () => _aprobarSolicitud(sec), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white), icon: const Icon(Icons.check_rounded, size: 14), label: Text(isEs ? 'Aceptar' : 'Accept')),
        ]),
      ]),
    );
  }

  Widget _buildSearchAndAssignCard(bool isEs) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.person_search_rounded, color: Color(0xFF0284C7), size: 20),
        const SizedBox(width: 8),
        Text(isEs ? 'Buscar y Asignar Secretaria' : 'Search and Assign Secretary', style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),
      Text(isEs ? 'Busca a tu secretaria por nombre o correo para seleccionarla:' : 'Search secretary by name or email to select her:', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      const SizedBox(height: 10),
      TextFormField(
        controller: _searchController, onChanged: _ejecutarBusqueda,
        decoration: InputDecoration(
          labelText: isEs ? 'Buscar por nombre o correo' : 'Search by name or email',
          hintText: isEs ? 'Ej: María o secretaria@ejemplo.com' : 'E.g: Mary or sec@example.com',
          prefixIcon: const Icon(Icons.search_rounded, size: 19),
          suffixIcon: _isSearching
              ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
              : (_searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _searchController.clear(); setState(() => _candidatos = []); }) : null),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      if (_candidatos.isNotEmpty && _selectedCandidate == null) ...[
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: ListView.separated(
            shrinkWrap: true, itemCount: _candidatos.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = _candidatos[i];
              return ListTile(
                dense: true,
                leading: CircleAvatar(radius: 15, backgroundColor: const Color(0xFFE0F2FE), backgroundImage: (c.fotoUrl != null && c.fotoUrl!.isNotEmpty) ? NetworkImage(c.fotoUrl!) : null, child: (c.fotoUrl == null || c.fotoUrl!.isEmpty) ? const Icon(Icons.person, color: Color(0xFF0284C7), size: 17) : null),
                title: Text(c.nombre, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                subtitle: Text(c.email, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                trailing: const Icon(Icons.touch_app_rounded, color: Color(0xFF0284C7), size: 17),
                onTap: () => setState(() { _selectedCandidate = c; _candidatos = []; }),
              );
            },
          ),
        ),
      ],
      if (_selectedCandidate != null) ...[const SizedBox(height: 12), _buildSelectedCandidateCard(isEs)],
    ]),
  );

  Widget _buildSelectedCandidateCard(bool isEs) {
    final c = _selectedCandidate!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBAE6FD))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: const Color(0xFFBAE6FD), backgroundImage: (c.fotoUrl != null && c.fotoUrl!.isNotEmpty) ? NetworkImage(c.fotoUrl!) : null, child: (c.fotoUrl == null || c.fotoUrl!.isEmpty) ? const Icon(Icons.person, color: Color(0xFF0284C7), size: 20) : null),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.nombre, style: GoogleFonts.mooli(fontSize: 13.5, fontWeight: FontWeight.bold)),
            Text(c.email, style: const TextStyle(fontSize: 11.5, color: Color(0xFF0284C7))),
          ])),
          IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)), tooltip: isEs ? 'Cambiar' : 'Change', onPressed: () => setState(() => _selectedCandidate = null)),
        ]),
        const SizedBox(height: 10),
        if (_sedes.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey('sel_cand_sede_$_selectedSedeId'),
            initialValue: _selectedSedeId,
            decoration: InputDecoration(labelText: isEs ? 'Asignar a Sede' : 'Assign to Clinic', prefixIcon: const Icon(Icons.location_city_rounded, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            items: _sedes.map((s) => DropdownMenuItem(value: s.id, child: Text(_nombreDeSede(s), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (val) => setState(() => _selectedSedeId = val),
          )
        else
          Text(isEs ? 'Debes registrar al menos una sede.' : 'Register a clinic first.', style: const TextStyle(fontSize: 12, color: Colors.orange)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity, height: 38,
          child: ElevatedButton.icon(
            onPressed: (_isSaving || _sedes.isEmpty) ? null : _vincularCandidata,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: _isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: Text(isEs ? 'Vincular Secretaria Seleccionada' : 'Link Selected Secretary', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ]),
    );
  }

  Widget _buildSecretariesListSection(bool isEs) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(isEs ? 'Secretarias Vinculadas' : 'Assigned Secretaries', style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold)),
      Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)), child: Text('${_secretarias.length}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
    ]),
    const SizedBox(height: 10),
    if (_secretarias.isEmpty)
      Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Center(child: Column(children: [
          Icon(Icons.people_outline_rounded, size: 42, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(isEs ? 'No tienes secretarias vinculadas' : 'No secretaries assigned yet', style: GoogleFonts.mooli(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
          const SizedBox(height: 3),
          Text(isEs ? 'Busca arriba a tu secretaria o revisa solicitudes pendientes.' : 'Search above or review pending requests.', style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
        ])),
      )
    else
      ..._secretarias.map((sec) => _buildSecretaryCard(sec, isEs)),
  ]);

  Widget _buildSecretaryCard(SecretaryAssignment sec, bool isEs) => Container(
    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: Row(children: [
      CircleAvatar(radius: 20, backgroundColor: const Color(0xFFE0F2FE), backgroundImage: (sec.fotoUrl != null && sec.fotoUrl!.isNotEmpty) ? NetworkImage(sec.fotoUrl!) : null, child: (sec.fotoUrl == null || sec.fotoUrl!.isEmpty) ? const Icon(Icons.person_rounded, color: Color(0xFF0284C7), size: 22) : null),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(sec.nombre, style: GoogleFonts.mooli(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        Text(sec.email, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        if (sec.nombreSede != null) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_city_rounded, size: 12, color: Color(0xFF0284C7)),
              const SizedBox(width: 4),
              Text(sec.nombreSede!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            ]),
          ),
        ],
      ])),
      IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 20), tooltip: isEs ? 'Desvincular' : 'Unlink', onPressed: () => _desvincular(sec)),
    ]),
  );
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/i18n_service.dart';
import '/services/patient_account_linking_service.dart';

/// Modal para vincular historial clínico previo y gestionar familiares dependientes.
class FamilyLinkingModal extends StatefulWidget {
  const FamilyLinkingModal({
    super.key,
    required this.idUsuario,
    required this.nombreUsuario,
    this.cedulaUsuario,
    this.telefonoUsuario,
    this.emailUsuario,
  });

  final String idUsuario;
  final String nombreUsuario;
  final String? cedulaUsuario;
  final String? telefonoUsuario;
  final String? emailUsuario;

  static Future<void> show(
    BuildContext context, {
    required String idUsuario,
    required String nombreUsuario,
    String? cedulaUsuario,
    String? telefonoUsuario,
    String? emailUsuario,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FamilyLinkingModal(
        idUsuario: idUsuario,
        nombreUsuario: nombreUsuario,
        cedulaUsuario: cedulaUsuario,
        telefonoUsuario: telefonoUsuario,
        emailUsuario: emailUsuario,
      ),
    );
  }

  @override
  State<FamilyLinkingModal> createState() => _FamilyLinkingModalState();
}

class _FamilyLinkingModalState extends State<FamilyLinkingModal> {
  final _svc = PatientAccountLinkingService.instance;
  final _reclamarCtrl = TextEditingController();
  final _famDocCtrl = TextEditingController();
  final _famNombreCtrl = TextEditingController();
  final _famCedulaCtrl = TextEditingController();
  final _famTelCtrl = TextEditingController();

  List<FamiliarDependiente> _familiares = [];
  bool _cargando = true;
  bool _procesando = false;
  bool _modoCrearNuevo = false;
  bool _esMenorEdad = false;
  String _parentesco = 'Hijo/a';
  String? _mensajeEstado;
  bool _mensajeExito = true;

  static const _parentescos = ['Hijo/a', 'Cónyuge', 'Padre/Madre', 'Hermano/a', 'Otro'];

  @override
  void initState() {
    super.initState();
    _reclamarCtrl.text = (widget.cedulaUsuario?.isNotEmpty == true)
        ? widget.cedulaUsuario!
        : (widget.telefonoUsuario ?? '');
    _cargarFamiliares();
  }

  @override
  void dispose() {
    _reclamarCtrl.dispose();
    _famDocCtrl.dispose();
    _famNombreCtrl.dispose();
    _famCedulaCtrl.dispose();
    _famTelCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarFamiliares() async {
    setState(() => _cargando = true);
    final list = await _svc.obtenerFamiliaresDependientes(widget.idUsuario);
    if (mounted) setState(() { _familiares = list; _cargando = false; });
  }

  void _mostrarMensaje(String msg, bool exito) {
    if (!mounted) return;
    setState(() { _mensajeEstado = msg; _mensajeExito = exito; });
  }

  Future<void> _reclamarMiHistorial() async {
    final dato = _reclamarCtrl.text.trim();
    if (dato.isEmpty) {
      _mostrarMensaje('Ingresa tu cédula o teléfono para buscar tu historial.', false);
      return;
    }
    setState(() => _procesando = true);
    final esTel = dato.length >= 10 && !dato.contains('-');
    final res = await _svc.vincularCuentaPorCedulaOTelefono(
      idUsuarioAuth: widget.idUsuario,
      nombreUsuario: widget.nombreUsuario,
      cedula: esTel ? '' : dato,
      telefono: esTel ? dato : widget.telefonoUsuario,
      email: widget.emailUsuario,
    );
    if (mounted) {
      setState(() => _procesando = false);
      _mostrarMensaje(res.mensaje, res.exitoso);
    }
  }

  Future<void> _agregarOVincularFamiliar() async {
    setState(() => _procesando = true);
    if (_modoCrearNuevo) {
      final nom = _famNombreCtrl.text.trim();
      if (nom.isEmpty) {
        setState(() => _procesando = false);
        _mostrarMensaje('El nombre del familiar es obligatorio.', false);
        return;
      }
      final creado = await _svc.crearDependienteFamiliar(
        idRepresentante: widget.idUsuario,
        nombre: nom,
        cedula: _famCedulaCtrl.text.trim(),
        telefono: _famTelCtrl.text.trim(),
        parentesco: _parentesco,
        esMenorEdad: _esMenorEdad,
      );
      if (mounted) {
        setState(() => _procesando = false);
        if (creado != null) {
          _famNombreCtrl.clear();
          _famCedulaCtrl.clear();
          _famTelCtrl.clear();
          _mostrarMensaje('Familiar "$nom" registrado y vinculado.', true);
          _cargarFamiliares();
        } else {
          _mostrarMensaje('No se pudo registrar el familiar.', false);
        }
      }
    } else {
      final dato = _famDocCtrl.text.trim();
      if (dato.isEmpty) {
        setState(() => _procesando = false);
        _mostrarMensaje('Ingresa la cédula o teléfono del familiar.', false);
        return;
      }
      final res = await _svc.vincularFamiliarPorCedulaOTelefono(
        idRepresentante: widget.idUsuario,
        cedulaOTelefono: dato,
        parentesco: _parentesco,
        esMenorEdad: _esMenorEdad,
      );
      if (mounted) {
        setState(() => _procesando = false);
        _mostrarMensaje(res.mensaje, res.exitoso);
        if (res.exitoso) {
          _famDocCtrl.clear();
          _cargarFamiliares();
        }
      }
    }
  }

  Future<void> _desvincular(FamiliarDependiente fam) async {
    final ok = await _svc.desvincularFamiliar(fam.idPaciente);
    if (mounted) {
      _mostrarMensaje(ok ? '${fam.nombre} desvinculado.' : 'Error al desvincular.', ok);
      if (ok) _cargarFamiliares();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.isSpanish;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: 56, bottom: bottomInset),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.family_restroom_rounded, color: theme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEs ? 'Grupo Familiar y Expediente' : 'Family Group & Records',
                      style: theme.titleMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              if (_mensajeEstado != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_mensajeExito ? Colors.teal : Colors.redAccent).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_mensajeEstado!, style: theme.bodySmall.copyWith(color: _mensajeExito ? Colors.teal : Colors.redAccent)),
                ),
              ],
              const SizedBox(height: 14),
              Text(isEs ? '1. Reclamar mi historial previo en clínica' : '1. Claim my prior clinic history', style: theme.labelLarge),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reclamarCtrl,
                      decoration: InputDecoration(
                        hintText: isEs ? 'Cédula o teléfono' : 'ID or phone',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _procesando ? null : _reclamarMiHistorial,
                    style: ElevatedButton.styleFrom(backgroundColor: theme.primary, foregroundColor: Colors.white),
                    child: Text(isEs ? 'Vincular' : 'Link'),
                  ),
                ],
              ),
              const Divider(height: 28),
              Text(isEs ? '2. Familiares dependientes' : '2. Linked family members', style: theme.labelLarge),
              const SizedBox(height: 8),
              if (_cargando)
                const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              else if (_familiares.isEmpty)
                Text(isEs ? 'Aún no tienes familiares vinculados.' : 'No linked family members yet.', style: theme.bodySmall)
              else
                ..._familiares.map((f) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: theme.primary.withValues(alpha: 0.15),
                        child: Icon(f.esMenorEdad ? Icons.child_care_rounded : Icons.person_rounded, color: theme.primary, size: 18),
                      ),
                      title: Text(f.nombre, style: theme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text('${f.parentesco}${f.cedula != null && f.cedula!.isNotEmpty ? ' • ${f.cedula}' : ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => _desvincular(f),
                      ),
                    )),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEs ? '3. Agregar familiar' : '3. Add family member', style: theme.labelLarge),
                  TextButton(
                    onPressed: () => setState(() => _modoCrearNuevo = !_modoCrearNuevo),
                    child: Text(_modoCrearNuevo ? (isEs ? 'Buscar existente' : 'Link existing') : (isEs ? 'Registrar nuevo' : 'Register new')),
                  ),
                ],
              ),
              if (_modoCrearNuevo) ...[
                TextField(controller: _famNombreCtrl, decoration: InputDecoration(labelText: isEs ? 'Nombre completo' : 'Full name', isDense: true)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _famCedulaCtrl, decoration: InputDecoration(labelText: isEs ? 'Cédula (opcional)' : 'ID (optional)', isDense: true))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _famTelCtrl, decoration: InputDecoration(labelText: isEs ? 'Teléfono (opcional)' : 'Phone (optional)', isDense: true))),
                  ],
                ),
              ] else
                TextField(controller: _famDocCtrl, decoration: InputDecoration(labelText: isEs ? 'Cédula o teléfono del familiar' : 'Family member ID or phone', isDense: true)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _parentesco,
                      decoration: InputDecoration(labelText: isEs ? 'Parentesco' : 'Relationship', isDense: true),
                      items: _parentescos.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (v) { if (v != null) setState(() => _parentesco = v); },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilterChip(
                    label: Text(isEs ? 'Menor' : 'Minor'),
                    selected: _esMenorEdad,
                    onSelected: (v) => setState(() => _esMenorEdad = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _procesando ? null : _agregarOVincularFamiliar,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(_modoCrearNuevo ? (isEs ? 'Registrar Familiar' : 'Register Family Member') : (isEs ? 'Vincular Familiar' : 'Link Family Member')),
                  style: ElevatedButton.styleFrom(backgroundColor: theme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

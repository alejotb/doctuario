import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/admin_tenant_service.dart';
import '/services/i18n_service.dart';

/// Modal interactivo para aprobar doctores, asignar plan comercial (Fundador, Pro, Clínicas)
/// y gestionar el estado financiero y activación del consultorio en la Base Central.
class AdminDoctorConfigSheetWidget extends StatefulWidget {
  const AdminDoctorConfigSheetWidget({
    super.key,
    required this.doc,
    this.onUpdated,
  });

  final DoctorPendingRequest doc;
  final VoidCallback? onUpdated;

  static Future<void> show(
    BuildContext context,
    DoctorPendingRequest doc, {
    VoidCallback? onUpdated,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) => AdminDoctorConfigSheetWidget(
        doc: doc,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<AdminDoctorConfigSheetWidget> createState() => _AdminDoctorConfigSheetWidgetState();
}

class _AdminDoctorConfigSheetWidgetState extends State<AdminDoctorConfigSheetWidget> {
  late final TextEditingController _urlController;
  late final TextEditingController _anonKeyController;
  late final TextEditingController _precioController;

  late String _selectedPlan;
  late String _selectedEstadoPago;
  late bool _modoSoloLectura;
  late bool _estaAprobado;

  bool _isSaving = false;
  bool _isTesting = false;
  String? _testResultMsg;
  bool? _testResultOk;

  final Map<String, double> _preciosSugeridos = {
    'fundador': 35.0,
    'individual': 50.0,
    'duo': 70.0,
    'grupo': 160.0,
    'clinica': 280.0,
  };

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.doc.dbUrl ?? '');
    _anonKeyController = TextEditingController(text: widget.doc.dbAnonKey ?? '');
    _selectedPlan = widget.doc.plan;
    _selectedEstadoPago = widget.doc.estadoPago;
    _modoSoloLectura = widget.doc.modoSoloLectura;
    _estaAprobado = widget.doc.estaAprobado;
    _precioController = TextEditingController(
      text: widget.doc.precioMensual.toStringAsFixed(0),
    );
    _cargarEstadoRealDirecto();
  }

  Future<void> _cargarEstadoRealDirecto() async {
    try {
      final docRes = await SupaFlow.client
          .from('doctores')
          .select('esta_aprobado, estado_verificacion')
          .eq('id', widget.doc.idDoctor)
          .maybeSingle();
      if (docRes != null && mounted) {
        final bool? realAprobado = docRes['esta_aprobado'] as bool?;
        if (realAprobado != null && realAprobado != _estaAprobado) {
          setState(() {
            _estaAprobado = realAprobado;
          });
        }
      }
    } catch (e) {
      debugPrint('AdminDoctorConfigSheet: Error consultando estado real directo: $e');
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  void _onPlanChanged(String? newPlan) {
    if (newPlan == null) return;
    setState(() {
      _selectedPlan = newPlan;
      if (_preciosSugeridos.containsKey(newPlan)) {
        _precioController.text = _preciosSugeridos[newPlan]!.toStringAsFixed(0);
      }
    });
  }

  Future<void> _guardarConfiguracion({bool forzarAprobacion = false}) async {
    setState(() => _isSaving = true);
    final double precio = double.tryParse(_precioController.text.trim()) ?? 35.0;
    final activoFinal = forzarAprobacion ? true : _estaAprobado;

    final ok = await AdminTenantService.instance.aprobarYConfigurarDoctor(
      idDoctor: widget.doc.idDoctor,
      nombreDoctor: widget.doc.nombre,
      activo: activoFinal,
      plan: _selectedPlan,
      precioMensual: precio,
      estadoPago: _selectedEstadoPago,
      modoSoloLectura: _modoSoloLectura,
      dbUrl: _urlController.text.trim(),
      dbAnonKey: _anonKeyController.text.trim(),
    );

    if (!mounted) return;
    final isEs = I18nService.instance.isSpanish;

    if (ok) {
      Navigator.of(context).pop();
      widget.onUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF249689),
          content: Text(
            isEs
                ? '¡Cuenta y estado de ${widget.doc.nombre} actualizados con éxito!'
                : 'Account & practice for ${widget.doc.nombre} successfully saved!',
          ),
        ),
      );
    } else {
      setState(() {
        _isSaving = false;
        _testResultOk = false;
        _testResultMsg = isEs
            ? 'No se pudo guardar la activación del doctor. Revisa la conexión.'
            : 'Could not save doctor activation. Check connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.isSpanish;
    final doc = widget.doc;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(22.0),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22.0)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de título
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isEs ? 'Aprobación y Plan: ${doc.nombre}' : 'Practice & Plan: ${doc.nombre}',
                      style: GoogleFonts.mooli(fontSize: 16.0, fontWeight: FontWeight.bold, color: theme.primaryText),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              Text(
                '${doc.especialidad} • ID: ${doc.idDoctor.length > 8 ? doc.idDoctor.substring(0, 8) : doc.idDoctor}',
                style: GoogleFonts.mooli(fontSize: 12.0, color: theme.secondaryText),
              ),
              const SizedBox(height: 14.0),

              // SECCIÓN 1: ESTADO DE APROBACIÓN DE CUENTA
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: _estaAprobado ? const Color(0x1410B981) : const Color(0x14F59E0B),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: _estaAprobado ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    width: 1.2,
                  ),
                ),
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFF10B981),
                  title: Row(
                    children: [
                      Icon(
                        _estaAprobado ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                        color: _estaAprobado ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        size: 20.0,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        _estaAprobado
                            ? (isEs ? 'Cuenta Aprobada y Activa' : 'Account Approved & Active')
                            : (isEs ? 'Pendiente de Aprobación' : 'Pending Approval'),
                        style: GoogleFonts.mooli(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: _estaAprobado ? const Color(0xFF10B981) : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    _estaAprobado
                        ? (isEs
                            ? 'El doctor puede ingresar a su panel médico y gestionar su consultorio.'
                            : 'Doctor can access clinical dashboard and agenda.')
                        : (isEs
                            ? 'El doctor verá la pantalla "Se está configurando su base de datos".'
                            : 'Doctor will see "Your database is being configured" screen.'),
                    style: GoogleFonts.mooli(fontSize: 11.0, color: theme.secondaryText),
                  ),
                  value: _estaAprobado,
                  onChanged: (val) => setState(() => _estaAprobado = val),
                ),
              ),
              const SizedBox(height: 12.0),

              // SECCIÓN 2: PLAN COMERCIAL Y FACTURACIÓN
              Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: const Color(0x0C249689),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: const Color(0xFF249689).withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFF249689), size: 18.0),
                        const SizedBox(width: 8.0),
                        Text(
                          isEs ? 'Plan Comercial y Facturación' : 'Commercial Plan & Billing',
                          style: GoogleFonts.mooli(fontSize: 13.0, fontWeight: FontWeight.bold, color: const Color(0xFF249689)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10.0),

                    // Selector de Tipo de Plan
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPlan,
                      decoration: InputDecoration(
                        labelText: isEs ? 'Tipo de Plan Asignado' : 'Assigned Plan Tier',
                        labelStyle: GoogleFonts.mooli(fontSize: 12.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        filled: true,
                        fillColor: theme.secondaryBackground,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      ),
                      items: [
                        DropdownMenuItem(value: 'fundador', child: Text(isEs ? 'Plan Fundador (\$35 USD/mes)' : 'Founder Plan (\$35 USD/mo)')),
                        DropdownMenuItem(value: 'individual', child: Text(isEs ? 'Plan Pro Individual (\$50 USD/mes)' : 'Pro Individual (\$50 USD/mo)')),
                        DropdownMenuItem(value: 'duo', child: Text(isEs ? 'Plan Dúo (\$70 USD/mes • 2 Médicos)' : 'Duo Plan (\$70 USD/mo • 2 Doctors)')),
                        DropdownMenuItem(value: 'grupo', child: Text(isEs ? 'Consultorio / Grupo (\$160 USD/mes • 5 Médicos)' : 'Practice / Group (\$160 USD/mo • 5 Doctors)')),
                        DropdownMenuItem(value: 'clinica', child: Text(isEs ? 'Clínica (\$280 USD/mes • Hasta 10 Médicos)' : 'Clinic (\$280 USD/mo • Up to 10 Doctors)')),
                      ],
                      onChanged: _onPlanChanged,
                    ),
                    const SizedBox(height: 10.0),

                    Row(
                      children: [
                        // Precio Mensual Editable
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: _precioController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: isEs ? 'Precio Mensual (\$)' : 'Monthly Price (\$)',
                              prefixText: '\$ ',
                              labelStyle: GoogleFonts.mooli(fontSize: 12.0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                              filled: true,
                              fillColor: theme.secondaryBackground,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),

                        // Estado de Pago
                        Expanded(
                          flex: 6,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedEstadoPago,
                            decoration: InputDecoration(
                              labelText: isEs ? 'Estado de Pago' : 'Payment Status',
                              labelStyle: GoogleFonts.mooli(fontSize: 12.0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                              filled: true,
                              fillColor: theme.secondaryBackground,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                            ),
                            items: [
                              DropdownMenuItem(value: 'al_dia', child: Text(isEs ? '🟢 Al Día' : '🟢 Paid / Current')),
                              DropdownMenuItem(value: 'pendiente', child: Text(isEs ? '🟡 Pendiente' : '🟡 Pending')),
                              DropdownMenuItem(value: 'mora', child: Text(isEs ? '🔴 En Mora' : '🔴 Overdue')),
                              DropdownMenuItem(value: 'cancelado', child: Text(isEs ? '⚪ Cancelado' : '⚪ Cancelled')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedEstadoPago = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),

                    // Switch Modo Solo Lectura (Impago)
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        isEs ? 'Modo Solo Lectura (Bloqueo por Impago)' : 'Read-Only Mode (Unpaid Suspension)',
                        style: GoogleFonts.mooli(fontSize: 12.0, fontWeight: FontWeight.bold, color: theme.primaryText),
                      ),
                      subtitle: Text(
                        isEs
                            ? 'El doctor puede ver y exportar sus historias clínicas, pero no registrar nuevos datos.'
                            : 'Doctor can view and export records, but cannot write new patient consultations.',
                        style: GoogleFonts.mooli(fontSize: 10.5, color: theme.secondaryText),
                      ),
                      value: _modoSoloLectura,
                      activeThumbColor: const Color(0xFF249689),
                      onChanged: (val) => setState(() => _modoSoloLectura = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10.0),

              // SECCIÓN 3: OPCIONAL AVANZADO (Servidor Dedicado VIP)
              ExpansionTile(
                title: Text(
                  isEs ? 'Servidor Dedicado Opcional (Clínicas VIP)' : 'Optional Dedicated Server (VIP Clinics)',
                  style: GoogleFonts.mooli(fontSize: 12.0, fontWeight: FontWeight.w600, color: theme.secondaryText),
                ),
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: isEs ? 'URL Supabase Privado' : 'Private Supabase URL',
                      hintText: 'https://xxx.supabase.co',
                      labelStyle: GoogleFonts.mooli(fontSize: 12.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      filled: true,
                      fillColor: theme.primaryBackground,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  TextField(
                    controller: _anonKeyController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: isEs ? 'Anon Key Privada' : 'Private Anon Key',
                      labelStyle: GoogleFonts.mooli(fontSize: 12.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      filled: true,
                      fillColor: theme.primaryBackground,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  if (_urlController.text.trim().isNotEmpty)
                    OutlinedButton(
                      onPressed: _isTesting
                          ? null
                          : () async {
                              setState(() => _isTesting = true);
                              final res = await AdminTenantService.instance.probarConexionBaseDatos(
                                dbUrl: _urlController.text.trim(),
                                dbAnonKey: _anonKeyController.text.trim(),
                              );
                              if (!mounted) return;
                              setState(() {
                                _isTesting = false;
                                _testResultOk = res['valido'] as bool?;
                                _testResultMsg = res['mensaje'] as String?;
                              });
                            },
                      child: _isTesting
                          ? const SizedBox(width: 14.0, height: 14.0, child: CircularProgressIndicator(strokeWidth: 2.0))
                          : Text(isEs ? 'Probar Conexión Servidor Dedicado' : 'Test Dedicated Server'),
                    ),
                ],
              ),

              if (_testResultMsg != null) ...[
                const SizedBox(height: 8.0),
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: (_testResultOk ?? false) ? const Color(0x1A249689) : Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: (_testResultOk ?? false) ? const Color(0xFF249689) : Colors.redAccent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (_testResultOk ?? false) ? Icons.check_circle : Icons.error_outline,
                        size: 16.0,
                        color: (_testResultOk ?? false) ? const Color(0xFF249689) : Colors.redAccent,
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          _testResultMsg!,
                          style: TextStyle(
                            fontSize: 12.0,
                            color: (_testResultOk ?? false) ? const Color(0xFF249689) : Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16.0),

              // BOTONES DE ACCIÓN
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                      ),
                      child: Text(isEs ? 'Cerrar' : 'Close', style: GoogleFonts.mooli(fontSize: 13.0)),
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : () => _guardarConfiguracion(),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16.0,
                              height: 16.0,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                            )
                          : Icon(
                              _estaAprobado ? Icons.save_rounded : Icons.check_circle_rounded,
                              size: 18.0,
                            ),
                      label: Text(
                        _estaAprobado
                            ? (isEs ? 'Guardar Cambios' : 'Save Changes')
                            : (isEs ? 'Aprobar y Activar Cuenta' : 'Approve & Activate Account'),
                        style: GoogleFonts.mooli(fontSize: 13.0, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _estaAprobado ? theme.primary : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/services/admin_tenant_service.dart';
import '/services/i18n_service.dart';
import 'components/admin_doctor_config_sheet_widget.dart';

/// Modal emergente para la gestión y aprobación de consultorios médicos (tenants).
///
/// Muestra los doctores registrados que necesitan aprobación y permite abrir
/// la configuración de su cuenta y base de datos privada en un modal interactivo.
class AdminDoctorTenantsModalWidget extends StatefulWidget {
  const AdminDoctorTenantsModalWidget({super.key, this.onUpdated});

  final VoidCallback? onUpdated;

  /// Despliega el modal adaptado para móvil (Bottom Sheet) o escritorio (Dialog).
  static Future<void> show(BuildContext context, {VoidCallback? onUpdated}) async {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    if (isDesktop) {
      await showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.3),
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: SizedBox(
            width: 640.0,
            height: 680.0,
            child: AdminDoctorTenantsModalWidget(onUpdated: onUpdated),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.88,
          child: AdminDoctorTenantsModalWidget(onUpdated: onUpdated),
        ),
      );
    }
  }

  /// Abre directamente el modal de configuración y activación de base de datos para un doctor específico.
  static Future<void> showConfigForDoctor(
    BuildContext context,
    DoctorPendingRequest doc, {
    VoidCallback? onUpdated,
  }) async {
    await AdminDoctorConfigSheetWidget.show(
      context,
      doc,
      onUpdated: onUpdated,
    );
  }

  @override
  State<AdminDoctorTenantsModalWidget> createState() => _AdminDoctorTenantsModalWidgetState();
}

class _AdminDoctorTenantsModalWidgetState extends State<AdminDoctorTenantsModalWidget> {
  bool _isLoading = true;
  bool _soloPendientes = true;
  List<DoctorPendingRequest> _solicitudes = [];

  @override
  void initState() {
    super.initState();
    _cargarSolicitudes();
  }

  Future<void> _cargarSolicitudes() async {
    setState(() => _isLoading = true);
    final items = await AdminTenantService.instance.listarSolicitudesDoctores(
      soloPendientes: _soloPendientes,
    );
    if (mounted) {
      setState(() {
        _solicitudes = items;
        _isLoading = false;
      });
    }
  }

  void _abrirConfiguracionCuenta(DoctorPendingRequest doc) {
    AdminDoctorTenantsModalWidget.showConfigForDoctor(
      context,
      doc,
      onUpdated: () {
        _cargarSolicitudes();
        widget.onUpdated?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final pendientesCount = _solicitudes.where((s) => !s.isAprobado).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20.0,
            offset: const Offset(0.0, 8.0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.0),
        child: Column(
          children: [
            // Cabecera superior
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(Icons.domain_verification_rounded, color: Color(0xFF0284C7), size: 20.0),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs ? 'Aprobación de Consultorios' : 'Medical Tenants Approval',
                          style: GoogleFonts.mooli(fontSize: 17.0, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          isEs ? 'Doctores registrados que necesitan aprobación' : 'Registered doctors awaiting approval',
                          style: GoogleFonts.mooli(fontSize: 12.0, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20.0, color: Color(0xFF64748B)),
                    onPressed: _cargarSolicitudes,
                    tooltip: isEs ? 'Actualizar' : 'Refresh',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20.0, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1.0, color: Color(0xFFF1F5F9)),

            // Filtros de estado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(
                      isEs ? 'Pendientes ($pendientesCount)' : 'Pending ($pendientesCount)',
                      style: GoogleFonts.mooli(fontSize: 12.0, fontWeight: FontWeight.bold),
                    ),
                    selected: _soloPendientes,
                    selectedColor: const Color(0xFFFEF3C7),
                    onSelected: (_) {
                      setState(() => _soloPendientes = true);
                      _cargarSolicitudes();
                    },
                  ),
                  const SizedBox(width: 8.0),
                  ChoiceChip(
                    label: Text(
                      isEs ? 'Todos los Doctores' : 'All Doctors',
                      style: GoogleFonts.mooli(fontSize: 12.0, fontWeight: FontWeight.w500),
                    ),
                    selected: !_soloPendientes,
                    onSelected: (_) {
                      setState(() => _soloPendientes = false);
                      _cargarSolicitudes();
                    },
                  ),
                ],
              ),
            ),

            // Lista de doctores
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
                  : _solicitudes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 48.0, color: Color(0xFF10B981)),
                                const SizedBox(height: 12.0),
                                Text(
                                  isEs ? 'No hay solicitudes pendientes' : 'No pending requests',
                                  style: GoogleFonts.mooli(fontSize: 16.0, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  isEs ? 'Todos los médicos registrados cuentan con su consultorio activo.' : 'All registered doctors are approved.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.mooli(fontSize: 12.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: _solicitudes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10.0),
                          itemBuilder: (ctx, i) {
                            final doc = _solicitudes[i];
                            final isAprobado = doc.isAprobado;

                            return Material(
                              color: isAprobado ? Colors.white : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12.0),
                              child: InkWell(
                                onTap: () => _abrirConfiguracionCuenta(doc),
                                borderRadius: BorderRadius.circular(12.0),
                                child: Container(
                                  padding: const EdgeInsets.all(14.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(
                                      color: isAprobado ? const Color(0xFFE2E8F0) : const Color(0xFFFDE68A),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isAprobado ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                        child: Icon(
                                          Icons.medical_services_rounded,
                                          color: isAprobado ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                          size: 19.0,
                                        ),
                                      ),
                                      const SizedBox(width: 12.0),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              doc.nombre,
                                              style: GoogleFonts.mooli(fontSize: 14.0, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                            ),
                                            const SizedBox(height: 2.0),
                                            Text(
                                              '${doc.email} • ${doc.especialidad}',
                                              style: GoogleFonts.mooli(fontSize: 12.0, color: const Color(0xFF64748B)),
                                            ),
                                            const SizedBox(height: 4.0),
                                            Wrap(
                                              spacing: 6.0,
                                              runSpacing: 4.0,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                                                  decoration: BoxDecoration(
                                                    color: isAprobado ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(6.0),
                                                  ),
                                                  child: Text(
                                                    isAprobado ? (isEs ? 'Activo' : 'Active') : (isEs ? 'Pendiente' : 'Pending'),
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: isAprobado ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0x140284C7),
                                                    borderRadius: BorderRadius.circular(6.0),
                                                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text(
                                                    '${doc.plan.toUpperCase()} • \$${doc.precioMensual.toStringAsFixed(0)}/m',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF0284C7),
                                                    ),
                                                  ),
                                                ),
                                                if (doc.modoSoloLectura)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6.0),
                                                    ),
                                                    child: Text(
                                                      isEs ? 'Solo Lectura' : 'Read Only',
                                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      ElevatedButton(
                                        onPressed: () => _abrirConfiguracionCuenta(doc),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isAprobado ? const Color(0xFFF1F5F9) : const Color(0xFF0284C7),
                                          foregroundColor: isAprobado ? const Color(0xFF334155) : Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                          elevation: 0.0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                        ),
                                        child: Text(
                                          isAprobado ? (isEs ? 'Configurar' : 'Config') : (isEs ? 'Activar' : 'Activate'),
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

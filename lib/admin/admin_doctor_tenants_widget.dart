import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/admin_tenant_service.dart';
import '/services/i18n_service.dart';
import 'components/admin_doctor_config_sheet_widget.dart';

/// Panel Administrativo para la visualización de solicitudes de doctores,
/// planes de suscripción (Fundador, Pro, Clínicas), facturación y modo solo lectura.
class AdminDoctorTenantsWidget extends StatefulWidget {
  const AdminDoctorTenantsWidget({super.key});

  static const String routeName = 'AdminDoctorTenants';
  static const String routePath = '/adminDoctorTenants';

  @override
  State<AdminDoctorTenantsWidget> createState() => _AdminDoctorTenantsWidgetState();
}

class _AdminDoctorTenantsWidgetState extends State<AdminDoctorTenantsWidget> {
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

  void _abrirModalAprobacion(DoctorPendingRequest doc) {
    AdminDoctorConfigSheetWidget.show(
      context,
      doc,
      onUpdated: _cargarSolicitudes,
    );
  }

  double get _ingresoMensualTotal => _solicitudes.fold(
        0.0,
        (acc, d) => acc + (d.isAprobado ? d.precioMensual : 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.isSpanish;

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Tarjeta de Métricas Financieras de Suscripciones
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: theme.alternate),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric(
                    title: isEs ? 'Doctores' : 'Doctors',
                    value: '${_solicitudes.length}',
                    color: theme.primary,
                  ),
                  Container(width: 1.0, height: 32.0, color: theme.alternate),
                  _buildMetric(
                    title: isEs ? 'Ingreso Est.' : 'Est. Revenue',
                    value: '\$${_ingresoMensualTotal.toStringAsFixed(0)}/m',
                    color: const Color(0xFF249689),
                  ),
                  Container(width: 1.0, height: 32.0, color: theme.alternate),
                  _buildMetric(
                    title: isEs ? 'Pendientes' : 'Pending',
                    value: '${_solicitudes.where((s) => !s.isAprobado).length}',
                    color: const Color(0xFFFFA000),
                  ),
                ],
              ),
            ),

            // Barra de Filtros
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(isEs ? 'Pendientes (${_solicitudes.where((s) => !s.isAprobado).length})' : 'Pending'),
                    selected: _soloPendientes,
                    onSelected: (val) {
                      setState(() => _soloPendientes = true);
                      _cargarSolicitudes();
                    },
                    selectedColor: const Color(0xFFFFA000).withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 10.0),
                  ChoiceChip(
                    label: Text(isEs ? 'Todos los Doctores' : 'All Doctors'),
                    selected: !_soloPendientes,
                    onSelected: (val) {
                      setState(() => _soloPendientes = false);
                      _cargarSolicitudes();
                    },
                  ),
                ],
              ),
            ),

            // Lista de Doctores
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _solicitudes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 54.0, color: theme.secondaryText),
                              const SizedBox(height: 12.0),
                              Text(
                                isEs ? 'No hay solicitudes pendientes' : 'No pending requests',
                                style: theme.bodyMedium.override(font: GoogleFonts.mooli(), color: theme.secondaryText),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: _solicitudes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10.0),
                          itemBuilder: (context, index) {
                            final doc = _solicitudes[index];
                            final isAprobado = doc.isAprobado;

                            return Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: theme.secondaryBackground,
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: theme.alternate, width: 1.0),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: theme.primary.withValues(alpha: 0.12),
                                    child: Icon(Icons.person_rounded, color: theme.primary),
                                  ),
                                  const SizedBox(width: 14.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doc.nombre,
                                          style: theme.bodyMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold), fontSize: 14.5),
                                        ),
                                        const SizedBox(height: 2.0),
                                        Text(
                                          '${doc.email} • ${doc.especialidad}',
                                          style: theme.bodySmall.override(font: GoogleFonts.mooli(), color: theme.secondaryText),
                                        ),
                                        const SizedBox(height: 6.0),
                                        Wrap(
                                          spacing: 6.0,
                                          runSpacing: 4.0,
                                          children: [
                                            // Estado de aprobación
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                                              decoration: BoxDecoration(
                                                color: isAprobado ? const Color(0x1A249689) : const Color(0x1AFFA000),
                                                borderRadius: BorderRadius.circular(6.0),
                                              ),
                                              child: Text(
                                                isAprobado ? (isEs ? 'Activo' : 'Active') : (isEs ? 'Pendiente' : 'Pending'),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isAprobado ? const Color(0xFF249689) : const Color(0xFFFFA000),
                                                ),
                                              ),
                                            ),

                                            // Badge de Plan y Precio
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                                              decoration: BoxDecoration(
                                                color: const Color(0x140284C7),
                                                borderRadius: BorderRadius.circular(6.0),
                                                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25)),
                                              ),
                                              child: Text(
                                                '${doc.plan.toUpperCase()} • \$${doc.precioMensual.toStringAsFixed(0)}/m',
                                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                              ),
                                            ),

                                            // Estado de Pago
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                                              decoration: BoxDecoration(
                                                color: doc.estadoPago == 'al_dia'
                                                    ? const Color(0x1A249689)
                                                    : (doc.estadoPago == 'mora' ? Colors.red.withValues(alpha: 0.1) : const Color(0x1AFFA000)),
                                                borderRadius: BorderRadius.circular(6.0),
                                              ),
                                              child: Text(
                                                doc.estadoPago == 'al_dia'
                                                    ? (isEs ? 'Al Día' : 'Paid')
                                                    : (doc.estadoPago == 'mora' ? (isEs ? 'En Mora' : 'Overdue') : doc.estadoPago.toUpperCase()),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: doc.estadoPago == 'al_dia'
                                                      ? const Color(0xFF249689)
                                                      : (doc.estadoPago == 'mora' ? Colors.redAccent : const Color(0xFFFFA000)),
                                                ),
                                              ),
                                            ),

                                            // Indicador de Modo Solo Lectura
                                            if (doc.modoSoloLectura)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withValues(alpha: 0.12),
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
                                    onPressed: () => _abrirModalAprobacion(doc),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isAprobado ? theme.primaryBackground : theme.primary,
                                      foregroundColor: isAprobado ? theme.primaryText : Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                    ),
                                    child: Text(
                                      isAprobado ? (isEs ? 'Editar Plan' : 'Edit Plan') : (isEs ? 'Activar' : 'Activate'),
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
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

  Widget _buildMetric({required String title, required String value, required Color color}) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.mooli(fontSize: 16.0, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2.0),
        Text(title, style: GoogleFonts.mooli(fontSize: 11.0, color: const Color(0xFF64748B))),
      ],
    );
  }
}

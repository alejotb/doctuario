import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../backend/supabase/supabase.dart';
import '../../services/i18n_service.dart';
import 'components/consultation_active_tab.dart';
import 'components/consultation_history_tab.dart';

/// Pantalla dedicada / Espacio de Trabajo para la Consulta Médica Activa.
/// Permite al médico atender al paciente sin distracciones ni tener que navegar
/// al perfil completo, manteniendo dos pestañas: Consulta Actual e Historial.
class DoctorConsultationWorkspaceWidget extends StatefulWidget {
  final String idDoctor;
  final CitasRow cita;
  final UsuariosRow? paciente;
  final VoidCallback onConsultaFinalizada;

  const DoctorConsultationWorkspaceWidget({
    super.key,
    required this.idDoctor,
    required this.cita,
    required this.paciente,
    required this.onConsultaFinalizada,
  });

  static Future<void> open(
    BuildContext context, {
    required String idDoctor,
    required CitasRow cita,
    required UsuariosRow? paciente,
    required VoidCallback onConsultaFinalizada,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => DoctorConsultationWorkspaceWidget(
          idDoctor: idDoctor,
          cita: cita,
          paciente: paciente,
          onConsultaFinalizada: onConsultaFinalizada,
        ),
      ),
    );
  }

  @override
  State<DoctorConsultationWorkspaceWidget> createState() =>
      _DoctorConsultationWorkspaceWidgetState();
}

class _DoctorConsultationWorkspaceWidgetState
    extends State<DoctorConsultationWorkspaceWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _obtenerNombrePaciente() {
    if (widget.paciente?.nombre != null &&
        widget.paciente!.nombre!.trim().isNotEmpty) {
      return widget.paciente!.nombre!.trim();
    }
    return 'Paciente en Consulta';
  }

  String _obtenerDetallesPaciente() {
    final List<String> detalles = [];
    if (widget.paciente?.cedula != null &&
        widget.paciente!.cedula!.trim().isNotEmpty) {
      detalles.add('C.I: ${widget.paciente!.cedula!.trim()}');
    }
    if (widget.paciente?.telefono != null &&
        widget.paciente!.telefono!.trim().isNotEmpty) {
      detalles.add('Tlf: ${widget.paciente!.telefono!.trim()}');
    }
    if (widget.paciente?.ciudadOrigen != null &&
        widget.paciente!.ciudadOrigen!.trim().isNotEmpty) {
      detalles.add(widget.paciente!.ciudadOrigen!.trim());
    }
    return detalles.isNotEmpty ? detalles.join(' • ') : 'Expediente ambulatorio';
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final esBorrador = widget.cita.data['es_borrador'] == true ||
        widget.cita.estado == 'en_consulta';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          tooltip: 'Volver a la agenda',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Borrador conservado. Puedes volver a reanudar la consulta en cualquier momento.'),
              duration: Duration(seconds: 2),
            ));
            Navigator.pop(context);
            widget.onConsultaFinalizada();
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE0F2FE),
              child: Text(
                _obtenerNombrePaciente().isNotEmpty
                    ? _obtenerNombrePaciente()[0].toUpperCase()
                    : 'P',
                style: const TextStyle(
                  color: Color(0xFF0284C7),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _obtenerNombrePaciente(),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.mooli(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: esBorrador
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          esBorrador ? 'Borrador Activo' : 'En Atención',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: esBorrador
                                ? const Color(0xFFB45309)
                                : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _obtenerDetallesPaciente(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_done_rounded,
                    size: 15, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Text(
                  isEs ? 'Auto-guardado activo' : 'Auto-save active',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0284C7),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0284C7),
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle:
              GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.normal),
          tabs: [
            Tab(
              icon: const Icon(Icons.medical_services_rounded, size: 18),
              text: isEs ? '1. Consulta Actual' : '1. Current Consultation',
            ),
            Tab(
              icon: const Icon(Icons.history_rounded, size: 18),
              text: isEs ? '2. Historial & Estudios' : '2. History & Studies',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ConsultationActiveTab(
            idDoctor: widget.idDoctor,
            cita: widget.cita,
            paciente: widget.paciente,
            onConsultaFinalizada: () {
              Navigator.pop(context);
              widget.onConsultaFinalizada();
            },
          ),
          ConsultationHistoryTab(
            idDoctor: widget.idDoctor,
            idPaciente: widget.cita.idPaciente,
            paciente: widget.paciente,
          ),
        ],
      ),
    );
  }
}

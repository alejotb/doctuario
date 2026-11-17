import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../backend/supabase/supabase.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../appointments/request_appointment/request_appointment_widget.dart';
import '../../components/skeleton_shimmer.dart';
import '../doctor_share_helper.dart';
import 'components/doctor_availability_slots_widget.dart';

class DoctorPublicProfileWidget extends StatefulWidget {
  final String idDoctor;
  final String? nombreDoctor;
  final String? especialidadDoctor;
  final String? fotoUrlDoctor;

  const DoctorPublicProfileWidget({
    super.key,
    required this.idDoctor,
    this.nombreDoctor,
    this.especialidadDoctor,
    this.fotoUrlDoctor,
  });

  static String routeName = 'DoctorPublicProfile';
  static String routePath = '/doctorPublicProfile';

  @override
  State<DoctorPublicProfileWidget> createState() => _DoctorPublicProfileWidgetState();
}

class _DoctorPublicProfileWidgetState extends State<DoctorPublicProfileWidget> {
  bool _isLoading = true;
  UsuariosRow? _doctorUsuario;
  DoctoresRow? _doctorInfo;
  List<DoctorSedesRow> _sedes = [];
  List<HorariosDisponibilidadRow> _horarios = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosDoctor();
  }

  Future<void> _cargarDatosDoctor() async {
    setState(() => _isLoading = true);
    try {
      final userRows = await UsuariosTable().queryRows(
        queryFn: (q) => q.eq('id', widget.idDoctor).limit(1),
      );
      if (userRows.isNotEmpty) _doctorUsuario = userRows.first;

      final docRows = await DoctoresTable().queryRows(
        queryFn: (q) => q.eq('id', widget.idDoctor).limit(1),
      );
      if (docRows.isNotEmpty) _doctorInfo = docRows.first;

      _sedes = await DoctorSedesTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', widget.idDoctor),
      );

      _horarios = await HorariosDisponibilidadTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', widget.idDoctor).eq('activo', true),
      );
    } catch (e) {
      debugPrint('Error cargando perfil público: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _irAAgendarCita({DateTime? fechaHora, String? idSede, String? modalidad}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestAppointmentWidget(
          idDoctor: widget.idDoctor,
          nombreDoctor: _doctorUsuario?.nombre ?? widget.nombreDoctor ?? 'Doctor',
          especialidadDoctor: _doctorInfo?.especialidad ?? widget.especialidadDoctor ?? 'Medicina General',
          fechaHoraInicial: fechaHora,
          idSedeInicial: idSede,
          modalidadInicial: modalidad,
        ),
      ),
    );
  }

  void _abrirModalCompartir() async {
    if (_doctorUsuario == null) return;
    final texto = await DoctorShareHelper.generarTextoCompartirDoctor(
      doctorUsuario: _doctorUsuario!,
      doctorInfo: _doctorInfo ?? DoctoresRow({'especialidad': widget.especialidadDoctor}),
      sedes: _sedes,
      horarios: _horarios,
    );
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Compartir Perfil Médico',
                  style: GoogleFonts.mooli(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(modalCtx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Comparte la disponibilidad del Dr(a). ${_doctorUsuario?.nombre ?? widget.nombreDoctor ?? "Doctor"} para que otros pacientes agenden su cita.',
              style: TextStyle(fontSize: 12.5, color: FlutterFlowTheme.of(context).secondaryText),
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: const Color(0xFFECFDF5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF10B981),
                child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
              ),
              title: const Text('Enviar por WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: const Text('Comparte sedes y horarios por chat', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF10B981)),
              onTap: () async {
                Navigator.pop(modalCtx);
                await DoctorShareHelper.compartirPorWhatsApp(texto);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              tileColor: const Color(0xFFF0F9FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF0284C7),
                child: Icon(Icons.copy_rounded, color: Colors.white, size: 18),
              ),
              title: const Text('Copiar al Portapapeles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: const Text('Copia los datos de atención para pegar donde desees', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF0284C7)),
              onTap: () async {
                Navigator.pop(modalCtx);
                await DoctorShareHelper.copiarAlPortapapeles(texto);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📋 Perfil copiado al portapapeles.'), backgroundColor: Color(0xFF0284C7)),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorHeader(String nombre, String especialidad, String? fotoUrl, double? costo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: (fotoUrl != null && fotoUrl.isNotEmpty)
                      ? Image.network(
                          fotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40, color: Color(0xFF0369A1)),
                        )
                      : const Icon(Icons.person, size: 40, color: Color(0xFF0369A1)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Dr(a). $nombre',
                            style: GoogleFonts.mooli(fontSize: 16.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 17),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      especialidad,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                    ),
                    const SizedBox(height: 6),
                    if (costo != null && costo > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          'Consulta: \$${costo.toStringAsFixed(0)} USD',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0284C7),
              side: const BorderSide(color: Color(0xFF93C5FD)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(double.infinity, 36),
            ),
            onPressed: _abrirModalCompartir,
            icon: const Icon(Icons.share_outlined, size: 15),
            label: const Text('Compartir perfil médico', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSedesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Consultorios y Sedes', style: GoogleFonts.mooli(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('${_sedes.length} sede(s)', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 8),
        if (_sedes.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FlutterFlowTheme.of(context).alternate),
            ),
            child: const Text('No hay sedes registradas para este doctor.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          )
        else
          ..._sedes.map((sede) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FlutterFlowTheme.of(context).alternate),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFF0284C7), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sede.nombreSede ?? 'Sede Médica', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        if (sede.direccion != null && sede.direccion!.isNotEmpty)
                          Text(sede.direccion!, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (sede.ciudad != null)
                    Text(sede.ciudad!, style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1), fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _doctorUsuario?.nombre ?? widget.nombreDoctor ?? 'Doctor';
    final especialidad = _doctorInfo?.especialidad ?? widget.especialidadDoctor ?? 'Especialista';
    final fotoUrl = _doctorUsuario?.fotoUrl ?? widget.fotoUrlDoctor;
    final biografia = _doctorInfo?.biografia;
    final costo = _doctorInfo?.costoConsulta;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Perfil del Especialista', style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 16)),
        elevation: 0.5,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        foregroundColor: FlutterFlowTheme.of(context).primaryText,
        actions: [
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share_rounded, color: Color(0xFF0284C7)),
            onPressed: _abrirModalCompartir,
          ),
        ],
      ),
      body: _isLoading
          ? const SkeletonDoctorProfile()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDoctorHeader(nombre, especialidad, fotoUrl, costo),
                  const SizedBox(height: 16),

                  if (biografia != null && biografia.trim().isNotEmpty) ...[
                    Text('Acerca del Especialista', style: GoogleFonts.mooli(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
                      ),
                      child: Text(
                        biografia.trim(),
                        style: TextStyle(fontSize: 12.5, color: FlutterFlowTheme.of(context).secondaryText, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // COMPONENTE VIVO DE DISPONIBILIDAD Y CUPOS (PRÓXIMOS 7 DÍAS)
                  DoctorAvailabilitySlotsWidget(
                    idDoctor: widget.idDoctor,
                    sedes: _sedes,
                    horarios: _horarios,
                    onSeleccionarCita: ({required fechaHora, required idSede, required modalidadAtencion}) {
                      _irAAgendarCita(fechaHora: fechaHora, idSede: idSede, modalidad: modalidadAtencion);
                    },
                  ),

                  const SizedBox(height: 20),
                  _buildSedesSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -3)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  tooltip: 'Compartir Perfil',
                  icon: const Icon(Icons.share_rounded, color: Color(0xFF0284C7)),
                  onPressed: _abrirModalCompartir,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                  ),
                  onPressed: () => _irAAgendarCita(),
                  icon: const Icon(Icons.calendar_month_rounded, size: 20),
                  label: Text(
                    'Agendar Cita Médica',
                    style: GoogleFonts.mooli(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

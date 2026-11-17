import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/supabase/supabase.dart';
import '/components/user_profile_modal.dart';
import '/doctors/doctor_pacientes_list/doctor_pacientes_list_widget.dart';
import '/doctors/doctor_sedes_config/doctor_sedes_config_widget.dart';
import '/doctors/doctor_agenda_panel/dialogs/doctor_secretaries_modal.dart';
import '/doctors/components/doctor_support_dialog.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/doctors_service.dart';

class AgendaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AgendaAppBar({
    super.key,
    required this.idDoctor,
    required this.doctorNombre,
    this.doctorGenero,
    required this.sedes,
    required this.sedeSeleccionadaId,
    this.onSedeChanged,
    required this.hasCitaEnConsulta,
    required this.doctorPhotoUrl,
    required this.currentUserPhoto,
    required this.onNuevaCita,
    required this.onAvisarRetraso,
    required this.onIngresarUrgencia,
    required this.onRefresh,
    required this.onPerfilActualizado,
  });

  final String idDoctor;
  final String? doctorNombre;
  final String? doctorGenero;
  final List<DoctorSedesRow> sedes;
  final String? sedeSeleccionadaId;
  final ValueChanged<String?>? onSedeChanged;
  final bool hasCitaEnConsulta;
  final String? doctorPhotoUrl;
  final String currentUserPhoto;
  final VoidCallback onNuevaCita;
  final VoidCallback onAvisarRetraso;
  final VoidCallback onIngresarUrgencia;
  final VoidCallback onRefresh;
  final VoidCallback onPerfilActualizado;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  String _construirTituloDoctor() {
    final rawName = doctorNombre?.trim() ?? '';
    if (rawName.isEmpty) return 'Portal Médico';

    final isFemale = DoctorItem.isFemaleDoctor(doctorGenero, rawName);
    final prefix = isFemale ? 'Dra.' : 'Dr.';

    final cleaned = rawName
        .replaceAll(RegExp(r'^(dr\.|dra\.|doctor|doctora)\s+', caseSensitive: false), '')
        .trim();

    return '$prefix $cleaned';
  }

  Widget _buildDisponibilidadBadge() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: hasCitaEnConsulta ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasCitaEnConsulta ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: hasCitaEnConsulta ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            hasCitaEnConsulta ? 'En Consulta' : 'Disponible',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: hasCitaEnConsulta ? const Color(0xFF991B1B) : const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    final String sedeNombre = sedeSeleccionadaId == null
        ? (sedes.length > 1
            ? 'Todas las Sedes'
            : (sedes.isNotEmpty ? sedes.first.nombreSede ?? 'Portal Clínico' : 'Portal Clínico'))
        : (sedes
                .firstWhere(
                  (s) => s.id == sedeSeleccionadaId,
                  orElse: () => sedes.first,
                )
                .nombreSede ??
            'Portal Clínico');

    final String doctorTitleFormatted = _construirTituloDoctor();
    final String subtitleText = sedeNombre;

    final String photoToShow = (doctorPhotoUrl != null && doctorPhotoUrl!.isNotEmpty)
        ? doctorPhotoUrl!
        : currentUserPhoto;

    if (isMobile) {
      return AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: FlutterFlowTheme.of(context).primaryText,
        elevation: 0.5,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25), width: 1.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/images/doctuario_logo.png', width: 28, height: 28, fit: BoxFit.cover, filterQuality: FilterQuality.high),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                doctorTitleFormatted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.mooli(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(width: 8),
            _buildDisponibilidadBadge(),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Opciones de Agenda',
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF0284C7)),
            onSelected: (val) async {
              switch (val) {
                case 'nueva_cita':
                  onNuevaCita();
                  break;
                case 'urgencia':
                  onIngresarUrgencia();
                  break;
                case 'retraso':
                  onAvisarRetraso();
                  break;
                case 'refresh':
                  onRefresh();
                  break;
                case 'sedes':
                  context.goNamed(DoctorSedesConfigWidget.routeName);
                  break;
                case 'pacientes':
                  context.goNamed(DoctorPacientesListWidget.routeName);
                  break;
                case 'secretarias':
                  DoctorSecretariesModal.show(context, idDoctor: idDoctor, sedes: sedes);
                  break;
                case 'perfil':
                  await UserProfileModal.show(context, isDoctorView: true);
                  onPerfilActualizado();
                  break;
                case 'soporte':
                  DoctorSupportDialog.show(
                    context,
                    idDoctor: idDoctor,
                    doctorNombre: doctorNombre ?? 'Doctor/a',
                  );
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'nueva_cita',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: Color(0xFF0284C7), size: 18),
                    SizedBox(width: 10),
                    Text('Agendar Cita', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'urgencia',
                child: Row(
                  children: [
                    Icon(Icons.emergency, color: Colors.red, size: 18),
                    SizedBox(width: 10),
                    Text('Ingresar Urgencia', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'retraso',
                child: Row(
                  children: [
                    Icon(Icons.campaign, color: Colors.orange, size: 18),
                    SizedBox(width: 10),
                    Text('Avisar Retraso', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'sedes',
                child: Row(
                  children: [
                    Icon(Icons.location_city_rounded, color: Color(0xFF0284C7), size: 18),
                    SizedBox(width: 10),
                    Text('Mis Sedes', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pacientes',
                child: Row(
                  children: [
                    Icon(Icons.people_alt_rounded, color: Color(0xFF334155), size: 18),
                    SizedBox(width: 10),
                    Text('Mis Pacientes', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'secretarias',
                child: Row(
                  children: [
                    Icon(Icons.support_agent_rounded, color: Color(0xFF0F766E), size: 18),
                    SizedBox(width: 10),
                    Text('Mis Secretarias', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(children: [Icon(Icons.refresh, size: 18), SizedBox(width: 10), Text('Actualizar Agenda', style: TextStyle(fontSize: 13))]),
              ),
              const PopupMenuItem(
                value: 'perfil',
                child: Row(children: [Icon(Icons.person_outline, size: 18), SizedBox(width: 10), Text('Mi Perfil', style: TextStyle(fontSize: 13))]),
              ),
              const PopupMenuItem(
                value: 'soporte',
                child: Row(children: [Icon(Icons.headset_mic_rounded, color: Color(0xFF0284C7), size: 18), SizedBox(width: 10), Text('Soporte y Ayuda', style: TextStyle(fontSize: 13))]),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      );
    }

    // Versión Desktop
    return AppBar(
      title: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/doctuario_logo.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Doc',
                    style: GoogleFonts.mooli(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'tuario',
                    style: GoogleFonts.mooli(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              if (sedes.length > 1 && onSedeChanged != null)
                PopupMenuButton<String?>(
                  tooltip: 'Cambiar o filtrar sede',
                  initialValue: sedeSeleccionadaId,
                  onSelected: onSedeChanged,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subtitleText,
                        style: GoogleFonts.mooli(
                          fontSize: 10.5,
                          color: const Color(0xFF0284C7),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF0284C7)),
                    ],
                  ),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem<String?>(
                      value: null,
                      child: Text(
                        '🌐 Todas las Sedes',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...sedes.map(
                      (s) => PopupMenuItem<String?>(
                        value: s.id,
                        child: Text(s.nombreSede ?? 'Sede', style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  subtitleText,
                  style: GoogleFonts.mooli(
                    fontSize: 10.5,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.white,
      foregroundColor: FlutterFlowTheme.of(context).primaryText,
      elevation: 0.5,
      actions: [
        _buildDisponibilidadBadge(),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Mis Sedes',
          icon: const Icon(Icons.location_city_rounded, color: Color(0xFF0284C7)),
          onPressed: () => context.goNamed(DoctorSedesConfigWidget.routeName),
        ),
        IconButton(
          tooltip: 'Mis Pacientes',
          icon: const Icon(Icons.people_alt_rounded),
          onPressed: () => context.goNamed(DoctorPacientesListWidget.routeName),
        ),
        IconButton(
          tooltip: 'Mis Secretarias',
          icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF0F766E)),
          onPressed: () {
            DoctorSecretariesModal.show(context, idDoctor: idDoctor, sedes: sedes);
          },
        ),
        IconButton(
          tooltip: 'Agendar Cita',
          icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0284C7)),
          onPressed: onNuevaCita,
        ),
        IconButton(
          tooltip: 'Avisar Retraso / Salida',
          icon: const Icon(Icons.campaign, color: Colors.orange),
          onPressed: onAvisarRetraso,
        ),
        IconButton(
          tooltip: 'Ingresar Urgencia',
          icon: const Icon(Icons.emergency, color: Colors.red),
          onPressed: onIngresarUrgencia,
        ),
        IconButton(
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh,
        ),
        IconButton(
          tooltip: 'Soporte y Ayuda',
          icon: const Icon(Icons.headset_mic_rounded, color: Color(0xFF0284C7)),
          onPressed: () {
            DoctorSupportDialog.show(
              context,
              idDoctor: idDoctor,
              doctorNombre: doctorNombre ?? 'Doctor/a',
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0, left: 4.0),
          child: Builder(
            builder: (avatarContext) => InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await UserProfileModal.show(avatarContext, isDoctorView: true);
                onPerfilActualizado();
              },
              child: Container(
                width: 36,
                height: 36,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: photoToShow.isNotEmpty
                    ? Image.network(
                        photoToShow,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 22),
                      )
                    : const Icon(Icons.person, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

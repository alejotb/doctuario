import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../flutter_flow/flutter_flow_theme.dart';
import '../../../services/i18n_service.dart';

/// Diálogo modal para configurar las preferencias de notificaciones,
/// adaptado dinámicamente según el rol del usuario (Doctor vs Paciente).
class NotificationPreferencesDialog extends StatefulWidget {
  final bool isDoctor;

  const NotificationPreferencesDialog({
    super.key,
    required this.isDoctor,
  });

  static Future<void> show(BuildContext context, {bool isDoctor = false}) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => NotificationPreferencesDialog(isDoctor: isDoctor),
    );
  }

  @override
  State<NotificationPreferencesDialog> createState() => _NotificationPreferencesDialogState();
}

class _NotificationPreferencesDialogState extends State<NotificationPreferencesDialog> {
  bool _isLoading = true;

  // Preferencias para Médicos
  bool _docNuevasCitas = true;
  bool _docLlegadaSala = true;
  bool _docCancelaciones = true;
  bool _docSobrecitas = true;
  bool _docNuevosEstudios = true;
  bool _docAlertasUrgencia = true;
  bool _docWhatsappResumen = true;
  bool _docInApp = true;

  // Preferencias para Pacientes
  bool _pacRecordatorioCitas = true;
  bool _pacAvisosRetraso = true;
  bool _pacConfirmacionTurno = true;
  bool _pacRecetasEmitidas = true;
  bool _pacEstudiosRevisados = true;
  bool _pacWhatsappRecordatorios = true;
  bool _pacInApp = true;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (widget.isDoctor) {
        _docNuevasCitas = prefs.getBool('notif_doc_nuevas_citas') ?? true;
        _docLlegadaSala = prefs.getBool('notif_doc_llegada_sala') ?? true;
        _docCancelaciones = prefs.getBool('notif_doc_cancelaciones') ?? true;
        _docSobrecitas = prefs.getBool('notif_doc_sobrecitas') ?? true;
        _docNuevosEstudios = prefs.getBool('notif_doc_estudios') ?? true;
        _docAlertasUrgencia = prefs.getBool('notif_doc_urgencia') ?? true;
        _docWhatsappResumen = prefs.getBool('notif_doc_whatsapp') ?? true;
        _docInApp = prefs.getBool('notif_doc_in_app') ?? true;
      } else {
        _pacRecordatorioCitas = prefs.getBool('notif_pac_recordatorio') ?? true;
        _pacAvisosRetraso = prefs.getBool('notif_pac_retraso') ?? true;
        _pacConfirmacionTurno = prefs.getBool('notif_pac_confirmacion') ?? true;
        _pacRecetasEmitidas = prefs.getBool('notif_pac_recetas') ?? true;
        _pacEstudiosRevisados = prefs.getBool('notif_pac_estudios') ?? true;
        _pacWhatsappRecordatorios = prefs.getBool('notif_pac_whatsapp') ?? true;
        _pacInApp = prefs.getBool('notif_pac_in_app') ?? true;
      }
    } catch (e) {
      debugPrint('Error cargando preferencias de notificaciones: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarPreferencia(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, val);
    } catch (e) {
      debugPrint('Error guardando $key: $e');
    }
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.alternate.withValues(alpha: 0.6)),
        ),
        child: SwitchListTile.adaptive(
          activeTrackColor: const Color(0xFF0284C7),
          activeThumbColor: Colors.white,
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            title,
            style: GoogleFonts.mooli(fontSize: 13.5, fontWeight: FontWeight.bold, color: theme.primaryText),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.mooli(fontSize: 11.5, color: theme.secondaryText),
          ),
          value: value,
          onChanged: (v) {
            onChanged(v);
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 6.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.mooli(fontSize: 11.0, fontWeight: FontWeight.w800, color: const Color(0xFF0284C7), letterSpacing: 0.6),
      ),
    );
  }

  List<Widget> _buildDoctorOptions(bool isEs) {
    return [
      _buildSectionHeader(isEs ? 'Agenda y Pacientes' : 'Schedule & Patients'),
      _buildSwitchTile(
        icon: Icons.event_available_rounded,
        iconColor: const Color(0xFF0284C7),
        title: isEs ? 'Nuevas Citas Agendadas' : 'New Booked Appointments',
        subtitle: isEs ? 'Avisar cuando un paciente o secretaria reserve un turno' : 'Notify when a new appointment is booked',
        value: _docNuevasCitas,
        onChanged: (v) {
          _docNuevasCitas = v;
          _guardarPreferencia('notif_doc_nuevas_citas', v);
        },
      ),
      _buildSwitchTile(
        icon: Icons.how_to_reg_rounded,
        iconColor: const Color(0xFF0D9488),
        title: isEs ? 'Llegada de Paciente a Sala' : 'Patient Arrival at Lobby',
        subtitle: isEs ? 'Notificar cuando recepción marque la llegada del paciente' : 'Notify when patient arrival is confirmed',
        value: _docLlegadaSala,
        onChanged: (v) {
          _docLlegadaSala = v;
          _guardarPreferencia('notif_doc_llegada_sala', v);
        },
      ),
      _buildSwitchTile(
        icon: Icons.event_busy_rounded,
        iconColor: const Color(0xFFEF4444),
        title: isEs ? 'Cancelaciones de Turnos' : 'Appointment Cancellations',
        subtitle: isEs ? 'Alerta inmediata cuando un turno sea liberado' : 'Immediate alert when a slot becomes free',
        value: _docCancelaciones,
        onChanged: (v) {
          _docCancelaciones = v;
          _guardarPreferencia('notif_doc_cancelaciones', v);
        },
      ),
      _buildSwitchTile(
        icon: Icons.person_add_alt_1_rounded,
        iconColor: const Color(0xFFD97706),
        title: isEs ? 'Solicitudes de Sobrecitas' : 'Overbooking Requests',
        subtitle: isEs ? 'Avisos de pacientes extra que requieren tu confirmación' : 'Alerts for extra slots requiring your approval',
        value: _docSobrecitas,
        onChanged: (v) {
          _docSobrecitas = v;
          _guardarPreferencia('notif_doc_sobrecitas', v);
        },
      ),
      _buildSectionHeader(isEs ? 'Expedientes y Urgencias' : 'Records & Emergencies'),
      _buildSwitchTile(
        icon: Icons.upload_file_rounded,
        iconColor: const Color(0xFF6366F1),
        title: isEs ? 'Nuevos Estudios y Paraclínicos' : 'New Lab & Imaging Uploads',
        subtitle: isEs ? 'Alerta cuando se adjunten análisis o PDF al expediente' : 'Alert when patient studies are attached',
        value: _docNuevosEstudios,
        onChanged: (v) {
          _docNuevosEstudios = v;
          _guardarPreferencia('notif_doc_estudios', v);
        },
      ),
      _buildSwitchTile(
        icon: Icons.emergency_rounded,
        iconColor: Colors.red,
        title: isEs ? 'Alertas de Emergencia en Sala' : 'Emergency Room Alerts',
        subtitle: isEs ? 'Aviso prioritario si recepción ingresa una urgencia' : 'Priority notification for walk-in emergencies',
        value: _docAlertasUrgencia,
        onChanged: (v) {
          _docAlertasUrgencia = v;
          _guardarPreferencia('notif_doc_urgencia', v);
        },
      ),
      _buildSectionHeader(isEs ? 'Canales de Notificación' : 'Delivery Channels'),
      _buildSwitchTile(
        icon: Icons.notifications_active_rounded,
        iconColor: const Color(0xFF0284C7),
        title: isEs ? 'Campanita de la Plataforma' : 'In-App Bell Notifications',
        subtitle: isEs ? 'Alertas visuales en tiempo real en la barra superior' : 'Real-time bell alerts in desktop and mobile bar',
        value: _docInApp,
        onChanged: (v) {
          _docInApp = v;
          _guardarPreferencia('notif_doc_in_app', v);
        },
      ),
      _buildSwitchTile(
        icon: Icons.chat_rounded,
        iconColor: const Color(0xFF10B981),
        title: isEs ? 'Resumen Diario por WhatsApp' : 'Daily WhatsApp Schedule',
        subtitle: isEs ? 'Recibir itinerario de pacientes y citas del día por WhatsApp' : 'Receive daily agenda overview via WhatsApp',
        value: _docWhatsappResumen,
        onChanged: (v) {
          _docWhatsappResumen = v;
          _guardarPreferencia('notif_doc_whatsapp', v);
        },
      ),
    ];
  }

  List<Widget> _buildPatientOptions(bool isEs) {
    return [
      _buildSectionHeader(isEs ? 'Recordatorios de Citas' : 'Appointment Reminders'),
      _buildSwitchTile(
        icon: Icons.alarm_rounded,
        iconColor: const Color(0xFF0284C7),
        title: isEs ? 'Recordatorios de Cita Próxima' : 'Upcoming Appointment Reminder',
        subtitle: isEs ? 'Aviso 24 horas y 2 horas antes de tu consulta médica' : 'Alerts 24h and 2h before your scheduled consult',
        value: _pacRecordatorioCitas,
        onChanged: (v) {
          _pacRecordatorioCitas = v;
          _guardarPreferencia('notif_pac_recordatorio', v);
        },
      ),
      _buildSwitchTile(
        icon: Icons.campaign_rounded,
        iconColor: const Color(0xFFD97706),
        title: isEs ? 'Avisos de Retraso del Médico' : 'Doctor Delay Broadcasts',
        subtitle: isEs ? 'Notificación en tiempo real si tu doctor tiene demora en consultorio' : 'Real-time alert if your doctor experiences delays',
        value: _pacAvisosRetraso,
        onChanged: (v) {
          _pacAvisosRetraso = v;
          _guardarPreferencia('notif_pac_retraso', v);
        },
      ),
      _buildSwitchTile(
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF10B981),
        title: isEs ? 'Confirmación y Cambios de Turno' : 'Appointment Confirmations',
        subtitle: isEs ? 'Aviso cuando el consultorio confirme o reprograme tu cita' : 'Alert when your booking is approved or rescheduled',
        value: _pacConfirmacionTurno,
        onChanged: (v) {
          _pacConfirmacionTurno = v;
          _guardarPreferencia('notif_pac_confirmacion', v);
        },
      ),
      _buildSectionHeader(isEs ? 'Atención y Documentos' : 'Care & Medical Documents'),
      _buildSwitchTile(
        icon: Icons.description_outlined,
        iconColor: const Color(0xFF6366F1),
        title: isEs ? 'Recetas y Reposos Médicos' : 'Prescriptions & Medical Leaves',
        subtitle: isEs ? 'Alerta inmediata cuando tu médico emita recetas o informes' : 'Notification when prescriptions or sick leaves are issued',
        value: _pacRecetasEmitidas,
        onChanged: (v) {
          _pacRecetasEmitidas = v;
          _guardarPreferencia('notif_pac_recetas', v);
        },
      ),
      _buildSwitchTile(
        icon: Icons.science_outlined,
        iconColor: const Color(0xFF0D9488),
        title: isEs ? 'Resultados de Estudios Revisados' : 'Reviewed Lab & Test Results',
        subtitle: isEs ? 'Aviso cuando el especialista revise tus análisis médicos' : 'Alert when the physician reviews your tests',
        value: _pacEstudiosRevisados,
        onChanged: (v) {
          _pacEstudiosRevisados = v;
          _guardarPreferencia('notif_pac_estudios', v);
        },
      ),
      _buildSectionHeader(isEs ? 'Canales de Notificación' : 'Delivery Channels'),
      _buildSwitchTile(
        icon: Icons.notifications_active_rounded,
        iconColor: const Color(0xFF0284C7),
        title: isEs ? 'Notificaciones en la App' : 'In-App Bell Notifications',
        subtitle: isEs ? 'Alertas en la campanita de la barra superior' : 'Alerts in top bar notification bell',
        value: _pacInApp,
        onChanged: (v) {
          _pacInApp = v;
          _guardarPreferencia('notif_pac_in_app', v);
        },
      ),
      _buildSwitchTile(
        icon: Icons.chat_rounded,
        iconColor: const Color(0xFF10B981),
        title: isEs ? 'Recordatorios por WhatsApp' : 'WhatsApp Reminders',
        subtitle: isEs ? 'Recibir avisos y confirmaciones a tu número de WhatsApp' : 'Receive updates and reminders directly on WhatsApp',
        value: _pacWhatsappRecordatorios,
        onChanged: (v) {
          _pacWhatsappRecordatorios = v;
          _guardarPreferencia('notif_pac_whatsapp', v);
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final theme = FlutterFlowTheme.of(context);
    final width = MediaQuery.of(context).size.width;
    final dialogWidth = (width * 0.92).clamp(320.0, 560.0);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: theme.secondaryBackground,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune_rounded, color: Color(0xFF0284C7), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEs ? 'Preferencias de Notificaciones' : 'Notification Preferences',
                  style: GoogleFonts.mooli(fontSize: 16.5, fontWeight: FontWeight.bold, color: theme.primaryText),
                ),
                Text(
                  widget.isDoctor
                      ? (isEs ? 'Avisos clínicos y de agenda médica' : 'Clinical & medical schedule alerts')
                      : (isEs ? 'Recordatorios y avisos para el paciente' : 'Reminders & patient alerts'),
                  style: GoogleFonts.mooli(fontSize: 11.5, color: theme.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: _isLoading
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF0284C7))),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.isDoctor ? _buildDoctorOptions(isEs) : _buildPatientOptions(isEs),
                ),
              ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            isEs ? 'Listo / Guardar' : 'Done / Save',
            style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

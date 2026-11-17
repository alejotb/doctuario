import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/i18n_service.dart';
import '../admin/admin_doctor_tenants_modal_widget.dart';
import '../doctors/components/doctor_logo_config_dialog.dart';
import '../doctors/components/doctor_gemini_config_dialog.dart';
import '../doctors/doctor_agenda_panel/dialogs/doctor_vacation_dialog.dart';
import '../my_account/dialogs/notification_preferences_dialog.dart';
import '../services/gemini_ai_service.dart';
import '/index.dart';

class UserProfileModal extends StatefulWidget {
  final bool isDoctorView;
  final VoidCallback? onDismiss;

  const UserProfileModal({
    super.key,
    this.isDoctorView = false,
    this.onDismiss,
  });

  /// Shows the user profile modal anchored directly beneath the tapped avatar widget.
  static Future<void> show(
    BuildContext context, {
    bool isDoctorView = false,
  }) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    double topPosition = 74.0;
    double rightPosition = 16.0;

    if (renderBox != null && renderBox.hasSize) {
      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      if (size.height > 0 && size.height <= 100 && offset.dy < screenHeight * 0.4) {
        topPosition = offset.dy + size.height + 6.0;
        rightPosition = (screenWidth - (offset.dx + size.width)).clamp(12.0, screenWidth - 100.0);
      } else if (size.height > 0 && size.height <= 100 && offset.dy >= screenHeight * 0.4) {
        topPosition = (offset.dy - 460.0).clamp(50.0, screenHeight - 200.0);
        rightPosition = (screenWidth - (offset.dx + size.width)).clamp(12.0, screenWidth - 100.0);
      }
    }
    topPosition = topPosition.clamp(50.0, (screenHeight - 200.0).clamp(50.0, screenHeight));

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'UserProfileDismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogCtx, anim1, anim2) => Stack(children: [
        Positioned(
          top: topPosition, right: rightPosition,
          child: Material(color: Colors.transparent, child: UserProfileModal(isDoctorView: isDoctorView, onDismiss: () => Navigator.of(dialogCtx).pop())),
        ),
      ]),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
  }

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal> {
  UsuariosRow? _usuario;
  bool _isDoctorUser = false;
  bool _isLoading = true;
  late bool _doctorSwitchValue;

  @override
  void initState() {
    super.initState();
    _isDoctorUser = widget.isDoctorView;
    _doctorSwitchValue = widget.isDoctorView && DualDatabaseConfig.instance.isDoctorViewActive;
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    final uid = SupaFlow.client.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      try {
        final rows = await UsuariosTable().querySingleRow(
          queryFn: (q) => q.eq('id', uid),
        );
        if (rows.isNotEmpty && mounted) {
          _usuario = rows.first;
          final role = (_usuario?.rol ?? '').trim().toLowerCase();
          final isExplicitPatient = role == 'paciente';
          _isDoctorUser = !isExplicitPatient && (role == 'doctor' || widget.isDoctorView);
          _doctorSwitchValue = _isDoctorUser && DualDatabaseConfig.instance.isDoctorViewActive;
          setState(() => _isLoading = false);
          return;
        }
      } catch (e) {
        debugPrint('Error cargando datos de usuario en modal: $e');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;
    final isSpanish = i18n.isSpanish;
    final screenWidth = MediaQuery.of(context).size.width;
    final modalWidth = (screenWidth * 0.88).clamp(280.0, 320.0);

    final rawRole = (_usuario?.rol ?? '').trim().toLowerCase();
    final isExplicitPatient = rawRole == 'paciente';
    final isDoctor = !isExplicitPatient && (rawRole == 'doctor' || widget.isDoctorView);
    final userName = _usuario?.nombre != null && _usuario!.nombre!.trim().isNotEmpty
        ? _usuario!.nombre!.trim()
        : (currentUserEmail.isNotEmpty ? currentUserEmail.split('@').first : 'Usuario');
    final userPhoto = _usuario?.fotoUrl;
    final userCity = _usuario?.ciudadOrigen;

    return Container(
      width: modalWidth,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.8),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20.0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _isLoading
          ? Container(
              height: 180.0,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: FlutterFlowTheme.of(context).primary,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Información del Usuario (Avatar, Nombre, Rol, Email)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 12.0),
                  child: Row(
                    children: [
                      // Avatar del usuario cargado desde UsuariosTable
                      Container(
                        width: 52.0,
                        height: 52.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).primary,
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.15),
                              blurRadius: 6.0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30.0),
                          child: (userPhoto != null && userPhoto.trim().isNotEmpty)
                              ? Image.network(
                                  userPhoto,
                                  width: 52.0,
                                  height: 52.0,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.person_rounded,
                                    size: 30.0,
                                    color: FlutterFlowTheme.of(context).secondaryText,
                                  ),
                                )
                              : Icon(
                                  Icons.person_rounded,
                                  size: 30.0,
                                  color: FlutterFlowTheme.of(context).secondaryText,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      // Datos de texto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userName,
                              style: FlutterFlowTheme.of(context).titleMedium.override(
                                    font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2.0),
                            // Badge de rol sutil
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: isDoctor
                                    ? FlutterFlowTheme.of(context).secondary.withValues(alpha: 0.15)
                                    : (rawRole == 'administrador'
                                        ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                                        : (rawRole == 'secretaria'
                                            ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                                            : FlutterFlowTheme.of(context).primary.withValues(alpha: 0.12))),
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Text(
                                isDoctor
                                    ? (isSpanish ? 'Doctor / Médico' : 'Doctor')
                                    : (rawRole == 'administrador'
                                        ? (isSpanish ? 'Administrador' : 'Administrator')
                                        : (rawRole == 'secretaria'
                                            ? (isSpanish ? 'Secretaria' : 'Secretary')
                                            : (isSpanish ? 'Paciente' : 'Patient'))),
                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.mooli(fontWeight: FontWeight.w600),
                                      color: isDoctor
                                          ? FlutterFlowTheme.of(context).secondary
                                          : (rawRole == 'administrador'
                                              ? const Color(0xFF7C3AED)
                                              : (rawRole == 'secretaria' ? const Color(0xFF0D9488) : FlutterFlowTheme.of(context).primary)),
                                      fontSize: 10.5,
                                    ),
                              ),
                            ),
                            if (currentUserEmail.isNotEmpty) ...[
                              const SizedBox(height: 3.0),
                              Text(
                                currentUserEmail,
                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.mooli(),
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                      fontSize: 11.0,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (userCity != null && userCity.trim().isNotEmpty) ...[
                              const SizedBox(height: 2.0),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 11.0,
                                    color: FlutterFlowTheme.of(context).secondaryText,
                                  ),
                                  const SizedBox(width: 2.0),
                                  Expanded(
                                    child: Text(
                                      userCity,
                                      style: FlutterFlowTheme.of(context).bodySmall.override(
                                            font: GoogleFonts.mooli(),
                                            color: FlutterFlowTheme.of(context).secondaryText,
                                            fontSize: 10.5,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1.0),

                // 2. Switch simple para cambiar entre modo Doctor y Paciente (SOLO VISIBLE PARA DOCTORES)
                if (isDoctor) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSpanish ? 'Modo Doctor' : 'Doctor Mode',
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                      font: GoogleFonts.mooli(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                isSpanish ? 'Alternar vista doctor / paciente' : 'Toggle doctor / patient view',
                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.mooli(),
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                      fontSize: 10.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _doctorSwitchValue,
                          activeTrackColor: FlutterFlowTheme.of(context).primary,
                          onChanged: (bool newValue) async {
                            setState(() {
                              _doctorSwitchValue = newValue;
                            });
                            await DualDatabaseConfig.instance.persistActiveViewMode(
                              newValue ? 'doctor' : 'paciente',
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              if (newValue) {
                                // Cambiar a vista Doctor
                                final uid = currentUserUid.isNotEmpty
                                    ? currentUserUid
                                    : (SupaFlow.client.auth.currentUser?.id ?? '');
                                context.goNamedAuth(
                                  DoctorAgendaPanelWidget.routeName,
                                  context.mounted,
                                  queryParameters: {
                                    'idDoctor': serializeParam(uid, ParamType.String),
                                  }.withoutNulls,
                                );
                              } else {
                                // Cambiar a vista Paciente
                                context.goNamedAuth(HomeWidget.routeName, context.mounted);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1.0),
                ],

                // 3. Opciones: Ver perfil completo y Cerrar sesión
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  child: Column(
                    children: [
                      // Ver perfil completo
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                        leading: Icon(Icons.account_circle_outlined, color: FlutterFlowTheme.of(context).primary, size: 20.0),
                        title: Text(isSpanish ? 'Ver perfil completo' : 'View full profile', style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w500), fontSize: 13.0)),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 18.0),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.goNamed(MyAccountWidget.routeName);
                        },
                      ),
                      // Preferencias de notificaciones
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                        leading: const Icon(Icons.tune_rounded, color: Color(0xFFEAB308), size: 20.0),
                        title: Text(isSpanish ? 'Preferencias de notificaciones' : 'Notification preferences', style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w500), fontSize: 13.0)),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 18.0),
                        onTap: () {
                          Navigator.of(context).pop();
                          NotificationPreferencesDialog.show(context, isDoctor: isDoctor);
                        },
                      ),
                      if (rawRole == 'administrador') ...[
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                          leading: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF3B82F6), size: 20.0),
                          title: Text(isSpanish ? 'Control de Cuentas' : 'Accounts Control', style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w500), fontSize: 13.0)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 18.0),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.goNamed(AdminAccountsDashboardWidget.routeName);
                          },
                        ),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                          leading: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF249689), size: 20.0),
                          title: Text(isSpanish ? 'Aprobación de Consultorios' : 'Tenants Approval', style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w500), fontSize: 13.0)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 18.0),
                          onTap: () {
                            Navigator.of(context).pop();
                            AdminDoctorTenantsModalWidget.show(context);
                          },
                        ),
                      ],
                      if (isDoctor) ...[
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                          leading: const Icon(Icons.business_rounded, color: Color(0xFF0284C7), size: 20.0),
                          title: Text(isSpanish ? 'Membrete y Logo Médico' : 'Medical Letterhead / Logo', style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w500), fontSize: 13.0)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 18.0),
                          onTap: () {
                            Navigator.of(context).pop();
                            final uid = currentUserUid.isNotEmpty ? currentUserUid : (SupaFlow.client.auth.currentUser?.id ?? '');
                            if (uid.isNotEmpty) DoctorLogoConfigDialog.show(context, idDoctor: uid);
                          },
                        ),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                          leading: const Icon(Icons.beach_access_rounded, color: Color(0xFFD97706), size: 20.0),
                          title: Text(isSpanish ? 'Vacaciones / Días Bloqueados' : 'Vacations / Blocked Days', style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w500), fontSize: 13.0)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 18.0),
                          onTap: () {
                            Navigator.of(context).pop();
                            final uid = currentUserUid.isNotEmpty ? currentUserUid : (SupaFlow.client.auth.currentUser?.id ?? '');
                            if (uid.isNotEmpty) DoctorVacationDialog.show(context, idDoctor: uid, onDiasActualizados: () {});
                          },
                        ),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                          leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 20.0),
                          title: Text(isSpanish ? 'Asistente IA (Gemini 3.8)' : 'AI Assistant (Gemini 3.8)', style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w500), fontSize: 13.0)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: GeminiAiService.instance.hasKey ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)), child: Text(GeminiAiService.instance.hasKey ? (isSpanish ? 'Activo' : 'Active') : (isSpanish ? 'Apagado' : 'Off'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GeminiAiService.instance.hasKey ? const Color(0xFF16A34A) : const Color(0xFF64748B)))),
                            const SizedBox(width: 4), const Icon(Icons.chevron_right_rounded, size: 18.0),
                          ]),
                          onTap: () {
                            Navigator.of(context).pop();
                            DoctorGeminiConfigDialog.show(context);
                          },
                        ),
                      ],
                      // Cerrar sesión
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                        leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20.0),
                        title: Text(isSpanish ? 'Cerrar sesión' : 'Sign out', style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w500), color: Colors.redAccent, fontSize: 13.0)),
                        onTap: () async {
                          Navigator.of(context).pop();
                          AppStateNotifier.instance.updateNotifyOnAuthChange(true);
                          await authManager.signOut();
                          AppStateNotifier.instance.clearRedirectLocation();
                          final navContext = appNavigatorKey.currentContext;
                          if (navContext != null && navContext.mounted) navContext.goNamed(Login1Widget.routeName);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

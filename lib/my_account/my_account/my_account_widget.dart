import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/components/change_password_dialog.dart';
import '/doctors/components/doctor_gemini_config_dialog.dart';
import '/doctors/components/doctor_logo_config_dialog.dart';
import '/doctors/components/doctor_solo_mode_dialog.dart';
import '/doctors/components/doctor_studies_config_dialog.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/main.dart';
import '/services/admin_tenant_service.dart';
import '/services/gemini_ai_service.dart';
import '/services/i18n_service.dart';
import '/services/secretary_management_service.dart';
import '../dialogs/notification_preferences_dialog.dart';
import 'family_linking_modal.dart';
import 'my_account_model.dart';

export 'my_account_model.dart';

/// Pantalla adaptativa del perfil del usuario (Doctor, Secretaria o Paciente).
class MyAccountWidget extends StatefulWidget {
  const MyAccountWidget({super.key});
  static String routeName = 'MyAccount';
  static String routePath = '/myAccount';

  @override
  State<MyAccountWidget> createState() => _MyAccountWidgetState();
}

class _MyAccountWidgetState extends State<MyAccountWidget> {
  late MyAccountModel _model;
  UsuariosRow? _usuario;
  DoctoresRow? _doctorData;
  int _conteoPendientesAdmin = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MyAccountModel());
    _cargarDatos();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final uid = SupaFlow.client.auth.currentUser?.id ?? currentUserUid;
    await GeminiAiService.instance.init();
    if (uid.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final userRows = await UsuariosTable().querySingleRow(queryFn: (q) => q.eq('id', uid));
      final user = userRows.isNotEmpty ? userRows.first : null;
      DoctoresRow? doc;
      int pendientes = 0;
      final role = (user?.rol ?? '').trim().toLowerCase();
      if (role == 'admin' || role == 'administrador') {
        pendientes = await AdminTenantService.instance.obtenerConteoPendientes();
      }

      if (role == 'doctor') {
        final docRows = await DoctoresTable().querySingleRow(queryFn: (q) => q.eq('id', uid));
        if (docRows.isNotEmpty) doc = docRows.first;
      }

      if (mounted) {
        setState(() {
          _usuario = user;
          _doctorData = doc;
          _conteoPendientesAdmin = pendientes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final isEs = I18nService.instance.isSpanish;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEs ? 'Cerrar Sesión' : 'Sign Out', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
        content: Text(isEs ? '¿Estás seguro de que deseas salir de tu cuenta?' : 'Are you sure you want to log out?', style: GoogleFonts.mooli()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(isEs ? 'Cancelar' : 'Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), onPressed: () => Navigator.of(ctx).pop(true), child: Text(isEs ? 'Cerrar Sesión' : 'Sign Out')),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      AppStateNotifier.instance.updateNotifyOnAuthChange(true);
      await authManager.signOut();
      AppStateNotifier.instance.clearRedirectLocation();
      if (mounted) context.goNamed(Login1Widget.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final theme = FlutterFlowTheme.of(context);
    final nombre = _usuario?.nombre ?? (currentUserDisplayName.isNotEmpty ? currentUserDisplayName : (isEs ? 'Usuario' : 'User'));
    final email = _usuario?.email ?? currentUserEmail;
    final telefono = _usuario?.telefono ?? '';
    final fotoUrl = (_usuario?.fotoUrl ?? '').trim();
    final rol = (_usuario?.rol ?? '').trim().toLowerCase();
    final isDoctor = rol == 'doctor';
    final especialidad = _doctorData?.especialidad ?? (isDoctor ? 'Medicina General' : null);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: Text(
          isEs ? 'Mi Perfil' : 'My Profile',
          style: theme.titleLarge.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold), fontSize: 18.0),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: isEs ? 'Actualizar' : 'Refresh',
            icon: Icon(Icons.refresh_rounded, color: theme.primaryText),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.primary)))
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 840;
                  final padH = isDesktop ? 32.0 : 16.0;
                  final padV = isDesktop ? 24.0 : 18.0;

                  final headerCard = _buildProfileHeaderCard(
                    theme: theme,
                    nombre: nombre,
                    email: email,
                    telefono: telefono,
                    fotoUrl: fotoUrl,
                    isDoctor: isDoctor,
                    especialidad: especialidad,
                    isDesktop: isDesktop,
                  );

                  final editBtn = _buildActionBtn(
                    theme: theme,
                    isOutline: true,
                    label: isEs ? 'Editar Perfil y Datos Básicos' : 'Edit Profile & Details',
                    icon: Icons.edit_rounded,
                    color: theme.primary,
                    onTap: () async {
                      await context.pushNamed(CreateProfileWidget.routeName, queryParameters: {'rol': isDoctor ? 'Doctor' : (_usuario?.rol ?? 'Paciente'), 'esEdicion': 'true'});
                      _cargarDatos();
                    },
                  );

                  final logoutBtn = _buildActionBtn(
                    theme: theme,
                    isOutline: false,
                    label: isEs ? 'Cerrar Sesión' : 'Sign Out',
                    icon: Icons.logout_rounded,
                    color: Colors.redAccent,
                    onTap: _confirmarCerrarSesion,
                  );

                  final isAdmin = AdminTenantService.instance.esUsuarioAdmin(rol, email);

                  final settingsCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAdmin) ...[
                        _buildSectionHeader(theme, isEs ? 'Administración del Sistema' : 'System Administration'),
                        const SizedBox(height: 8.0),
                        _buildAdminCard(theme, isEs),
                        const SizedBox(height: 20.0),
                      ],
                      if (isDoctor) ...[
                        _buildSectionHeader(theme, isEs ? 'Gestión Profesional e IA' : 'Professional & AI Settings'),
                        const SizedBox(height: 8.0),
                        _buildProfessionalCard(theme, isEs),
                        const SizedBox(height: 20.0),
                      ] else ...[
                        _buildActionBtn(
                          theme: theme, isOutline: true,
                          label: isEs ? 'Grupo Familiar y Vincular Expediente' : 'Family Group & Link Records',
                          icon: Icons.family_restroom_rounded, color: theme.primary,
                          onTap: () => FamilyLinkingModal.show(context, idUsuario: _usuario?.id ?? currentUserUid, nombreUsuario: nombre, cedulaUsuario: _usuario?.cedula, telefonoUsuario: telefono, emailUsuario: email),
                        ),
                        const SizedBox(height: 20.0),
                      ],
                      _buildSectionHeader(theme, isEs ? 'Ajustes de la Aplicación' : 'App Preferences'),
                      const SizedBox(height: 8.0),
                      _buildPreferencesCard(theme, isEs),
                    ],
                  );

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isDesktop) ...[
                          Text(
                            isEs ? 'Panel de Perfil y Configuración' : 'Profile & Settings Dashboard',
                            style: theme.headlineSmall.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold), color: theme.primaryText),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            isEs ? 'Administra tu identidad, herramientas profesionales y ajustes de la cuenta.' : 'Manage your identity, professional tools and account settings.',
                            style: theme.bodyMedium.override(font: GoogleFonts.mooli(), color: theme.secondaryText),
                          ),
                          const SizedBox(height: 20.0),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(flex: 4, child: Column(children: [headerCard, const SizedBox(height: 16.0), editBtn, const SizedBox(height: 12.0), logoutBtn])),
                            const SizedBox(width: 24.0),
                            Expanded(flex: 6, child: settingsCol),
                          ]),
                        ] else ...[
                          headerCard,
                          const SizedBox(height: 16.0),
                          editBtn,
                          const SizedBox(height: 20.0),
                          settingsCol,
                          const SizedBox(height: 24.0),
                          logoutBtn,
                          const SizedBox(height: 28.0),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildProfileHeaderCard({
    required FlutterFlowTheme theme,
    required String nombre,
    required String email,
    required String telefono,
    required String fotoUrl,
    required bool isDoctor,
    String? especialidad,
    required bool isDesktop,
  }) {
    final avatar = Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(48.0),
          onTap: () async {
            await context.pushNamed(ProfileImageWidget.routeName);
            _cargarDatos();
          },
          child: Container(
            width: isDesktop ? 96.0 : 76.0,
            height: isDesktop ? 96.0 : 76.0,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.primary, width: 2.5), color: theme.primary.withValues(alpha: 0.1)),
            child: fotoUrl.isNotEmpty
                ? Image.network(fotoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, size: 44.0, color: theme.primary))
                : Icon(Icons.person_rounded, size: 44.0, color: theme.primary),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(5.0),
            decoration: BoxDecoration(color: theme.primary, shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13.0),
          ),
        ),
      ],
    );

    final details = [
      Text(nombre, style: (isDesktop ? theme.titleLarge : theme.titleMedium).override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold), fontSize: isDesktop ? 18.0 : 17.0), textAlign: isDesktop ? TextAlign.center : TextAlign.start, maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 4.0),
      if (isDoctor && especialidad != null) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.5),
          decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6.0)),
          child: Text(especialidad, style: GoogleFonts.mooli(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7))),
        ),
        const SizedBox(height: 6.0),
      ],
      Text(email, style: theme.bodySmall.override(font: GoogleFonts.mooli(), color: theme.secondaryText, fontSize: 13.0), textAlign: isDesktop ? TextAlign.center : TextAlign.start, maxLines: 1, overflow: TextOverflow.ellipsis),
      if (telefono.isNotEmpty) ...[
        const SizedBox(height: 4.0),
        Row(mainAxisAlignment: isDesktop ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
          Icon(Icons.phone_outlined, size: 12.0, color: theme.secondaryText),
          const SizedBox(width: 4.0),
          Text(telefono, style: theme.bodySmall.override(font: GoogleFonts.mooli(), color: theme.secondaryText, fontSize: 12.0)),
        ]),
      ],
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 22.0 : 18.0),
      decoration: BoxDecoration(color: theme.secondaryBackground, borderRadius: BorderRadius.circular(16.0), border: Border.all(color: theme.alternate, width: 1.0)),
      child: isDesktop
          ? Column(crossAxisAlignment: CrossAxisAlignment.center, children: [avatar, const SizedBox(height: 14.0), ...details])
          : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [avatar, const SizedBox(width: 16.0), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: details))]),
    );
  }

  Widget _buildActionBtn({required FlutterFlowTheme theme, required bool isOutline, required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 46.0,
      child: isOutline
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: color, size: 18.0),
              label: Text(label, style: GoogleFonts.mooli(fontSize: 14.0, fontWeight: FontWeight.bold, color: color)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: color, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), backgroundColor: color.withValues(alpha: 0.05)),
            )
          : TextButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: color, size: 19.0),
              label: Text(label, style: GoogleFonts.mooli(fontSize: 14.0, fontWeight: FontWeight.bold, color: color)),
              style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0), side: BorderSide(color: color.withValues(alpha: 0.3))), backgroundColor: color.withValues(alpha: 0.05)),
            ),
    );
  }

  Widget _buildAdminCard(FlutterFlowTheme theme, bool isEs) {
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFF249689).withValues(alpha: 0.3), width: 1.0),
      ),
      child: Column(
        children: [
          _buildTile(
            icon: Icons.dashboard_customize_rounded,
            iconColor: const Color(0xFF3B82F6),
            title: isEs ? 'Panel y Control de Cuentas' : 'Accounts Dashboard',
            subtitle: isEs ? 'Estadísticas, usuarios, suspender y roles' : 'Metrics, users, roles & control',
            onTap: () => context.goNamed(AdminAccountsDashboardWidget.routeName),
          ),
          const Divider(height: 1.0, indent: 56.0),
          _buildTile(
            icon: Icons.admin_panel_settings_rounded,
            iconColor: const Color(0xFF249689),
            title: isEs ? 'Aprobación de Consultorios' : 'Clinics & Tenants Approval',
            subtitle: _conteoPendientesAdmin > 0
                ? (isEs ? '$_conteoPendientesAdmin doctores por activar' : '$_conteoPendientesAdmin pending')
                : (isEs ? 'Todos los consultorios activados' : 'All clinics active'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_conteoPendientesAdmin > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12.0)),
                    child: Text('$_conteoPendientesAdmin', style: const TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(width: 6.0),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14.0, color: Colors.grey),
              ],
            ),
            onTap: () => context.goNamed(AdminDoctorTenantsWidget.routeName),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalCard(FlutterFlowTheme theme, bool isEs) {
    final uid = SupaFlow.client.auth.currentUser?.id ?? currentUserUid;
    final hasGemini = GeminiAiService.instance.hasKey;
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: theme.alternate, width: 1.0),
      ),
      child: Column(
        children: [
          _buildTile(
            icon: Icons.auto_awesome_rounded,
            iconColor: const Color(0xFF4F46E5),
            title: 'Google Gemini 3.8 Flash (IA)',
            subtitle: hasGemini ? (isEs ? 'Clave activa' : 'Key active') : (isEs ? 'Configura tu clave para IA' : 'Configure key for AI'),
            onTap: () async { await DoctorGeminiConfigDialog.show(context); setState(() {}); },
          ),
          const Divider(height: 1.0, indent: 56.0),
          _buildTile(
            icon: Icons.business_rounded,
            iconColor: const Color(0xFF0284C7),
            title: isEs ? 'Membrete y Logotipo Médico' : 'Medical Letterhead / Logo',
            subtitle: isEs ? 'Personaliza encabezados para recetas e informes' : 'Customize headers for reports',
            onTap: () { if (uid.isNotEmpty) DoctorLogoConfigDialog.show(context, idDoctor: uid); },
          ),
          const Divider(height: 1.0, indent: 56.0),
          _buildTile(
            icon: Icons.biotech_rounded,
            iconColor: const Color(0xFF10B981),
            title: isEs ? 'Estudios y Procedimientos en Consulta' : 'In-Office Studies & Procedures',
            subtitle: isEs ? 'Configura qué estudios realizas y el tiempo que suman' : 'Configure procedures & additional time',
            onTap: () { if (uid.isNotEmpty) DoctorStudiesConfigDialog.show(context, idDoctor: uid); },
          ),
          const Divider(height: 1.0, indent: 56.0),
          _buildTile(
            icon: (_doctorData?.visibleEnCatalogo ?? true) ? Icons.public_rounded : Icons.visibility_off_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: isEs ? 'Modo Doctor Solo y Enlace Privado' : 'Solo Doctor Mode & Private Link',
            subtitle: (_doctorData?.visibleEnCatalogo ?? true)
                ? (isEs ? 'Visible en catálogo público • Toca para configurar' : 'Visible in public catalog • Tap to configure')
                : (isEs ? 'Modo Solo activo (oculto del catálogo)' : 'Solo Mode active (hidden from catalog)'),
            onTap: () async {
              if (uid.isEmpty) return;
              await DoctorSoloModeDialog.show(context, idDoctor: uid, initialVisible: _doctorData?.visibleEnCatalogo ?? true, doctorUsuario: _usuario, doctorInfo: _doctorData);
              _cargarDatos();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoSolicitarSecretaria(bool isEs) async {
    final uid = SupaFlow.client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) return;
    final emailCtrl = TextEditingController();
    bool enviando = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: Text(
            isEs ? 'Vincularme como Secretaria' : 'Link as a Secretary',
            style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 17.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEs
                    ? 'Ingresa el correo del médico con quien trabajas. El médico recibirá tu solicitud y, al aceptarla, se habilitará tu panel de Recepción.'
                    : 'Enter the email of the doctor you work with. Once the doctor approves your request, your Reception dashboard will be enabled.',
                style: GoogleFonts.mooli(fontSize: 12.5, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 14.0),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: isEs ? 'Correo del médico' : 'Doctor email',
                  hintText: 'doctor@ejemplo.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: enviando ? null : () => Navigator.of(ctx).pop(),
              child: Text(isEs ? 'Cancelar' : 'Cancel', style: GoogleFonts.mooli()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
              onPressed: enviando
                  ? null
                  : () async {
                      final emailDoc = emailCtrl.text.trim();
                      if (emailDoc.isEmpty) return;
                      setDialogState(() => enviando = true);
                      try {
                        await SecretaryManagementService().vincularSecretariaConDoctorPorEmail(
                          idSecretaria: uid,
                          emailDoctor: emailDoc,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF0F766E),
                              content: Text(
                                isEs
                                    ? 'Solicitud enviada. Cuando el médico la acepte tendrás acceso al panel de secretaria.'
                                    : 'Request sent. Once the doctor accepts, you will have access to the secretary panel.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => enviando = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text(e.toString().replaceFirst('Exception: ', '')),
                            ),
                          );
                        }
                      }
                    },
              child: enviando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEs ? 'Enviar solicitud' : 'Send request', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    emailCtrl.dispose();
  }

  Widget _buildPreferencesCard(FlutterFlowTheme theme, bool isEs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rolActual = (_usuario?.rol ?? '').trim().toLowerCase();
    final puedeSolicitarSecretaria = rolActual != 'doctor' && rolActual != 'admin' && rolActual != 'administrador';
    return Container(
      decoration: BoxDecoration(color: theme.secondaryBackground, borderRadius: BorderRadius.circular(14.0), border: Border.all(color: theme.alternate, width: 1.0)),
      child: Column(children: [
        if (puedeSolicitarSecretaria) ...[
          _buildTile(
            icon: Icons.support_agent_rounded,
            iconColor: const Color(0xFF0F766E),
            title: isEs ? 'Trabajar como Secretaria de un Médico' : 'Work as a Doctor\'s Secretary',
            subtitle: isEs ? 'Envía solicitud a uno o más doctores para gestionar su agenda' : 'Send a request to one or more doctors to manage their schedule',
            onTap: () => _mostrarDialogoSolicitarSecretaria(isEs),
          ),
          const Divider(height: 1.0, indent: 56.0),
        ],
        _buildTile(icon: Icons.lock_reset_rounded, iconColor: const Color(0xFF0284C7), title: isEs ? 'Cambiar Contraseña' : 'Change Password', subtitle: isEs ? 'Actualizar contraseña de acceso' : 'Update account password', onTap: () => ChangePasswordDialog.show(context)),
        const Divider(height: 1.0, indent: 56.0),
        _buildTile(icon: Icons.tune_rounded, iconColor: const Color(0xFFEAB308), title: isEs ? 'Preferencias de Notificaciones' : 'Notification Preferences', subtitle: isEs ? 'Configurar qué alertas recibir' : 'Configure alert preferences', onTap: () => NotificationPreferencesDialog.show(context, isDoctor: rolActual == 'doctor')),
        const Divider(height: 1.0, indent: 56.0),
        _buildTile(
          icon: Icons.language_rounded, iconColor: const Color(0xFF10B981), title: isEs ? 'Idioma del Sistema' : 'System Language', subtitle: isEs ? 'Español' : 'English',
          trailing: TextButton(onPressed: () async { await I18nService.instance.setLanguage(isEs ? 'en' : 'es'); setState(() {}); }, child: Text(isEs ? 'Cambiar a EN' : 'Switch to ES', style: GoogleFonts.mooli(fontWeight: FontWeight.bold, color: theme.primary))),
        ),
        const Divider(height: 1.0, indent: 56.0),
        ListTile(
          leading: Container(padding: const EdgeInsets.all(8.0), decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.dark_mode_outlined, color: Color(0xFF6366F1), size: 20.0)),
          title: Text(isEs ? 'Modo Oscuro' : 'Dark Mode', style: GoogleFonts.mooli(fontWeight: FontWeight.w600, fontSize: 14.0)),
          subtitle: Text(isDark ? (isEs ? 'Activado' : 'Enabled') : (isEs ? 'Desactivado' : 'Disabled'), style: GoogleFonts.mooli(fontSize: 12.0, color: theme.secondaryText)),
          trailing: Switch.adaptive(value: isDark, activeTrackColor: theme.primary, onChanged: (val) { MyApp.of(context).setThemeMode(val ? ThemeMode.dark : ThemeMode.light); setState(() {}); }),
        ),
      ]),
    );
  }

  Widget _buildSectionHeader(FlutterFlowTheme theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(title, style: theme.labelMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold), color: theme.secondaryText, fontSize: 12.0)),
    );
  }

  Widget _buildTile({required IconData icon, required Color iconColor, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(8.0), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 20.0)),
      title: Text(title, style: GoogleFonts.mooli(fontWeight: FontWeight.w600, fontSize: 14.0)),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.mooli(fontSize: 12.0, color: Colors.grey.shade600)) : null,
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 15.0, color: Colors.grey),
    );
  }
}

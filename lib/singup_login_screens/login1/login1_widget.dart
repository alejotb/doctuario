import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/google_auth_service.dart';
import '/services/i18n_service.dart';
import '/legal/privacy_policy_widget.dart';
import '/legal/terms_of_service_widget.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login1_model.dart';
export 'login1_model.dart';

class Login1Widget extends StatefulWidget {
  const Login1Widget({super.key});

  static String routeName = 'Login1';
  static String routePath = '/login1';

  @override
  State<Login1Widget> createState() => _Login1WidgetState();
}

class _Login1WidgetState extends State<Login1Widget> {
  late Login1Model _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isGoogleLoading = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Login1Model());
    _model.emailAddressTextController ??= TextEditingController(); _model.emailAddressFocusNode ??= FocusNode();
    _model.passwordTextController ??= TextEditingController(); _model.passwordFocusNode ??= FocusNode();
    _authSub = SupaFlow.client.auth.onAuthStateChange.listen((data) {
      if ((data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.userUpdated) && mounted && SupaFlow.client.auth.currentUser != null) {
        _redireccionarUsuarioAutenticado();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb && Uri.base.queryParameters['error_code'] == 'otp_expired') {
        final isEs = I18nService.instance.isSpanish;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: FlutterFlowTheme.of(context).error,
            duration: const Duration(seconds: 8),
            content: Text(
              isEs
                  ? 'El enlace de confirmación ha caducado o ya fue utilizado. Si tu cuenta ya fue confirmada, por favor inicia sesión.'
                  : 'The confirmation link has expired or was already used. If already confirmed, please log in.',
            ),
          ),
        );
      }
      if (SupaFlow.client.auth.currentUser != null && loggedIn) {
        _redireccionarUsuarioAutenticado();
      } else {
        safeSetState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _model.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    GoRouter.of(context).prepareAuthEvent();

    final user = await authManager.signInWithEmail(
      context,
      _model.emailAddressTextController.text.trim(),
      _model.passwordTextController.text,
    );
    if (user == null) return;
    await _redireccionarUsuarioAutenticado();
  }

  Future<void> _redireccionarUsuarioAutenticado() async {
    final currentUser = SupaFlow.client.auth.currentUser;
    final meta = currentUser?.userMetadata ?? const <String, dynamic>{};
    String userRole = await DualDatabaseConfig.instance.resolveUserRole(currentUser);
    try {
      final existing = await UsuariosTable().querySingleRow(queryFn: (q) => q.eq('id', currentUserUid));
      if (existing.isEmpty) {
        await UsuariosTable().upsert({
          'id': currentUserUid,
          'email': _model.emailAddressTextController.text.trim(),
          'rol': userRole,
          'created_at': supaSerialize<DateTime>(getCurrentTimestamp),
        });
      } else {
        final r = (existing.first.rol ?? userRole).toLowerCase().trim();
        userRole = (r == 'admin' || r == 'administrador') ? 'administrador' : r;
      }
    } catch (e) {
      debugPrint('Error verificando sincronización en BD: $e');
    }

    if (!mounted) return;
    if (userRole == 'doctor') {
      await DualDatabaseConfig.instance.persistActiveViewMode('doctor');
      bool perfilCompleto = false;
      bool setupCompleto = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        final uRows = await UsuariosTable().querySingleRow(queryFn: (q) => q.eq('id', currentUserUid));
        final dRows = await DoctoresTable().querySingleRow(queryFn: (q) => q.eq('id', currentUserUid));
        final sedes = await DoctorSedesTable().queryRows(queryFn: (q) => q.eq('id_doctor', currentUserUid).limit(1));
        final tieneCiudad = (uRows.isNotEmpty && (uRows.first.ciudadOrigen?.trim().isNotEmpty ?? false)) || (meta['ciudad_origen']?.toString().trim().isNotEmpty ?? false);
        final tieneEspecialidad = (dRows.isNotEmpty && (dRows.first.especialidad?.trim().isNotEmpty ?? false)) || (meta['especialidad']?.toString().trim().isNotEmpty ?? false);
        setupCompleto = (prefs.getBool('prontudoc_setup_completo_$currentUserUid') ?? false) || meta['setup_completo'] == true || sedes.isNotEmpty;
        perfilCompleto = setupCompleto || (prefs.getBool('prontudoc_perfil_completo_$currentUserUid') ?? false) || meta['perfil_completo'] == true || (tieneCiudad && tieneEspecialidad);
      } catch (_) {}
      if (!mounted) return;
      final targetRoute = !perfilCompleto ? CreateProfileWidget.routeName : (setupCompleto ? DoctorAgendaPanelWidget.routeName : DoctorSetupWidget.routeName);
      final params = !perfilCompleto
          ? {'rol': serializeParam('Doctor', ParamType.String)}.withoutNulls
          : {'idDoctor': serializeParam(currentUserUid, ParamType.String)}.withoutNulls;
      context.goNamedAuth(targetRoute, mounted, queryParameters: params);
    } else if (userRole == 'administrador' || userRole == 'admin') {
      await DualDatabaseConfig.instance.persistActiveViewMode('administrador');
      if (!mounted) return;
      context.goNamedAuth(AdminAccountsDashboardWidget.routeName, mounted);
    } else if (userRole == 'secretaria') {
      await DualDatabaseConfig.instance.persistActiveViewMode('secretaria');
      if (!mounted) return;
      context.goNamedAuth(SecretaryDashboardWidget.routeName, mounted, queryParameters: {'idSecretaria': serializeParam(currentUserUid, ParamType.String)}.withoutNulls);
    } else {
      await DualDatabaseConfig.instance.persistActiveViewMode('paciente');
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.goNamedAuth(HomeWidget.routeName, mounted);
      }
    }
  }

  Future<void> _iniciarConGoogle() async {
    setState(() => _isGoogleLoading = true);
    final ok = await GoogleAuthService.instance.initiateGoogleOAuth(context: context);
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    if (ok && SupaFlow.client.auth.currentUser != null) {
      await _redireccionarUsuarioAutenticado();
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768.0;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Center(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24.0 : 18.0,
                  vertical: isDesktop ? 18.0 : 10.0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 480.0 : 420.0),
                  child: Container(
                    padding: isDesktop ? const EdgeInsets.all(30.0) : EdgeInsets.zero,
                    decoration: isDesktop
                        ? BoxDecoration(
                            color: FlutterFlowTheme.of(context).secondaryBackground,
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(color: FlutterFlowTheme.of(context).alternate, width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 18.0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          )
                        : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Encabezado superior con Marca Doctuario y Selector de Idioma
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48.0, height: 48.0,
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.0), border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2))),
                              child: ClipRRect(borderRadius: BorderRadius.circular(11.0), child: Image.asset('assets/images/doctuario_logo.png', width: 48.0, height: 48.0, fit: BoxFit.cover, filterQuality: FilterQuality.high)),
                            ),
                            const SizedBox(width: 12.0),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i18n.tr('app_name', defaultText: 'Doctuario'), style: FlutterFlowTheme.of(context).titleMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold), fontSize: 20.0)),
                                Text(i18n.isSpanish ? 'Salud y Gestión Médica' : 'Healthcare & Clinic App', style: FlutterFlowTheme.of(context).labelSmall.override(font: GoogleFonts.mooli(), color: FlutterFlowTheme.of(context).secondaryText, fontSize: 11.0)),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => I18nService.showLanguageDialog(context),
                              borderRadius: BorderRadius.circular(20.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                                decoration: BoxDecoration(color: FlutterFlowTheme.of(context).secondaryBackground, borderRadius: BorderRadius.circular(20.0), border: Border.all(color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3))),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(i18n.isSpanish ? '🇪🇸 ES' : '🇺🇸 EN', style: FlutterFlowTheme.of(context).bodySmall.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w600))),
                                  const SizedBox(width: 4.0),
                                  Icon(Icons.arrow_drop_down, size: 18.0, color: FlutterFlowTheme.of(context).secondaryText),
                                ]),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Tooltip(
                              message: i18n.isSpanish ? 'Cerrar e ir a Inicio' : 'Close and explore Home',
                              child: InkWell(
                                onTap: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.goNamed('Home'),
                                borderRadius: BorderRadius.circular(20.0),
                                child: Container(
                                  width: 32.0, height: 32.0,
                                  decoration: BoxDecoration(color: FlutterFlowTheme.of(context).secondaryBackground, shape: BoxShape.circle, border: Border.all(color: FlutterFlowTheme.of(context).alternate)),
                                  child: Icon(Icons.close_rounded, size: 18.0, color: FlutterFlowTheme.of(context).secondaryText),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 18.0),

                    // Título y Subtítulo de Login
                    Text(
                      i18n.tr('welcome_back', defaultText: 'Bienvenido de nuevo'),
                      style: FlutterFlowTheme.of(context).displaySmall.override(
                        font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                        fontSize: 24.0,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      i18n.tr('login_subtitle', defaultText: 'Ingresa tus credenciales para acceder a Doctuario'),
                      style: FlutterFlowTheme.of(context).labelMedium.override(
                        font: GoogleFonts.mooli(),
                        color: FlutterFlowTheme.of(context).secondaryText,
                        fontSize: 13.5,
                      ),
                    ),

                    const SizedBox(height: 18.0),

                    // Campo de Correo Electrónico
                    TextFormField(
                      controller: _model.emailAddressTextController,
                      focusNode: _model.emailAddressFocusNode,
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_model.passwordFocusNode),
                      decoration: InputDecoration(
                        labelText: i18n.tr('email_label', defaultText: 'Correo electrónico'),
                        labelStyle: FlutterFlowTheme.of(context).labelMedium.override(font: GoogleFonts.mooli()),
                        prefixIcon: Icon(Icons.email_outlined, color: FlutterFlowTheme.of(context).secondaryText, size: 20.0),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x6257636C)), borderRadius: BorderRadius.circular(12.0)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: FlutterFlowTheme.of(context).primary, width: 1.5), borderRadius: BorderRadius.circular(12.0)),
                        errorBorder: OutlineInputBorder(borderSide: BorderSide(color: FlutterFlowTheme.of(context).error), borderRadius: BorderRadius.circular(12.0)),
                        focusedErrorBorder: OutlineInputBorder(borderSide: BorderSide(color: FlutterFlowTheme.of(context).error, width: 1.5), borderRadius: BorderRadius.circular(12.0)),
                        filled: true,
                        fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli()),
                      validator: _model.emailAddressTextControllerValidator.asValidator(context),
                    ),

                    const SizedBox(height: 16.0),

                    // Campo de Contraseña
                    TextFormField(
                      controller: _model.passwordTextController,
                      focusNode: _model.passwordFocusNode,
                      autofillHints: const [AutofillHints.password],
                      obscureText: !_model.passwordVisibility,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _iniciarSesion(),
                      decoration: InputDecoration(
                        labelText: i18n.tr('password_label', defaultText: 'Contraseña'),
                        labelStyle: FlutterFlowTheme.of(context).labelMedium.override(font: GoogleFonts.mooli()),
                        prefixIcon: Icon(Icons.lock_outline, color: FlutterFlowTheme.of(context).secondaryText, size: 20.0),
                        suffixIcon: InkWell(
                          onTap: () => safeSetState(() => _model.passwordVisibility = !_model.passwordVisibility),
                          focusNode: FocusNode(skipTraversal: true),
                          child: Icon(
                            _model.passwordVisibility ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: FlutterFlowTheme.of(context).secondaryText,
                            size: 20.0,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x6257636C)), borderRadius: BorderRadius.circular(12.0)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: FlutterFlowTheme.of(context).primary, width: 1.5), borderRadius: BorderRadius.circular(12.0)),
                        errorBorder: OutlineInputBorder(borderSide: BorderSide(color: FlutterFlowTheme.of(context).error), borderRadius: BorderRadius.circular(12.0)),
                        focusedErrorBorder: OutlineInputBorder(borderSide: BorderSide(color: FlutterFlowTheme.of(context).error, width: 1.5), borderRadius: BorderRadius.circular(12.0)),
                        filled: true,
                        fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli()),
                      validator: _model.passwordTextControllerValidator.asValidator(context),
                    ),

                    const SizedBox(height: 8.0),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () => context.pushNamed(ForgotPasswordWidget.routeName),
                        child: Text(
                          i18n.tr('forgot_password', defaultText: '¿Olvidaste tu contraseña?'),
                          style: FlutterFlowTheme.of(context).labelMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w600), color: FlutterFlowTheme.of(context).primary, fontSize: 12.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18.0),
                    InkWell(
                      onTap: _iniciarSesion,
                      borderRadius: BorderRadius.circular(24.0),
                      child: Container(
                        height: 46.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [FlutterFlowTheme.of(context).secondary, FlutterFlowTheme.of(context).primary, FlutterFlowTheme.of(context).secondary], begin: const AlignmentDirectional(1.0, -0.5), end: const AlignmentDirectional(-1.0, 0.5)),
                          borderRadius: BorderRadius.circular(24.0),
                          boxShadow: [BoxShadow(color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3), blurRadius: 10.0, offset: const Offset(0, 4))],
                        ),
                        child: Center(
                          child: Text(
                            i18n.tr('login_button', defaultText: 'Iniciar Sesión'),
                            style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold), color: Colors.white, fontSize: 15.0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14.0),
                    Row(
                      children: [
                        Expanded(child: Divider(color: FlutterFlowTheme.of(context).alternate, thickness: 1.0)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0),
                          child: Text(
                            i18n.isSpanish ? 'o continúa con' : 'or continue with',
                            style: FlutterFlowTheme.of(context).labelSmall.override(font: GoogleFonts.mooli(), color: FlutterFlowTheme.of(context).secondaryText),
                          ),
                        ),
                        Expanded(child: Divider(color: FlutterFlowTheme.of(context).alternate, thickness: 1.0)),
                      ],
                    ),

                    const SizedBox(height: 12.0),

                    // Botón Iniciar Sesión con Google
                    GoogleAuthService.instance.buildGoogleButton(
                      context: context,
                      label: i18n.isSpanish ? 'Continuar con Google' : 'Continue with Google',
                      isLoading: _isGoogleLoading,
                      onPressed: _iniciarConGoogle,
                    ),

                    const SizedBox(height: 18.0),

                    // Separador "¿No tienes cuenta? Regístrate como:"
                    Center(
                      child: Text(
                        i18n.isSpanish ? '¿No tienes una cuenta? Regístrate como:' : "Don't have an account? Sign up as:",
                        style: FlutterFlowTheme.of(context).labelMedium.override(
                          font: GoogleFonts.mooli(fontWeight: FontWeight.w500),
                          color: FlutterFlowTheme.of(context).secondaryText,
                          fontSize: 12.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10.0),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.pushNamed(CreateAccountWidget.routeName),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11.0),
                          side: BorderSide(color: FlutterFlowTheme.of(context).primary, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        ),
                        child: Text(i18n.tr('create_account_button', defaultText: 'Crear Cuenta'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: FlutterFlowTheme.of(context).primary)),
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Wrap(
                      alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6.0,
                      children: [
                        InkWell(
                          onTap: () => context.pushNamed(CreateAccountWidget.routeName, queryParameters: {'rol': serializeParam('Doctor', ParamType.String)}.withoutNulls),
                          child: Text(i18n.isSpanish ? '¿Eres médico? Regístrate aquí' : 'Are you a doctor? Sign up here', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: FlutterFlowTheme.of(context).secondary, decoration: TextDecoration.underline)),
                        ),
                        Text('•', style: TextStyle(fontSize: 12.0, color: FlutterFlowTheme.of(context).secondaryText)),
                        InkWell(
                          onTap: () => context.pushNamed(CreateAccountWidget.routeName, queryParameters: {'rol': serializeParam('Secretaria', ParamType.String)}.withoutNulls),
                          child: Text(i18n.isSpanish ? '¿Eres secretaria? Regístrate aquí' : 'Are you a secretary? Sign up here', style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Color(0xFF0284C7), decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(i18n.isSpanish ? 'Al ingresar, aceptas los ' : 'By signing in, you agree to the ', style: TextStyle(fontSize: 11.5, color: FlutterFlowTheme.of(context).secondaryText)),
                          InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceWidget())), child: Text(i18n.isSpanish ? 'Términos' : 'Terms', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: FlutterFlowTheme.of(context).primary, decoration: TextDecoration.underline))),
                          Text(i18n.isSpanish ? ' y la ' : ' and ', style: TextStyle(fontSize: 11.5, color: FlutterFlowTheme.of(context).secondaryText)),
                          InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyWidget())), child: Text(i18n.isSpanish ? 'Política de Privacidad' : 'Privacy Policy', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: FlutterFlowTheme.of(context).primary, decoration: TextDecoration.underline))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
}
}

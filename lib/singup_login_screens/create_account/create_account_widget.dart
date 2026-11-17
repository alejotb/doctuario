import 'dart:async';
import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/doctor_patient_sync_service.dart';
import '/services/google_auth_service.dart';
import '/services/i18n_service.dart';
import '/legal/privacy_policy_widget.dart';
import '/legal/terms_of_service_widget.dart';
import '../components/auth_benefits_carousel.dart';
import '/index.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simple_gradient_text/simple_gradient_text.dart';
import 'create_account_model.dart';
export 'create_account_model.dart';

class CreateAccountWidget extends StatefulWidget {
  const CreateAccountWidget({super.key, this.rol});
  final String? rol;

  static String routeName = 'CreateAccount';
  static String routePath = '/createAccount';

  @override
  State<CreateAccountWidget> createState() => _CreateAccountWidgetState();
}

class _CreateAccountWidgetState extends State<CreateAccountWidget> {
  late CreateAccountModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isGoogleLoading = false;
  bool _isLoading = false;
  late String _selectedRol;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CreateAccountModel());
    _model.emailTextController ??= TextEditingController(); _model.emailFocusNode ??= FocusNode();
    _model.phoneNumberTextController ??= TextEditingController(); _model.phoneNumberFocusNode ??= FocusNode();
    _model.passwordTextController ??= TextEditingController(); _model.passwordFocusNode ??= FocusNode();
    _model.confirmPasswordTextController ??= TextEditingController(); _model.confirmPasswordFocusNode ??= FocusNode();
    final initial = (widget.rol ?? '').toLowerCase().trim();
    _selectedRol = initial == 'doctor' ? 'Doctor' : (initial == 'secretaria' ? 'Secretaria' : 'Paciente');
    _authSub = SupaFlow.client.auth.onAuthStateChange.listen((data) {
      if (_isLoading) return;
      if ((data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.userUpdated) && mounted && SupaFlow.client.auth.currentUser != null) {
        if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else { context.goNamed('Home'); }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SupaFlow.client.auth.currentUser != null && loggedIn) {
        context.goNamed('Home');
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

  void _mostrarErrorCuentaExistente(String email) {
    if (!mounted) return;
    final i18n = I18nService.instance;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: FlutterFlowTheme.of(context).error,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22.0),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                i18n.isSpanish
                    ? 'Esta cuenta ($email) ya existe en la base de datos. Por favor inicia sesión.'
                    : 'This account ($email) already exists in database. Please log in.',
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: i18n.isSpanish ? 'INICIAR SESIÓN' : 'LOG IN',
          textColor: Colors.white,
          onPressed: () => context.pushNamed(Login1Widget.routeName),
        ),
      ),
    );
  }

  Future<void> _crearCuenta() async {
    final i18n = I18nService.instance;
    final fullName = _model.phoneNumberTextController.text.trim();
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: FlutterFlowTheme.of(context).error, content: Text(i18n.isSpanish ? 'Por favor ingresa tu nombre completo.' : 'Please enter your full name.')));
      return;
    }

    final password = _model.passwordTextController.text;
    final confirmPassword = _model.confirmPasswordTextController.text;
    final hasValidFormat = password.length >= 8 && password.contains(RegExp(r'[A-Z]')) && password.contains(RegExp(r'[a-z]')) && password.contains(RegExp(r'[0-9]')) && password.contains(RegExp(r'[!@#\$&*~%^()_\-+=\[\]{}|;:,.<>?/\\`"]'));

    if (!hasValidFormat) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: FlutterFlowTheme.of(context).error, content: Text(i18n.isSpanish ? 'La contraseña debe tener al menos 8 caracteres, mayúscula, minúscula, número y símbolo.' : 'Password must have at least 8 characters, upper, lower, number, and special character.'), duration: const Duration(seconds: 4)));
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: FlutterFlowTheme.of(context).error, content: Text(i18n.isSpanish ? '¡Las contraseñas no coinciden!' : "Passwords don't match!")));
      return;
    }

    final emailText = _model.emailTextController.text.trim();
    if (emailText.isEmpty || !emailText.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: FlutterFlowTheme.of(context).error, content: Text(i18n.isSpanish ? 'Por favor ingresa un correo válido.' : 'Please enter a valid email.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Verificación previa en la base de datos (tabla usuarios)
      try {
        final existing = await SupaFlow.client.from('usuarios').select('id, email, rol').ilike('email', emailText).maybeSingle();
        if (existing != null) {
          _mostrarErrorCuentaExistente(emailText);
          return;
        }
      } catch (_) {}

      final isDoctorRole = _selectedRol == 'Doctor';
      final isSecretaryRole = _selectedRol == 'Secretaria';
      final rolNormalizado = isDoctorRole ? 'doctor' : (isSecretaryRole ? 'secretaria' : 'paciente');
      final redirectUrl = (kIsWeb && Uri.base.origin.isNotEmpty && !Uri.base.origin.contains('localhost')) ? '${Uri.base.origin}/' : 'https://doctuario.com/';

      if (!mounted) return;
      final user = await authManager.createAccountWithEmail(
        context,
        emailText,
        password,
        data: {'rol': rolNormalizado, 'nombre': fullName, 'full_name': fullName},
        emailRedirectTo: redirectUrl,
      );
      if (user == null) return;

      // 2. Supabase devuelve identities vacías cuando el usuario ya existe en Auth
      final identities = SupaFlow.client.auth.currentUser?.identities;
      if (identities != null && identities.isEmpty) {
        try {
          await SupaFlow.client.auth.signOut();
        } catch (_) {}
        _mostrarErrorCuentaExistente(emailText);
        return;
      }

      final rawUid = user.uid;
      final String userId = (rawUid != null && rawUid.isNotEmpty)
          ? rawUid
          : (currentUserUid.isNotEmpty ? currentUserUid : (SupaFlow.client.auth.currentUser?.id ?? ''));

      if (userId.isNotEmpty) {
        try {
          await SupaFlow.client.from('usuarios').update({'rol': rolNormalizado, 'nombre': fullName}).eq('id', userId);
        } catch (_) {
          try {
            await UsuariosTable().upsert({'id': userId, 'email': emailText, 'nombre': fullName, 'rol': rolNormalizado, 'created_at': supaSerialize<DateTime>(getCurrentTimestamp)});
          } catch (_) {}
        }
        if (isDoctorRole) {
          await DualDatabaseConfig.instance.persistActiveViewMode('doctor');
          try {
            await SupaFlow.client.from('doctores').upsert({'id': userId, 'esta_aprobado': false, 'estado_verificacion': 'pendiente', 'created_at': supaSerialize<DateTime>(getCurrentTimestamp)});
          } catch (_) {}
          try {
            await DoctorPatientSyncService().asegurarDoctorEnBaseClinica(idDoctor: userId, nombre: fullName, email: emailText);
          } catch (_) {}
        } else {
          await DualDatabaseConfig.instance.persistActiveViewMode('paciente');
          if (!isSecretaryRole) {
            try {
              await PacientesTable().upsert({'id': userId, 'created_at': supaSerialize<DateTime>(getCurrentTimestamp)});
            } catch (_) {}
          }
        }
      }

      if (!mounted) return;
      final currentAuthUser = SupaFlow.client.auth.currentUser;
      final isConfirmed = currentAuthUser?.emailConfirmedAt != null;

      if (!isConfirmed) {
        context.goNamedAuth(EmailConfirmationPendingWidget.routeName, mounted, queryParameters: {
          'email': serializeParam(emailText, ParamType.String),
          'rol': serializeParam(rolNormalizado, ParamType.String),
          'idDoctor': serializeParam(userId, ParamType.String),
        }.withoutNulls);
        return;
      }

      if (isDoctorRole) {
        context.goNamedAuth(CreateProfileWidget.routeName, mounted, queryParameters: {'rol': serializeParam('Doctor', ParamType.String)}.withoutNulls);
      } else {
        context.pushNamedAuth(CreateProfileWidget.routeName, mounted, queryParameters: {'rol': serializeParam(rolNormalizado, ParamType.String)}.withoutNulls);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildReqItem(String label, bool satisfied) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
      decoration: BoxDecoration(color: satisfied ? const Color(0x1A249689) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6.0), border: Border.all(color: satisfied ? const Color(0xFF249689) : const Color(0x22000000), width: 0.8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(satisfied ? Icons.check_circle : Icons.circle_outlined, size: 12.0, color: satisfied ? const Color(0xFF249689) : Colors.grey),
        const SizedBox(width: 4.0),
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: satisfied ? FontWeight.bold : FontWeight.normal, color: satisfied ? const Color(0xFF249689) : Colors.grey)),
      ]),
    );
  }

  Future<void> _crearCuentaConGoogle() async {
    setState(() => _isGoogleLoading = true);
    final isDoc = _selectedRol == 'Doctor';
    final isSec = _selectedRol == 'Secretaria';
    final roleToSend = isDoc ? 'doctor' : (isSec ? 'secretaria' : 'paciente');
    await DualDatabaseConfig.instance.persistActiveViewMode(isDoc ? 'doctor' : 'paciente');
    if (!mounted) return;
    final ok = await GoogleAuthService.instance.initiateGoogleOAuth(context: context, defaultRole: roleToSend);
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    if (ok && SupaFlow.client.auth.currentUser != null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.goNamed('Home');
      }
    }
  }

  InputDecoration _fieldDeco(BuildContext context, {required String label, required IconData icon, Widget? suffix, Color? customBorderColor, String? helperText, Color? helperColor}) {
    final theme = FlutterFlowTheme.of(context);
    final borderSide = customBorderColor != null ? BorderSide(color: customBorderColor, width: 1.5) : const BorderSide(color: Color(0x6257636C));
    final focusedSide = customBorderColor != null ? BorderSide(color: customBorderColor, width: 2.0) : BorderSide(color: theme.primary, width: 1.5);
    return InputDecoration(
      labelText: label, labelStyle: theme.labelMedium.override(font: GoogleFonts.mooli(), color: customBorderColor),
      prefixIcon: Icon(icon, color: customBorderColor ?? theme.secondaryText, size: 20.0), suffixIcon: suffix,
      helperText: helperText, helperStyle: helperColor != null ? TextStyle(fontSize: 11.0, color: helperColor, fontWeight: FontWeight.w600) : null,
      enabledBorder: OutlineInputBorder(borderSide: borderSide, borderRadius: BorderRadius.circular(12.0)),
      focusedBorder: OutlineInputBorder(borderSide: focusedSide, borderRadius: BorderRadius.circular(12.0)),
      filled: true, fillColor: theme.primaryBackground, contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;
    final isDoc = _selectedRol == 'Doctor';
    final isSec = _selectedRol == 'Secretaria';
    final isDesktop = MediaQuery.of(context).size.width >= 900.0;
    final themeColor = isDoc ? FlutterFlowTheme.of(context).secondary : (isSec ? const Color(0xFF0284C7) : FlutterFlowTheme.of(context).primary);
    final roleIcon = isDoc ? Icons.medical_services_outlined : (isSec ? Icons.support_agent_rounded : Icons.person_outline);
    final titleText = isDoc ? (i18n.isSpanish ? 'Registro de Médico / Especialista' : 'Doctor Registration') : (isSec ? (i18n.isSpanish ? 'Registro de Asistente' : 'Assistant Registration') : (i18n.isSpanish ? 'Crear Cuenta en Doctuario' : 'Create Account'));
    final subtitleText = isDoc ? (i18n.isSpanish ? 'Crea tu cuenta profesional para gestionar tu consultorio y agenda.' : 'Create clinical account.') : (isSec ? (i18n.isSpanish ? 'Crea tu cuenta para vincularte con los consultorios.' : 'Create office account.') : (i18n.isSpanish ? 'Regístrate para agendar consultas y ver expedientes clínicos.' : 'Sign up for appointments.'));
    final passText = _model.passwordTextController.text;
    final confirmText = _model.confirmPasswordTextController.text;
    final hasConfirmInput = confirmText.isNotEmpty;
    final passwordsMatch = hasConfirmInput && passText == confirmText;
    final confirmBorderColor = !hasConfirmInput ? null : (passwordsMatch ? const Color(0xFF249689) : FlutterFlowTheme.of(context).error);
    final confirmHelper = !hasConfirmInput ? null : (passwordsMatch ? (i18n.isSpanish ? '✓ Las contraseñas coinciden' : '✓ Passwords match') : (i18n.isSpanish ? '✗ Las contraseñas no coinciden' : '✗ Passwords do not match'));

    Widget formCard = Container(
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(color: FlutterFlowTheme.of(context).secondaryBackground, borderRadius: BorderRadius.circular(20.0), border: Border.all(color: FlutterFlowTheme.of(context).alternate, width: 1.0), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16.0, offset: const Offset(0, 4))]),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.goNamed(Login1Widget.routeName), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20.0)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                InkWell(
                  onTap: () => I18nService.showLanguageDialog(context),
                  borderRadius: BorderRadius.circular(20.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                    decoration: BoxDecoration(color: FlutterFlowTheme.of(context).primaryBackground, borderRadius: BorderRadius.circular(20.0), border: Border.all(color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(i18n.isSpanish ? '🇪🇸 ES' : '🇺🇸 EN', style: FlutterFlowTheme.of(context).bodySmall.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w600))),
                      const SizedBox(width: 4.0), Icon(Icons.arrow_drop_down, size: 18.0, color: FlutterFlowTheme.of(context).secondaryText),
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
                      decoration: BoxDecoration(color: FlutterFlowTheme.of(context).primaryBackground, shape: BoxShape.circle, border: Border.all(color: FlutterFlowTheme.of(context).alternate)),
                      child: Icon(Icons.close_rounded, size: 18.0, color: FlutterFlowTheme.of(context).secondaryText),
                    ),
                  ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 14.0),
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8.0), decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10.0)), child: Icon(roleIcon, color: themeColor, size: 22.0)),
              const SizedBox(width: 10.0),
              Expanded(child: Text(titleText, style: FlutterFlowTheme.of(context).titleLarge.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold), fontSize: 18.0))),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(subtitleText, style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(), color: FlutterFlowTheme.of(context).secondaryText, fontSize: 13.0)),
          if (isDoc) ...[
            const SizedBox(height: 10.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
              decoration: BoxDecoration(color: FlutterFlowTheme.of(context).secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10.0), border: Border.all(color: FlutterFlowTheme.of(context).secondary.withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(Icons.verified_user_outlined, size: 16.0, color: FlutterFlowTheme.of(context).secondary),
                const SizedBox(width: 8.0),
                Expanded(child: Text(i18n.isSpanish ? 'Registro reservado para profesionales. Se requerirá verificación médica.' : 'Reserved for medical professionals. Verification required.', style: const TextStyle(fontSize: 11.0))),
              ]),
            ),
            const SizedBox(height: 6.0),
            InkWell(
              onTap: () => setState(() => _selectedRol = 'Paciente'),
              child: Text(i18n.isSpanish ? '¿Eres paciente? Regístrate aquí' : 'Are you a patient? Sign up here', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: FlutterFlowTheme.of(context).primary, decoration: TextDecoration.underline)),
            ),
          ] else if (isSec) ...[
            const SizedBox(height: 10.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
              decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10.0), border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3))),
              child: Row(children: [
                const Icon(Icons.support_agent_rounded, size: 16.0, color: Color(0xFF0284C7)),
                const SizedBox(width: 8.0),
                Expanded(child: Text(i18n.isSpanish ? 'Podrás vincularte a los consultorios de tus doctores una vez registrado.' : 'You can link to doctor offices once registered.', style: const TextStyle(fontSize: 11.0))),
              ]),
            ),
            const SizedBox(height: 6.0),
            InkWell(
              onTap: () => setState(() => _selectedRol = 'Paciente'),
              child: Text(i18n.isSpanish ? '¿Eres paciente? Regístrate aquí' : 'Are you a patient? Sign up here', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: FlutterFlowTheme.of(context).primary, decoration: TextDecoration.underline)),
            ),
          ],
          const SizedBox(height: 16.0),
          TextFormField(
            controller: _model.phoneNumberTextController, focusNode: _model.phoneNumberFocusNode, keyboardType: TextInputType.name, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_model.emailFocusNode), decoration: _fieldDeco(context, label: i18n.isSpanish ? 'Nombre Completo' : 'Full Name', icon: Icons.person_outline),
            style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli()), validator: _model.phoneNumberTextControllerValidator.asValidator(context),
          ),
          const SizedBox(height: 14.0),
          TextFormField(
            controller: _model.emailTextController, focusNode: _model.emailFocusNode, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_model.passwordFocusNode), decoration: _fieldDeco(context, label: i18n.tr('email_label', defaultText: 'Correo electrónico'), icon: Icons.email_outlined),
            style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli()), validator: _model.emailTextControllerValidator.asValidator(context),
          ),
          const SizedBox(height: 14.0),
          TextFormField(
            controller: _model.passwordTextController, focusNode: _model.passwordFocusNode, obscureText: !_model.passwordVisibility, textInputAction: TextInputAction.next,
            onChanged: (_) => safeSetState(() {}), onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_model.confirmPasswordFocusNode),
            decoration: _fieldDeco(context, label: i18n.tr('password_label', defaultText: 'Contraseña'), icon: Icons.lock_outline, suffix: InkWell(onTap: () => safeSetState(() => _model.passwordVisibility = !_model.passwordVisibility), child: Icon(_model.passwordVisibility ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: FlutterFlowTheme.of(context).secondaryText, size: 20.0))),
            style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli()), validator: _model.passwordTextControllerValidator.asValidator(context),
          ),
          const SizedBox(height: 8.0),
          Wrap(
            spacing: 8.0, runSpacing: 4.0,
            children: [
              _buildReqItem('8+ cars', _model.passwordTextController.text.length >= 8),
              _buildReqItem('Mayús', _model.passwordTextController.text.contains(RegExp(r'[A-Z]'))),
              _buildReqItem('Minús', _model.passwordTextController.text.contains(RegExp(r'[a-z]'))),
              _buildReqItem('Número', _model.passwordTextController.text.contains(RegExp(r'[0-9]'))),
              _buildReqItem('Símbolo', _model.passwordTextController.text.contains(RegExp(r'[!@#\$&*~%^()_\-+=\[\]{}|;:,.<>?/\\`"]'))),
            ],
          ),
          const SizedBox(height: 12.0),
          TextFormField(
            controller: _model.confirmPasswordTextController, focusNode: _model.confirmPasswordFocusNode,
            obscureText: !_model.confirmPasswordVisibility, textInputAction: TextInputAction.done,
            onChanged: (_) => safeSetState(() {}), onFieldSubmitted: (_) async => _crearCuenta(),
            decoration: _fieldDeco(
              context, label: i18n.tr('confirm_password_label', defaultText: 'Confirmar Contraseña'), icon: Icons.lock_outline,
              customBorderColor: confirmBorderColor, helperText: confirmHelper, helperColor: confirmBorderColor,
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasConfirmInput) Icon(passwordsMatch ? Icons.check_circle_rounded : Icons.cancel_rounded, color: confirmBorderColor, size: 18.0),
                  const SizedBox(width: 4.0),
                  InkWell(onTap: () => safeSetState(() => _model.confirmPasswordVisibility = !_model.confirmPasswordVisibility), child: Icon(_model.confirmPasswordVisibility ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: FlutterFlowTheme.of(context).secondaryText, size: 20.0)),
                  const SizedBox(width: 8.0),
                ],
              ),
            ),
            style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli()), validator: _model.confirmPasswordTextControllerValidator.asValidator(context),
          ),
          SizedBox(height: hasConfirmInput ? 14.0 : 22.0),
          InkWell(
            onTap: _isLoading ? null : _crearCuenta,
            borderRadius: BorderRadius.circular(24.0),
            child: Container(
              height: 48.0,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isDoc ? [FlutterFlowTheme.of(context).secondary, const Color(0xFF0284C7), FlutterFlowTheme.of(context).secondary] : (isSec ? [const Color(0xFF0284C7), const Color(0xFF0D9488), const Color(0xFF0284C7)] : [FlutterFlowTheme.of(context).secondary, FlutterFlowTheme.of(context).primary, FlutterFlowTheme.of(context).secondary]), begin: const AlignmentDirectional(1.0, -0.5), end: const AlignmentDirectional(-1.0, 0.5)),
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: [BoxShadow(color: themeColor.withValues(alpha: 0.3), blurRadius: 10.0, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(width: 22.0, height: 22.0, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                    : Text(i18n.tr('create_account_title', defaultText: 'Crear Cuenta'), style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold), color: Colors.white, fontSize: 15.0)),
              ),
            ),
          ),
          const SizedBox(height: 18.0),
          Row(
            children: [
              Expanded(child: Divider(color: FlutterFlowTheme.of(context).alternate, thickness: 1.0)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 14.0), child: Text(i18n.isSpanish ? 'o regístrate con' : 'or sign up with', style: FlutterFlowTheme.of(context).labelSmall.override(font: GoogleFonts.mooli(), color: FlutterFlowTheme.of(context).secondaryText))),
              Expanded(child: Divider(color: FlutterFlowTheme.of(context).alternate, thickness: 1.0)),
            ],
          ),
          const SizedBox(height: 16.0),
          GoogleAuthService.instance.buildGoogleButton(context: context, label: i18n.isSpanish ? 'Registrarse con Google' : 'Sign up with Google', isLoading: _isGoogleLoading, onPressed: _crearCuentaConGoogle),
          const SizedBox(height: 20.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(i18n.tr('already_have_account', defaultText: '¿Ya tienes cuenta? '), style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(), color: FlutterFlowTheme.of(context).secondaryText, fontSize: 13.0)),
              InkWell(
                onTap: () => context.pushNamed(Login1Widget.routeName),
                child: GradientText(i18n.tr('login_button', defaultText: 'Iniciar Sesión'), style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold), fontSize: 13.0, decoration: TextDecoration.underline), colors: [FlutterFlowTheme.of(context).primary, FlutterFlowTheme.of(context).secondary], gradientDirection: GradientDirection.ltr, gradientType: GradientType.linear),
              ),
            ],
          ),
          const SizedBox(height: 18.0),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(i18n.isSpanish ? 'Al registrarte, aceptas los ' : 'By signing up, you agree to the ', style: TextStyle(fontSize: 11.5, color: FlutterFlowTheme.of(context).secondaryText)),
                InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceWidget())), child: Text(i18n.isSpanish ? 'Términos' : 'Terms', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: FlutterFlowTheme.of(context).primary, decoration: TextDecoration.underline))),
                Text(i18n.isSpanish ? ' y la ' : ' and ', style: TextStyle(fontSize: 11.5, color: FlutterFlowTheme.of(context).secondaryText)),
                InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyWidget())), child: Text(i18n.isSpanish ? 'Política de Privacidad' : 'Privacy Policy', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: FlutterFlowTheme.of(context).primary, decoration: TextDecoration.underline))),
              ],
            ),
          ),
        ],
      ),
    );

    Widget imagePlaceholderSide = AuthBenefitsCarousel(role: _selectedRol);

    return GestureDetector(
      onTap: () { FocusScope.of(context).unfocus(); FocusManager.instance.primaryFocus?.unfocus(); },
      child: Scaffold(
        key: scaffoldKey, backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: isDesktop
                  ? ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1050.0), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(flex: 1, child: formCard), const SizedBox(width: 28.0), Expanded(flex: 1, child: imagePlaceholderSide)]))
                  : ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460.0), child: formCard),
            ),
          ),
        ),
      ),
    );
  }
}

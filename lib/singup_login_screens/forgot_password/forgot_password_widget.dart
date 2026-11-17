import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/i18n_service.dart';
import 'forgot_password_model.dart';
export 'forgot_password_model.dart';

class ForgotPasswordWidget extends StatefulWidget {
  const ForgotPasswordWidget({super.key});

  static String routeName = 'ForgotPassword';
  static String routePath = '/forgotPassword';

  @override
  State<ForgotPasswordWidget> createState() => _ForgotPasswordWidgetState();
}

class _ForgotPasswordWidgetState extends State<ForgotPasswordWidget> {
  late ForgotPasswordModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ForgotPasswordModel());

    _model.emailAddressTextController ??= TextEditingController();
    _model.emailAddressFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Botón volver
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => context.safePop(),
                        icon: const Icon(Icons.arrow_back_ios, size: 20.0),
                      ),
                    ),

                    const SizedBox(height: 8.0),

                    // Logo ProntuDoc
                    Center(
                      child: Container(
                        width: 72.0,
                        height: 72.0,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16.0),
                            child: Image.asset(
                              'assets/images/doctuario_logo.png',
                              width: 52.0,
                              height: 52.0,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              isAntiAlias: true,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.local_hospital_rounded,
                                size: 36.0,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Center(
                      child: Text(
                        'Doctuario',
                        style: GoogleFonts.mooli(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20.0),

                    // Título
                    Text(
                      i18n.tr('forgot_password', defaultText: '¿Olvidaste tu contraseña?'),
                      style: FlutterFlowTheme.of(context).titleLarge.override(
                            font: GoogleFonts.mooli(
                              fontWeight: FontWeight.bold,
                            ),
                            fontSize: 22.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      i18n.isSpanish
                          ? 'Te enviaremos un correo seguro desde Doctuario con un enlace para restablecer tu contraseña. Por favor, ingresa el correo asociado a tu cuenta.'
                          : 'We will send you a secure email from Doctuario with a link to reset your password. Please enter the email associated with your account.',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.mooli(),
                            color: FlutterFlowTheme.of(context).secondaryText,
                            fontSize: 14.0,
                            lineHeight: 1.5,
                          ),
                    ),

                    const SizedBox(height: 28.0),

                    // Campo de Correo
                    TextFormField(
                      controller: _model.emailAddressTextController,
                      focusNode: _model.emailAddressFocusNode,
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: i18n.tr('email_label', defaultText: 'Correo electrónico'),
                        labelStyle: FlutterFlowTheme.of(context).labelMedium.override(font: GoogleFonts.mooli()),
                        prefixIcon: Icon(Icons.email_outlined, color: FlutterFlowTheme.of(context).secondaryText, size: 20.0),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0x6257636C), width: 1.0),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: FlutterFlowTheme.of(context).primary, width: 1.5),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(font: GoogleFonts.mooli()),
                      validator: _model.emailAddressTextControllerValidator.asValidator(context),
                    ),

                    const SizedBox(height: 24.0),

                    // Botón Enviar Enlace
                    InkWell(
                      splashColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () async {
                        if (_model.emailAddressTextController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                i18n.isSpanish
                                    ? 'Por favor, ingresa tu correo electrónico'
                                    : 'Please enter your email address',
                              ),
                            ),
                          );
                          return;
                        }

                        final redirectUrl = kIsWeb
                            ? '${Uri.base.origin}/'
                            : 'doctuario://reset-password';

                        await authManager.resetPassword(
                          email: _model.emailAddressTextController.text.trim(),
                          context: context,
                          redirectTo: redirectUrl,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.green,
                              content: Text(
                                i18n.isSpanish
                                    ? 'Enlace de restablecimiento enviado a tu correo.'
                                    : 'Password reset link sent to your email.',
                              ),
                            ),
                          );
                          context.safePop();
                        }
                      },
                      child: Container(
                        height: 48.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              FlutterFlowTheme.of(context).secondary,
                              FlutterFlowTheme.of(context).primary,
                              FlutterFlowTheme.of(context).secondary,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                            begin: const AlignmentDirectional(1.0, -0.5),
                            end: const AlignmentDirectional(-1.0, 0.5),
                          ),
                          borderRadius: BorderRadius.circular(24.0),
                          boxShadow: [
                            BoxShadow(
                              color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
                              blurRadius: 10.0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            i18n.isSpanish ? 'Enviar Enlace de Recuperación' : 'Send Reset Link',
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.mooli(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  color: Colors.white,
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

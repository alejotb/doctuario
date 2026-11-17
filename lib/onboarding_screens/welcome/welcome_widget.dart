import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/i18n_service.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simple_gradient_text/simple_gradient_text.dart';
import 'welcome_model.dart';
export 'welcome_model.dart';

class WelcomeWidget extends StatefulWidget {
  const WelcomeWidget({super.key});

  static String routeName = 'welcome';
  static String routePath = '/welcome';

  @override
  State<WelcomeWidget> createState() => _WelcomeWidgetState();
}

class _WelcomeWidgetState extends State<WelcomeWidget> {
  late WelcomeModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WelcomeModel());
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
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: SafeArea(
          top: true,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Barra superior con selector de idioma
                    Align(
                      alignment: Alignment.topRight,
                      child: InkWell(
                        onTap: () => I18nService.showLanguageDialog(context),
                        borderRadius: BorderRadius.circular(20.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                i18n.isSpanish ? '🇪🇸 ES' : '🇺🇸 EN',
                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.mooli(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(width: 4.0),
                              Icon(
                                Icons.arrow_drop_down,
                                size: 18.0,
                                color: FlutterFlowTheme.of(context).secondaryText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // Imagen Principal de Bienvenida
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: Image.asset(
                        'assets/images/379869661_b42e55ab-56f7-4ede-abcd-96cd2f6dce84_(1).jpg',
                        width: double.infinity,
                        height: 260.0,
                        fit: BoxFit.cover,
                      ),
                    ),

                    const SizedBox(height: 32.0),

                    // Título de Bienvenida
                    Text(
                      i18n.tr('welcome_title', defaultText: 'Bienvenido a MediConnect'),
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).headlineSmall.override(
                            font: GoogleFonts.mooli(
                              fontWeight: FontWeight.bold,
                            ),
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontSize: 24.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                    const SizedBox(height: 12.0),

                    // Descripción
                    Text(
                      i18n.tr(
                        'welcome_desc',
                        defaultText:
                            'Tu sistema integral para gestión de consultas médicas presenciales, historial clínico seguro y seguimiento de pacientes.',
                      ),
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.mooli(),
                            color: FlutterFlowTheme.of(context).secondaryText,
                            fontSize: 14.0,
                            lineHeight: 1.5,
                          ),
                    ),

                    const SizedBox(height: 32.0),

                    // Botón "Comenzar"
                    InkWell(
                      splashColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () async {
                        context.pushNamed(Onboarding1Widget.routeName);
                      },
                      child: Container(
                        width: double.infinity,
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
                            i18n.tr('get_started', defaultText: 'Comenzar'),
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

                    const SizedBox(height: 20.0),

                    // ¿Ya tienes cuenta? Iniciar Sesión
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          i18n.tr('already_have_account', defaultText: '¿Ya tienes cuenta? '),
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                font: GoogleFonts.mooli(),
                                color: FlutterFlowTheme.of(context).primaryText,
                                fontSize: 14.0,
                              ),
                        ),
                        InkWell(
                          onTap: () async {
                            context.pushNamed(Login1Widget.routeName);
                          },
                          child: GradientText(
                            i18n.tr('login_button', defaultText: 'Iniciar Sesión'),
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.mooli(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                            colors: [
                              FlutterFlowTheme.of(context).primary,
                              FlutterFlowTheme.of(context).secondary,
                            ],
                            gradientDirection: GradientDirection.ltr,
                            gradientType: GradientType.linear,
                          ),
                        ),
                      ],
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

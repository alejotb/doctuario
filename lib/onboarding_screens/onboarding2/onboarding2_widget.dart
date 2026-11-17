import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/i18n_service.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'onboarding2_model.dart';
export 'onboarding2_model.dart';

class Onboarding2Widget extends StatefulWidget {
  const Onboarding2Widget({super.key});

  static String routeName = 'onboarding2';
  static String routePath = '/onboarding2';

  @override
  State<Onboarding2Widget> createState() => _Onboarding2WidgetState();
}

class _Onboarding2WidgetState extends State<Onboarding2Widget> {
  late Onboarding2Model _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Onboarding2Model());
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
                    Text(
                      i18n.isSpanish
                          ? 'Gestión Inteligente de Turnos'
                          : 'Smart Queue & Shift Management',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).headlineSmall.override(
                            font: GoogleFonts.mooli(
                              fontWeight: FontWeight.bold,
                            ),
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      i18n.isSpanish
                          ? 'Conoce el estado de tu turno en tiempo real. Recibe notificaciones y avisos de retrasos o emergencias por WhatsApp.'
                          : 'Track your appointment in real time. Receive delay updates and queue alerts directly via WhatsApp.',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.mooli(),
                            color: FlutterFlowTheme.of(context).secondaryText,
                            fontSize: 14.0,
                            lineHeight: 1.5,
                          ),
                    ),
                    const SizedBox(height: 24.0),
                    // Indicador de pasos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8.0,
                          height: 8.0,
                          decoration: BoxDecoration(
                            color: const Color(0x2B0F0F0F),
                            borderRadius: BorderRadius.circular(24.0),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Container(
                          width: 30.0,
                          height: 8.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).primary,
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Container(
                          width: 8.0,
                          height: 8.0,
                          decoration: BoxDecoration(
                            color: const Color(0x2B0F0F0F),
                            borderRadius: BorderRadius.circular(24.0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28.0),
                    // Botón Siguiente
                    InkWell(
                      onTap: () async {
                        context.pushNamed(Onboarding3Widget.routeName);
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
                        ),
                        child: Center(
                          child: Text(
                            i18n.isSpanish ? 'Siguiente' : 'Next',
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
                    const SizedBox(height: 16.0),
                    // Botón Omitir
                    InkWell(
                      onTap: () async {
                        context.pushNamed(HomeWidget.routeName);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          i18n.isSpanish ? 'Omitir' : 'Skip',
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                font: GoogleFonts.mooli(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 14.0,
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

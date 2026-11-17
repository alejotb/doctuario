import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'splash_screen_model.dart';
export 'splash_screen_model.dart';

/// Pantalla de bienvenida y carga inicial (Splash Screen) de Doctuario.
///
/// Presenta la identidad visual oficial de Doctuario con el isotipo de
/// historia clínica / expediente médico independiente, animación de entrada fluida y
/// transición automática hacia el panel principal o la pantalla de login.
class SplashScreenWidget extends StatefulWidget {
  const SplashScreenWidget({super.key});

  static String routeName = 'splashScreen';
  static String routePath = '/splashScreen';

  @override
  State<SplashScreenWidget> createState() => _SplashScreenWidgetState();
}

class _SplashScreenWidgetState extends State<SplashScreenWidget>
    with SingleTickerProviderStateMixin {
  late SplashScreenModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SplashScreenModel());

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();
    _iniciarNavegacionAutomatica();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _animController.dispose();
    _model.dispose();
    super.dispose();
  }

  /// Inicia el temporizador de navegación automática hacia la pantalla adecuada
  void _iniciarNavegacionAutomatica() {
    _navTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      if (currentUser != null && loggedIn) {
        context.goNamed('Home');
      } else {
        context.goNamed('Login1');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        body: Container(
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF8FAFC),
                Color(0xFFE2E8F0),
                Color(0xFFF0FDF4),
              ],
              stops: [0.0, 0.6, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Contenido central animado (Logo + Título + Subtítulo)
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildLogoContainer(theme),
                          const SizedBox(height: 24.0),
                          _buildAppTitle(theme),
                          const SizedBox(height: 8.0),
                          _buildAppSubtitle(theme),
                          const SizedBox(height: 36.0),
                          _buildProgressIndicator(theme),
                        ],
                      ),
                    ),
                  ),
                ),

                // Pie de página con versión e información institucional
                Positioned(
                  bottom: 24.0,
                  left: 0.0,
                  right: 0.0,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildFooter(theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Contenedor estilizado para el isotipo de la historia clínica médica
  Widget _buildLogoContainer(FlutterFlowTheme theme) {
    return Container(
      width: 175.0,
      height: 175.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.22),
            blurRadius: 36.0,
            spreadRadius: 4.0,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36.0),
        child: Image.asset(
          'assets/images/doctuario_logo.png',
          width: 175.0,
          height: 175.0,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  /// Título de marca principal
  Widget _buildAppTitle(FlutterFlowTheme theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Doc',
          style: GoogleFonts.outfit(
            fontSize: 40.0,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.6,
          ),
        ),
        Text(
          'tuario',
          style: GoogleFonts.outfit(
            fontSize: 40.0,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0284C7),
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }

  /// Lema o subtítulo descriptivo del expediente clínico
  Widget _buildAppSubtitle(FlutterFlowTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Text(
        'Historias clínicas y gestión médica inteligente',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15.0,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF64748B),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Indicador sutil de carga médica
  Widget _buildProgressIndicator(FlutterFlowTheme theme) {
    return SizedBox(
      width: 28.0,
      height: 28.0,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(
          const Color(0xFF0284C7).withValues(alpha: 0.8),
        ),
      ),
    );
  }

  /// Pie de página institucional
  Widget _buildFooter(FlutterFlowTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 14.0,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6.0),
            Text(
              'Plataforma Médica Certificada',
              style: GoogleFonts.mooli(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Text(
          'v1.0 • doctuario.com',
          style: GoogleFonts.mooli(
            fontSize: 11.0,
            color: const Color(0xFFCBD5E1),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

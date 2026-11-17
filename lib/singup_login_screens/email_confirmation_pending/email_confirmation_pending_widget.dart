import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/i18n_service.dart';

/// Pantalla informativa que solicita al usuario revisar su correo para confirmar la cuenta
/// y luego lo redirige automáticamente según su rol:
/// - Doctores: a CreateProfileWidget para completar su perfil clínico
/// - Pacientes: a HomeWidget / CreateProfileWidget (página principal de la app)
class EmailConfirmationPendingWidget extends StatefulWidget {
  final String email;
  final String rol;
  final String? idDoctor;

  const EmailConfirmationPendingWidget({
    super.key,
    required this.email,
    required this.rol,
    this.idDoctor,
  });

  static const String routeName = 'EmailConfirmationPending';
  static const String routePath = '/emailConfirmationPending';

  @override
  State<EmailConfirmationPendingWidget> createState() =>
      _EmailConfirmationPendingWidgetState();
}

class _EmailConfirmationPendingWidgetState
    extends State<EmailConfirmationPendingWidget> {
  bool _isChecking = false;
  bool _isResending = false;
  int _cooldownSeconds = 60;
  Timer? _cooldownTimer;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _escucharConfirmacionAuth();
    _iniciarCooldown(60);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb && Uri.base.queryParameters['error_code'] == 'otp_expired') {
        final isEs = I18nService.instance.isSpanish;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: FlutterFlowTheme.of(context).error,
            duration: const Duration(seconds: 8),
            content: Text(
              isEs
                  ? 'El enlace de confirmación ha caducado o ya fue utilizado. Puedes solicitar uno nuevo o iniciar sesión.'
                  : 'The confirmation link has expired or was already used.',
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _iniciarCooldown([int segundos = 60]) {
    _cooldownTimer?.cancel();
    _cooldownSeconds = segundos;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_cooldownSeconds > 1) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      }
    });
  }

  void _escucharConfirmacionAuth() {
    _authSub = SupaFlow.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user ?? SupaFlow.client.auth.currentUser;
      if (user != null && user.emailConfirmedAt != null) {
        _navegarSegunRol(user.id);
      }
    });
  }

  Future<void> _mostrarDialogoYaConfirmado() async {
    final isEs = I18nService.instance.isSpanish;
    final theme = FlutterFlowTheme.of(context);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF249689), size: 26.0),
            const SizedBox(width: 8.0),
            Expanded(child: Text(isEs ? '¿Ya abriste el enlace?' : 'Did you open the link?', style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 17.0))),
          ],
        ),
        content: Text(
          isEs
              ? 'Si ya hiciste clic en el enlace desde tu teléfono u otra ventana, tu correo ya está confirmado en Doctuario.\n\nPuedes iniciar sesión ahora mismo con tu correo y contraseña.'
              : 'If you already opened the link on another device, your email is confirmed. You can log in now.',
          style: GoogleFonts.mooli(fontSize: 13.5, color: theme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isEs ? 'Esperar' : 'Wait', style: TextStyle(color: theme.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF249689), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.goNamed(Login1Widget.routeName);
            },
            child: Text(isEs ? 'Iniciar Sesión' : 'Log In', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _comprobarEstadoConfirmacion() async {
    setState(() => _isChecking = true);
    final isEs = I18nService.instance.isSpanish;

    try {
      // 1. Intentar refrescar la sesión actual
      try {
        final refreshRes = await SupaFlow.client.auth.refreshSession();
        final user = refreshRes.user;
        if (user != null && user.emailConfirmedAt != null) {
          setState(() => _isChecking = false);
          _navegarSegunRol(user.id);
          return;
        }
      } catch (_) {}

      // 2. Consultar directamente a Supabase Auth por el usuario actualizado
      try {
        final userRes = await SupaFlow.client.auth.getUser();
        final user = userRes.user;
        if (user != null && user.emailConfirmedAt != null) {
          setState(() => _isChecking = false);
          _navegarSegunRol(user.id);
          return;
        }
      } catch (_) {}

      // 3. Consultar cache local
      final user = SupaFlow.client.auth.currentUser;
      if (user != null && user.emailConfirmedAt != null) {
        setState(() => _isChecking = false);
        _navegarSegunRol(user.id);
        return;
      }

      // 4. Si la sesión no se detecta en esta ventana (e.g. confirmada en teléfono), guiar a login
      if (mounted) {
        setState(() => _isChecking = false);
        _mostrarDialogoYaConfirmado();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChecking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text(isEs ? 'Error al comprobar estado: $e' : 'Error checking status: $e')),
        );
      }
    }
  }

  Future<void> _reenviarCorreo() async {
    if (_isResending || _cooldownSeconds > 0) return;
    setState(() => _isResending = true);
    final isEs = I18nService.instance.isSpanish;

    try {
      await SupaFlow.client.auth.resend(
        type: OtpType.signup,
        email: widget.email.trim(),
      );
      _iniciarCooldown(60);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF249689),
            content: Text(
              isEs
                  ? 'Correo reenviado a ${widget.email}. Espera 60s antes de solicitar otro.'
                  : 'Confirmation email resent to ${widget.email}.',
              style: GoogleFonts.mooli(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        final isRateLimit = errStr.contains('rate') || errStr.contains('limit') || errStr.contains('over_email');
        if (isRateLimit) _iniciarCooldown(60);
        final errorMsg = isRateLimit
            ? (isEs
                ? 'Límite de envíos alcanzado por seguridad de Supabase. Espera un minuto antes de solicitar otro correo.'
                : 'Email rate limit reached. Please wait a minute before requesting again.')
            : (isEs ? 'No se pudo reenviar el correo: $e' : 'Could not resend email: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text(errorMsg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _navegarSegunRol(String userId) async {
    if (!mounted) return;
    final esDoctor = widget.rol.toLowerCase().trim() == 'doctor';

    if (esDoctor) {
      await DualDatabaseConfig.instance.persistActiveViewMode('doctor');
      if (!mounted) return;
      context.goNamedAuth(
        CreateProfileWidget.routeName,
        mounted,
        queryParameters: {
          'rol': serializeParam('Doctor', ParamType.String),
        }.withoutNulls,
      );
    } else {
      context.goNamedAuth(HomeWidget.routeName, mounted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.isSpanish;
    final esDoctor = widget.rol.toLowerCase() == 'doctor';

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.primaryText),
          onPressed: () => context.goNamed(Login1Widget.routeName),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF249689).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_rounded,
                      size: 52.0,
                      color: Color(0xFF249689),
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  Text(
                    isEs ? '¡Revisa tu correo electrónico!' : 'Check your email inbox!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.mooli(
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    isEs
                        ? 'Hemos enviado un enlace de confirmación a:'
                        : 'We sent a verification link to:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.mooli(
                      fontSize: 14.0,
                      color: theme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: theme.secondaryBackground,
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: theme.alternate),
                    ),
                    child: Text(
                      widget.email,
                      style: GoogleFonts.mooli(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF249689),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: theme.secondaryBackground,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: theme.alternate),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepItem(
                          numero: '1',
                          titulo: isEs ? 'Abre tu bandeja de entrada' : 'Open your inbox',
                          descripcion: isEs
                              ? 'Busca el correo enviado por Doctuario.'
                              : 'Look for the email sent by Doctuario.',
                        ),
                        const SizedBox(height: 12.0),
                        _buildStepItem(
                          numero: '2',
                          titulo: isEs ? 'Haz clic en el enlace' : 'Click the verification link',
                          descripcion: isEs
                              ? 'Confirma que este correo te pertenece.'
                              : 'Confirm that this email address belongs to you.',
                        ),
                        const SizedBox(height: 12.0),
                        _buildStepItem(
                          numero: '3',
                          titulo: isEs ? 'Ingreso automático' : 'Automatic Access',
                          descripcion: esDoctor
                              ? (isEs
                                  ? 'Te mostraremos la pantalla de espera mientras tu consultorio privado es configurado.'
                                  : 'We will show the waiting screen while your clinic is configured.')
                              : (isEs
                                  ? 'Accederás directamente a la página principal de Doctuario.'
                                  : 'You will enter directly into Doctuario Home.'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28.0),
                  SizedBox(
                    width: double.infinity,
                    height: 50.0,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF249689),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        elevation: 1,
                      ),
                      icon: _isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded, size: 20.0),
                      label: Text(
                        _isChecking
                            ? (isEs ? 'Comprobando...' : 'Checking...')
                            : (isEs ? 'Ya confirmé mi correo' : "I've verified my email"),
                        style: GoogleFonts.mooli(
                          fontSize: 15.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _isChecking ? null : _comprobarEstadoConfirmacion,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  SizedBox(
                    width: double.infinity,
                    height: 48.0,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _cooldownSeconds > 0 ? theme.secondaryText : theme.primaryText,
                        side: BorderSide(color: theme.alternate),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      ),
                      icon: _isResending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_cooldownSeconds > 0 ? Icons.timer_outlined : Icons.refresh_rounded, size: 18.0),
                      label: Text(
                        _isResending
                            ? (isEs ? 'Reenviando...' : 'Resending...')
                            : (_cooldownSeconds > 0
                                ? (isEs ? 'Reenviar en ${_cooldownSeconds}s' : 'Resend in ${_cooldownSeconds}s')
                                : (isEs ? 'Reenviar enlace de confirmación' : 'Resend confirmation link')),
                        style: GoogleFonts.mooli(fontSize: 14.0, fontWeight: _cooldownSeconds > 0 ? FontWeight.normal : FontWeight.w600),
                      ),
                      onPressed: (_isResending || _cooldownSeconds > 0) ? null : _reenviarCorreo,
                    ),
                  ),
                  const SizedBox(height: 14.0),
                  TextButton.icon(
                    icon: const Icon(Icons.login_rounded, size: 18.0, color: Color(0xFF249689)),
                    onPressed: () => context.goNamed(Login1Widget.routeName),
                    label: Text(
                      isEs ? '¿Ya confirmaste en tu teléfono? Inicia sesión aquí' : 'Already confirmed on phone? Log in here',
                      style: GoogleFonts.mooli(fontSize: 13.5, color: const Color(0xFF249689), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required String numero,
    required String titulo,
    required String descripcion,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF249689),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            numero,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12.0,
            ),
          ),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: GoogleFonts.mooli(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                descripcion,
                style: GoogleFonts.mooli(
                  fontSize: 12.0,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/supabase/supabase.dart';
import 'i18n_service.dart';

/// Servicio que gestiona la verificación del estado de suscripción de los doctores
/// e implementa el plan de contingencia de Modo Solo Lectura (retención y descarga).
class DoctorSubscriptionService {
  DoctorSubscriptionService._();
  static final DoctorSubscriptionService instance = DoctorSubscriptionService._();

  bool _isReadOnly = false;
  bool _isPendingApproval = false;
  String _estadoPago = 'al_dia';
  String _estadoVerificacion = 'pendiente';
  bool _initialized = false;
  DateTime? _ultimoChequeo;

  /// Retorna si el doctor actualmente tiene activa la contingencia de solo lectura.
  bool get isReadOnly => _isReadOnly;

  /// Retorna si el doctor aún está pendiente de verificación/aprobación por el administrador.
  bool get isPendingApproval => _isPendingApproval;

  /// Retorna si el administrador solicitó número de registro / colegiatura al médico.
  bool get requiereCredenciales => _estadoVerificacion == 'solicitud_credenciales';

  /// Retorna el estado textual ('al_dia' o 'solo_lectura').
  String get estadoPago => _estadoPago;

  /// Reinicia la caché local al cerrar sesión.
  void reset() {
    _isReadOnly = false;
    _isPendingApproval = false;
    _estadoPago = 'al_dia';
    _estadoVerificacion = 'pendiente';
    _initialized = false;
    _ultimoChequeo = null;
  }

  /// Consulta el estado de pago y aprobación del doctor en la Base Única.
  Future<bool> verificarEstadoDoctor({String? idDoctor, bool forzar = false}) async {
    final uid = idDoctor ?? SupaFlow.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      reset();
      return false;
    }

    final ahora = DateTime.now();
    if (!forzar && _initialized && _ultimoChequeo != null && ahora.difference(_ultimoChequeo!).inMinutes < 5) {
      return _isReadOnly;
    }

    try {
      final client = DualDatabaseConfig.instance.patientClient;
      final res = await client
          .from('doctores_tenants')
          .select('estado_pago, modo_solo_lectura')
          .eq('id_doctor', uid)
          .maybeSingle();

      if (res != null) {
        final st = (res['estado_pago']?.toString() ?? 'al_dia').toLowerCase().trim();
        _estadoPago = st;
        _isReadOnly = (st == 'solo_lectura') || (res['modo_solo_lectura'] == true);
      } else {
        _estadoPago = 'al_dia';
        _isReadOnly = false;
      }

      try {
        final docRes = await client
            .from('doctores')
            .select('esta_aprobado, estado_verificacion')
            .eq('id', uid)
            .maybeSingle();
        if (docRes != null) {
          final stDoc = (docRes['estado_verificacion']?.toString() ?? 'pendiente').toLowerCase().trim();
          _estadoVerificacion = stDoc.isEmpty ? 'pendiente' : stDoc;
          final approved = docRes['esta_aprobado'] == true &&
              (stDoc == 'aprobado' || stDoc == 'activo' || stDoc.isEmpty);
          _isPendingApproval = !approved;
        } else {
          _estadoVerificacion = 'pendiente';
          _isPendingApproval = true;
        }
      } catch (_) {}

      _initialized = true;
      _ultimoChequeo = ahora;
    } catch (e) {
      debugPrint('DoctorSubscriptionService: Error verificando estado: $e');
    }
    return _isReadOnly;
  }

  /// Muestra un modal explicativo al doctor cuando intenta realizar una acción de escritura bloqueada.
  void mostrarModalRestriccionPago(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_clock_rounded, size: 42.0, color: Colors.orange.shade700),
            ),
            const SizedBox(height: 16.0),
            Text(
              isEs ? 'Modo Solo Lectura y Descarga' : 'Read-Only & Download Mode',
              textAlign: TextAlign.center,
              style: GoogleFonts.mooli(fontSize: 18.0, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 10.0),
            Text(
              isEs
                  ? 'Tu consultorio se encuentra en contingencia por suscripción pendiente. Puedes consultar y descargar todas tus historias clínicas, citas y exámenes anteriores, pero no es posible registrar nuevos pacientes ni agendar citas.'
                  : 'Your clinic is in read-only mode due to a pending subscription. You can review and download all past medical records, appointments and exams, but creating new records is temporarily paused.',
              textAlign: TextAlign.center,
              style: GoogleFonts.mooli(fontSize: 13.5, color: Colors.blueGrey.shade600, height: 1.4),
            ),
            const SizedBox(height: 22.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.download_done_rounded, color: Color(0xFF10B981), size: 22.0),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      isEs
                          ? 'Tus datos clínicos están 100% seguros y respaldados en tu base privada.'
                          : 'Your medical data is 100% safe and backed up in your private database.',
                      style: GoogleFonts.mooli(fontSize: 12.0, color: const Color(0xFF334155), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(isEs ? 'Entendido' : 'Got it', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF249689),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18.0),
                    label: Text(isEs ? 'Contactar Soporte' : 'Contact Support', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final url = Uri.parse('https://wa.me/?text=Hola%2C%20deseo%20regularizar%20mi%20suscripci%C3%B3n%20en%20Doctuario.');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner visual para insertar en el dashboard del doctor cuando esté en contingencia de solo lectura.
class DoctorReadOnlyBannerWidget extends StatelessWidget {
  const DoctorReadOnlyBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final isReadOnly = DoctorSubscriptionService.instance.isReadOnly;
    final isPending = DoctorSubscriptionService.instance.isPendingApproval;
    if (!isReadOnly && !isPending) return const SizedBox.shrink();

    if (!isReadOnly && isPending) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color(0xFF7DD3FC), width: 1.0),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Color(0xFF0284C7), size: 22.0),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEs ? 'Estamos configurando tu cuenta' : 'We are setting up your account',
                    style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF0C4A6E)),
                  ),
                  Text(
                    isEs
                        ? 'Nuestro equipo está preparando tu consultorio digital. Muy pronto tendrás acceso completo.'
                        : 'Our team is preparing your digital practice. You will have full access very soon.',
                    style: GoogleFonts.mooli(fontSize: 11.0, color: const Color(0xFF0369A1)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.orange.shade300, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange.shade800, size: 22.0),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? 'Modo Solo Lectura (Suscripción Pendiente)' : 'Read-Only Mode (Pending Payment)',
                  style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.orange.shade900),
                ),
                Text(
                  isEs ? 'Puedes consultar y descargar expedientes. Nuevos registros pausados.' : 'Records are viewable and downloadable. New entries paused.',
                  style: GoogleFonts.mooli(fontSize: 11.0, color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => DoctorSubscriptionService.instance.mostrarModalRestriccionPago(context),
            child: Text(
              isEs ? 'Detalles' : 'Details',
              style: GoogleFonts.mooli(fontSize: 12.0, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla amigable que se muestra a doctores recién registrados mientras el
/// administrador configura y habilita su cuenta médica.
class DoctorAccountSetupPendingScreen extends StatefulWidget {
  final String idDoctor;
  final VoidCallback onRefreshStatus;
  final Future<void> Function() onSignOut;

  const DoctorAccountSetupPendingScreen({
    super.key,
    required this.idDoctor,
    required this.onRefreshStatus,
    required this.onSignOut,
  });

  @override
  State<DoctorAccountSetupPendingScreen> createState() =>
      _DoctorAccountSetupPendingScreenState();
}

class _DoctorAccountSetupPendingScreenState
    extends State<DoctorAccountSetupPendingScreen> {
  final TextEditingController _registroController = TextEditingController();
  bool _checking = false;
  bool _sendingCredential = false;
  bool _credentialSent = false;

  @override
  void dispose() {
    _registroController.dispose();
    super.dispose();
  }

  Future<void> _enviarRegistroMedico() async {
    final nro = _registroController.text.trim();
    if (nro.isEmpty) return;
    setState(() => _sendingCredential = true);
    try {
      await SupaFlow.client.from('doctores').update({
        'nro_colegiatura': nro,
        'estado_verificacion': 'pendiente',
      }).eq('id', widget.idDoctor);
      if (!mounted) return;
      setState(() {
        _credentialSent = true;
        _sendingCredential = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F766E),
          content: Text(
            I18nService.instance.isSpanish
                ? 'Datos recibidos. Continuamos configurando tu cuenta.'
                : 'Details received. We are continuing to configure your account.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sendingCredential = false);
      }
    }
  }

  Future<void> _revisarEstado() async {
    setState(() => _checking = true);
    await DoctorSubscriptionService.instance
        .verificarEstadoDoctor(idDoctor: widget.idDoctor, forzar: true);
    if (!mounted) return;
    setState(() => _checking = false);
    widget.onRefreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final requiereCredenciales =
        DoctorSubscriptionService.instance.requiereCredenciales && !_credentialSent;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(28.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18.0),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0F2FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings_suggest_rounded,
                        size: 46.0,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    Text(
                      isEs
                          ? 'Estamos configurando tu cuenta'
                          : 'We are setting up your account',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.mooli(
                        fontSize: 21.0,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      isEs
                          ? 'Estamos preparando tu consultorio digital y ajustando todas tus herramientas médicas para que tengas la mejor experiencia. Te notificaremos en cuanto esté listo.'
                          : 'We are preparing your digital practice and setting up your medical workspace. We will notify you as soon as everything is ready.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.mooli(
                        fontSize: 13.5,
                        color: const Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                    if (requiereCredenciales) ...[
                      const SizedBox(height: 22.0),
                      Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEs
                                  ? 'Dato adicional para finalizar la configuración'
                                  : 'Additional detail to complete setup',
                              style: GoogleFonts.mooli(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.0,
                                color: const Color(0xFF0369A1),
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            Text(
                              isEs
                                  ? 'Por favor indícanos tu número de registro médico o colegiatura para personalizar tus récipes e informes.'
                                  : 'Please enter your medical license or registration number to personalize your prescriptions and reports.',
                              style: GoogleFonts.mooli(
                                fontSize: 12.0,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            TextField(
                              controller: _registroController,
                              decoration: InputDecoration(
                                hintText: isEs
                                    ? 'Ej. MPPS 123456 / Colegiatura'
                                    : 'e.g. Medical License #',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 12.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10.0),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                                onPressed: _sendingCredential ? null : _enviarRegistroMedico,
                                child: _sendingCredential
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isEs ? 'Enviar número de registro' : 'Submit license number',
                                        style: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24.0),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        onPressed: _checking ? null : _revisarEstado,
                        icon: _checking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 19.0),
                        label: Text(
                          isEs ? 'Verificar si ya está lista' : 'Check status',
                          style: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    TextButton.icon(
                      onPressed: () async => await widget.onSignOut(),
                      icon: const Icon(Icons.logout_rounded, size: 18.0, color: Color(0xFF64748B)),
                      label: Text(
                        isEs ? 'Cerrar sesión' : 'Sign out',
                        style: GoogleFonts.mooli(color: const Color(0xFF64748B)),
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

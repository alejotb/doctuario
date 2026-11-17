import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../flutter_flow/flutter_flow_theme.dart';
import '../services/i18n_service.dart';
import 'legal_portal_widget.dart';

/// Pantalla oficial de la Política de Privacidad y Protección de Datos de Doctuario.
///
/// Detalla la recopilación, tratamiento, seguridad, aislamiento multitenant,
/// garantía de no compromiso de datos de pacientes y derechos conforme a estándares
/// de protección de datos clínicos y confidencialidad médica.
class PrivacyPolicyWidget extends StatelessWidget {
  const PrivacyPolicyWidget({super.key});

  static const String routeName = 'PrivacyPolicy';
  static const String routePath = '/privacy';

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final i18n = I18nService.instance;
    final isEs = i18n.isSpanish;

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        title: Text(
          isEs ? 'Política de Privacidad' : 'Privacy Policy',
          style: GoogleFonts.mooli(
            fontWeight: FontWeight.bold,
            fontSize: 18.0,
            color: theme.primaryText,
          ),
        ),
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(context, theme, isEs),
                  const SizedBox(height: 16.0),
                  _buildPortalBanner(context, theme, isEs),
                  const SizedBox(height: 20.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.business_rounded,
                    title: isEs ? '1. Responsable del Tratamiento y Rol' : '1. Data Controller & Processing Role',
                    body: isEs
                        ? 'Doctuario (doctuario.com) es una plataforma tecnológica orientada a la gestión médica digital, expedientes clínicos y reserva de citas de salud. Operamos como Encargados del Tratamiento de los datos gestionados por los médicos y sus clínicas.'
                        : 'Doctuario (doctuario.com) is a digital healthcare management platform. We act as Data Processors for patient records administered by practicing physicians and medical clinics.',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.verified_user_rounded,
                    title: isEs ? '2. Garantía de No Compromiso de Datos' : '2. Patient Data Non-Compromise Guarantee',
                    body: isEs
                        ? 'COMPROMISO ÉTICO Y LEGAL: Los datos de los pacientes jamás estarán comprometidos. Doctuario no vende, no alquila, no monetiza ni comparte información médica ni personal con aseguradoras, farmacéuticas o empresas de publicidad bajo ninguna circunstancia.'
                        : 'ETHICAL & LEGAL COMMITMENT: Patient data is never compromised. Doctuario does not sell, license, monetize, or disclose health records or personal information to insurers, pharmaceutical firms, or ad networks under any circumstances.',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.shield_rounded,
                    title: isEs ? '3. Aislamiento Multitenant y Cifrado Fuerte' : '3. Multi-Tenant Isolation & Strong Encryption',
                    body: isEs
                        ? 'Cada consultorio médico dispone de un entorno de base de datos aislado que impide la fuga o acceso entre diferentes profesionales. La información se encuentra cifrada en tránsito (TLS/HTTPS) y en reposo mediante algoritmos criptográficos robustos (AES + HMAC-SHA256).'
                        : 'Each medical clinic operates within an isolated database partition that prevents cross-tenant access. Data is encrypted in transit (TLS/HTTPS) and at rest utilizing robust cryptographic standards (AES + HMAC-SHA256).',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.folder_shared_rounded,
                    title: isEs ? '4. Soberanía del Médico y Datos del Paciente' : '4. Doctor Custody & Patient Records Sovereignty',
                    body: isEs
                        ? 'El médico tratante es el custodio legal de la historia clínica. Doctuario garantiza que el doctor siempre tendrá acceso irrestricto para consultar, revisar y exportar sus registros. En caso de suspensión o impago, los datos no se borran y se preserva el acceso en Modo Solo Lectura.'
                        : 'The attending physician serves as the legal custodian of clinical records. Doctuario guarantees uninterrupted access to view and export records. In the event of subscription lapse, files are preserved and accessible in Read-Only Mode.',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.folder_open_rounded,
                    title: isEs ? '5. Información Recopilada' : '5. Information We Collect',
                    body: isEs
                        ? 'Recopilamos únicamente los datos necesarios para la gestión asistencial:\n\n'
                            '• Identificación: Nombre, correo electrónico, teléfono, documento de identidad.\n'
                            '• Información Clínica: Citas, notas de evolución médica, recetas y archivos adjuntados por el médico o paciente.\n'
                            '• Datos Técnicos de Seguridad: Tokens de autenticación y auditorías de acceso.'
                        : 'We only collect data strictly necessary for care delivery:\n\n'
                            '• Identification: Name, email address, phone, ID number.\n'
                            '• Clinical Information: Appointment schedules, progress notes, prescriptions, and medical file attachments.\n'
                            '• Technical Security Data: Session auth tokens and security access logs.',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.rule_rounded,
                    title: isEs ? '6. Derechos del Usuario (ARCO / GDPR)' : '6. User Rights (GDPR / ARCO)',
                    body: isEs
                        ? 'Todo usuario tiene derecho a acceder a sus datos personales, solicitar su corrección, solicitar la eliminación de su cuenta o revocar el consentimiento previamente otorgado mediante las opciones de su perfil o contactando a nuestro equipo oficial.'
                        : 'Every user is entitled to access their personal records, request corrections, request account removal, or revoke previously granted consent through profile settings or our official support channel.',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.mail_outline_rounded,
                    title: isEs ? '7. Contacto de Privacidad y Delegado' : '7. Privacy Contact & Data Protection Officer',
                    body: isEs
                        ? 'Para cualquier consulta o ejercicio de derechos sobre la privacidad de sus datos:\n\n'
                            'soporte@doctuario.com | legal@doctuario.com\n'
                            'https://doctuario.com'
                        : 'For questions or to exercise your data privacy rights:\n\n'
                            'soporte@doctuario.com | legal@doctuario.com\n'
                            'https://doctuario.com',
                  ),
                  const SizedBox(height: 32.0),
                  _buildFooter(theme, isEs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortalBanner(BuildContext context, FlutterFlowTheme theme, bool isEs) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LegalPortalWidget(initialTab: 1)),
      ),
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color(0x12249689),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color(0xFF249689).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.security_rounded, color: Color(0xFF249689), size: 22.0),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                isEs
                    ? 'Ver Garantía de Privacidad y Blindaje Legal en el Centro Integral →'
                    : 'View Privacy Guarantee & Legal Shielding in the Full Portal →',
                style: GoogleFonts.mooli(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF249689),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    FlutterFlowTheme theme,
    bool isEs,
  ) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: theme.alternate),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: Image.asset(
              'assets/images/doctuario_logo.png',
              width: 56.0,
              height: 56.0,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doctuario Privacy Statement',
                  style: GoogleFonts.mooli(
                    fontSize: 17.0,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  isEs
                      ? 'Compromiso de No Compromiso de Datos • Versión 2.0 (Noviembre 2026)'
                      : 'Non-Compromise Data Commitment • Version 2.0 (November 2026)',
                  style: GoogleFonts.mooli(
                    fontSize: 12.0,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required FlutterFlowTheme theme,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF249689).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Icon(icon, color: const Color(0xFF249689), size: 20.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.mooli(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),
          Text(
            body,
            style: GoogleFonts.mooli(
              fontSize: 13.5,
              height: 1.55,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(FlutterFlowTheme theme, bool isEs) {
    return Center(
      child: Column(
        children: [
          Text(
            '© 2026 Doctuario Inc. Todos los derechos reservados.',
            style: GoogleFonts.mooli(
              fontSize: 12.0,
              color: theme.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4.0),
          Text(
            'https://doctuario.com',
            style: GoogleFonts.mooli(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF249689),
            ),
          ),
        ],
      ),
    );
  }
}

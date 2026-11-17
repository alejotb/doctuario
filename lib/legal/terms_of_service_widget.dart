import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../flutter_flow/flutter_flow_theme.dart';
import '../services/i18n_service.dart';
import 'legal_portal_widget.dart';

/// Pantalla oficial de las Condiciones del Servicio de Doctuario.
///
/// Establece los términos contractuales, responsabilidades, exención médica,
/// régimen de suscripción con preservación en modo solo lectura, custodia del médico
/// y blindaje legal integral para pacientes y profesionales de la salud.
class TermsOfServiceWidget extends StatelessWidget {
  const TermsOfServiceWidget({super.key});

  static const String routeName = 'TermsOfService';
  static const String routePath = '/terms';

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final i18n = I18nService.instance;
    final isEs = i18n.isSpanish;

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        title: Text(
          isEs ? 'Condiciones del Servicio' : 'Terms of Service',
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
                    icon: Icons.gavel_rounded,
                    title: isEs ? '1. Aceptación de los Términos' : '1. Acceptance of Terms',
                    body: isEs
                        ? 'Al registrarse, acceder o utilizar la plataforma Doctuario (sitio web doctuario.com o aplicaciones móviles), usted acepta cumplir íntegramente las presentes Condiciones del Servicio y nuestra Política de Privacidad. Si no está de acuerdo con alguno de estos términos, debe abstenerse de utilizar la plataforma.'
                        : 'By registering, accessing, or using Doctuario (doctuario.com website or mobile apps), you agree to be bound by these Terms of Service and our Privacy Policy. If you do not agree with any of these terms, you must not use the platform.',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.medical_services_rounded,
                    title: isEs ? '2. Alcance y Descargo Médico' : '2. Medical Disclaimer & Scope',
                    body: isEs
                        ? 'IMPORTANTE: Doctuario es una plataforma tecnológica de gestión clínica y software como servicio (SaaS) que facilita la programación de citas, el registro de expedientes y la comunicación entre médico y paciente.\n\n'
                            '• Doctuario NO presta servicios de atención médica, no es hospital ni servicio de emergencias médicas vitales (911).\n'
                            '• Los diagnósticos, prescripciones y tratamientos emitidos son responsabilidad exclusiva de los profesionales médicos certificados que atienden al paciente.'
                        : 'IMPORTANT: Doctuario is a clinical management software platform (SaaS) facilitating appointment scheduling and medical record-keeping.\n\n'
                            '• Doctuario is NOT an emergency response provider or healthcare facility.\n'
                            '• Medical diagnoses, prescriptions, and treatments are the sole responsibility of the certified medical professionals attending the patient.',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.lock_outline_rounded,
                    title: isEs ? '3. No Compromiso de Datos de Pacientes' : '3. Non-Compromise of Patient Data',
                    body: isEs
                        ? 'GARANTÍA IRREVOCABLE: Los datos médicos y personales de los pacientes jamás serán comercializados, transferidos, cedidos ni expuestos a terceras partes. No se utilizan para perfilamiento publicitario ni se venden a farmacéuticas o aseguradoras. Operan bajo estricto cifrado y aislamiento hermético.'
                        : 'IRREVOCABLE GUARANTEE: Patient medical and personal information will never be monetized, sold, or disclosed to third parties. Data is protected with end-to-end cloud encryption and strict multi-tenant isolation.',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.folder_shared_rounded,
                    title: isEs ? '4. Soberanía y Acceso Permanente del Doctor' : '4. Doctor Data Sovereignty & Perpetual Access',
                    body: isEs
                        ? 'El profesional de la salud es el custodio legal de los expedientes clínicos de sus pacientes. Doctuario garantiza que el médico siempre tendrá acceso a consultar, revisar y exportar sus historias clínicas, salvaguardando la continuidad del tratamiento y el cumplimiento ético de custodia de datos de salud.'
                        : 'The healthcare professional remains the legal custodian of their patient charts. Doctuario guarantees perpetual access to view and export patient histories, upholding ethical standards and medical continuity of care.',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.receipt_long_rounded,
                    title: isEs ? '5. Régimen de Impago: Modo Solo Lectura' : '5. Unpaid Subscription: Read-Only Mode',
                    body: isEs
                        ? 'En caso de que el consultorio o doctor incurra en mora, falta de pago o vencimiento de su plan de suscripción:\n\n'
                            '• Los datos existentes NO se borran ni se eliminan jamás.\n'
                            '• El doctor MANTIENE ACCESO para consultar y exportar todos los expedientes de sus pacientes.\n'
                            '• La cuenta pasa a MODO SOLO LECTURA: no se podrán registrar nuevos pacientes ni nuevas consultas hasta regularizar el pago.'
                        : 'In the event of an overdue balance or subscription lapse:\n\n'
                            '• Existing patient data is NEVER deleted or destroyed.\n'
                            '• The physician RETAINS ACCESS to view, inspect, and export all existing records.\n'
                            '• The account enters READ-ONLY MODE: registering new patients or appointments is paused until payment is regularized.',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.shield_rounded,
                    title: isEs ? '6. Blindaje Legal e Indemnidad' : '6. Legal Shielding & Indemnification',
                    body: isEs
                        ? 'El propietario, desarrolladores y operadores de Doctuario quedan expresamente liberados de toda responsabilidad civil, penal o médica por actos u omisiones de los doctores o pacientes. Los usuarios se obligan a indemnizar y mantener indemne a Doctuario ante cualquier reclamación derivada del uso indebido del servicio o negligencia médica profesional.'
                        : 'Doctuario owners, developers, and operators are fully released from any liability arising from medical malpractice or clinical decisions. Users agree to indemnify and hold harmless the platform from any claims resulting from service misuse or clinical malpractice.',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.copyright_rounded,
                    title: isEs ? '7. Propiedad Intelectual del Software' : '7. Software Intellectual Property',
                    body: isEs
                        ? 'Todos los derechos de propiedad intelectual sobre el software, diseño, logotipos, marcas comerciales ("Doctuario") y código fuente son titularidad exclusiva de Doctuario Inc. Se concede a los usuarios una licencia limitada, revocable y no exclusiva para el uso personal y profesional de la plataforma.'
                        : 'All intellectual property rights regarding the software, design, logos, trademarks ("Doctuario"), and source code belong exclusively to Doctuario Inc. Users are granted a limited, revocable, non-exclusive license for personal and clinical use.',
                  ),
                  const SizedBox(height: 18.0),
                  _buildSection(
                    context: context,
                    theme: theme,
                    icon: Icons.update_rounded,
                    title: isEs ? '8. Modificaciones y Contacto' : '8. Modifications and Contact',
                    body: isEs
                        ? 'Nos reservamos el derecho de modificar o actualizar estos términos en cualquier momento. El uso continuado tras la publicación implicará su aceptación.\n\n'
                            'Consultas legales y contractuales:\n'
                            'legal@doctuario.com | https://doctuario.com'
                        : 'We reserve the right to modify these terms at any time. Continued use following updates constitutes acceptance.\n\n'
                            'For legal inquiries: legal@doctuario.com | https://doctuario.com',
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
        MaterialPageRoute(builder: (_) => const LegalPortalWidget()),
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
            const Icon(Icons.auto_stories_rounded, color: Color(0xFF249689), size: 22.0),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                isEs
                    ? 'Explorar el Centro Legal Completo con búsqueda y pestañas interactivas →'
                    : 'Explore the Full Legal Center with search and interactive tabs →',
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
                  'Doctuario Terms of Service',
                  style: GoogleFonts.mooli(
                    fontSize: 17.0,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  isEs
                      ? 'Acuerdo legal de usuario • Versión 2.0 (Actualizada Noviembre 2026)'
                      : 'Legal User Agreement • Version 2.0 (Updated November 2026)',
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
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Icon(icon, color: const Color(0xFF0284C7), size: 20.0),
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
              color: const Color(0xFF0284C7),
            ),
          ),
        ],
      ),
    );
  }
}

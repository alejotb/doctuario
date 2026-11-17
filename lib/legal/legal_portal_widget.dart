import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../flutter_flow/flutter_flow_theme.dart';
import '../services/i18n_service.dart';

/// Centro Legal Integral y Condiciones del Servicio de Doctuario.
///
/// Consolida las políticas contractuales, blindaje legal, garantía de no compromiso
/// de datos de pacientes, soberanía y custodia médica permanente, y el régimen de
/// suscripciones con preservación en modo solo lectura ante impago.
class LegalPortalWidget extends StatefulWidget {
  const LegalPortalWidget({super.key, this.initialTab = 0});

  static const String routeName = 'LegalPortal';
  static const String routePath = '/legal';

  final int initialTab;

  @override
  State<LegalPortalWidget> createState() => _LegalPortalWidgetState();
}

class _LegalPortalWidgetState extends State<LegalPortalWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _copiarTexto(BuildContext context, String texto, String mensaje) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF249689),
        content: Text(mensaje),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.isSpanish;

    final tabs = [
      {'title': isEs ? 'Condiciones de Uso' : 'Terms of Use', 'icon': Icons.gavel_rounded},
      {'title': isEs ? 'No Compromiso de Datos' : 'Data Protection', 'icon': Icons.lock_outline_rounded},
      {'title': isEs ? 'Custodia del Doctor' : 'Doctor Custody', 'icon': Icons.folder_shared_rounded},
      {'title': isEs ? 'Suscripción e Impago' : 'Subscription & Billing', 'icon': Icons.receipt_long_rounded},
      {'title': isEs ? 'Blindaje y Descargo' : 'Legal Shielding', 'icon': Icons.shield_rounded},
    ];

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        title: Text(
          isEs ? 'Centro Legal y Condiciones' : 'Legal Center & Terms',
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: theme.primary,
          unselectedLabelColor: theme.secondaryText,
          indicatorColor: theme.primary,
          indicatorWeight: 3.0,
          labelStyle: GoogleFonts.mooli(fontSize: 13.0, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.mooli(fontSize: 12.5),
          tabs: tabs.map((t) {
            return Tab(
              icon: Icon(t['icon'] as IconData, size: 18.0),
              text: t['title'] as String,
            );
          }).toList(),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTabContent(context, theme, isEs, _getTermsContent(isEs)),
            _buildTabContent(context, theme, isEs, _getDataProtectionContent(isEs)),
            _buildTabContent(context, theme, isEs, _getDoctorCustodyContent(isEs)),
            _buildTabContent(context, theme, isEs, _getSubscriptionContent(isEs)),
            _buildTabContent(context, theme, isEs, _getLegalShieldContent(isEs)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    FlutterFlowTheme theme,
    bool isEs,
    List<Map<String, dynamic>> sections,
  ) {
    final filtered = _filterQuery.isEmpty
        ? sections
        : sections.where((s) {
            final t = (s['title'] as String).toLowerCase();
            final b = (s['body'] as String).toLowerCase();
            return t.contains(_filterQuery) || b.contains(_filterQuery);
          }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopAlertBadge(theme, isEs),
              const SizedBox(height: 14.0),
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _filterQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: isEs ? 'Buscar en esta sección legal...' : 'Search within this legal section...',
                  hintStyle: GoogleFonts.mooli(fontSize: 12.5, color: theme.secondaryText),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18.0),
                  suffixIcon: _filterQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18.0),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _filterQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.secondaryBackground,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: theme.alternate),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: theme.secondaryBackground,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Center(
                    child: Text(
                      isEs ? 'No se encontraron cláusulas coincidentes.' : 'No matching clauses found.',
                      style: GoogleFonts.mooli(color: theme.secondaryText),
                    ),
                  ),
                )
              else
                ...filtered.map((sec) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildSectionCard(context, theme, sec, isEs),
                    )),
              const SizedBox(height: 20.0),
              _buildLegalFooter(context, theme, isEs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAlertBadge(FlutterFlowTheme theme, bool isEs) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0x12249689),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF249689).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: Color(0xFF249689), size: 24.0),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? 'Marco Legal Vinculante y Garantías Doctuario' : 'Binding Legal Framework & Doctuario Guarantees',
                  style: GoogleFonts.mooli(fontSize: 13.0, fontWeight: FontWeight.bold, color: const Color(0xFF249689)),
                ),
                const SizedBox(height: 2.0),
                Text(
                  isEs
                      ? 'Datos de pacientes 100% aislados • Custodia permanente del médico • Modo Solo Lectura garantizado por impago.'
                      : '100% Isolated patient data • Permanent doctor custody • Read-Only mode guaranteed upon unpaid balance.',
                  style: GoogleFonts.mooli(fontSize: 11.5, color: theme.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    FlutterFlowTheme theme,
    Map<String, dynamic> sec,
    bool isEs,
  ) {
    final title = sec['title'] as String;
    final body = sec['body'] as String;
    final icon = sec['icon'] as IconData? ?? Icons.article_rounded;
    final isCrucial = sec['crucial'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: isCrucial ? const Color(0xFF249689).withValues(alpha: 0.5) : theme.alternate,
          width: isCrucial ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: (isCrucial ? const Color(0xFF249689) : theme.primary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Icon(icon, color: isCrucial ? const Color(0xFF249689) : theme.primary, size: 20.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.mooli(
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryText,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16.0),
                tooltip: isEs ? 'Copiar cláusula' : 'Copy clause',
                color: theme.secondaryText,
                onPressed: () => _copiarTexto(
                  context,
                  '$title\n\n$body',
                  isEs ? 'Cláusula copiada al portapapeles' : 'Clause copied to clipboard',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Text(
            body,
            style: GoogleFonts.mooli(
              fontSize: 13.0,
              height: 1.55,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalFooter(BuildContext context, FlutterFlowTheme theme, bool isEs) {
    return Column(
      children: [
        Divider(color: theme.alternate),
        const SizedBox(height: 12.0),
        Text(
          isEs
              ? '¿Dudas sobre el tratamiento de datos o términos comerciales? Contacte a:'
              : 'Questions regarding data compliance or commercial terms? Contact:',
          style: GoogleFonts.mooli(fontSize: 11.5, color: theme.secondaryText),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4.0),
        Text(
          'legal@doctuario.com • https://doctuario.com',
          style: GoogleFonts.mooli(
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF249689),
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          '© 2026 Doctuario Inc. Todos los derechos reservados.',
          style: GoogleFonts.mooli(fontSize: 11.0, color: theme.secondaryText),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getTermsContent(bool isEs) {
    return [
      {
        'icon': Icons.handshake_rounded,
        'title': isEs ? '1. Naturaleza del Servicio y Acuerdo Vinculante' : '1. Nature of Service and Binding Agreement',
        'body': isEs
            ? 'Doctuario (accesible mediante doctuario.com y aplicaciones afines) es una plataforma tecnológica que provee soluciones de software como servicio (SaaS) orientadas a la optimización operativa de consultorios médicos, gestión de agenda y registro de historias clínicas digitales. Al registrarse, el usuario declara haber leído, comprendido y aceptado todas las estipulaciones aquí recogidas.'
            : 'Doctuario (accessible via doctuario.com and related apps) is a software-as-a-service (SaaS) platform providing digital operational tools for medical offices, schedule management, and electronic health records. By creating an account, users declare having read, understood, and agreed to all provisions contained herein.',
      },
      {
        'icon': Icons.medical_services_rounded,
        'title': isEs ? '2. No Prestación Directa de Servicios Médicos' : '2. No Direct Provision of Healthcare Services',
        'body': isEs
            ? 'Doctuario NO presta servicios de atención médica, no es una entidad prestadora de salud (EPS/IPS), ni actúa como centro médico asistencial. La plataforma funciona estrictamente como canal tecnológico facilitador. Cada acto médico, evolución clínica, emisión de recetas o prescripciones es de exclusiva responsabilidad del profesional tratante debidamente colegiado y habilitado.'
            : 'Doctuario DOES NOT provide direct medical care, is not a hospital or health insurer, and does not operate as an emergency medical service. The platform serves solely as an enabling software suite. Every medical assessment, diagnosis, prescription, or clinical note is under the exclusive responsibility of the attending certified healthcare practitioner.',
      },
      {
        'icon': Icons.phone_in_talk_rounded,
        'title': isEs ? '3. Exclusión de Urgencias y Emergencias Vitales' : '3. Exclusion of Vital Emergency Services',
        'body': isEs
            ? 'La plataforma NO está diseñada ni autorizada para la atención de emergencias médicas con riesgo inminente para la vida o la integridad física. En caso de emergencia o urgencia súbita, los pacientes deben comunicarse de inmediato con los servicios de respuesta rápida de su región (ej. 911, ambulancias o centro hospitalario de guardia más cercano).'
            : 'The platform is NOT designed or certified for life-threatening emergency medical situations. In any acute or life-threatening event, patients must immediately contact local public emergency services (e.g., 911, ambulance dispatch, or the nearest emergency room).',
      },
      {
        'icon': Icons.badge_rounded,
        'title': isEs ? '4. Idoneidad y Veracidad Profesional' : '4. Professional Eligibility and Licensure',
        'body': isEs
            ? 'Los profesionales que se registren como Médicos o Especialistas garantizan bajo fe de juramento que cuentan con título universitario habilitante, licencias de ejercicio profesional vigentes y autorización de las autoridades sanitarias competentes de su jurisdicción. Doctuario se reserva el derecho de auditar y suspender cuentas que no acrediten idoneidad.'
            : 'Users registering as Doctors or Healthcare Specialists warrant under oath that they possess valid professional licenses and regulatory clearance in their respective jurisdictions. Doctuario reserves the right to audit credentials and suspend any account that fails to provide verified credentials.',
      },
    ];
  }

  List<Map<String, dynamic>> _getDataProtectionContent(bool isEs) {
    return [
      {
        'crucial': true,
        'icon': Icons.verified_user_rounded,
        'title': isEs ? '1. Garantía Absoluta de No Compromiso de Datos' : '1. Absolute Non-Compromise Guarantee',
        'body': isEs
            ? 'COMPROMISO FUNDAMENTAL: Los datos personales, antecedentes de salud, diagnósticos e historias clínicas de los pacientes NUNCA serán comprometidos, compartidos, cedidos, comercializados ni transferidos a terceros. Doctuario NO monetiza datos de salud ni utiliza expedientes médicos para publicidad, perfilamiento comercial ni venta a farmacéuticas o aseguradoras.'
            : 'FUNDAMENTAL GUARANTEE: Patient personal data, health history, diagnoses, and medical charts will NEVER be compromised, shared, licensed, or sold to third parties. Doctuario does NOT monetize healthcare information and does not use clinical records for advertising or sale to pharmaceutical or insurance companies.',
      },
      {
        'icon': Icons.lock_clock_rounded,
        'title': isEs ? '2. Cifrado Criptográfico y Aislamiento Multitenant' : '2. Cryptographic Encryption & Tenant Isolation',
        'body': isEs
            ? 'Todos los datos clínicos se resguardan mediante protocolos de cifrado robusto en tránsito (TLS 1.3 / HTTPS) y en reposo (AES con HMAC-SHA256 y arquitectura multitenant aislada). Esto asegura que la base de datos de cada consultorio médico opera en un espacio privado hermético, impidiendo cualquier acceso cruzado o filtración no autorizada entre doctores o entidades externas.'
            : 'All clinical data is safeguarded through rigorous encryption in transit (TLS 1.3 / HTTPS) and at rest (AES with HMAC-SHA256 and multi-tenant isolation). Each medical office operates in an isolated private partition, preventing unauthorized cross-access or data exposure between clinics or external parties.',
      },
      {
        'icon': Icons.health_and_safety_rounded,
        'title': isEs ? '3. Cumplimiento de Confidencialidad y Secreto Médico' : '3. Medical Secrecy & Compliance Standards',
        'body': isEs
            ? 'Doctuario acata rigurosamente los preceptos del secreto médico y las leyes rectoras sobre protección de datos personales de salud (incluyendo principios GDPR y HIPAA en materia de seguridad tecnológica). Solo el personal técnico estrictamente autorizado puede ejecutar labores de soporte técnico de emergencia bajo acuerdos de confidencialidad reforzados.'
            : 'Doctuario adheres strictly to medical confidentiality tenets and healthcare data protection regulations (including technical HIPAA and GDPR security baselines). Only authorized infrastructure operators may carry out necessary maintenance under strict confidentiality protocols.',
      },
    ];
  }

  List<Map<String, dynamic>> _getDoctorCustodyContent(bool isEs) {
    return [
      {
        'crucial': true,
        'icon': Icons.folder_shared_rounded,
        'title': isEs ? '1. Soberanía y Custodia Legal de la Historia Clínica' : '1. Sovereignty and Legal Custody of Charts',
        'body': isEs
            ? 'Conforme a la legislación médica internacional y local, el profesional de la salud es el custodio legal y depositario ético de las historias clínicas de sus pacientes. Doctuario actúa en calidad exclusiva de "Encargado del Tratamiento Tecnológico" (Data Processor) y en ningún momento asume titularidad ni secuestro sobre los expedientes clínicos registrados.'
            : 'Pursuant to international healthcare regulations, the medical doctor serves as the legal and ethical custodian of their patient charts. Doctuario acts strictly as a "Data Processor" and at no time claims ownership over or withholds clinical records recorded on the platform.',
      },
      {
        'icon': Icons.all_inclusive_rounded,
        'title': isEs ? '2. Derecho Ininterrumpido de Consulta y Exportación' : '2. Uninterrupted Right to Access & Export',
        'body': isEs
            ? 'El doctor siempre tendrá garantizado el acceso pleno a los datos de sus pacientes para consulta, revisión y descarga/exportación. Bajo ninguna circunstancia Doctuario destruirá, bloqueará ni eliminará los datos históricos de los pacientes, asegurando la continuidad asistencial y el cumplimiento del deber deontológico del médico de conservar el historial de sus pacientes.'
            : 'Physicians are permanently guaranteed full access to their patient records for consultation, review, and export. Under no circumstances will Doctuario delete, withhold, or destroy historical patient files, safeguarding continuity of care and the doctor\'s statutory duty of record preservation.',
      },
    ];
  }

  List<Map<String, dynamic>> _getSubscriptionContent(bool isEs) {
    return [
      {
        'crucial': true,
        'icon': Icons.lock_open_rounded,
        'title': isEs ? '1. Régimen de Impago: Activación del Modo Solo Lectura' : '1. Unpaid Balance: Read-Only Mode Activation',
        'body': isEs
            ? 'En caso de mora, falta de pago oportuno o vencimiento del plan de suscripción del consultorio médico:\n\n'
            '• PRESERVACIÓN TOTAL: Los datos de los pacientes NO se borran ni se pierden.\n'
            '• ACCESO CONTINUO: El doctor CONSERVA ACCESO a todos sus pacientes e historias clínicas ya registradas para consultarlas y respaldarlas.\n'
            '• RESTRICCIÓN OPERATIVA: Mientras persista el impago, el sistema entrará en MODO SOLO LECTURA, quedando inhabilitada la creación de nuevos pacientes, nuevas consultas, recetas o modificaciones en la base de datos hasta que se regularice la suscripción.'
            : 'In the event of an unpaid invoice, payment lapse, or subscription expiration for a medical practice:\n\n'
            '• COMPLETE PRESERVATION: Patient files are NEVER deleted or purged.\n'
            '• CONTINUOUS ACCESS: The doctor RETAINS ACCESS to all historical patient files for review and backup.\n'
            '• WRITE SUSPENSION: During the unpaid period, the practice switches to READ-ONLY MODE, restricting the registration of new patients, new appointments, or new clinical updates until payment is settled.',
      },
      {
        'icon': Icons.restore_page_rounded,
        'title': isEs ? '2. Reactivación Inmediata de Escritura' : '2. Immediate Restoration of Write Privileges',
        'body': isEs
            ? 'Una vez acreditado el pago adeudado o renovado el plan, las capacidades de registro, agendamiento y edición se restablecen de forma automática e inmediata sin pérdida alguna de información ni alteración de registros existentes.'
            : 'Upon confirmation of the outstanding balance or plan renewal, full write, scheduling, and charting features are restored automatically and instantly without any data loss or schema alterations.',
      },
    ];
  }

  List<Map<String, dynamic>> _getLegalShieldContent(bool isEs) {
    return [
      {
        'crucial': true,
        'icon': Icons.security_rounded,
        'title': isEs ? '1. Exención de Responsabilidad Médica y Mala Praxis' : '1. Medical Liability & Malpractice Disclaimer',
        'body': isEs
            ? 'El propietario, desarrolladores, administradores y afiliados de Doctuario quedan expresamente exonerados de cualquier responsabilidad civil, penal, administrativa o ética derivada de diagnósticos erróneos, tratamientos inadecuados, prescripción de fármacos o demoras atribuibles a los profesionales médicos o a los pacientes. La responsabilidad del acto médico recae única y exclusivamente sobre el profesional tratante.'
            : 'The owner, developers, operators, and affiliates of Doctuario are expressly released from any civil, criminal, administrative, or disciplinary liability arising from misdiagnoses, clinical errors, prescriptions, or delays attributable to healthcare professionals or patients. Clinical accountability lies exclusively with the attending physician.',
      },
      {
        'icon': Icons.cloud_off_rounded,
        'title': isEs ? '2. Limitación de Responsabilidad por Fallas de Terceros' : '2. Third-Party Infrastructure & Force Majeure',
        'body': isEs
            ? 'Doctuario opera sobre infraestructuras cloud líderes (Supabase, PostgreSQL, Google Cloud) con altos estándares de disponibilidad. Sin embargo, no se asume responsabilidad por interrupciones de conectividad, caídas del servicio de telecomunicaciones, ataques masivos de denegación de servicio (DDoS) ni eventos de fuerza mayor ajenos al control razonable de la plataforma.'
            : 'Doctuario operates on premier cloud infrastructures (Supabase, PostgreSQL, Google Cloud) designed for high reliability. However, no liability is assumed for network dropouts, telecom provider outages, severe DDoS incidents, or force majeure events beyond reasonable platform control.',
      },
      {
        'icon': Icons.policy_rounded,
        'title': isEs ? '3. Cláusula de Indemnidad' : '3. Indemnification Clause',
        'body': isEs
            ? 'El usuario (médico o paciente) se compromete a mantener indemne a Doctuario frente a cualquier reclamo, demanda, daño, perjuicio o gasto legal que se origine por el uso indebido de la plataforma, el incumplimiento de estos términos o la transgresión de normas sanitarias y deontológicas aplicables.'
            : 'Users (physicians or patients) agree to defend, indemnify, and hold harmless Doctuario from any claims, damages, liabilities, or legal expenses arising from misuse of the platform, breach of these terms, or violation of applicable medical practice standards.',
      },
      {
        'icon': Icons.copyright_rounded,
        'title': isEs ? '4. Propiedad Intelectual del Software' : '4. Software Intellectual Property',
        'body': isEs
            ? 'La plataforma Doctuario, su código fuente, arquitectura multitenant, marcas, logotipos y diseños son propiedad intelectual exclusiva de Doctuario Inc. Queda prohibida la reproducción, descompilación o ingeniería inversa no autorizada.'
            : 'Doctuario software, multi-tenant architecture, algorithms, source code, and trademarks are the exclusive intellectual property of Doctuario Inc. Unauthorized decompilation or reverse engineering is strictly prohibited.',
      },
    ];
  }
}

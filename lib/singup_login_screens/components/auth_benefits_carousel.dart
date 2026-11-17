import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../services/i18n_service.dart';

/// Modelo de datos para las diapositivas del carrusel de bienvenida
class _CarouselSlide {
  final String imagePath;
  final String titleEs;
  final String titleEn;
  final String subtitleEs;
  final String subtitleEn;

  const _CarouselSlide({
    required this.imagePath,
    required this.titleEs,
    required this.titleEn,
    required this.subtitleEs,
    required this.subtitleEn,
  });
}

/// Elemento individual de beneficio para el tipo de usuario
class _BenefitItem {
  final IconData icon;
  final Color iconColor;
  final String titleEs;
  final String titleEn;
  final String descriptionEs;
  final String descriptionEn;

  const _BenefitItem({
    required this.icon,
    required this.iconColor,
    required this.titleEs,
    required this.titleEn,
    required this.descriptionEs,
    required this.descriptionEn,
  });
}

/// Componente de carrusel rotativo con imágenes y lista de beneficios dinámicos
/// diseñado para acompañar el formulario de creación de cuentas en pantallas grandes.
class AuthBenefitsCarousel extends StatefulWidget {
  /// Rol seleccionado ('Doctor', 'Paciente', 'Secretaria')
  final String role;

  const AuthBenefitsCarousel({
    super.key,
    required this.role,
  });

  @override
  State<AuthBenefitsCarousel> createState() => _AuthBenefitsCarouselState();
}

class _AuthBenefitsCarouselState extends State<AuthBenefitsCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  static const List<_CarouselSlide> _slides = [
    _CarouselSlide(
      imagePath: 'assets/images/auth_doctor_clinic.jpg',
      titleEs: 'Gestión Médica de Vanguardia',
      titleEn: 'Next-Generation Clinical Management',
      subtitleEs: 'Transforma la atención a tus pacientes con herramientas digitales intuitivas.',
      subtitleEn: 'Transform patient care with intuitive digital health tools.',
    ),
    _CarouselSlide(
      imagePath: 'assets/images/auth_doctor_patient.jpg',
      titleEs: 'Atención Confiable y Cercana',
      titleEn: 'Empowering Patient Consultations',
      subtitleEs: 'Conexión humana respaldada por expedientes clínicos seguros.',
      subtitleEn: 'Empathetic care backed by private and safe health records.',
    ),
    _CarouselSlide(
      imagePath: 'assets/images/online-conference-patient-doctor-generative-ai.jpg',
      titleEs: 'Salud Conectada en Tiempo Real',
      titleEn: 'Real-Time Connected Healthcare',
      subtitleEs: 'Agenda, recordatorios y resultados médicos al alcance de tu mano.',
      subtitleEn: 'Appointments, reminders, and medical tests at your fingertips.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _iniciarAutoPlay();
  }

  void _iniciarAutoPlay() {
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _slides.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<_BenefitItem> _obtenerBeneficiosParaRol(bool isDoc, bool isSec) {
    if (isDoc) {
      return const [
        _BenefitItem(
          icon: Icons.calendar_month_rounded,
          iconColor: Color(0xFF0284C7),
          titleEs: 'Agenda Flexible e Inteligente',
          titleEn: 'Smart & Flexible Agenda',
          descriptionEs: 'Atiende por orden de llegada con cupos diarios o asigna turnos por horario.',
          descriptionEn: 'Support first-come arrival with quotas or set fixed scheduled slots.',
        ),
        _BenefitItem(
          icon: Icons.shield_rounded,
          iconColor: Color(0xFF14B8A6),
          titleEs: 'Expediente Clínico Privado',
          titleEn: 'Private Clinical Records',
          descriptionEs: 'Historiales y estudios respaldados en tu consultorio privado con máxima seguridad.',
          descriptionEn: 'Medical records stored strictly inside your private tenant database.',
        ),
        _BenefitItem(
          icon: Icons.auto_awesome_rounded,
          iconColor: Color(0xFF8B5CF6),
          titleEs: 'Asistente de IA Gemini',
          titleEn: 'Gemini Clinical AI Assistant',
          descriptionEs: 'Generación asistida de resúmenes diagnósticos y planes de tratamiento.',
          descriptionEn: 'AI-assisted summaries, clinical notes, and treatment guidance.',
        ),
        _BenefitItem(
          icon: Icons.location_city_rounded,
          iconColor: Color(0xFFD97706),
          titleEs: 'Múltiples Sedes y Secretarias',
          titleEn: 'Multi-Clinic & Staff Sync',
          descriptionEs: 'Coordina diferentes consultorios y otorga permisos ágiles a tu personal.',
          descriptionEn: 'Organize various clinics and sync with reception staff effortlessly.',
        ),
      ];
    } else if (isSec) {
      return const [
        _BenefitItem(
          icon: Icons.desk_rounded,
          iconColor: Color(0xFF0284C7),
          titleEs: 'Recepción Ágil en Sala',
          titleEn: 'Fast Reception Desk',
          descriptionEs: 'Control de llegada de pacientes, orden de turnos y validación de citas.',
          descriptionEn: 'Real-time patient check-in, queue management, and appointment confirmation.',
        ),
        _BenefitItem(
          icon: Icons.sync_alt_rounded,
          iconColor: Color(0xFF14B8A6),
          titleEs: 'Sincronización Directa con Médicos',
          titleEn: 'Direct Doctor Coordination',
          descriptionEs: 'Vincúlate a uno o varios consultorios sin complicaciones de agenda.',
          descriptionEn: 'Seamlessly link to one or multiple doctor practices.',
        ),
        _BenefitItem(
          icon: Icons.notifications_active_rounded,
          iconColor: Color(0xFF8B5CF6),
          titleEs: 'Gestión Eficiente de Notificaciones',
          titleEn: 'Notification Center',
          descriptionEs: 'Avisos inmediatos sobre citas confirmadas o reprogramaciones.',
          descriptionEn: 'Instant updates regarding rescheduled or confirmed visits.',
        ),
      ];
    } else {
      return const [
        _BenefitItem(
          icon: Icons.near_me_rounded,
          iconColor: Color(0xFF0284C7),
          titleEs: 'Especialistas Cerca de Ti',
          titleEn: 'Specialists Close to You',
          descriptionEs: 'Filtra por tu ciudad o estado y encuentra al médico ideal para tu salud.',
          descriptionEn: 'Find certified doctors filtered by proximity and medical specialty.',
        ),
        _BenefitItem(
          icon: Icons.bolt_rounded,
          iconColor: Color(0xFF14B8A6),
          titleEs: 'Citas Rápidas y Transparentes',
          titleEn: 'Fast & Transparent Booking',
          descriptionEs: 'Reserva en segundos conociendo cupos restantes y horarios en tiempo real.',
          descriptionEn: 'Book appointments instantly with live quota visibility.',
        ),
        _BenefitItem(
          icon: Icons.receipt_long_rounded,
          iconColor: Color(0xFF8B5CF6),
          titleEs: 'Estudios y Resultados Digitales',
          titleEn: 'Centralized Lab Results',
          descriptionEs: 'Visualiza informes médicos, recetas y órdenes desde tu teléfono o PC.',
          descriptionEn: 'Access medical reports and lab results from any device anytime.',
        ),
        _BenefitItem(
          icon: Icons.lock_outline_rounded,
          iconColor: Color(0xFFD97706),
          titleEs: 'Privacidad Médica Absoluta',
          titleEn: 'Confidential & Safe',
          descriptionEs: 'Tus datos clínicos permanecen protegidos bajo confidencialidad médica.',
          descriptionEn: 'Your medical identity and history are protected with top security.',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;
    final isDoc = widget.role == 'Doctor';
    final isSec = widget.role == 'Secretaria';
    final beneficios = _obtenerBeneficiosParaRol(isDoc, isSec);

    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Carrusel de imágenes rotativas con indicador de páginas
          SizedBox(
            height: 250.0,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (ctx, index) {
                    final slide = _slides[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          slide.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.medical_services_rounded, size: 48, color: Color(0xFF0284C7)),
                          ),
                        ),
                        // Degradado inferior para legibilidad del texto
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.25),
                                Colors.black.withValues(alpha: 0.82),
                              ],
                              stops: const [0.4, 0.7, 1.0],
                            ),
                          ),
                        ),
                        // Textos descriptivos sobre la imagen
                        Positioned(
                          left: 18.0,
                          right: 18.0,
                          bottom: 22.0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                i18n.isSpanish ? slide.titleEs : slide.titleEn,
                                style: GoogleFonts.mooli(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3.0),
                              Text(
                                i18n.isSpanish ? slide.subtitleEs : slide.subtitleEn,
                                style: GoogleFonts.mooli(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12.0,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                // Indicador de puntos interactivo
                Positioned(
                  right: 18.0,
                  top: 14.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_slides.length, (idx) {
                        final isSel = idx == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: isSel ? 16.0 : 6.0,
                          height: 6.0,
                          decoration: BoxDecoration(
                            color: isSel ? Colors.white : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(3.0),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sección de beneficios específicos según el tipo de cuenta
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isDoc ? Icons.medical_services_rounded : (isSec ? Icons.support_agent_rounded : Icons.star_rounded),
                      size: 20.0,
                      color: isDoc ? const Color(0xFF0284C7) : const Color(0xFF14B8A6),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      i18n.isSpanish
                          ? 'Beneficios de usar Doctuario'
                          : 'Benefits of using Doctuario',
                      style: GoogleFonts.mooli(
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                        color: FlutterFlowTheme.of(context).primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14.0),
                // Lista de ventajas destacadas
                ...beneficios.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32.0,
                            height: 32.0,
                            decoration: BoxDecoration(
                              color: b.iconColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Icon(b.icon, size: 18.0, color: b.iconColor),
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i18n.isSpanish ? b.titleEs : b.titleEn,
                                  style: GoogleFonts.mooli(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: FlutterFlowTheme.of(context).primaryText,
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  i18n.isSpanish ? b.descriptionEs : b.descriptionEn,
                                  style: GoogleFonts.mooli(
                                    fontSize: 11.5,
                                    color: FlutterFlowTheme.of(context).secondaryText,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

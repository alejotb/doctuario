import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de Internacionalización para gestionar idioma en MediConnect
class I18nService extends ChangeNotifier {
  static final I18nService _instance = I18nService._internal();
  static I18nService get instance => _instance;

  I18nService._internal();

  static const String _prefKey = 'app_language_code';

  String _currentLanguage = 'es'; // Español por defecto
  String get currentLanguage => _currentLanguage;
  Locale get currentLocale => Locale(_currentLanguage, '');

  bool get isSpanish => _currentLanguage == 'es';

  /// Inicializa el idioma cargando preferencia guardada o detectando locale del dispositivo
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(_prefKey);

      if (savedLang != null && (savedLang == 'es' || savedLang == 'en')) {
        _currentLanguage = savedLang;
      } else {
        // Detectar locale del dispositivo
        final deviceLocale = ui.PlatformDispatcher.instance.locale;
        if (deviceLocale.languageCode == 'en') {
          _currentLanguage = 'en';
        } else {
          // Si es español o cualquier otro idioma latinoamericano/europeo, español por defecto
          _currentLanguage = 'es';
        }
      }
    } catch (_) {
      _currentLanguage = 'es';
    }
    notifyListeners();
  }

  /// Cambia el idioma manualmente y lo persiste
  Future<void> setLanguage(String langCode) async {
    if (langCode != 'es' && langCode != 'en') return;
    if (_currentLanguage == langCode) return;

    _currentLanguage = langCode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, langCode);
    } catch (_) {}
  }

  /// Diccionario de traducciones
  static final Map<String, Map<String, String>> _translations = {
    // General
    'app_name': {
      'es': 'Doctuario',
      'en': 'Doctuario',
    },
    'tagline': {
      'es': 'Tu salud en buenas manos',
      'en': 'Your health in good hands',
    },
    'cancel': {
      'es': 'Cancelar',
      'en': 'Cancel',
    },
    'save': {
      'es': 'Guardar',
      'en': 'Save',
    },
    'accept': {
      'es': 'Aceptar',
      'en': 'Accept',
    },
    'search': {
      'es': 'Buscar',
      'en': 'Search',
    },

    // Login & Registro
    'welcome_back': {
      'es': 'Bienvenido de nuevo',
      'en': 'Welcome Back',
    },
    'login_subtitle': {
      'es': 'Ingresa tus credenciales para acceder al sistema',
      'en': 'Enter your credentials to access the system',
    },
    'email_label': {
      'es': 'Correo electrónico',
      'en': 'Email address',
    },
    'password_label': {
      'es': 'Contraseña',
      'en': 'Password',
    },
    'forgot_password': {
      'es': '¿Olvidaste tu contraseña?',
      'en': 'Forgot Password?',
    },
    'login_button': {
      'es': 'Iniciar Sesión',
      'en': 'Log In',
    },
    'no_account': {
      'es': '¿No tienes una cuenta? ',
      'en': "Don't have an account? ",
    },
    'register_link': {
      'es': 'Regístrate aquí',
      'en': 'Register here',
    },
    'or_continue_with': {
      'es': 'O continúa con',
      'en': 'Or continue with',
    },
    'continue_google': {
      'es': 'Continuar con Google',
      'en': 'Continue with Google',
    },
    'continue_apple': {
      'es': 'Continuar con Apple',
      'en': 'Continue with Apple',
    },
    'create_account_title': {
      'es': 'Crear Cuenta',
      'en': 'Create Account',
    },
    'create_account_subtitle': {
      'es': 'Únete para gestionar tus consultas y citas médicas',
      'en': 'Join to manage your medical consultations and appointments',
    },
    'confirm_password_label': {
      'es': 'Confirmar Contraseña',
      'en': 'Confirm Password',
    },

    // Onboarding / Welcome
    'welcome_title': {
      'es': 'Bienvenido a Doctuario',
      'en': 'Welcome to Doctuario',
    },
    'welcome_desc': {
      'es': 'Tu sistema integral para gestión de citas médicas presenciales, historial clínico seguro y seguimiento de pacientes.',
      'en': 'Your comprehensive platform for in-person doctor appointments, secure medical records, and patient care.',
    },
    'get_started': {
      'es': 'Comenzar',
      'en': 'Get Started',
    },
    'already_have_account': {
      'es': '¿Ya tienes cuenta? ',
      'en': 'Already have an account? ',
    },

    // Menú y Navegación
    'nav_home': {
      'es': 'Inicio',
      'en': 'Home',
    },
    'nav_appointments': {
      'es': 'Mis Citas',
      'en': 'Appointments',
    },
    'nav_doctors': {
      'es': 'Médicos',
      'en': 'Doctors',
    },
    'nav_profile': {
      'es': 'Perfil',
      'en': 'Profile',
    },
    'nav_agenda': {
      'es': 'Mi Agenda',
      'en': 'My Agenda',
    },
    'nav_secretary': {
      'es': 'Secretaría',
      'en': 'Secretary',
    },
    'nav_calendar': {
      'es': 'Calendario',
      'en': 'Calendar',
    },

    // Home y Búsqueda
    'home_greeting': {
      'es': 'Hola, ¿cómo te sientes hoy?',
      'en': 'Hello, how are you feeling today?',
    },
    'search_doctor_placeholder': {
      'es': 'Buscar médicos por especialidad o cercanía...',
      'en': 'Search doctors by specialty or proximity...',
    },
    'categories_title': {
      'es': 'Especialidades Médicas',
      'en': 'Medical Specialties',
    },
    'top_doctors_title': {
      'es': 'Médicos Cercanos',
      'en': 'Nearby Doctors',
    },
    'see_all': {
      'es': 'Ver todos',
      'en': 'See all',
    },

    // Citas y Consultas
    'book_appointment': {
      'es': 'Reservar Cita Presencial',
      'en': 'Book In-Person Appointment',
    },
    'appointment_type_general': {
      'es': 'Consulta Presencial General',
      'en': 'General In-Person Consultation',
    },
    'appointment_type_followup': {
      'es': 'Control y Seguimiento',
      'en': 'Follow-up Consultation',
    },
    'appointment_type_urgent': {
      'es': 'Atención Prioritaria / Triage',
      'en': 'Priority Care / Triage',
    },
    'select_date_time': {
      'es': 'Seleccionar Fecha y Hora',
      'en': 'Select Date & Time',
    },
    'doctor_availability': {
      'es': 'Disponibilidad del Médico',
      'en': 'Doctor Availability',
    },

    // Perfil y Configuración
    'my_account_title': {
      'es': 'Mi Cuenta',
      'en': 'My Account',
    },
    'edit_profile': {
      'es': 'Editar Perfil',
      'en': 'Edit Profile',
    },
    'medical_exams': {
      'es': 'Mis Exámenes Médicos',
      'en': 'My Medical Exams',
    },
    'language_setting': {
      'es': 'Idioma / Language',
      'en': 'Language / Idioma',
    },
    'help_support': {
      'es': 'Ayuda y Soporte',
      'en': 'Help & Support',
    },
    'logout': {
      'es': 'Cerrar Sesión',
      'en': 'Log Out',
    },
  };

  /// Obtiene el texto traducido para una clave dada
  String tr(String key, {String? defaultText}) {
    final entry = _translations[key];
    if (entry != null) {
      return entry[_currentLanguage] ?? entry['es'] ?? defaultText ?? key;
    }
    return defaultText ?? key;
  }

  /// Muestra un modal/diálogo rápido para cambiar el idioma
  static void showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: Row(
            children: [
              const Icon(Icons.language, color: Color(0xFF25A7A7)),
              const SizedBox(width: 8.0),
              Text(
                I18nService.instance.isSpanish ? 'Seleccionar Idioma' : 'Select Language',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Text('🇪🇸', style: TextStyle(fontSize: 24.0)),
                title: const Text('Español (Predeterminado)'),
                trailing: I18nService.instance.currentLanguage == 'es'
                    ? const Icon(Icons.check_circle, color: Color(0xFF25A7A7))
                    : null,
                onTap: () {
                  I18nService.instance.setLanguage('es');
                  Navigator.of(ctx).pop();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Text('🇺🇸', style: TextStyle(fontSize: 24.0)),
                title: const Text('English'),
                trailing: I18nService.instance.currentLanguage == 'en'
                    ? const Icon(Icons.check_circle, color: Color(0xFF25A7A7))
                    : null,
                onTap: () {
                  I18nService.instance.setLanguage('en');
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                I18nService.instance.isSpanish ? 'Cerrar' : 'Close',
                style: const TextStyle(color: Color(0xFF25A7A7)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Extensión de conveniencia en BuildContext
extension I18nContextExtension on BuildContext {
  String tr(String key, {String? defaultText}) =>
      I18nService.instance.tr(key, defaultText: defaultText);
}

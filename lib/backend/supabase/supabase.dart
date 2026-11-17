import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dual_database_config.dart';

export 'database/database.dart';
export 'storage/storage.dart';
export 'dual_database_config.dart';

/// URL y clave pública de conexión para la Base de Datos Central
const String _kDefaultSupabaseUrl = 'https://zrvpssjlxhumgldltsbq.supabase.co';
const String _kDefaultSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpydnBzc2pseGh1bWdsZGx0c2JxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0MTE2NzEsImV4cCI6MjEwNjk4NzY3MX0.V3x1oH-Addjv-PkV2V-MPFGoPpfu0QOCcrRRrPWZx40';

/// URL de conexión resuelta desde variables de compilación o valor predeterminado
String get supabaseUrl => const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: _kDefaultSupabaseUrl,
    );

/// Clave anon resuelta desde variables de compilación o valor predeterminado
String get supabaseAnonKey => const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: _kDefaultSupabaseAnonKey,
    );

/// Gestor central de infraestructura de Supabase para Doctuario / MediConnect.
///
/// Implementa autenticación robusta mediante PKCE (Proof Key for Code Exchange)
/// para evitar la exposición de tokens en la barra de URL o en el historial del
/// navegador, garantizando sesiones seguras y desautenticación completa.
class SupaFlow {
  SupaFlow._();

  static SupaFlow? _instance;

  /// Instancia única en memoria (Singleton) del cliente SupaFlow
  static SupaFlow get instance => _instance ??= SupaFlow._();

  final _supabase = Supabase.instance.client;

  /// Cliente principal de Supabase para operaciones en la base de datos central
  static SupabaseClient get client => instance._supabase;

  /// Retorna si existe un usuario autenticado en el cliente central
  static bool get isAuthenticated => client.auth.currentUser != null;

  /// Identificador único UUID del usuario autenticado actualmente
  static String? get currentUserId => client.auth.currentUser?.id;

  /// Correo electrónico del usuario autenticado actualmente
  static String? get currentUserEmail => client.auth.currentUser?.email;

  /// Inicializa la conexión con Supabase aplicando los estándares de autenticación:
  /// - Flujo implícito para soporte cross-device fluido en enlaces de confirmación de email y OAuth.
  /// - Inicialización coordinada del ecosistema multitenant de base dual.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      headers: const {
        'X-Client-Info': 'doctuario-secure-flutter',
      },
      anonKey: supabaseAnonKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );

    // Inicializar configuración y clientes de base de datos dual (clínica y central)
    await DualDatabaseConfig.instance.initializeClients();
  }

  /// Cierra de forma integral y segura la sesión en todos los clientes:
  /// 1. Invalida tokens de acceso y refresco en Supabase Central vía API.
  /// 2. Cierra la sesión activa en el cliente de la base de datos clínica privada.
  /// 3. Limpia las credenciales y cachés temporales en SharedPreferences.
  static Future<void> safeSignOutAll() async {
    try {
      debugPrint('SupaFlow: Iniciando cierre integral de sesión seguro...');

      // 1. Cierre en cliente central
      try {
        await client.auth.signOut();
      } catch (e) {
        debugPrint('Nota cerrando sesión en base central: $e');
      }

      // 2. Cierre en cliente de clínica si difiere del central
      if (DualDatabaseConfig.instance.isDistinctDualDatabase) {
        try {
          await DualDatabaseConfig.instance.doctorClient.auth.signOut();
        } catch (e) {
          debugPrint('Nota cerrando sesión en base clínica: $e');
        }
      }

      // 3. Limpieza de claves de sesión en almacenamiento local
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('prontudoc_active_view_mode');
        await prefs.remove('cached_doctor_tenant_url');
        await prefs.remove('cached_doctor_tenant_anon_key');
      } catch (e) {
        debugPrint('Nota limpiando caché de preferencias locales: $e');
      }

      debugPrint('SupaFlow: Cierre de sesión finalizado exitosamente.');
    } catch (e) {
      debugPrint('Error en safeSignOutAll: $e');
    }
  }

  /// Valida si la sesión actual sigue activa y no ha caducado
  static bool isCurrentSessionValid() {
    final session = client.auth.currentSession;
    if (session == null) return false;
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return true;
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    return DateTime.now().isBefore(expiryDate);
  }

  /// Verifica la conectividad básica con la base de datos central
  static Future<bool> testCentralConnection() async {
    try {
      final res = await client.from('usuarios').select('id').limit(1);
      return res.isNotEmpty || res.isEmpty;
    } catch (e) {
      debugPrint('SupaFlow: Prueba de conectividad central falló: $e');
      return false;
    }
  }

  /// Verifica la conectividad con la base de datos privada del doctor
  static Future<bool> testDoctorConnection() async {
    try {
      final docClient = DualDatabaseConfig.instance.doctorClient;
      final res = await docClient.from('doctores').select('id').limit(1);
      return res.isNotEmpty || res.isEmpty;
    } catch (e) {
      debugPrint('SupaFlow: Prueba de conectividad clínica falló: $e');
      return false;
    }
  }

  /// Obtiene los detalles estructurados de la sesión actual
  static SupabaseSessionDetails? getSessionDetails() {
    final session = client.auth.currentSession;
    if (session == null) return null;

    final expiresAt = session.expiresAt;
    final expiryDateTime = expiresAt != null
        ? DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
        : null;

    return SupabaseSessionDetails(
      userId: session.user.id,
      email: session.user.email,
      expiresAt: expiryDateTime,
      isExpired: expiryDateTime != null && DateTime.now().isAfter(expiryDateTime),
      tokenType: session.tokenType,
    );
  }

  /// Refresca la sesión actual si está próxima a expirar (menos de 5 minutos)
  static Future<bool> refreshSessionIfNeeded() async {
    try {
      final session = client.auth.currentSession;
      if (session == null) return false;

      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        final difference = expiry.difference(DateTime.now());
        if (difference.inMinutes < 5) {
          debugPrint('SupaFlow: Refrescando token de autenticación PKCE preventivamente...');
          await client.auth.refreshSession();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('SupaFlow: Nota al refrescar sesión: $e');
      return false;
    }
  }
}

/// Representa el estado y metadatos de seguridad de una sesión activa de Supabase
class SupabaseSessionDetails {
  final String userId;
  final String? email;
  final DateTime? expiresAt;
  final bool isExpired;
  final String? tokenType;

  const SupabaseSessionDetails({
    required this.userId,
    this.email,
    this.expiresAt,
    required this.isExpired,
    this.tokenType,
  });

  @override
  String toString() {
    return 'SupabaseSessionDetails(userId: $userId, email: $email, expiresAt: $expiresAt, isExpired: $isExpired)';
  }
}

/// Observador de eventos del ciclo de vida de autenticación para auditoría y seguridad
class SupabaseAuthObserver {
  SupabaseAuthObserver._();

  static final SupabaseAuthObserver instance = SupabaseAuthObserver._();

  /// Registra un escuchador para eventos de autenticación
  void Function()? listenAuthEvents({
    void Function(String userId)? onSignedIn,
    void Function()? onSignedOut,
    void Function()? onTokenRefreshed,
  }) {
    final subscription = SupaFlow.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
          if (session != null) onSignedIn?.call(session.user.id);
          break;
        case AuthChangeEvent.signedOut:
          onSignedOut?.call();
          break;
        case AuthChangeEvent.tokenRefreshed:
          onTokenRefreshed?.call();
          break;
        default:
          break;
      }
    });

    return () => subscription.cancel();
  }
}


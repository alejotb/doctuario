import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'i18n_service.dart';

/// Servicio especializado para autenticación con Google OAuth en Supabase.
///
/// Gestiona tanto el inicio de sesión como la creación de cuentas con Google,
/// asegurando:
/// 1. Detección automática y sincronización en la tabla `usuarios`.
/// 2. Aprovisionamiento automático de la base de datos si el usuario es Doctor.
/// 3. Enrutamiento inteligente según el rol del usuario (Doctor vs Paciente).
/// 4. Compatibilidad multiplataforma (Web, Android e iOS con deep linking).
class GoogleAuthService {
  GoogleAuthService._();

  static GoogleAuthService? _instance;
  static GoogleAuthService get instance => _instance ??= GoogleAuthService._();

  /// URL de retorno configurada para deep linking en móviles y web de Doctuario
  static const String _kRedirectUrl = 'doctuario://login-callback';
  static const String _kPendingRoleKey = 'doctuario_pending_oauth_role';

  String? _inMemoryPendingRole;

  /// Normaliza y valida estrictamente el rol para el registro público.
  /// Por seguridad, NUNCA permite auto-asignarse 'administrador' ni 'secretaria'.
  String _normalizarRol(String? rawRole) {
    final cleaned = (rawRole ?? '').trim().toLowerCase();
    if (cleaned == 'doctor' || cleaned == 'medico' || cleaned == 'médico') {
      return 'doctor';
    }
    return 'paciente';
  }

  /// Guarda el rol elegido en sesión local segura antes de redirigir al navegador de Google OAuth
  Future<void> _savePendingRole(String? role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (role != null && role.trim().isNotEmpty) {
        final norm = _normalizarRol(role);
        _inMemoryPendingRole = norm;
        await prefs.setString(_kPendingRoleKey, norm);
      } else {
        _inMemoryPendingRole = null;
        await prefs.remove(_kPendingRoleKey);
      }
    } catch (_) {}
  }

  /// Recupera el rol pendiente de forma segura desde parámetros de URL, memoria o SharedPreferences local.
  Future<String?> _resolvePendingRole(String? explicitRole) async {
    if (explicitRole != null && explicitRole.trim().isNotEmpty) {
      return _normalizarRol(explicitRole);
    }
    if (kIsWeb && Uri.base.queryParameters.containsKey('oauth_role')) {
      final urlRole = Uri.base.queryParameters['oauth_role'];
      if (urlRole != null && urlRole.isNotEmpty) {
        return _normalizarRol(urlRole);
      }
    }
    if (_inMemoryPendingRole != null && _inMemoryPendingRole!.isNotEmpty) {
      return _normalizarRol(_inMemoryPendingRole);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kPendingRoleKey);
      if (saved != null && saved.trim().isNotEmpty) {
        return _normalizarRol(saved);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _clearPendingRole() async {
    _inMemoryPendingRole = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPendingRoleKey);
    } catch (_) {}
  }

  /// Inicia el flujo de autenticación con Google OAuth vía Supabase
  Future<bool> initiateGoogleOAuth({
    required BuildContext context,
    String? defaultRole,
  }) async {
    try {
      debugPrint('GoogleAuthService: Iniciando OAuth con Google (rol solicitado: $defaultRole)...');
      await _savePendingRole(defaultRole);

      StreamSubscription<AuthState>? authSubscription;
      Completer<bool>? authCompleter;

      if (!kIsWeb) {
        authCompleter = Completer<bool>();
        authSubscription = SupaFlow.client.auth.onAuthStateChange.listen((data) {
          final event = data.event;
          debugPrint('GoogleAuthService: onAuthStateChange evento: $event');
          if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.userUpdated) {
            if (authCompleter != null && !authCompleter.isCompleted) {
              authCompleter.complete(true);
            }
          }
        });
      }

      final normRole = (defaultRole != null && defaultRole.trim().isNotEmpty) ? _normalizarRol(defaultRole) : null;
      final roleQuery = (normRole != null && normRole == 'doctor') ? '?oauth_role=doctor' : '';

      final String webRedirect = (kIsWeb && Uri.base.origin.isNotEmpty && !Uri.base.origin.contains('localhost'))
          ? '${Uri.base.origin}/$roleQuery'
          : 'https://doctuario.com/$roleQuery';
      final String mobileRedirect = (normRole != null && normRole == 'doctor')
          ? '$_kRedirectUrl?oauth_role=doctor'
          : _kRedirectUrl;

      final launched = await SupaFlow.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? webRedirect : mobileRedirect,
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
      );

      if (!launched) {
        debugPrint('GoogleAuthService: No se pudo abrir la ventana de OAuth.');
        await authSubscription?.cancel();
        return false;
      }

      if (!kIsWeb && authCompleter != null) {
        debugPrint('GoogleAuthService: Esperando retorno de OAuth desde navegador...');
        final authSuccess = await authCompleter.future.timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            debugPrint('GoogleAuthService: Tiempo agotado esperando callback de OAuth.');
            return false;
          },
        );
        await authSubscription?.cancel();

        if (authSuccess) {
          final navCtx = context.mounted ? context : appNavigatorKey.currentContext;
          if (navCtx != null && navCtx.mounted) {
            debugPrint('GoogleAuthService: Callback recibido con éxito. Sincronizando usuario...');
            await handlePostGoogleAuthSync(context: navCtx, fallbackRole: defaultRole);
            return true;
          }
        }
        return authSuccess;
      }

      if (kIsWeb && context.mounted) {
        await handlePostGoogleAuthSync(context: context, fallbackRole: defaultRole);
      }
      return true;
    } catch (e) {
      debugPrint('GoogleAuthService: Error durante signInWithOAuth: $e');
      if (context.mounted) {
        final isEs = I18nService.instance.isSpanish;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEs ? 'Error conectando con Google: $e' : 'Google sign-in error: $e',
              style: GoogleFonts.mooli(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }
  }

  /// Sincroniza al usuario autenticado con Google en la base de datos y navega
  /// a su pantalla principal correspondiente (Doctor vs Paciente).
  Future<void> handlePostGoogleAuthSync({
    required BuildContext context,
    String? fallbackRole,
  }) async {
    try {
      var user = SupaFlow.client.auth.currentUser;
      if (user == null) {
        await Future.delayed(const Duration(milliseconds: 1000));
        user = SupaFlow.client.auth.currentUser;
      }
      if (user == null) {
        debugPrint('GoogleAuthService: No hay usuario autenticado activo.');
        return;
      }

      final uid = user.id;
      final email = user.email ?? '';
      final metadata = user.userMetadata ?? {};
      final fullName = metadata['full_name'] as String? ?? metadata['name'] as String? ?? '';
      final photoUrl = metadata['avatar_url'] as String? ?? metadata['picture'] as String? ?? '';
      final pendingRole = await _resolvePendingRole(fallbackRole);
      final nowIso = DateTime.now().toUtc().toIso8601String();

      String userRole = pendingRole ?? await DualDatabaseConfig.instance.resolveUserRole(user);
      List<UsuariosRow> existingUser = [];
      try {
        existingUser = await UsuariosTable().querySingleRow(queryFn: (q) => q.eq('id', uid));
      } catch (_) {}

      if (existingUser.isEmpty) {
        try {
          await UsuariosTable().upsert({
            'id': uid, 'email': email,
            'nombre': fullName.isNotEmpty ? fullName : null,
            'foto_url': photoUrl.isNotEmpty ? photoUrl : null,
            'rol': userRole, 'created_at': nowIso,
          });
        } catch (_) {}
      } else {
        final dbRole = (existingUser.first.rol ?? '').trim().toLowerCase();
        final currentDbRole = (dbRole == 'admin' || dbRole == 'administrador')
            ? 'administrador'
            : (dbRole == 'secretaria' ? 'secretaria' : (dbRole == 'doctor' ? 'doctor' : 'paciente'));
        if (pendingRole == 'doctor' || fallbackRole == 'doctor') {
          userRole = 'doctor';
          try {
            await SupaFlow.client.from('usuarios').update({'rol': 'doctor'}).eq('id', uid);
          } catch (_) {}
          try {
            await SupaFlow.client.auth.updateUser(UserAttributes(data: {'rol': 'doctor'}));
          } catch (_) {}
        } else {
          userRole = currentDbRole;
        }
      }

      await _clearPendingRole();

      if (userRole == 'doctor') {
        await DualDatabaseConfig.instance.persistActiveViewMode('doctor');
        try {
          await SupaFlow.client.auth.updateUser(UserAttributes(data: {'rol': 'doctor'}));
        } catch (_) {}
        try {
          final existingDoc = await DoctoresTable().querySingleRow(queryFn: (q) => q.eq('id', uid));
          if (existingDoc.isEmpty) {
            await DoctoresTable().insert({
              'id': uid,
              'esta_aprobado': false,
              'estado_verificacion': 'pendiente',
              'created_at': nowIso,
            });
          }
        } catch (_) {}
      } else if (existingUser.isEmpty) {
        try {
          await PacientesTable().upsert({'id': uid, 'created_at': nowIso});
        } catch (_) {}
      }

      final navCtx = context.mounted ? context : appNavigatorKey.currentContext;
      if (navCtx != null && navCtx.mounted) {
        if (userRole == 'doctor') {
          await DualDatabaseConfig.instance.consultarYConectarTenantDoctor(uid);
          if (!navCtx.mounted) return;
          navCtx.goNamedAuth(
            DoctorAgendaPanelWidget.routeName,
            navCtx.mounted,
            queryParameters: {'idDoctor': serializeParam(uid, ParamType.String)}.withoutNulls,
          );
        } else if (userRole == 'administrador' || userRole == 'admin') {
          await DualDatabaseConfig.instance.persistActiveViewMode('administrador');
          if (!navCtx.mounted) return;
          navCtx.goNamedAuth(AdminAccountsDashboardWidget.routeName, navCtx.mounted);
        } else if (userRole == 'secretaria') {
          await DualDatabaseConfig.instance.persistActiveViewMode('secretaria');
          if (!navCtx.mounted) return;
          navCtx.goNamedAuth(
            SecretaryDashboardWidget.routeName,
            navCtx.mounted,
            queryParameters: {'idSecretaria': serializeParam(uid, ParamType.String)}.withoutNulls,
          );
        } else {
          await DualDatabaseConfig.instance.persistActiveViewMode('paciente');
          if (!navCtx.mounted) return;
          navCtx.goNamedAuth(HomeWidget.routeName, navCtx.mounted);
        }
      }
    } catch (e) {
      debugPrint('GoogleAuthService: Error en sincronización post-login: $e');
    }
  }

  final Set<String> _syncedUids = {};
  bool _isSyncing = false;

  /// Asegura que el usuario autenticado (por ejemplo tras recarga web o deep link)
  /// esté sincronizado en UsuariosTable sin disparar bucles de eventos de Auth.
  Future<void> ensureUserSynced({String? userId, String? fallbackRole}) async {
    if (_isSyncing) return;
    try {
      final user = SupaFlow.client.auth.currentUser;
      if (user == null) return;
      final uid = userId ?? user.id;
      if (uid.isEmpty) return;

      final pendingRole = await _resolvePendingRole(fallbackRole);
      if (_syncedUids.contains(uid) && pendingRole == null) return;

      _isSyncing = true;
      _syncedUids.add(uid);

      final metadata = user.userMetadata ?? {};
      final metaRole = metadata['rol'] as String?;
      final shouldBeDoctor = pendingRole == 'doctor' ||
          (kIsWeb && Uri.base.queryParameters['oauth_role'] == 'doctor') ||
          (metaRole != null && _normalizarRol(metaRole) == 'doctor');
      final resolvedRole = shouldBeDoctor
          ? 'doctor'
          : (pendingRole ?? (metaRole != null ? _normalizarRol(metaRole) : 'paciente'));

      final existingUser = await UsuariosTable().querySingleRow(
        queryFn: (q) => q.eq('id', uid),
      );

      final email = user.email ?? '';
      final fullName = metadata['full_name'] as String? ?? metadata['name'] as String? ?? '';
      final photoUrl = metadata['avatar_url'] as String? ?? metadata['picture'] as String? ?? '';
      final nowIso = DateTime.now().toUtc().toIso8601String();

      if (existingUser.isEmpty) {
        try {
          await UsuariosTable().upsert({
            'id': uid,
            'email': email,
            'nombre': fullName.isNotEmpty ? fullName : null,
            'foto_url': photoUrl.isNotEmpty ? photoUrl : null,
            'rol': resolvedRole,
            'created_at': nowIso,
          });
        } catch (_) {}

        if (resolvedRole == 'doctor') {
          await DualDatabaseConfig.instance.persistActiveViewMode('doctor');
          if ((metaRole ?? '').toLowerCase() != 'doctor') {
            try {
              await SupaFlow.client.auth.updateUser(UserAttributes(data: {'rol': 'doctor'}));
            } catch (_) {}
          }
          try {
            final existingDoc = await DoctoresTable().querySingleRow(queryFn: (q) => q.eq('id', uid));
            if (existingDoc.isEmpty) {
              await DoctoresTable().insert({
                'id': uid,
                'esta_aprobado': false,
                'estado_verificacion': 'pendiente',
                'created_at': nowIso,
              });
            }
          } catch (_) {}
        } else {
          try {
            await PacientesTable().upsert({'id': uid, 'created_at': nowIso});
          } catch (_) {}
        }
      } else if (shouldBeDoctor) {
        await DualDatabaseConfig.instance.persistActiveViewMode('doctor');
        if ((existingUser.first.rol ?? '').toLowerCase().trim() != 'doctor') {
          try {
            await UsuariosTable().update(data: {'rol': 'doctor'}, matchingRows: (q) => q.eq('id', uid));
          } catch (_) {}
        }
        if ((metaRole ?? '').toLowerCase().trim() != 'doctor') {
          try {
            await SupaFlow.client.auth.updateUser(UserAttributes(data: {'rol': 'doctor'}));
          } catch (_) {}
        }
      }
      if (pendingRole != null) {
        await _clearPendingRole();
      }
    } catch (e) {
      debugPrint('GoogleAuthService: Error en ensureUserSynced: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Construye un botón interactivo estilizado de Google para formularios
  Widget buildGoogleButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    final theme = FlutterFlowTheme.of(context);

    return InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(14.0),
      child: Container(
        height: 48.0,
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: theme.alternate,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20.0,
                height: 20.0,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              )
            else ...[
              _buildGoogleLogoBadge(),
              const SizedBox(width: 12.0),
              Text(
                label,
                style: GoogleFonts.mooli(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Dibuja el isotipo oficial 'G' de Google mediante un contenedor visual
  Widget _buildGoogleLogoBadge() {
    return Container(
      width: 22.0,
      height: 22.0,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 20.0,
            height: 20.0,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 2.0,
                ),
              ],
            ),
          ),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 14.0,
                fontWeight: FontWeight.w900,
              ),
              children: const [
                TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

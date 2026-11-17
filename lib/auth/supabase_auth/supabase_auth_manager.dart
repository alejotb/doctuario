import 'dart:async';

import 'package:flutter/material.dart';
import '/auth/auth_manager.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'email_auth.dart';

import 'supabase_user_provider.dart';

export '/auth/base_auth_user_provider.dart';

/// Gestor de autenticación para Supabase en ProntoDoc.
///
/// Implementa los flujos de inicio de sesión, creación de cuentas,
/// cierre de sesión, actualización de correo, contraseñas y restablecimiento
/// de credenciales mediante el cliente oficial de Supabase Auth.
///
/// Además sincroniza el usuario con el [AppStateNotifier] para mantener
/// la reactividad del enrutamiento de GoRouter en tiempo real.
class SupabaseAuthManager extends AuthManager with EmailSignInManager {
  /// Retorna el identificador único del usuario actualmente autenticado,
  /// o una cadena vacía si no existe ninguna sesión activa.
  String get currentUid => currentUser?.uid ?? '';

  /// Retorna el correo electrónico del usuario actualmente autenticado,
  /// o una cadena vacía si no existe ninguna sesión activa.
  String get currentEmail => currentUser?.email ?? '';

  /// Indica si el usuario actual cuenta con una sesión activa.
  bool get isUserLoggedIn => loggedIn;

  /// Cierra la sesión activa del usuario actual en Supabase.
  ///
  /// Invalida los tokens de acceso y refresco tanto en memoria
  /// como en el almacenamiento local seguro del dispositivo.
  @override
  Future signOut() {
    return SupaFlow.safeSignOutAll();
  }

  /// Elimina la cuenta del usuario autenticado actualmente.
  ///
  /// Muestra un mensaje de error visual mediante [SnackBar] si la
  /// operación no se puede completar en el servidor de Supabase.
  @override
  Future deleteUser(BuildContext context) async {
    try {
      if (!loggedIn) {
        debugPrint('Error: delete user attempted with no logged in user!');
        return;
      }
      await currentUser?.delete();
    } on AuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    }
  }

  /// Actualiza la dirección de correo electrónico del usuario autenticado.
  ///
  /// Envía un correo de confirmación a la nueva dirección indicada
  /// antes de aplicar el cambio de manera definitiva en Supabase.
  @override
  Future updateEmail({
    required String email,
    required BuildContext context,
  }) async {
    try {
      if (!loggedIn) {
        debugPrint('Error: update email attempted with no logged in user!');
        return;
      }
      await currentUser?.updateEmail(email);
    } on AuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email change confirmation email sent')),
    );
  }

  /// Actualiza la contraseña del usuario actualmente autenticado en Supabase.
  ///
  /// Requiere que el usuario tenga una sesión activa y válida.
  /// Si ocurre un error de autenticación, se notifica en el [BuildContext].
  Future updatePassword({
    required String newPassword,
    required BuildContext context,
  }) async {
    try {
      if (!loggedIn) {
        debugPrint('Error: update password attempted with no logged in user!');
        return;
      }
      await currentUser?.updatePassword(newPassword);
    } on AuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated successfully')),
    );
  }

  /// Envía un correo electrónico para restablecer la contraseña olvidada.
  ///
  /// [email] Correo del usuario registrado que solicita el restablecimiento.
  /// [redirectTo] URL opcional de redirección para manejar el deep link.
  @override
  Future resetPassword({
    required String email,
    required BuildContext context,
    String? redirectTo,
  }) async {
    try {
      await SupaFlow.client.auth
          .resetPasswordForEmail(email, redirectTo: redirectTo);
    } on AuthException catch (e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
      return null;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset email sent')),
    );
  }

  /// Inicia sesión con credenciales tradicionales de correo y contraseña.
  ///
  /// Retorna la instancia de [BaseAuthUser] si la autenticación es exitosa,
  /// o `null` si las credenciales son incorrectas o falló la conexión.
  @override
  Future<BaseAuthUser?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  ) =>
      _signInOrCreateAccount(
        context,
        () => emailSignInFunc(email, password),
      );

  /// Registra una nueva cuenta de usuario con correo electrónico y contraseña.
  ///
  /// Valida la creación en el servidor de Supabase Auth y retorna
  /// el nuevo usuario para su posterior registro en las tablas de la BD.
  @override
  Future<BaseAuthUser?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password, {
    Map<String, dynamic>? data,
    String? emailRedirectTo,
  }) =>
      _signInOrCreateAccount(
        context,
        () => emailCreateAccountFunc(
          email,
          password,
          data: data,
          emailRedirectTo: emailRedirectTo,
        ),
      );

  /// Intenta iniciar sesión o registrar una cuenta utilizando Supabase Auth.
  ///
  /// Maneja excepciones de tipo [AuthException] y actualiza las referencias
  /// en memoria de [currentUser] y [AppStateNotifier] de manera segura.
  Future<BaseAuthUser?> _signInOrCreateAccount(
    BuildContext context,
    Future<User?> Function() signInFunc,
  ) async {
    try {
      final user = await signInFunc();
      if (user != null && user.identities != null && user.identities!.isEmpty) {
        throw const AuthException('User already registered');
      }
      final authUser =
          user == null ? null : MediConnectHealthcareAppSupabaseUser(user);

      // Update currentUser here in case user info needs to be used immediately
      // after a user is signed in. This should be handled by the user stream,
      // but adding here too in case of a race condition where the user stream
      // doesn't assign the currentUser in time.
      if (authUser != null) {
        currentUser = authUser;
        AppStateNotifier.instance.update(authUser);
      }
      return authUser;
    } on AuthException catch (e) {
      final isAlreadyRegistered =
          e.message.toLowerCase().contains('already registered') ||
              e.message.toLowerCase().contains('already in use') ||
              e.message.toLowerCase().contains('user already exists');
      final isEmailNotConfirmed =
          e.message.toLowerCase().contains('email not confirmed');
      final errorMsg = isAlreadyRegistered
          ? 'Ya existe una cuenta registrada con este correo electrónico.'
          : (isEmailNotConfirmed
              ? 'El correo aún no ha sido confirmado. Revisa tu bandeja de entrada o confirma el usuario en Supabase.'
              : 'Error: ${e.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
      return null;
    }
  }
}

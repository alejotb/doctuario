import '/backend/supabase/supabase.dart';

Future<User?> emailSignInFunc(
  String email,
  String password,
) async {
  final AuthResponse res = await SupaFlow.client.auth
      .signInWithPassword(email: email, password: password);
  return res.user;
}

Future<User?> emailCreateAccountFunc(
  String email,
  String password, {
  Map<String, dynamic>? data,
  String? emailRedirectTo,
}) async {
  final AuthResponse res = await SupaFlow.client.auth.signUp(
    email: email,
    password: password,
    data: data,
    emailRedirectTo: emailRedirectTo,
  );

  // If signUp succeeds and user is returned, ensure active session
  if (res.user != null) {
    if (res.session == null) {
      try {
        final signRes = await SupaFlow.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        return signRes.user ?? res.user;
      } catch (_) {
        // En caso de que se requiera confirmación de email por configuración en Supabase
        return res.user;
      }
    }
    return res.user;
  }

  return null;
}

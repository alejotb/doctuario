import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/i18n_service.dart';

/// Modal dialog for authenticated users (Doctors, Staff, Patients) to securely
/// update their account password within the ProntuDoc platform.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  /// Static helper method to display the password update dialog.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const ChangePasswordDialog(),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _hasMinLength(String val) => val.length >= 6;
  bool _hasUppercase(String val) => val.contains(RegExp(r'[A-Z]'));
  bool _hasNumber(String val) => val.contains(RegExp(r'[0-9]'));

  Future<void> _actualizarContrasena() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final isEs = I18nService.instance.currentLanguage == 'es';
    setState(() => _isLoading = true);

    try {
      final newPass = _newPasswordController.text.trim();
      final user = SupaFlow.client.auth.currentUser;

      if (user == null) {
        throw Exception(
          isEs
              ? 'No hay una sesión activa para cambiar la contraseña.'
              : 'No active session found to change password.',
        );
      }

      await SupaFlow.client.auth.updateUser(
        UserAttributes(password: newPass),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEs
                ? '¡Contraseña actualizada exitosamente en Doctuario!'
                : 'Password successfully updated on Doctuario!',
            style: GoogleFonts.mooli(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isEs ? "Error al actualizar contraseña: " : "Error updating password: "}$e',
            style: GoogleFonts.mooli(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.currentLanguage == 'es';
    final currentText = _newPasswordController.text;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Center(
        child: Container(
          width: 460.0,
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20.0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: Color(0xFF0284C7),
                          size: 26.0,
                        ),
                      ),
                      const SizedBox(width: 14.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEs ? 'Cambiar Contraseña' : 'Change Password',
                              style: theme.titleMedium.override(
                                font: GoogleFonts.mooli(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18.0,
                                ),
                              ),
                            ),
                            Text(
                              isEs
                                  ? 'Seguridad de tu cuenta en Doctuario'
                                  : 'Doctuario account security',
                              style: theme.bodySmall.override(
                                font: GoogleFonts.mooli(
                                  color: theme.secondaryText,
                                  fontSize: 12.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded, size: 22.0),
                        tooltip: isEs ? 'Cerrar' : 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18.0),
                  const Divider(height: 1.0),
                  const SizedBox(height: 18.0),

                  // Nueva contraseña
                  Text(
                    isEs ? 'Nueva Contraseña' : 'New Password',
                    style: GoogleFonts.mooli(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: isEs ? 'Ingresa al menos 6 caracteres' : 'At least 6 characters',
                      hintStyle: GoogleFonts.mooli(fontSize: 13.0, color: theme.secondaryText),
                      prefixIcon: const Icon(Icons.key_rounded, size: 20.0),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20.0,
                        ),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                      filled: true,
                      fillColor: theme.primaryBackground,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: theme.alternate),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: theme.alternate),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.8),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return isEs ? 'Ingresa la nueva contraseña' : 'Enter new password';
                      }
                      if (val.length < 6) {
                        return isEs ? 'Mínimo 6 caracteres' : 'Minimum 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12.0),

                  // Requisitos visuales
                  _buildRequirementRow(
                    met: _hasMinLength(currentText),
                    text: isEs ? 'Al menos 6 caracteres' : 'At least 6 characters',
                    theme: theme,
                  ),
                  _buildRequirementRow(
                    met: _hasUppercase(currentText),
                    text: isEs ? 'Al menos una letra mayúscula' : 'At least one uppercase letter',
                    theme: theme,
                  ),
                  _buildRequirementRow(
                    met: _hasNumber(currentText),
                    text: isEs ? 'Al menos un número' : 'At least one number',
                    theme: theme,
                  ),
                  const SizedBox(height: 16.0),

                  // Confirmar contraseña
                  Text(
                    isEs ? 'Confirmar Nueva Contraseña' : 'Confirm New Password',
                    style: GoogleFonts.mooli(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      hintText: isEs ? 'Repite la contraseña' : 'Repeat password',
                      hintStyle: GoogleFonts.mooli(fontSize: 13.0, color: theme.secondaryText),
                      prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 20.0),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20.0,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      filled: true,
                      fillColor: theme.primaryBackground,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: theme.alternate),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: theme.alternate),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.8),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return isEs ? 'Confirma tu contraseña' : 'Confirm your password';
                      }
                      if (val != _newPasswordController.text) {
                        return isEs ? 'Las contraseñas no coinciden' : 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24.0),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13.0),
                            side: BorderSide(color: theme.alternate),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: Text(
                            isEs ? 'Cancelar' : 'Cancel',
                            style: GoogleFonts.mooli(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                              color: theme.secondaryText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _actualizarContrasena,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13.0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20.0,
                                  height: 20.0,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  isEs ? 'Guardar' : 'Save',
                                  style: GoogleFonts.mooli(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementRow({
    required bool met,
    required String text,
    required FlutterFlowTheme theme,
  }) {
    final color = met ? const Color(0xFF10B981) : theme.secondaryText.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 15.0,
          ),
          const SizedBox(width: 8.0),
          Text(
            text,
            style: GoogleFonts.mooli(
              fontSize: 11.5,
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

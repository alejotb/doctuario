import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/i18n_service.dart';

/// Sección de avatar interactivo, carga/eliminación y previsualización de foto de perfil.
class CreateProfilePhotoSection extends StatelessWidget {
  const CreateProfilePhotoSection({
    super.key,
    required this.photoUrl,
    required this.onUploadPressed,
    required this.onDeletePressed,
  });

  final String photoUrl;
  final VoidCallback onUploadPressed;
  final VoidCallback onDeletePressed;

  void _mostrarModalFoto(BuildContext context) {
    final i18n = I18nService.instance;
    final theme = FlutterFlowTheme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450.0),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20.0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 16.0, 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        i18n.isSpanish ? 'Foto de Perfil' : 'Profile Photo',
                        style: theme.titleMedium.override(
                          font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                          fontSize: 18.0,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded, size: 22.0),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1.0),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: Image.network(
                      photoUrl,
                      width: double.infinity,
                      height: 320.0,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 250.0,
                        color: theme.primaryBackground,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, size: 48.0, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 18.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            onDeletePressed();
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18.0),
                          label: Text(
                            i18n.isSpanish ? 'Eliminar' : 'Delete',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            onUploadPressed();
                          },
                          icon: const Icon(Icons.camera_alt_outlined, size: 18.0, color: Colors.white),
                          label: Text(
                            i18n.isSpanish ? 'Cambiar Foto' : 'Change Photo',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;
    final theme = FlutterFlowTheme.of(context);
    final hasPhoto = photoUrl.isNotEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Tooltip(
                message: hasPhoto
                    ? (i18n.isSpanish ? 'Clic para ver foto completa' : 'Click to view full photo')
                    : (i18n.isSpanish ? 'Subir foto de perfil' : 'Upload profile photo'),
                child: InkWell(
                  onTap: () {
                    if (hasPhoto) {
                      _mostrarModalFoto(context);
                    } else {
                      onUploadPressed();
                    }
                  },
                  borderRadius: BorderRadius.circular(60.0),
                  child: Container(
                    width: 100.0,
                    height: 100.0,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: theme.primaryBackground,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.primary, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primary.withValues(alpha: 0.18),
                          blurRadius: 10.0,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: hasPhoto
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.person_rounded,
                              size: 60.0,
                              color: theme.secondaryText,
                            ),
                          )
                        : Icon(
                            Icons.person_rounded,
                            size: 60.0,
                            color: theme.secondaryText.withValues(alpha: 0.6),
                          ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: onUploadPressed,
                  borderRadius: BorderRadius.circular(20.0),
                  child: Container(
                    width: 32.0,
                    height: 32.0,
                    decoration: BoxDecoration(
                      color: theme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.0),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4.0),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16.0),
                  ),
                ),
              ),
              if (hasPhoto)
                Positioned(
                  top: 0,
                  right: 0,
                  child: InkWell(
                    onTap: onDeletePressed,
                    borderRadius: BorderRadius.circular(20.0),
                    child: Container(
                      width: 28.0,
                      height: 28.0,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.0),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4.0),
                        ],
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 15.0),
                    ),
                  ),
                ),
            ],
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 8.0),
            InkWell(
              onTap: () => _mostrarModalFoto(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fullscreen_rounded, size: 16.0, color: theme.primary),
                  const SizedBox(width: 4.0),
                  Text(
                    i18n.isSpanish ? 'Ver foto completa' : 'View full photo',
                    style: theme.bodySmall.override(
                      font: GoogleFonts.mooli(fontWeight: FontWeight.w600),
                      color: theme.primary,
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Panel lateral decorativo para la vista de escritorio en Completar Perfil.
class CreateProfileDesktopBanner extends StatelessWidget {
  const CreateProfileDesktopBanner({super.key, required this.isDoctor});

  final bool isDoctor;

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;
    final theme = FlutterFlowTheme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 560.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: theme.alternate, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                gradient: LinearGradient(
                  colors: [
                    theme.primary.withValues(alpha: 0.07),
                    theme.secondary.withValues(alpha: 0.04),
                    theme.secondaryBackground,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 110.0,
                    height: 110.0,
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.primary.withValues(alpha: 0.35), width: 2.0),
                    ),
                    child: Icon(
                      isDoctor ? Icons.medical_services_outlined : Icons.add_photo_alternate_outlined,
                      size: 50.0,
                      color: theme.primary,
                    ),
                  ),
                  const SizedBox(height: 18.0),
                  Text(
                    isDoctor
                        ? (i18n.isSpanish ? 'Perfil Profesional Médico' : 'Professional Medical Profile')
                        : (i18n.isSpanish ? 'Tu Expediente de Salud' : 'Your Healthcare Profile'),
                    style: theme.titleMedium.override(
                      font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                      fontSize: 18.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    isDoctor
                        ? (i18n.isSpanish
                            ? 'Configura tus especialidades, subespecialidades y ubicación para que tus pacientes te encuentren fácilmente.'
                            : 'Configure your specialties, subspecialties, and location so your patients can easily find you.')
                        : (i18n.isSpanish
                            ? 'Mantén tus datos actualizados para agendar citas y recibir tus informes médicos al instante.'
                            : 'Keep your details updated to book appointments and receive medical reports instantly.'),
                    style: theme.bodyMedium.override(
                      font: GoogleFonts.mooli(),
                      color: theme.secondaryText,
                      fontSize: 13.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado con navegación, selector de idioma y título del formulario.
class CreateProfileHeaderSection extends StatelessWidget {
  const CreateProfileHeaderSection({
    super.key,
    required this.isDoctor,
    required this.userRole,
    required this.onBack,
    this.esEdicion = false,
  });

  final bool isDoctor;
  final String userRole;
  final VoidCallback onBack;
  final bool esEdicion;

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (esEdicion)
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios, size: 20.0))
            else
              const SizedBox(width: 8.0, height: 36.0),
            InkWell(
              onTap: () => I18nService.showLanguageDialog(context),
              borderRadius: BorderRadius.circular(20.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: theme.primaryBackground,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      i18n.isSpanish ? '🇪🇸 ES' : '🇺🇸 EN',
                      style: theme.bodySmall.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 4.0),
                    Icon(Icons.arrow_drop_down, size: 18.0, color: theme.secondaryText),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Icon(
                isDoctor ? Icons.medical_services_outlined : Icons.person_outline,
                color: theme.primary,
                size: 22.0,
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                esEdicion
                    ? (i18n.isSpanish ? 'Actualizar Perfil ($userRole)' : 'Update Profile ($userRole)')
                    : (i18n.isSpanish ? 'Completar Perfil ($userRole)' : 'Complete Profile ($userRole)'),
                style: theme.titleLarge.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold), fontSize: 22.0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6.0),
        Text(
          i18n.isSpanish
              ? 'Ingresa tus datos personales y profesionales para finalizar tu cuenta.'
              : 'Enter your personal and professional details to finalize your account.',
          style: theme.bodyMedium.override(font: GoogleFonts.mooli(), color: theme.secondaryText, fontSize: 13.0),
        ),
      ],
    );
  }
}

/// Botón principal de guardado del perfil.
class CreateProfileSaveButton extends StatelessWidget {
  const CreateProfileSaveButton({super.key, required this.onTap, this.esEdicion = false});

  final VoidCallback onTap;
  final bool esEdicion;

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.0),
      child: Container(
        height: 48.0,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.secondary, theme.primary, theme.secondary],
            stops: const [0.0, 0.5, 1.0],
            begin: const AlignmentDirectional(1.0, -0.5),
            end: const AlignmentDirectional(-1.0, 0.5),
          ),
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: [BoxShadow(color: theme.primary.withValues(alpha: 0.3), blurRadius: 10.0, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Text(
            esEdicion
                ? (i18n.isSpanish ? 'Guardar Cambios' : 'Save Changes')
                : (i18n.isSpanish ? 'Guardar y Continuar' : 'Save & Continue'),
            style: theme.bodyMedium.override(
              font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
              color: Colors.white,
              fontSize: 15.0,
            ),
          ),
        ),
      ),
    );
  }
}

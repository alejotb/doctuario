import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import '/services/i18n_service.dart';
import 'profile_image_model.dart';
export 'profile_image_model.dart';

class ProfileImageWidget extends StatefulWidget {
  const ProfileImageWidget({super.key});

  static String routeName = 'ProfileImage';
  static String routePath = '/profileImage';

  @override
  State<ProfileImageWidget> createState() => _ProfileImageWidgetState();
}

class _ProfileImageWidgetState extends State<ProfileImageWidget> {
  late ProfileImageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  String _currentPhotoUrl = '';
  String _initialPhotoUrl = '';
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileImageModel());
    _cargarFotoActual();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _cargarFotoActual() async {
    setState(() => _isLoading = true);
    final uid = SupaFlow.client.auth.currentUser?.id ?? currentUserUid;
    if (uid.isNotEmpty) {
      try {
        final rows = await UsuariosTable().querySingleRow(
          queryFn: (q) => q.eq('id', uid),
        );
        if (rows.isNotEmpty && mounted) {
          final u = rows.first;
          setState(() {
            _currentPhotoUrl = (u.fotoUrl ?? '').trim();
            _initialPhotoUrl = _currentPhotoUrl;
          });
        }
      } catch (e) {
        debugPrint('Error cargando foto de perfil: $e');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _seleccionarYSubirFoto() async {
    final selectedMedia = await selectMediaWithSourceBottomSheet(
      context: context,
      storageFolderPath: 'fotos_perfil/usuarios',
      allowPhoto: true,
    );

    if (selectedMedia != null &&
        selectedMedia.every((m) => validateFileFormat(m.storagePath, context))) {
      setState(() => _isUploading = true);
      try {
        final downloadUrls = await uploadSupabaseStorageFiles(
          bucketName: 'images',
          selectedFiles: selectedMedia,
        );

        if (downloadUrls.isNotEmpty) {
          final newUrl = downloadUrls.first;
          if (_initialPhotoUrl.isNotEmpty && _initialPhotoUrl != newUrl) {
            deleteSupabaseFileFromPublicUrl(_initialPhotoUrl);
          }
          setState(() {
            _currentPhotoUrl = newUrl;
          });

          // Guardar inmediatamente en UsuariosTable
          final uid = SupaFlow.client.auth.currentUser?.id ?? currentUserUid;
          if (uid.isNotEmpty) {
            await UsuariosTable().update(
              data: {'foto_url': newUrl},
              matchingRows: (q) => q.eq('id', uid),
            );
            await SupaFlow.client.auth.updateUser(
              UserAttributes(data: {'foto_url': newUrl, 'avatar_url': newUrl}),
            );
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Foto subida y actualizada con éxito.'),
                backgroundColor: Colors.teal,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error subiendo imagen: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al subir imagen: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _eliminarFoto() async {
    if (_currentPhotoUrl.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Foto de Perfil'),
        content: const Text('¿Estás seguro de que deseas eliminar tu foto de perfil?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final oldUrl = _currentPhotoUrl;
    await deleteSupabaseFileFromPublicUrl(oldUrl);

    setState(() {
      _currentPhotoUrl = '';
      _initialPhotoUrl = '';
    });

    final uid = SupaFlow.client.auth.currentUser?.id ?? currentUserUid;
    if (uid.isNotEmpty) {
      try {
        await UsuariosTable().update(
          data: {'foto_url': ''},
          matchingRows: (q) => q.eq('id', uid),
        );
        await SupaFlow.client.auth.updateUser(
          UserAttributes(data: {'foto_url': '', 'avatar_url': ''}),
        );
      } catch (e) {
        debugPrint('Error al eliminar foto de BD: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto de perfil eliminada.'),
          backgroundColor: Colors.blueGrey,
        ),
      );
    }
  }

  Future<void> _guardarCambios() async {
    setState(() => _isSaving = true);
    final uid = SupaFlow.client.auth.currentUser?.id ?? currentUserUid;
    if (uid.isNotEmpty) {
      try {
        await UsuariosTable().update(
          data: {'foto_url': _currentPhotoUrl},
          matchingRows: (q) => q.eq('id', uid),
        );
        await SupaFlow.client.auth.updateUser(
          UserAttributes(data: {'foto_url': _currentPhotoUrl, 'avatar_url': _currentPhotoUrl}),
        );
      } catch (e) {
        debugPrint('Error guardando foto en BD: $e');
      }
    }
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Foto de perfil guardada correctamente.'),
          backgroundColor: Colors.teal,
        ),
      );
      context.safePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;
    final isSpanish = i18n.isSpanish;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      appBar: AppBar(
        title: Text(
          isSpanish ? 'Foto de Perfil' : 'Profile Image',
          style: FlutterFlowTheme.of(context).titleLarge.override(
                font: GoogleFonts.mooli(
                  fontWeight: FontWeight.bold,
                ),
              ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: FlutterFlowTheme.of(context).primaryText),
          onPressed: () => context.safePop(),
        ),
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        elevation: 0.5,
      ),
      body: SafeArea(
        top: true,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20.0),
                    // Vista previa del Avatar
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 180.0,
                          height: 180.0,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).primary,
                              width: 3.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.15),
                                blurRadius: 16.0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _isUploading
                              ? const Center(child: CircularProgressIndicator())
                              : (_currentPhotoUrl.isNotEmpty
                                  ? Image.network(
                                      _currentPhotoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.person_rounded,
                                        size: 90.0,
                                        color: FlutterFlowTheme.of(context).secondaryText,
                                      ),
                                    )
                                  : Icon(
                                      Icons.person_rounded,
                                      size: 90.0,
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                    )),
                        ),
                        // Botón flotante para editar foto
                        InkWell(
                          onTap: _isUploading ? null : _seleccionarYSubirFoto,
                          borderRadius: BorderRadius.circular(25.0),
                          child: Container(
                            width: 44.0,
                            height: 44.0,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 20.0,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36.0),

                    // Botón Subir Imagen / Cambiar Imagen
                    InkWell(
                      splashColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: _isUploading ? null : _seleccionarYSubirFoto,
                      child: Container(
                        width: double.infinity,
                        height: 50.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              FlutterFlowTheme.of(context).secondary,
                              FlutterFlowTheme.of(context).primary,
                              FlutterFlowTheme.of(context).secondary
                            ],
                            stops: const [0.0, 1.0, 1.0],
                            begin: const AlignmentDirectional(1.0, -0.5),
                            end: const AlignmentDirectional(-1.0, 0.5),
                          ),
                          borderRadius: BorderRadius.circular(100.0),
                        ),
                        child: Align(
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 20.0),
                              const SizedBox(width: 8.0),
                              Text(
                                _currentPhotoUrl.isNotEmpty
                                    ? (isSpanish ? 'Cambiar Imagen' : 'Change Image')
                                    : (isSpanish ? 'Subir Imagen' : 'Upload Image'),
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                      font: GoogleFonts.mooli(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      color: Colors.white,
                                      fontSize: 15.0,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Botón Borrar Foto (si existe una foto)
                    if (_currentPhotoUrl.isNotEmpty) ...[
                      const SizedBox(height: 14.0),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        label: Text(
                          isSpanish ? 'Eliminar Foto de Perfil' : 'Remove Profile Photo',
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isUploading ? null : _eliminarFoto,
                      ),
                    ],

                    const SizedBox(height: 14.0),

                    // Botón Guardar Cambios
                    FFButtonWidget(
                      onPressed: _isSaving ? null : _guardarCambios,
                      text: isSpanish ? 'Guardar Cambios' : 'Save Changes',
                      options: FFButtonOptions(
                        width: double.infinity,
                        height: 50.0,
                        padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                        iconPadding: EdgeInsets.zero,
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                              font: GoogleFonts.mooli(
                                fontWeight: FontWeight.bold,
                              ),
                              color: FlutterFlowTheme.of(context).primary,
                            ),
                        elevation: 0.0,
                        borderSide: BorderSide(
                          color: FlutterFlowTheme.of(context).primary,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(100.0),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

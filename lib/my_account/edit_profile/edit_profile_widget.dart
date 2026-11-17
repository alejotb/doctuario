import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/flutter_flow/upload_data.dart';
import '/services/i18n_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_profile_model.dart';
export 'edit_profile_model.dart';

class EditProfileWidget extends StatefulWidget {
  const EditProfileWidget({super.key});

  static String routeName = 'EditProfile';
  static String routePath = '/editProfile';

  @override
  State<EditProfileWidget> createState() => _EditProfileWidgetState();
}

class _EditProfileWidgetState extends State<EditProfileWidget> {
  late EditProfileModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  String _localPhotoUrl = '';
  bool _isUploadingPhoto = false;
  bool _isSaving = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditProfileModel());
    _model.firstNameFocusNode ??= FocusNode();
    _model.emailInputFocusNode ??= FocusNode();
    _model.phoneNumberInputFocusNode ??= FocusNode();

    _cargarDatosUsuario();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosUsuario() async {
    final uid = SupaFlow.client.auth.currentUser?.id ?? currentUserUid;
    if (uid.isNotEmpty) {
      try {
        final rows = await UsuariosTable().querySingleRow(
          queryFn: (q) => q.eq('id', uid),
        );
        if (rows.isNotEmpty && mounted) {
          final u = rows.first;
          setState(() {
            _localPhotoUrl = (u.fotoUrl ?? '').trim();
            _model.firstNameTextController ??= TextEditingController(text: u.nombre ?? '');
            _model.emailInputTextController ??= TextEditingController(text: u.email ?? currentUserEmail);
            _model.phoneNumberInputTextController ??= TextEditingController(text: u.telefono ?? '');
            _model.genderValue = 'Male';
            _isInitialized = true;
          });
        }
      } catch (e) {
        debugPrint('Error cargando usuario para editar: $e');
      }
    }
  }

  Future<void> _seleccionarYSubirFoto() async {
    final oldUrl = _localPhotoUrl;
    final selectedMedia = await selectMediaWithSourceBottomSheet(
      context: context,
      storageFolderPath: 'fotos_perfil/usuarios',
      allowPhoto: true,
    );

    if (selectedMedia != null &&
        selectedMedia.every((m) => validateFileFormat(m.storagePath, context))) {
      setState(() => _isUploadingPhoto = true);
      try {
        final downloadUrls = await uploadSupabaseStorageFiles(
          bucketName: 'images',
          selectedFiles: selectedMedia,
        );

        if (downloadUrls.isNotEmpty) {
          final newUrl = downloadUrls.first;
          if (oldUrl.isNotEmpty && oldUrl != newUrl) {
            deleteSupabaseFileFromPublicUrl(oldUrl);
          }
          setState(() {
            _localPhotoUrl = newUrl;
          });

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
                content: Text('✅ Foto de perfil actualizada.'),
                backgroundColor: Colors.teal,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error subiendo foto en editar perfil: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al subir imagen a Supabase Storage: $e'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _actualizarPerfil() async {
    setState(() => _isSaving = true);
    final uid = SupaFlow.client.auth.currentUser?.id ?? currentUserUid;

    if (uid.isNotEmpty) {
      try {
        await UsuariosTable().update(
          data: {
            'nombre': _model.firstNameTextController?.text.trim() ?? '',
            'telefono': _model.phoneNumberInputTextController?.text.trim() ?? '',
            'foto_url': _localPhotoUrl,
          },
          matchingRows: (q) => q.eq('id', uid),
        );

        await SupaFlow.client.auth.updateUser(
          UserAttributes(
            data: {
              'foto_url': _localPhotoUrl,
              'avatar_url': _localPhotoUrl,
              'nombre': _model.firstNameTextController?.text.trim() ?? '',
            },
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Perfil actualizado correctamente.'),
              backgroundColor: Colors.teal,
            ),
          );
          context.safePop();
        }
      } catch (e) {
        debugPrint('Error guardando perfil en BD: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;
    final isSpanish = i18n.isSpanish;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20.0, 30.0, 20.0, 0.0),
                child: FutureBuilder<List<UsuariosRow>>(
                  future: UsuariosTable().querySingleRow(
                    queryFn: (q) => q.eqOrNull(
                      'id',
                      currentUserUid,
                    ),
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData && !_isInitialized) {
                      return Center(
                        child: SizedBox(
                          width: 50.0,
                          height: 50.0,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              FlutterFlowTheme.of(context).primary,
                            ),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasData && snapshot.data!.isNotEmpty && !_isInitialized) {
                      final u = snapshot.data!.first;
                      _localPhotoUrl = (u.fotoUrl ?? '').trim();
                      _model.firstNameTextController ??= TextEditingController(text: u.nombre ?? '');
                      _model.emailInputTextController ??= TextEditingController(text: u.email ?? currentUserEmail);
                      _model.phoneNumberInputTextController ??= TextEditingController(text: u.telefono ?? '');
                      _model.genderValue = 'Male';
                      _isInitialized = true;
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                context.safePop();
                              },
                              child: Icon(
                                Icons.arrow_back,
                                color: FlutterFlowTheme.of(context).primaryText,
                                size: 24.0,
                              ),
                            ),
                            Text(
                              isSpanish ? 'Editar Perfil' : 'Edit Profile',
                              style: FlutterFlowTheme.of(context).titleLarge.override(
                                    font: GoogleFonts.mooli(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            ),
                          ].divide(const SizedBox(width: 10.0)),
                        ),
                        const SizedBox(height: 16.0),
                        // Avatar con botón de editar
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 86.0,
                                  height: 86.0,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: FlutterFlowTheme.of(context).secondaryBackground,
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context).primary,
                                      width: 2.0,
                                    ),
                                  ),
                                  child: _isUploadingPhoto
                                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                      : (_localPhotoUrl.isNotEmpty
                                          ? Image.network(
                                              _localPhotoUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Icon(
                                                Icons.person_rounded,
                                                size: 48.0,
                                                color: FlutterFlowTheme.of(context).secondaryText,
                                              ),
                                            )
                                          : Icon(
                                              Icons.person_rounded,
                                              size: 48.0,
                                              color: FlutterFlowTheme.of(context).secondaryText,
                                            )),
                                ),
                                InkWell(
                                  onTap: _isUploadingPhoto ? null : _seleccionarYSubirFoto,
                                  borderRadius: BorderRadius.circular(15.0),
                                  child: Container(
                                    width: 28.0,
                                    height: 28.0,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context).primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 14.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 20.0),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            scrollDirection: Axis.vertical,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: TextFormField(
                                  controller: _model.firstNameTextController ??= TextEditingController(),
                                  focusNode: _model.firstNameFocusNode,
                                  autofocus: false,
                                  obscureText: false,
                                  decoration: InputDecoration(
                                    labelText: isSpanish ? 'Nombre Completo' : 'Full Name',
                                    labelStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                                          font: GoogleFonts.mooli(fontWeight: FontWeight.w500),
                                          fontSize: 14.0,
                                        ),
                                    hintText: 'Enter your name',
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context).alternate,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context).primary,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    filled: true,
                                    fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                                    contentPadding: const EdgeInsets.all(16.0),
                                  ),
                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                        font: GoogleFonts.mooli(fontWeight: FontWeight.w500),
                                        fontSize: 15.0,
                                      ),
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: TextFormField(
                                  controller: _model.emailInputTextController ??= TextEditingController(text: currentUserEmail),
                                  focusNode: _model.emailInputFocusNode,
                                  autofocus: false,
                                  readOnly: true,
                                  obscureText: false,
                                  decoration: InputDecoration(
                                    labelText: isSpanish ? 'Correo Electrónico' : 'Email',
                                    labelStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                                          font: GoogleFonts.mooli(fontWeight: FontWeight.w500),
                                          fontSize: 14.0,
                                        ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context).alternate,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context).primary,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    filled: true,
                                    fillColor: FlutterFlowTheme.of(context).primaryBackground,
                                    contentPadding: const EdgeInsets.all(16.0),
                                  ),
                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                        font: GoogleFonts.mooli(fontWeight: FontWeight.w500),
                                        fontSize: 15.0,
                                        color: FlutterFlowTheme.of(context).secondaryText,
                                      ),
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: TextFormField(
                                  controller: _model.phoneNumberInputTextController ??= TextEditingController(),
                                  focusNode: _model.phoneNumberInputFocusNode,
                                  autofocus: false,
                                  obscureText: false,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: isSpanish ? 'Número de Teléfono' : 'Phone Number',
                                    labelStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                                          font: GoogleFonts.mooli(fontWeight: FontWeight.w500),
                                          fontSize: 14.0,
                                        ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context).alternate,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context).primary,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    filled: true,
                                    fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                                    contentPadding: const EdgeInsets.all(16.0),
                                  ),
                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                        font: GoogleFonts.mooli(fontWeight: FontWeight.w500),
                                        fontSize: 15.0,
                                      ),
                                ),
                              ),
                              FlutterFlowDropDown<String>(
                                controller: _model.genderValueController ??= FormFieldController<String>(
                                  _model.genderValue ??= 'Male',
                                ),
                                options: const ['Male', 'Female', 'Other'],
                                optionLabels: isSpanish
                                    ? const ['Masculino', 'Femenino', 'Otro']
                                    : const ['Male', 'Female', 'Other'],
                                onChanged: (val) => safeSetState(() => _model.genderValue = val),
                                width: 200.0,
                                height: 50.0,
                                textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                                      font: GoogleFonts.mooli(fontWeight: FontWeight.w500),
                                      fontSize: 15.0,
                                    ),
                                hintText: isSpanish ? 'Selecciona género' : 'Select gender',
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: FlutterFlowTheme.of(context).secondaryText,
                                  size: 24.0,
                                ),
                                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                                elevation: 2.0,
                                borderColor: FlutterFlowTheme.of(context).alternate,
                                borderWidth: 1.0,
                                borderRadius: 8.0,
                                margin: const EdgeInsets.all(14.0),
                                hidesUnderline: true,
                                isOverButton: false,
                                isSearchable: false,
                                isMultiSelect: false,
                              ),
                            ].divide(const SizedBox(height: 15.0)),
                          ),
                        ),
                        Divider(
                          thickness: 1.0,
                          color: FlutterFlowTheme.of(context).alternate,
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(0.0, 15.0, 0.0, 0.0),
                          child: InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: _isSaving ? null : _actualizarPerfil,
                            child: Container(
                              width: double.infinity,
                              height: 48.0,
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
                                alignment: const AlignmentDirectional(0.0, 0.0),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 22.0,
                                        height: 22.0,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text(
                                        isSpanish ? 'Guardar Cambios' : 'Update',
                                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                                              font: GoogleFonts.mooli(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              color: FlutterFlowTheme.of(context).primaryBackground,
                                              fontSize: 15.0,
                                            ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ].divide(const SizedBox(height: 10.0)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

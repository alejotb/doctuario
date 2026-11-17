import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/flutter_flow/upload_data.dart';
import '/services/i18n_service.dart';
import '/services/specialties_service.dart';
import '/services/doctor_patient_sync_service.dart';
import '/services/patient_account_linking_service.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'create_profile_model.dart';
import 'create_profile_photo_section.dart';
import 'create_profile_location_modals.dart';
import 'create_profile_specialties_section.dart';
export 'create_profile_model.dart';

class CreateProfileWidget extends StatefulWidget {
  const CreateProfileWidget({
    super.key,
    required this.rol,
    this.esEdicion = false,
  });

  final String? rol;
  final bool esEdicion;

  static String routeName = 'CreateProfile';
  static String routePath = '/createProfile';
  @override
  State<CreateProfileWidget> createState() => _CreateProfileWidgetState();
}
class _CreateProfileWidgetState extends State<CreateProfileWidget> {
  late CreateProfileModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  String _localPhotoUrl = '';
  DateTime? _fechaNacimiento;
  List<String> _selectedSpecialties = [];
  Map<String, List<String>> _subspecialtiesBySpecialty = {};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CreateProfileModel());
    _model.firstNameTextController ??= TextEditingController();
    _model.firstNameFocusNode ??= FocusNode();
    _model.idTextController ??= TextEditingController();
    _model.idFocusNode ??= FocusNode();
    _model.emailInputTextController ??= TextEditingController(text: currentUserEmail);
    _model.emailInputFocusNode ??= FocusNode();
    _model.phoneNumberInputTextController ??= TextEditingController(text: currentPhoneNumber);
    _model.phoneNumberInputFocusNode ??= FocusNode();
    _model.estadoTextController ??= TextEditingController();
    _model.estadoFocusNode ??= FocusNode();
    _model.ciudadTextController ??= TextEditingController();
    _model.ciudadFocusNode ??= FocusNode();
    _model.specialtyTextController ??= TextEditingController();
    _model.specialtyFocusNode ??= FocusNode();
    _model.subspecialtyTextController ??= TextEditingController();
    _model.subspecialtyFocusNode ??= FocusNode();
    _model.biografiaTextController ??= TextEditingController();
    _model.biografiaFocusNode ??= FocusNode();
    _cargarDatosExistentes();
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  Future<void> _cargarDatosExistentes() async {
    final currentUser = SupaFlow.client.auth.currentUser;
    final uid = currentUser?.id;
    if (uid == null || uid.isEmpty) return;
    final meta = currentUser?.userMetadata ?? const <String, dynamic>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = await UsuariosTable().querySingleRow(queryFn: (q) => q.eq('id', uid));
      final u = rows.isNotEmpty ? rows.first : null;
      final foto = (u?.fotoUrl?.trim().isNotEmpty ?? false) ? u!.fotoUrl!.trim() : (meta['foto_url']?.toString().trim() ?? '');
      final nombre = (u?.nombre?.trim().isNotEmpty ?? false) ? u!.nombre!.trim() : (meta['nombre']?.toString().trim() ?? '');
      final cedula = (u?.cedula?.trim().isNotEmpty ?? false) ? u!.cedula!.trim() : (meta['cedula']?.toString().trim() ?? '');
      final tel = (u?.telefono?.trim().isNotEmpty ?? false) ? u!.telefono!.trim() : (meta['telefono']?.toString().trim() ?? '');
      final ciudad = (u?.ciudadOrigen?.trim().isNotEmpty ?? false) ? u!.ciudadOrigen!.trim() : (meta['ciudad_origen']?.toString().trim() ?? '');
      if (mounted) {
        safeSetState(() {
          if (foto.isNotEmpty) { _localPhotoUrl = foto; _model.uploadedFileUrl_uploadData317 = foto; }
          if (nombre.isNotEmpty) _model.firstNameTextController?.text = nombre;
          if (cedula.isNotEmpty) _model.idTextController?.text = cedula;
          if (tel.isNotEmpty) _model.phoneNumberInputTextController?.text = tel;
          if (u?.fechaNacimiento != null) _fechaNacimiento = u!.fechaNacimiento;
          if (ciudad.isNotEmpty) {
            _model.ciudadOrigen = ciudad;
            final parts = ciudad.split(',');
            if (parts.length >= 2) {
              _model.ciudadTextController?.text = parts[0].trim();
              _model.estadoOrigen = parts.sublist(1).join(',').trim();
              _model.estadoTextController?.text = _model.estadoOrigen!;
            } else {
              _model.ciudadTextController?.text = ciudad;
            }
          }
        });
      }
      final isDoc = ((widget.rol ?? u?.rol ?? meta['rol']?.toString() ?? '').toLowerCase() == 'doctor');
      if (isDoc) {
        final docRows = await DoctoresTable().querySingleRow(queryFn: (q) => q.eq('id', uid));
        final d = docRows.isNotEmpty ? docRows.first : null;
        final rawSpec = (d?.especialidad?.trim().isNotEmpty ?? false) ? d!.especialidad! : (meta['especialidad']?.toString() ?? '');
        final rawBio = (d?.biografia?.trim().isNotEmpty ?? false) ? d!.biografia! : (meta['biografia']?.toString() ?? '');
        if (mounted) {
          safeSetState(() {
            if (rawSpec.isNotEmpty) {
              final parsed = SpecialtiesService.parseEspecialidadesCompuestas(rawSpec);
              _selectedSpecialties = parsed.especialidades;
              _subspecialtiesBySpecialty = parsed.subespecialidades;
              if (_selectedSpecialties.isNotEmpty) {
                _model.selectedSpecialty = _selectedSpecialties.first;
                _model.specialtyTextController?.text = _selectedSpecialties.join(', ');
              }
            }
            if (rawBio.isNotEmpty) _model.biografiaTextController?.text = rawBio;
          });
        }
        final setupDone = (prefs.getBool('prontudoc_setup_completo_$uid') ?? false) || meta['setup_completo'] == true;
        if (!widget.esEdicion && (setupDone || (ciudad.isNotEmpty && _selectedSpecialties.isNotEmpty))) {
          final sedes = await DoctorSedesTable().queryRows(queryFn: (q) => q.eq('id_doctor', uid).limit(1));
          if (mounted && (setupDone || sedes.isNotEmpty)) {
            context.goNamed(DoctorAgendaPanelWidget.routeName, queryParameters: {'idDoctor': serializeParam(uid, ParamType.String)}.withoutNulls);
            return;
          }
        }
      } else if (!widget.esEdicion && ciudad.isNotEmpty && mounted) {
        context.goNamed(HomeWidget.routeName);
      }
    } catch (e) {
      debugPrint('Error cargando datos previos del usuario: $e');
    }
  }

  Future<void> _sincronizarFotoEnBd(String url) async {
    final uid = SupaFlow.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return;
    try {
      await UsuariosTable().update(data: {'foto_url': url}, matchingRows: (q) => q.eq('id', uid));
      await SupaFlow.client.auth.updateUser(UserAttributes(data: {'foto_url': url, 'avatar_url': url}));
    } catch (e) {
      debugPrint('Error sincronizando foto de usuario en BD: $e');
    }
  }

  Future<void> _seleccionarYSubirFoto(BuildContext context) async {
    final oldUrl = _localPhotoUrl;
    final selectedMedia = await selectMediaWithSourceBottomSheet(
      context: context,
      storageFolderPath: 'fotos_perfil/${widget.rol ?? "usuarios"}',
      allowPhoto: true,
    );
    if (selectedMedia == null || !selectedMedia.every((m) => validateFileFormat(m.storagePath, context))) return;
    safeSetState(() => _model.isDataUploading_uploadData317 = true);
    var selectedUploadedFiles = <FFUploadedFile>[];
    var downloadUrls = <String>[];
    try {
      selectedUploadedFiles = selectedMedia
          .map((m) => FFUploadedFile(
                name: m.storagePath.split('/').last,
                bytes: m.bytes,
                height: m.dimensions?.height,
                width: m.dimensions?.width,
                blurHash: m.blurHash,
                originalFilename: m.originalFilename,
              ))
          .toList();
      downloadUrls = await uploadSupabaseStorageFiles(bucketName: kImagesBucket, selectedFiles: selectedMedia);
    } catch (e) {
      debugPrint('Error subiendo imagen a Storage: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      _model.isDataUploading_uploadData317 = false;
    }
    if (selectedUploadedFiles.length == selectedMedia.length && downloadUrls.length == selectedMedia.length) {
      if (oldUrl.isNotEmpty && oldUrl != downloadUrls.first) deleteSupabaseFileFromPublicUrl(oldUrl);
      safeSetState(() {
        _localPhotoUrl = downloadUrls.first;
        _model.uploadedLocalFile_uploadData317 = selectedUploadedFiles.first;
        _model.uploadedFileUrl_uploadData317 = _localPhotoUrl;
      });
      await _sincronizarFotoEnBd(_localPhotoUrl);
    }
  }

  Future<void> _eliminarFotoActual(BuildContext context) async {
    if (_localPhotoUrl.isNotEmpty) await deleteSupabaseFileFromPublicUrl(_localPhotoUrl);
    safeSetState(() {
      _localPhotoUrl = '';
      _model.uploadedFileUrl_uploadData317 = '';
      _model.uploadedLocalFile_uploadData317 = FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
    });
    await _sincronizarFotoEnBd('');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18nService.instance.isSpanish ? 'Foto eliminada' : 'Photo deleted'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _guardarPerfil() async {
    final i18n = I18nService.instance;
    final selectedRole = (widget.rol ?? 'paciente').toLowerCase().trim();
    final userId = currentUserUid.isNotEmpty ? currentUserUid : (SupaFlow.client.auth.currentUser?.id ?? '');
    final userEmail = _model.emailInputTextController.text.trim().isNotEmpty
        ? _model.emailInputTextController.text.trim()
        : (currentUserEmail.isNotEmpty ? currentUserEmail : (SupaFlow.client.auth.currentUser?.email ?? ''));

    if (_model.ciudadOrigen == null || _model.ciudadOrigen!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(i18n.isSpanish ? 'Por favor selecciona tu ciudad o la más cercana a tu ubicación.' : 'Please select your city or the nearest one to your location.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (userId.isNotEmpty) {
      final nombre = _model.firstNameTextController.text.trim();
      final cedula = _model.idTextController.text.trim();
      final telefono = _model.phoneNumberInputTextController.text.trim();
      final especialidadFinal = selectedRole == 'doctor'
          ? SpecialtiesService.formatEspecialidadesCompuestas(_selectedSpecialties, _subspecialtiesBySpecialty)
          : '';
      final bioText = _model.biografiaTextController?.text.trim() ?? '';

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('prontudoc_perfil_completo_$userId', true);
      } catch (_) {}

      try {
        await SupaFlow.client.auth.updateUser(UserAttributes(data: {
          'nombre': nombre,
          'full_name': nombre,
          'cedula': cedula,
          'telefono': telefono,
          'ciudad_origen': _model.ciudadOrigen,
          'rol': selectedRole,
          'foto_url': _localPhotoUrl,
          'avatar_url': _localPhotoUrl,
          'perfil_completo': true,
          if (selectedRole == 'doctor') 'especialidad': especialidadFinal,
          if (selectedRole == 'doctor' && bioText.isNotEmpty) 'biografia': bioText,
        }));
      } catch (_) {}

      try {
        await UsuariosTable().upsert({
          'id': userId,
          'nombre': nombre,
          'cedula': cedula,
          'telefono': telefono,
          'email': userEmail,
          'rol': selectedRole,
          'foto_url': _localPhotoUrl,
          'ciudad_origen': _model.ciudadOrigen,
        });
      } catch (e) {
        debugPrint('Error actualizando perfil en usuarios: $e');
      }

      if (selectedRole == 'doctor') {
        try {
          await DualDatabaseConfig.instance.patientClient.from('doctores').upsert({
            'id': userId,
            'especialidad': especialidadFinal,
            if (bioText.isNotEmpty) 'biografia': bioText,
          });
        } catch (_) {}
        try {
          await DoctorPatientSyncService().asegurarDoctorEnBaseClinica(
            idDoctor: userId,
            nombre: nombre,
            email: userEmail,
            telefono: telefono,
            fotoUrl: _localPhotoUrl,
            especialidad: especialidadFinal,
          );
          if (bioText.isNotEmpty) {
            await DoctoresTable().update(data: {'biografia': bioText, 'especialidad': especialidadFinal}, matchingRows: (q) => q.eq('id', userId));
          }
        } catch (_) {}
      } else if (selectedRole == 'paciente') {
        try {
          await PacientesTable().upsert({
            'id': userId, 'id_usuario': userId, 'nombre': nombre, 'cedula': cedula, 'telefono': telefono,
            'email': userEmail, 'ciudad_origen': _model.ciudadOrigen, 'fecha_nacimiento': _fechaNacimiento?.toIso8601String(), 'cuenta_vinculada': true,
          });
          final linkRes = await PatientAccountLinkingService.instance.vincularCuentaPorCedulaOTelefono(
            idUsuarioAuth: userId, nombreUsuario: nombre, cedula: cedula, telefono: telefono, email: userEmail,
          );
          if (mounted && (linkRes.citasReclamadas > 0 || linkRes.examenesReclamados > 0)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(linkRes.mensaje), backgroundColor: Colors.teal));
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    if (widget.esEdicion) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.isSpanish ? 'Perfil actualizado exitosamente' : 'Profile updated successfully'), backgroundColor: Colors.teal),
      );
      context.goNamedAuth(MyAccountWidget.routeName, mounted);
      return;
    }
    if (selectedRole == 'doctor') {
      bool tieneSedes = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        final setupDone = prefs.getBool('prontudoc_setup_completo_$userId') ?? false;
        final sedes = await DoctorSedesTable().queryRows(queryFn: (q) => q.eq('id_doctor', userId).limit(1));
        tieneSedes = setupDone || sedes.isNotEmpty;
      } catch (_) {}
      if (!mounted) return;
      final targetRoute = tieneSedes ? DoctorAgendaPanelWidget.routeName : DoctorSetupWidget.routeName;
      context.goNamedAuth(targetRoute, mounted, queryParameters: {'idDoctor': serializeParam(userId, ParamType.String)}.withoutNulls);
    } else {
      context.goNamedAuth(HomeWidget.routeName, mounted);
    }
  }

  Widget _buildInput({
    required FlutterFlowTheme theme,
    required TextEditingController? controller,
    required FocusNode? focusNode,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.next,
    int maxLines = 1,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: theme.labelMedium.override(font: GoogleFonts.mooli()),
        prefixIcon: Icon(icon, color: theme.secondaryText, size: 20.0),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x6257636C), width: 1.0), borderRadius: BorderRadius.circular(12.0)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.primary, width: 1.5), borderRadius: BorderRadius.circular(12.0)),
        filled: true,
        fillColor: theme.primaryBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      ),
      style: theme.bodyMedium.override(font: GoogleFonts.mooli()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;
    final theme = FlutterFlowTheme.of(context);
    final isDoctor = (widget.rol ?? '').toLowerCase() == 'doctor';
    final userRole = widget.rol ?? (i18n.isSpanish ? 'Paciente' : 'Patient');
    final isDesktop = MediaQuery.of(context).size.width >= 900.0;

    final Widget formCard = Container(
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: theme.alternate, width: 1.0),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16.0, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CreateProfileHeaderSection(
            isDoctor: isDoctor,
            userRole: userRole,
            esEdicion: widget.esEdicion,
            onBack: () => context.goNamed(MyAccountWidget.routeName),
          ),
          const SizedBox(height: 18.0),
          CreateProfilePhotoSection(
            photoUrl: _localPhotoUrl,
            onUploadPressed: () => _seleccionarYSubirFoto(context),
            onDeletePressed: () => _eliminarFotoActual(context),
          ),
          const SizedBox(height: 20.0),
          _buildInput(theme: theme, controller: _model.firstNameTextController, focusNode: _model.firstNameFocusNode, label: i18n.isSpanish ? 'Nombre Completo' : 'Full Name', icon: Icons.person_outline),
          const SizedBox(height: 14.0),
          _buildInput(theme: theme, controller: _model.idTextController, focusNode: _model.idFocusNode, label: i18n.isSpanish ? 'Cédula / Documento de Identidad' : 'ID / Identification', icon: Icons.badge_outlined),
          const SizedBox(height: 14.0),
          _buildInput(theme: theme, controller: _model.phoneNumberInputTextController, focusNode: _model.phoneNumberInputFocusNode, label: i18n.isSpanish ? 'Teléfono / WhatsApp (Opcional)' : 'Phone / WhatsApp (Optional)', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 14.0),
          CreateProfileLocationSelector(
            estadoOrigen: _model.estadoOrigen,
            ciudadActual: _model.ciudadTextController?.text,
            ciudadOrigenCompleta: _model.ciudadOrigen,
            onEstadoSelected: (est) => safeSetState(() {
              _model.estadoOrigen = est;
              _model.estadoTextController?.text = est;
              _model.ciudadOrigen = null;
              _model.ciudadTextController?.text = '';
            }),
            onCiudadSelected: (ciu, formatted) => safeSetState(() {
              _model.ciudadTextController?.text = ciu;
              _model.ciudadOrigen = formatted;
            }),
          ),
          const SizedBox(height: 14.0),
          FlutterFlowDropDown<String>(
            controller: _model.genderValueController ??= FormFieldController<String>(_model.genderValue ??= ''),
            options: i18n.isSpanish ? ['Masculino', 'Femenino', 'Otro'] : ['Male', 'Female', 'Other'],
            optionLabels: i18n.isSpanish ? ['Masculino', 'Femenino', 'Otro'] : ['Male', 'Female', 'Other'],
            onChanged: (val) => safeSetState(() => _model.genderValue = val),
            width: double.infinity,
            height: 50.0,
            textStyle: theme.bodyMedium.override(font: GoogleFonts.mooli(), fontSize: 14.0),
            hintText: i18n.isSpanish ? 'Seleccionar Género' : 'Select Gender',
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.secondaryText, size: 24.0),
            fillColor: theme.primaryBackground,
            elevation: 2.0,
            borderColor: const Color(0x6257636C),
            borderWidth: 1.0,
            borderRadius: 12.0,
            margin: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
            hidesUnderline: true,
            isOverButton: false,
            isSearchable: false,
            isMultiSelect: false,
          ),
          if (isDoctor) ...[
            const SizedBox(height: 16.0),
            CreateProfileSpecialtiesSection(
              selectedSpecialties: _selectedSpecialties,
              subspecialtiesBySpecialty: _subspecialtiesBySpecialty,
              onChanged: (specs, subsBySpec) => safeSetState(() {
                _selectedSpecialties = specs;
                _subspecialtiesBySpecialty = subsBySpec;
                _model.selectedSpecialty = specs.isNotEmpty ? specs.first : null;
                _model.specialtyTextController?.text = specs.join(', ');
              }),
            ),
            const SizedBox(height: 14.0),
            _buildInput(theme: theme, controller: _model.biografiaTextController, focusNode: _model.biografiaFocusNode, label: i18n.isSpanish ? 'Breve Presentación / Biografía (Opcional)' : 'Short Bio / Presentation (Optional)', icon: Icons.description_outlined, maxLines: 2, textInputAction: TextInputAction.done, onSubmitted: (_) async => _guardarPerfil()),
          ],
          const SizedBox(height: 24.0),
          CreateProfileSaveButton(onTap: _guardarPerfil, esEdicion: widget.esEdicion),
        ],
      ),
    );

    return PopScope(
      canPop: widget.esEdicion,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: theme.primaryBackground,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: isDesktop
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [Expanded(child: formCard), const SizedBox(width: 28.0), Expanded(child: CreateProfileDesktopBanner(isDoctor: isDoctor))],
                        ),
                      )
                    : ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520.0), child: formCard),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

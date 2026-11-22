import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/i18n_service.dart';
import '/services/doctors_service.dart';
import '/services/patient_location_service.dart';
import '/services/specialties_service.dart';
import '/services/venezuela_locations.dart';
import '/components/skeleton_shimmer.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'category_list_model.dart';
export 'category_list_model.dart';

class CategoryListWidget extends StatefulWidget {
  final String? specialty;

  const CategoryListWidget({
    super.key,
    this.specialty,
  });

  static String routeName = 'CategoryList';
  static String routePath = '/categoryList';

  @override
  State<CategoryListWidget> createState() => _CategoryListWidgetState();
}

class _CategoryListWidgetState extends State<CategoryListWidget> {
  late CategoryListModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  String _searchQuery = '';
  String? _selectedSubspecialty;
  bool _onlyMyCity = true;
  List<DoctorItem> _allDoctors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CategoryListModel());
    _loadDoctors();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final docs = await DoctorsService.instance.getDoctors(
        filterSpecialty: widget.specialty,
      );
      if (mounted) {
        setState(() {
          _allDoctors = docs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Extrae todas las subespecialidades disponibles entre los doctores cargados y las sugeridas de la especialidad
  List<String> _extractSubspecialties() {
    final Set<String> subs = {};
    if (widget.specialty != null && widget.specialty!.trim().isNotEmpty) {
      subs.addAll(SpecialtiesService.getSugerenciasSubespecialidad(widget.specialty));
    }
    for (final doc in _allDoctors) {
      final parsed = SpecialtiesService.parseEspecialidadesCompuestas(doc.specialty);
      for (final list in parsed.subespecialidades.values) {
        subs.addAll(list);
      }
    }
    return subs.toList();
  }

  List<DoctorItem> _getFilteredDoctors(String currentLocation) {
    final currentCityNorm = VenezuelaLocations.normalize(currentLocation.split(',').first.trim());
    final queryNorm = VenezuelaLocations.normalize(_searchQuery);
    final subNorm = _selectedSubspecialty != null ? VenezuelaLocations.normalize(_selectedSubspecialty!) : null;

    var list = _allDoctors.where((doc) {
      if (subNorm != null && subNorm.isNotEmpty) {
        final specNorm = VenezuelaLocations.normalize(doc.specialty);
        final bioNorm = VenezuelaLocations.normalize(doc.biography ?? '');
        if (!specNorm.contains(subNorm) && !bioNorm.contains(subNorm)) {
          return false;
        }
      }
      if (queryNorm.isNotEmpty) {
        final matchName = VenezuelaLocations.normalize(doc.name).contains(queryNorm);
        final matchSpec = VenezuelaLocations.normalize(doc.specialty).contains(queryNorm);
        final matchCity = VenezuelaLocations.normalize(doc.city ?? '').contains(queryNorm);
        final matchClinic = VenezuelaLocations.normalize(doc.clinics ?? '').contains(queryNorm);
        if (!matchName && !matchSpec && !matchCity && !matchClinic) {
          return false;
        }
      }
      if (_onlyMyCity && currentCityNorm.isNotEmpty && !currentCityNorm.contains('venezuela')) {
        final docCityNorm = VenezuelaLocations.normalize(doc.city ?? '');
        if (!docCityNorm.contains(currentCityNorm)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Si en la ciudad predeterminada no hay médicos de esta especialidad y el usuario no ha forzado filtro,
    // ordenamos primero los de la ciudad del usuario y luego el resto
    if (list.isEmpty && _onlyMyCity && _allDoctors.isNotEmpty && _searchQuery.isEmpty && _selectedSubspecialty == null) {
      list = List<DoctorItem>.from(_allDoctors);
    }

    // Ordenar priorizando la ciudad seleccionada por el usuario
    if (currentCityNorm.isNotEmpty) {
      final sameCity = list.where((d) => VenezuelaLocations.normalize(d.city ?? '').contains(currentCityNorm)).toList();
      final otherCity = list.where((d) => !VenezuelaLocations.normalize(d.city ?? '').contains(currentCityNorm)).toList();
      return [...sameCity, ...otherCity];
    }
    return list;
  }

  Widget _buildDoctorTile(BuildContext context, DoctorItem doctor) {
    final isSpanish = I18nService.instance.isSpanish;
    final theme = FlutterFlowTheme.of(context);
    final parsed = SpecialtiesService.parseEspecialidadesCompuestas(doctor.specialty);
    final allDocSubs = <String>[];
    for (final sList in parsed.subespecialidades.values) {
      allDocSubs.addAll(sList);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: theme.alternate, width: 1.0),
        boxShadow: const [
          BoxShadow(
            blurRadius: 4.0,
            color: Color(0x10000000),
            offset: Offset(0.0, 2.0),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.0),
        onTap: () {
          context.pushNamed(
            DoctorPublicProfileWidget.routeName,
            queryParameters: {
              'alias': serializeParam(doctor.alias, ParamType.String),
              'nombreDoctor': serializeParam(doctor.name, ParamType.String),
              'especialidadDoctor': serializeParam(doctor.specialty, ParamType.String),
              'fotoUrlDoctor': serializeParam(doctor.photoUrl, ParamType.String),
            }.withoutNulls,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Container(
                  width: 84.0,
                  height: 84.0,
                  color: theme.primaryBackground,
                  child: doctor.photoUrl != null && doctor.photoUrl!.isNotEmpty
                      ? Image.network(
                          doctor.photoUrl!,
                          width: 84.0,
                          height: 84.0,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person_rounded,
                            size: 42.0,
                            color: theme.secondaryText,
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: 42.0,
                          color: theme.secondaryText,
                        ),
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      doctor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium.override(
                        font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                        color: theme.primaryText,
                        fontSize: 15.0,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      parsed.especialidades.isNotEmpty
                          ? parsed.especialidades.join(' • ')
                          : doctor.specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium.override(
                        font: GoogleFonts.mooli(fontWeight: FontWeight.w600),
                        color: theme.primary,
                        fontSize: 12.5,
                      ),
                    ),
                    if (allDocSubs.isNotEmpty) ...[
                      const SizedBox(height: 4.0),
                      Wrap(
                        spacing: 4.0,
                        runSpacing: 4.0,
                        children: allDocSubs.take(3).map((sub) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: theme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              sub,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: theme.primary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 5.0),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13.5,
                          color: theme.secondaryText,
                        ),
                        const SizedBox(width: 3.0),
                        Expanded(
                          child: Text(
                            doctor.city ?? doctor.clinics ?? 'Venezuela',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodySmall.override(
                              font: GoogleFonts.mooli(),
                              color: theme.secondaryText,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            context.pushNamed(
                              RequestAppointmentWidget.routeName,
                              queryParameters: {
                                'alias': serializeParam(doctor.alias, ParamType.String),
                                'nombreDoctor': serializeParam(doctor.name, ParamType.String),
                                'especialidadDoctor': serializeParam(doctor.specialty, ParamType.String),
                              }.withoutNulls,
                            );
                          },
                          borderRadius: BorderRadius.circular(16.0),
                          child: Container(
                            height: 30.0,
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [theme.secondary, theme.primary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isSpanish ? 'Agendar Cita' : 'Book Appointment',
                              style: theme.bodySmall.override(
                                font: GoogleFonts.mooli(fontWeight: FontWeight.w600),
                                color: Colors.white,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        TextButton(
                          onPressed: () {
                            context.pushNamed(
                              DoctorPublicProfileWidget.routeName,
                              queryParameters: {
                                'alias': serializeParam(doctor.alias, ParamType.String),
                                'nombreDoctor': serializeParam(doctor.name, ParamType.String),
                                'especialidadDoctor': serializeParam(doctor.specialty, ParamType.String),
                                'fotoUrlDoctor': serializeParam(doctor.photoUrl, ParamType.String),
                              }.withoutNulls,
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                            minimumSize: const Size(0, 30),
                          ),
                          child: Text(
                            isSpanish ? 'Ver perfil' : 'View profile',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSpanish = I18nService.instance.isSpanish;
    final theme = FlutterFlowTheme.of(context);
    final subspecialties = _extractSubspecialties();
    final titleText = (widget.specialty != null && widget.specialty!.trim().isNotEmpty)
        ? widget.specialty!
        : (isSpanish ? 'Especialistas' : 'Specialists');

    return ValueListenableBuilder<String>(
      valueListenable: PatientLocationService.instance.currentLocationNotifier,
      builder: (context, currentLocation, _) {
        final cityOnly = PatientLocationService.instance.currentCityOnly;
        final filteredDoctors = _getFilteredDoctors(currentLocation);
        final hasDoctorsInMyCity = _allDoctors.any((d) =>
            VenezuelaLocations.normalize(d.city ?? '')
                .contains(VenezuelaLocations.normalize(cityOnly)));

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: theme.primaryBackground,
            body: SafeArea(
              top: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  if (Navigator.of(context).canPop()) {
                                    context.safePop();
                                  } else {
                                    context.goNamed(HomeWidget.routeName);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10.0),
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    color: theme.primaryText,
                                    size: 24.0,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  titleText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.titleMedium.override(
                                    font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                                    fontSize: 18.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Selector de ubicación predeterminada del usuario
                        InkWell(
                          onTap: () => PatientLocationService.instance.mostrarSelectorUbicacion(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.secondaryBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.alternate),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_rounded, size: 15, color: theme.primary),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 130),
                                  child: Text(
                                    cityOnly,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.mooli(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: theme.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    // Buscador tolerante a acentos + Filtro de ciudad
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.secondaryBackground,
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: theme.alternate),
                            ),
                            child: TextField(
                              onChanged: (val) => safeSetState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: isSpanish
                                    ? 'Buscar médico o subespecialidad...'
                                    : 'Search doctor or subspecialty...',
                                hintStyle: TextStyle(fontSize: 12.5, color: theme.secondaryText),
                                prefixIcon: Icon(Icons.search_rounded, size: 19, color: theme.primary),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 11.0, horizontal: 12.0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        FilterChip(
                          label: Text(
                            _onlyMyCity && hasDoctorsInMyCity
                                ? cityOnly
                                : (isSpanish ? 'Todas las ciudades' : 'All cities'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: (_onlyMyCity && hasDoctorsInMyCity) ? Colors.white : theme.primaryText,
                            ),
                          ),
                          selected: _onlyMyCity && hasDoctorsInMyCity,
                          selectedColor: theme.primary,
                          checkmarkColor: Colors.white,
                          backgroundColor: theme.secondaryBackground,
                          onSelected: (val) => safeSetState(() => _onlyMyCity = val),
                        ),
                      ],
                    ),
                    // Barra horizontal de Subespecialidades
                    if (subspecialties.isNotEmpty) ...[
                      const SizedBox(height: 10.0),
                      SizedBox(
                        height: 34.0,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
                                label: Text(
                                  isSpanish ? 'Todas' : 'All',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedSubspecialty == null ? Colors.white : theme.primaryText,
                                  ),
                                ),
                                selected: _selectedSubspecialty == null,
                                selectedColor: theme.primary,
                                backgroundColor: theme.secondaryBackground,
                                onSelected: (_) => safeSetState(() => _selectedSubspecialty = null),
                              ),
                            ),
                            ...subspecialties.map((sub) {
                              final isSel = _selectedSubspecialty == sub;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ChoiceChip(
                                  label: Text(
                                    sub,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isSel ? Colors.white : theme.primaryText,
                                    ),
                                  ),
                                  selected: isSel,
                                  selectedColor: theme.primary,
                                  backgroundColor: theme.secondaryBackground,
                                  onSelected: (selected) => safeSetState(() {
                                    _selectedSubspecialty = selected ? sub : null;
                                  }),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12.0),
                    Expanded(
                      child: _isLoading
                          ? SkeletonDoctorCard.list(count: 4)
                          : filteredDoctors.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_search_rounded, size: 46, color: theme.secondaryText),
                                      const SizedBox(height: 10),
                                      Text(
                                        isSpanish
                                            ? 'No se encontraron especialistas con estos filtros.'
                                            : 'No specialists found with these filters.',
                                        textAlign: TextAlign.center,
                                        style: theme.bodyMedium.override(
                                          font: GoogleFonts.mooli(),
                                          color: theme.secondaryText,
                                        ),
                                      ),
                                      if (_onlyMyCity || _selectedSubspecialty != null) ...[
                                        const SizedBox(height: 10),
                                        TextButton.icon(
                                          onPressed: () => safeSetState(() {
                                            _onlyMyCity = false;
                                            _selectedSubspecialty = null;
                                            _searchQuery = '';
                                          }),
                                          icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                                          label: Text(isSpanish ? 'Ver en todas las ciudades' : 'View in all cities'),
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredDoctors.length,
                                  itemBuilder: (context, index) {
                                    return _buildDoctorTile(context, filteredDoctors[index]);
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/i18n_service.dart';
import '/services/doctors_service.dart';
import '/services/patient_location_service.dart';
import '/services/venezuela_locations.dart';
import '/components/skeleton_shimmer.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'top_doctors_model.dart';
export 'top_doctors_model.dart';

typedef DoctorsNearWidget = TopDoctorsWidget;

class TopDoctorsWidget extends StatefulWidget {
  const TopDoctorsWidget({super.key});

  static String routeName = 'DoctorsNear';
  static String routePath = '/doctorsNear';

  @override
  State<TopDoctorsWidget> createState() => _TopDoctorsWidgetState();
}

class _TopDoctorsWidgetState extends State<TopDoctorsWidget> {
  late TopDoctorsModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TopDoctorsModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  String _cleanCityName(DoctorItem doctor) {
    final raw = (doctor.city ?? '').trim();
    if (raw.isEmpty || raw.toLowerCase() == 'venezuela') {
      return I18nService.instance.isSpanish ? 'Otras ubicaciones' : 'Other locations';
    }
    return raw.split(',').first.trim();
  }

  Widget _buildCompactDoctorCard(BuildContext context, DoctorItem doctor) {
    final isSpanish = I18nService.instance.isSpanish;
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
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
      child: Container(
        padding: const EdgeInsets.all(11.0),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: theme.alternate, width: 1.0),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4.0,
              color: Color(0x0D000000),
              offset: Offset(0.0, 2.0),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: Container(
                width: 72.0,
                height: 72.0,
                color: theme.primaryBackground,
                child: doctor.photoUrl != null && doctor.photoUrl!.isNotEmpty
                    ? Image.network(
                        doctor.photoUrl!,
                        width: 72.0,
                        height: 72.0,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person_rounded,
                          size: 36.0,
                          color: theme.secondaryText,
                        ),
                      )
                    : Icon(
                        Icons.person_rounded,
                        size: 36.0,
                        color: theme.secondaryText,
                      ),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyMedium.override(
                      font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                      color: theme.primaryText,
                      fontSize: 14.0,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    doctor.specialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyMedium.override(
                      font: GoogleFonts.mooli(fontWeight: FontWeight.w600),
                      color: theme.primary,
                      fontSize: 12.0,
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13.0,
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
                            fontSize: 11.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7.0),
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
                        borderRadius: BorderRadius.circular(14.0),
                        child: Container(
                          height: 27.0,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [theme.secondary, theme.primary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isSpanish ? 'Agendar Cita' : 'Book',
                            style: theme.bodySmall.override(
                              font: GoogleFonts.mooli(fontWeight: FontWeight.w600),
                              color: Colors.white,
                              fontSize: 11.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        isSpanish ? 'Ver perfil' : 'Profile',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600,
                          color: theme.primary,
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
    );
  }

  /// Agrupa los doctores manteniendo el orden de cercanía (1º Ciudad del usuario, 2º Ciudades cercanas, 3º Otras ciudades)
  List<MapEntry<String, List<DoctorItem>>> _groupDoctorsByCity(
    List<DoctorItem> doctors,
    String userCity,
  ) {
    final Map<String, List<DoctorItem>> grouped = {};
    final List<String> cityOrder = [];
    final userCityNorm = VenezuelaLocations.normalize(userCity);
    final isEs = I18nService.instance.isSpanish;

    for (final doc in doctors) {
      final rawCity = _cleanCityName(doc);
      final isUserCity = userCityNorm.isNotEmpty &&
          VenezuelaLocations.normalize(rawCity).contains(userCityNorm);
      final headerTitle = isUserCity
          ? (isEs ? '📍 En tu ciudad ($rawCity)' : '📍 In your city ($rawCity)')
          : '📍 $rawCity';

      if (!grouped.containsKey(headerTitle)) {
        grouped[headerTitle] = [];
        cityOrder.add(headerTitle);
      }
      grouped[headerTitle]!.add(doc);
    }

    return cityOrder.map((k) => MapEntry(k, grouped[k]!)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isSpanish = I18nService.instance.isSpanish;
    final theme = FlutterFlowTheme.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: PatientLocationService.instance.currentLocationNotifier,
      builder: (context, currentLocation, _) {
        final cityOnly = PatientLocationService.instance.currentCityOnly;

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
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                if (Navigator.of(context).canPop()) {
                                  context.safePop();
                                } else {
                                  context.goNamed(HomeWidget.routeName);
                                }
                              },
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: theme.primaryText,
                                size: 24.0,
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Text(
                              isSpanish ? 'Doctores cerca de ti' : 'Doctors near you',
                              style: theme.titleMedium.override(
                                font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                                fontSize: 18.0,
                              ),
                            ),
                          ],
                        ),
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
                                Icon(Icons.edit_rounded, size: 13, color: theme.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    // Buscador tolerante a acentos
                    Container(
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
                              ? 'Buscar doctor, especialidad o ciudad...'
                              : 'Search doctor, specialty, or city...',
                          hintStyle: TextStyle(fontSize: 12.5, color: theme.secondaryText),
                          prefixIcon: Icon(Icons.search_rounded, size: 19, color: theme.primary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11.0, horizontal: 12.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14.0),
                    // Doctors grouped by City
                    Expanded(
                      child: FutureBuilder<List<DoctorItem>>(
                        future: DoctorsService.instance.getDoctors(
                          filterCity: currentLocation,
                          randomizeRotation: true,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return SkeletonDoctorCard.list(count: 5);
                          }

                          var doctors = snapshot.data ?? [];
                          if (_searchQuery.trim().isNotEmpty) {
                            final q = VenezuelaLocations.normalize(_searchQuery);
                            doctors = doctors.where((d) =>
                                VenezuelaLocations.normalize(d.name).contains(q) ||
                                VenezuelaLocations.normalize(d.specialty).contains(q) ||
                                VenezuelaLocations.normalize(d.city ?? '').contains(q) ||
                                VenezuelaLocations.normalize(d.clinics ?? '').contains(q)).toList();
                          }

                          if (doctors.isEmpty) {
                            return Center(
                              child: Text(
                                isSpanish
                                    ? 'No se encontraron doctores registrados.'
                                    : 'No doctors found.',
                                style: theme.bodyMedium.override(
                                  font: GoogleFonts.mooli(),
                                  color: theme.secondaryText,
                                ),
                              ),
                            );
                          }

                          final citySections = _groupDoctorsByCity(doctors, cityOnly);

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth > 1050
                                  ? 3
                                  : (constraints.maxWidth > 650 ? 2 : 1);
                              final spacing = 12.0;
                              final cardWidth = columns == 1
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

                              return ListView.builder(
                                itemCount: citySections.length,
                                itemBuilder: (context, secIdx) {
                                  final section = citySections[secIdx];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 18.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 10.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: theme.primary.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  section.key,
                                                  style: GoogleFonts.mooli(
                                                    fontSize: 13.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: theme.primary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '(${section.value.length})',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.secondaryText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Wrap(
                                          spacing: spacing,
                                          runSpacing: spacing,
                                          children: section.value.map((doc) {
                                            return SizedBox(
                                              width: cardWidth,
                                              child: _buildCompactDoctorCard(context, doc),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
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

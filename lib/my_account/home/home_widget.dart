import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/services/i18n_service.dart';
import '/services/patient_location_service.dart';
import '/services/doctors_service.dart';
import '/services/medical_specialties_service.dart';
import '/services/citas_service.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_model.dart';
export 'home_model.dart';

class HomeWidget extends StatefulWidget {
  const HomeWidget({super.key});

  static String routeName = 'Home';
  static String routePath = '/home';

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  late HomeModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeModel());
    PatientLocationService.instance.currentLocationNotifier.addListener(_onLocationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  void _onLocationChanged() {
    if (mounted) safeSetState(() {});
  }

  @override
  void dispose() {
    PatientLocationService.instance.currentLocationNotifier.removeListener(_onLocationChanged);
    _model.dispose();
    super.dispose();
  }

  Widget _buildDoctorCard(BuildContext context, DoctorItem doctor) {
    final isSpanish = I18nService.instance.isSpanish;
    return Container(
      width: 180.0,
      margin: const EdgeInsetsDirectional.only(end: 14.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6.0,
            color: Color(0x0C000000),
            offset: Offset(0.0, 3.0),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor Image & Info (Tappable for Public Profile)
            InkWell(
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () async {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      width: double.infinity,
                      height: 115.0,
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      child: doctor.photoUrl != null && doctor.photoUrl!.isNotEmpty
                          ? Image.network(
                              doctor.photoUrl!,
                              width: double.infinity,
                              height: 115.0,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 52.0,
                                  color: FlutterFlowTheme.of(context).secondaryText.withValues(alpha: 0.6),
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.person_rounded,
                                size: 52.0,
                                color: FlutterFlowTheme.of(context).secondaryText.withValues(alpha: 0.6),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  // Doctor Name (Dr. / Dra. [Nombre])
                  Text(
                    doctor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.mooli(
                            fontWeight: FontWeight.bold,
                          ),
                          color: FlutterFlowTheme.of(context).primaryText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 3.0),
                  // Specialty
                  Text(
                    doctor.specialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.mooli(
                            fontWeight: FontWeight.w600,
                          ),
                          color: FlutterFlowTheme.of(context).primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 5.0),
                  // City / Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14.0,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                      const SizedBox(width: 3.0),
                      Expanded(
                        child: Text(
                          doctor.city ?? doctor.clinics ?? 'Venezuela',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                font: GoogleFonts.mooli(),
                                color: FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 11.0,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Agendar Cita Button
            InkWell(
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () async {
                context.pushNamed(
                  RequestAppointmentWidget.routeName,
                  queryParameters: {
                    'alias': serializeParam(doctor.alias, ParamType.String),
                    'nombreDoctor': serializeParam(doctor.name, ParamType.String),
                    'especialidadDoctor': serializeParam(doctor.specialty, ParamType.String),
                  }.withoutNulls,
                );
              },
              child: Container(
                width: double.infinity,
                height: 34.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FlutterFlowTheme.of(context).secondary,
                      FlutterFlowTheme.of(context).primary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.25),
                      blurRadius: 6.0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  isSpanish ? 'Agendar Cita' : 'Book Now',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.mooli(
                          fontWeight: FontWeight.bold,
                        ),
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
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
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24.0, 20.0, 24.0, 30.0),
              child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barra de búsqueda: solo en versión móvil ya que en escritorio está en la barra superior
                      if (!isDesktop)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
                          child: InkWell(
                            onTap: () => context.pushNamed(DoctorsListWidget.routeName),
                            borderRadius: BorderRadius.circular(20.0),
                            child: Container(
                              width: double.infinity,
                              height: 40.0,
                              padding: const EdgeInsets.symmetric(horizontal: 14.0),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).primaryBackground,
                                borderRadius: BorderRadius.circular(20.0),
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    size: 18.0,
                                    color: Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Text(
                                      I18nService.instance.isSpanish
                                          ? 'Buscar médicos por especialidad...'
                                          : 'Search doctors by specialty...',
                                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                                            font: GoogleFonts.mooli(
                                              fontWeight: FontWeight.w500,
                                            ),
                                            color: FlutterFlowTheme.of(context).secondaryText,
                                            fontSize: 12.0,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 0.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 256.6,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Text(
                                I18nService.instance.isSpanish ? 'Especialidades Médicas' : 'Doctor Specialities',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.mooli(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                              ),
                            ].divide(const SizedBox(width: 5.0)),
                          ),
                        ),
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            context
                                .pushNamed(DoctorSpecialitiesWidget.routeName);
                          },
                          child: Text(
                            I18nService.instance.isSpanish ? 'Ver todos' : 'See all',
                            style: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.mooli(
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: const AlignmentDirectional(-1.0, 0.0),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(0.0, 14.0, 0.0, 0.0),
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(right: 28.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: MedicalSpecialtiesService.list.map((specialty) {
                                return Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 16.0),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      context.pushNamed(
                                        CategoryListWidget.routeName,
                                        queryParameters: {
                                          'specialty': serializeParam(specialty.nameEs, ParamType.String),
                                        }.withoutNulls,
                                      );
                                    },
                                    child: SizedBox(
                                      width: 72.0,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 58.0,
                                            height: 58.0,
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
                                              boxShadow: const [
                                                BoxShadow(
                                                  blurRadius: 6.0,
                                                  color: Color(0x15000000),
                                                  offset: Offset(0.0, 2.0),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: 38.0,
                                                height: 38.0,
                                                clipBehavior: Clip.antiAlias,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Image.asset(
                                                  specialty.assetImage,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Icon(
                                                    Icons.medical_services_rounded,
                                                    color: Colors.white,
                                                    size: 22.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                                            child: Text(
                                              specialty.getLocalizedName(I18nService.instance.isSpanish),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                    font: GoogleFonts.mooli(
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    fontSize: 11.5,
                                                    letterSpacing: 0.0,
                                                    color: FlutterFlowTheme.of(context).primaryText,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          // Indicador visual de que la barra es scrolleable horizontalmente
                          IgnorePointer(
                            child: Container(
                              width: 36.0,
                              height: 92.0,
                              alignment: Alignment.centerRight,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    FlutterFlowTheme.of(context).secondaryBackground.withValues(alpha: 0.0),
                                    FlutterFlowTheme.of(context).secondaryBackground.withValues(alpha: 0.92),
                                  ],
                                ),
                              ),
                              child: Container(
                                width: 22.0,
                                height: 22.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16.0,
                                  color: FlutterFlowTheme.of(context).primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Doctores cerca de ti / Doctors near you
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 10.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 256.6,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Text(
                                I18nService.instance.isSpanish ? 'Doctores cerca de ti' : 'Doctors near you',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.mooli(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                              ),
                            ].divide(const SizedBox(width: 5.0)),
                          ),
                        ),
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            context.pushNamed(TopDoctorsWidget.routeName);
                          },
                          child: Text(
                            I18nService.instance.isSpanish ? 'Ver todos' : 'See all',
                            style: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.mooli(
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dynamic Doctors List from Supabase Database (max 5 same city randomly rotated, then nearby cities, then others)
                  FutureBuilder<List<DoctorItem>>(
                    future: DoctorsService.instance.getDoctors(
                      filterCity: PatientLocationService.instance.currentLocation,
                      maxSameCity: 5,
                      randomizeRotation: true,
                      limit: 15,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          height: 255.0,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        );
                      }

                      final doctors = snapshot.data ?? [];
                      if (doctors.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).secondaryBackground,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate,
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 52.0,
                                height: 52.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.medical_services_outlined,
                                  size: 26.0,
                                  color: FlutterFlowTheme.of(context).primary,
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              Text(
                                I18nService.instance.isSpanish
                                    ? 'No se ha registrado ningún doctor en la aplicación'
                                    : 'No doctors have been registered in the application',
                                textAlign: TextAlign.center,
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                      font: GoogleFonts.mooli(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                      fontSize: 13.5,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }

                      return SizedBox(
                        height: 255.0,
                        child: Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(right: 28.0),
                              itemCount: doctors.length,
                              itemBuilder: (context, index) {
                                return _buildDoctorCard(context, doctors[index]);
                              },
                            ),
                            if (doctors.length > 2)
                              IgnorePointer(
                                child: Container(
                                  width: 34.0,
                                  height: 255.0,
                                  alignment: Alignment.centerRight,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        FlutterFlowTheme.of(context).secondaryBackground.withValues(alpha: 0.0),
                                        FlutterFlowTheme.of(context).secondaryBackground.withValues(alpha: 0.88),
                                      ],
                                    ),
                                  ),
                                  child: Container(
                                    width: 24.0,
                                    height: 24.0,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      size: 17.0,
                                      color: FlutterFlowTheme.of(context).primary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 10.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 256.6,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Text(
                                I18nService.instance.isSpanish ? 'Próxima Cita' : 'Upcoming Schedule',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.mooli(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                              ),
                            ].divide(const SizedBox(width: 5.0)),
                          ),
                        ),
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            context.pushNamed(MyAppointmentWidget.routeName);
                          },
                          child: Text(
                            I18nService.instance.isSpanish ? 'Ver todas' : 'See all',
                            style: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.mooli(
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FutureBuilder<AppointmentItem?>(
                    future: CitasService.instance.getUpcomingAppointment(
                      isSpanish: I18nService.instance.isSpanish,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          width: double.infinity,
                          height: 120.0,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        );
                      }

                      final cita = snapshot.data;

                      if (cita == null) {
                        // Patient has no scheduled appointments
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).secondaryBackground,
                            borderRadius: BorderRadius.circular(14.0),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 4.0,
                                color: Color(0x10000000),
                                offset: Offset(0.0, 2.0),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44.0,
                                height: 44.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.calendar_today_rounded,
                                  color: FlutterFlowTheme.of(context).primary,
                                  size: 22.0,
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      I18nService.instance.isSpanish
                                          ? 'Sin citas programadas'
                                          : 'No scheduled appointments',
                                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                                            font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                                            fontSize: 13.5,
                                          ),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      I18nService.instance.isSpanish
                                          ? 'Agenda una consulta presencial con nuestros especialistas.'
                                          : 'Book an in-person consultation with our specialists.',
                                      style: FlutterFlowTheme.of(context).bodySmall.override(
                                            font: GoogleFonts.mooli(),
                                            color: FlutterFlowTheme.of(context).secondaryText,
                                            fontSize: 11.0,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              FFButtonWidget(
                                onPressed: () async {
                                  context.pushNamed(DoctorsListWidget.routeName);
                                },
                                text: I18nService.instance.isSpanish ? 'Agendar' : 'Book',
                                options: FFButtonOptions(
                                  height: 34.0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                  color: FlutterFlowTheme.of(context).primary,
                                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                        font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                                        color: Colors.white,
                                        fontSize: 12.0,
                                      ),
                                  elevation: 0.0,
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Patient has an appointment
                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).secondaryBackground,
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 6.0,
                              color: Color(0x18000000),
                              offset: Offset(0.0, 2.0),
                            )
                          ],
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12.0),
                                    child: Image.network(
                                      cita.doctorPhoto ??
                                          'https://images.unsplash.com/photo-1622253692010-333f2da6031d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=600',
                                      width: 50.0,
                                      height: 50.0,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 50.0,
                                        height: 50.0,
                                        color: FlutterFlowTheme.of(context).primaryBackground,
                                        child: Icon(Icons.person_rounded,
                                            color: FlutterFlowTheme.of(context).secondaryText),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          cita.doctorName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: FlutterFlowTheme.of(context).titleSmall.override(
                                                font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                                                fontSize: 15.0,
                                                color: FlutterFlowTheme.of(context).primaryText,
                                              ),
                                        ),
                                        const SizedBox(height: 2.0),
                                        Text(
                                          cita.consultationType,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                                font: GoogleFonts.mooli(),
                                                color: FlutterFlowTheme.of(context).primary,
                                                fontSize: 12.0,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (cita.doctorPhone != null && cita.doctorPhone!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(8.0),
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10.0),
                                      ),
                                      child: Icon(
                                        Icons.phone_outlined,
                                        color: FlutterFlowTheme.of(context).primary,
                                        size: 20.0,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12.0),
                              Divider(height: 1.0, color: FlutterFlowTheme.of(context).alternate),
                              const SizedBox(height: 12.0),
                              // Date & Time badges
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today_rounded,
                                              size: 15.0, color: FlutterFlowTheme.of(context).primary),
                                          const SizedBox(width: 6.0),
                                          Expanded(
                                            child: Text(
                                              cita.formattedDate,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: FlutterFlowTheme.of(context).bodySmall.override(
                                                    font: GoogleFonts.mooli(fontWeight: FontWeight.w600),
                                                    color: FlutterFlowTheme.of(context).primaryText,
                                                    fontSize: 11.0,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10.0),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context).secondary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time_rounded,
                                              size: 15.0, color: FlutterFlowTheme.of(context).secondary),
                                          const SizedBox(width: 6.0),
                                          Expanded(
                                            child: Text(
                                              cita.formattedTime,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: FlutterFlowTheme.of(context).bodySmall.override(
                                                    font: GoogleFonts.mooli(fontWeight: FontWeight.w600),
                                                    color: FlutterFlowTheme.of(context).primaryText,
                                                    fontSize: 11.0,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20.0),
                ].divide(const SizedBox(height: 0.0)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}

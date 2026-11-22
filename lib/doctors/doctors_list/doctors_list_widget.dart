import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/i18n_service.dart';
import '/services/doctors_service.dart';
import '/services/venezuela_locations.dart';
import '/components/skeleton_shimmer.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'doctors_list_model.dart';
export 'doctors_list_model.dart';

class DoctorsListWidget extends StatefulWidget {
  const DoctorsListWidget({super.key});

  static String routeName = 'DoctorsList';
  static String routePath = '/doctorsList';

  @override
  State<DoctorsListWidget> createState() => _DoctorsListWidgetState();
}

class _DoctorsListWidgetState extends State<DoctorsListWidget> {
  late DoctorsListModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DoctorsListModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Widget _buildDoctorTile(BuildContext context, DoctorItem doctor) {
    final isSpanish = I18nService.instance.isSpanish;
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
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
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12.0),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4.0,
              color: Color(0x10000000),
              offset: Offset(0.0, 2.0),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Doctor Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Container(
                  width: 90.0,
                  height: 90.0,
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  child: doctor.photoUrl != null && doctor.photoUrl!.isNotEmpty
                      ? Image.network(
                          doctor.photoUrl!,
                          width: 90.0,
                          height: 90.0,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person_rounded,
                            size: 45.0,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: 45.0,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                ),
              ),
              const SizedBox(width: 14.0),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      doctor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.mooli(
                              fontWeight: FontWeight.bold,
                            ),
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontSize: 15.0,
                          ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      doctor.specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.mooli(
                              fontWeight: FontWeight.w600,
                            ),
                            color: FlutterFlowTheme.of(context).primary,
                            fontSize: 12.5,
                          ),
                    ),
                    const SizedBox(height: 4.0),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13.0,
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
                    const SizedBox(height: 8.0),
                    // Button
                    Container(
                      height: 28.0,
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FlutterFlowTheme.of(context).secondary,
                            FlutterFlowTheme.of(context).primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isSpanish ? 'Ver Perfil y Horarios' : 'View Profile & Hours',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.mooli(
                                fontWeight: FontWeight.w600,
                              ),
                              color: FlutterFlowTheme.of(context).secondaryBackground,
                              fontSize: 11.5,
                            ),
                      ),
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 20.0, 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input Field
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).alternate,
                      width: 1.0,
                    ),
                  ),
                  child: TextField(
                    onChanged: (val) {
                      safeSetState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: isSpanish
                          ? 'Buscar por médico, especialidad o clínica...'
                          : 'Search by doctor, specialty, or clinic...',
                      hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.mooli(),
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                Text(
                  isSpanish ? 'Doctores Disponibles' : 'Available Doctors',
                  style: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.mooli(
                          fontWeight: FontWeight.w600,
                        ),
                        color: FlutterFlowTheme.of(context).primaryText,
                        fontSize: 15.0,
                      ),
                ),
                const SizedBox(height: 10.0),
                // Dynamic Doctors List
                Expanded(
                  child: FutureBuilder<List<DoctorItem>>(
                    future: DoctorsService.instance.getDoctors(),
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
                            (d.city != null && VenezuelaLocations.normalize(d.city!).contains(q)) ||
                            (d.clinics != null && VenezuelaLocations.normalize(d.clinics!).contains(q))).toList();
                      }

                      if (doctors.isEmpty) {
                        return Center(
                          child: Text(
                            isSpanish
                                ? 'No se encontraron doctores.'
                                : 'No doctors found.',
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.mooli(),
                                  color: FlutterFlowTheme.of(context).secondaryText,
                                ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: doctors.length,
                        itemBuilder: (context, index) {
                          return _buildDoctorTile(context, doctors[index]);
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
  }
}

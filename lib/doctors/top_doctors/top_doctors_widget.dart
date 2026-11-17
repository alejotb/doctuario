import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/i18n_service.dart';
import '/services/doctors_service.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'top_doctors_model.dart';
export 'top_doctors_model.dart';

class TopDoctorsWidget extends StatefulWidget {
  const TopDoctorsWidget({super.key});

  static String routeName = 'TopDoctors';
  static String routePath = '/topDoctors';

  @override
  State<TopDoctorsWidget> createState() => _TopDoctorsWidgetState();
}

class _TopDoctorsWidgetState extends State<TopDoctorsWidget> {
  late TopDoctorsModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

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

  Widget _buildDoctorCard(BuildContext context, DoctorItem doctor) {
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
            'idDoctor': serializeParam(doctor.id, ParamType.String),
            'nombreDoctor': serializeParam(doctor.name, ParamType.String),
            'especialidadDoctor': serializeParam(doctor.specialty, ParamType.String),
            'fotoUrlDoctor': serializeParam(doctor.photoUrl, ParamType.String),
          }.withoutNulls,
        );
      },
      child: Container(
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
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Container(
                  width: double.infinity,
                  height: 120.0,
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  child: doctor.photoUrl != null && doctor.photoUrl!.isNotEmpty
                      ? Image.network(
                          doctor.photoUrl!,
                          width: double.infinity,
                          height: 120.0,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person_rounded,
                            size: 50.0,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: 50.0,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                doctor.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.mooli(
                        fontWeight: FontWeight.bold,
                      ),
                      color: FlutterFlowTheme.of(context).primaryText,
                      fontSize: 14.0,
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
                      fontSize: 12.0,
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
              const Spacer(),
              Container(
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
                ),
                alignment: Alignment.center,
                child: Text(
                  isSpanish ? 'Ver Perfil' : 'View Profile',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.mooli(
                          fontWeight: FontWeight.w600,
                        ),
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        fontSize: 12.0,
                      ),
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
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Header Bar
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () async {
                            context.safePop();
                          },
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 24.0,
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Text(
                          isSpanish ? 'Doctores cerca de ti' : 'Doctors near you',
                          style: FlutterFlowTheme.of(context).titleMedium.override(
                                font: GoogleFonts.mooli(
                                  fontWeight: FontWeight.bold,
                                ),
                                fontSize: 18.0,
                              ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36.0,
                          height: 36.0,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                FlutterFlowTheme.of(context).secondary,
                                FlutterFlowTheme.of(context).primary,
                                FlutterFlowTheme.of(context).secondary,
                              ],
                              stops: const [0.0, 1.0, 1.0],
                              begin: const AlignmentDirectional(1.0, -0.5),
                              end: const AlignmentDirectional(-1.0, 0.5),
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: InkWell(
                            onTap: () async {
                              context.pushNamed(NotificationsWidget.routeName);
                            },
                            child: Icon(
                              Icons.notifications_rounded,
                              color: FlutterFlowTheme.of(context).secondaryBackground,
                              size: 18.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        InkWell(
                          onTap: () async {
                            context.pushNamed(MyAccountWidget.routeName);
                          },
                          child: Container(
                            width: 36.0,
                            height: 36.0,
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: Image.network(
                              'https://cdn.pixabay.com/photo/2023/02/18/11/00/icon-7797704_640.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20.0),
                // Doctors Grid
                Expanded(
                  child: FutureBuilder<List<DoctorItem>>(
                    future: DoctorsService.instance.getDoctors(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        );
                      }

                      final doctors = snapshot.data ?? [];
                      if (doctors.isEmpty) {
                        return Center(
                          child: Text(
                            isSpanish
                                ? 'No se encontraron doctores registrados.'
                                : 'No doctors found.',
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.mooli(),
                                  color: FlutterFlowTheme.of(context).secondaryText,
                                ),
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 900
                              ? 4
                              : (constraints.maxWidth > 600 ? 3 : 2);
                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 14.0,
                              mainAxisSpacing: 14.0,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: doctors.length,
                            itemBuilder: (context, index) {
                              return _buildDoctorCard(context, doctors[index]);
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
  }
}

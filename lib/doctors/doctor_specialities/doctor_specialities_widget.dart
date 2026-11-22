import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/i18n_service.dart';
import '/services/medical_specialties_service.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'doctor_specialities_model.dart';
export 'doctor_specialities_model.dart';

class DoctorSpecialitiesWidget extends StatefulWidget {
  const DoctorSpecialitiesWidget({super.key});

  static String routeName = 'DoctorSpecialities';
  static String routePath = '/doctorSpecialities';

  @override
  State<DoctorSpecialitiesWidget> createState() =>
      _DoctorSpecialitiesWidgetState();
}

class _DoctorSpecialitiesWidgetState extends State<DoctorSpecialitiesWidget> {
  late DoctorSpecialitiesModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DoctorSpecialitiesModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSpanish = I18nService.instance.isSpanish;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;
    final crossAxisCount = screenWidth > 1100
        ? 6
        : screenWidth > 768
            ? 4
            : 3;

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
            padding: EdgeInsetsDirectional.fromSTEB(
              isDesktop ? 32.0 : 20.0,
              20.0,
              isDesktop ? 32.0 : 20.0,
              20.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Top Header with Back button, Title and actions
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            if (Navigator.of(context).canPop()) {
                              context.safePop();
                            } else {
                              context.goNamed(HomeWidget.routeName);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 8.0, 0.0),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: FlutterFlowTheme.of(context).primaryText,
                              size: 26.0,
                            ),
                          ),
                        ),
                        Text(
                          isSpanish ? 'Especialidades Médicas' : 'Doctor Specialities',
                          style: FlutterFlowTheme.of(context).titleMedium.override(
                                font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                                fontSize: 20.0,
                                fontWeight: FontWeight.bold,
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38.0,
                          height: 38.0,
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
                            shape: BoxShape.circle,
                          ),
                          child: InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              context.pushNamed(NotificationsWidget.routeName);
                            },
                            child: Icon(
                              Icons.notifications_rounded,
                              color: FlutterFlowTheme.of(context).secondaryBackground,
                              size: 20.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            context.pushNamed(MyAccountWidget.routeName);
                          },
                          child: Container(
                            width: 38.0,
                            height: 38.0,
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
                // Grid of all Medical Specialties
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 14.0,
                      mainAxisSpacing: 14.0,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: MedicalSpecialtiesService.list.length,
                    itemBuilder: (context, index) {
                      final specialty = MedicalSpecialtiesService.list[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).secondaryBackground,
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 8.0,
                              color: Color(0x18000000),
                              offset: Offset(0.0, 2.0),
                              spreadRadius: 1.0,
                            )
                          ],
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                        ),
                        child: InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          borderRadius: BorderRadius.circular(14.0),
                          onTap: () async {
                            context.pushNamed(
                              CategoryListWidget.routeName,
                              queryParameters: {
                                'specialty': serializeParam(specialty.nameEs, ParamType.String),
                              }.withoutNulls,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 54.0,
                                  height: 54.0,
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
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 36.0,
                                      height: 36.0,
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
                                const SizedBox(height: 8.0),
                                Text(
                                  specialty.getLocalizedName(isSpanish),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                        font: GoogleFonts.mooli(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        fontSize: 12.0,
                                        color: FlutterFlowTheme.of(context).primaryText,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

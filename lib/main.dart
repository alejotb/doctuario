import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/supabase_auth/supabase_user_provider.dart';
import 'auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import 'backend/firebase/firebase_config.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'services/doctor_subscription_service.dart';
import 'services/google_auth_service.dart';
import 'services/i18n_service.dart';
import 'services/notifications_service.dart';
import 'services/patient_location_service.dart';
import 'admin/admin_doctor_tenants_modal_widget.dart';
import 'admin/admin_support_tickets_modal.dart';
import 'components/app_navigation_shell.dart';
import 'components/skeleton_shimmer.dart';
import 'doctors/doctor_secretaries/doctor_secretaries_widget.dart';
import 'patient/patient_my_appointments/patient_my_appointments_widget.dart';
import 'index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();
  await initFirebase();
  await Future.wait([SupaFlow.initialize(), FlutterFlowTheme.initialize(), I18nService.instance.init(), PatientLocationService.instance.init()]);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  final Widget Function(BuildContext)? initialLoggedInWidget;
  final String appTitle;
  const MyApp({super.key, this.initialLoggedInWidget, this.appTitle = 'Doctuario'});
  @override
  MyAppState createState() => MyAppState();
  static MyAppState of(BuildContext context) => context.findAncestorStateOfType<MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad};
}

class MyAppState extends State<MyApp> {
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;
  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  late Stream<BaseAuthUser> userStream;

  String getRoute([RouteMatch? routeMatch]) {
    final m = routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    return (m is ImperativeRouteMatch ? m.matches : _router.routerDelegate.currentConfiguration).uri.path;
  }
  List<String> getRouteStack() => _router.routerDelegate.currentConfiguration.matches.map((e) => getRoute(e)).toList();

  @override
  void initState() {
    super.initState();
    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier, initialLoggedInWidget: widget.initialLoggedInWidget);
    userStream = mediConnectHealthcareAppSupabaseUserStream()
      ..listen((user) {
        _appStateNotifier.update(user);
        if (user.loggedIn && user.authUserInfo.uid != null) {
          final isOauthDoc = kIsWeb && Uri.base.queryParameters['oauth_role'] == 'doctor';
          GoogleAuthService.instance.ensureUserSynced(userId: user.authUserInfo.uid, fallbackRole: isOauthDoc ? 'doctor' : null);
        }
      });
    jwtTokenStream.listen((_) {});
    Future.delayed(const Duration(milliseconds: 1000), () => _appStateNotifier.stopShowingSplashImage());
    I18nService.instance.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => safeSetState(() {});
  @override void dispose() { I18nService.instance.removeListener(_onLocaleChanged); super.dispose(); }
  void setThemeMode(ThemeMode mode) => safeSetState(() { _themeMode = mode; FlutterFlowTheme.saveThemeMode(mode); });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false, title: widget.appTitle, scrollBehavior: MyAppScrollBehavior(),
      locale: I18nService.instance.currentLocale,
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: const [Locale('es', ''), Locale('en', '')],
      theme: ThemeData(brightness: Brightness.light, useMaterial3: false), darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: false),
      themeMode: _themeMode, routerConfig: _router,
    );
  }
}

class NavBarPage extends StatefulWidget {
  const NavBarPage({super.key, this.initialPage, this.page, this.disableResizeToAvoidBottomInset = false});
  final String? initialPage;
  final Widget? page;
  final bool disableResizeToAvoidBottomInset;

  @override
  State<NavBarPage> createState() => _NavBarPageState();
}

class _NavBarPageState extends State<NavBarPage> {
  static String? _cachedUserId;
  static String? _cachedRol;
  static String _cachedNombre = '';
  static String _cachedGenero = '';
  static String _cachedFotoUrl = '';
  static bool _cachedPerfilCompleto = false;

  String _currentPageName = 'Home';
  late Widget? _currentPage;
  String _rol = 'paciente';
  String _userNombre = '';
  String _userGenero = '';
  String _userFotoUrl = '';
  bool _isResolvingInitialRole = false;
  int _refreshCounter = 0;

  static String _inferInitialRole(String? uid, String? initialPage) {
    if (uid == null || uid.isEmpty) return 'paciente';
    if (_cachedUserId == uid && _cachedRol != null) return _cachedRol!;

    if (initialPage != null) {
      if (const {'Agenda', 'Sedes', 'Pacientes', 'Secretarias', 'Consultas'}.contains(initialPage)) {
        return 'doctor';
      }
      if (initialPage == 'Recepcion') return 'secretaria';
      if (const {'Dashboard', 'Tenants', 'Doctores'}.contains(initialPage)) {
        return 'administrador';
      }
    }

    final persisted = DualDatabaseConfig.instance.activeViewMode.trim().toLowerCase();
    if (persisted == 'administrador' || persisted == 'admin') return 'administrador';
    if (persisted == 'doctor') return 'doctor';
    if (persisted == 'secretaria') return 'secretaria';

    final metaRol = (SupaFlow.client.auth.currentUser?.userMetadata?['rol'] ?? '').toString().trim().toLowerCase();
    if (metaRol == 'administrador' || metaRol == 'admin') return 'administrador';
    if (metaRol == 'doctor' || metaRol == 'medico' || metaRol == 'médico') return 'doctor';
    if (metaRol == 'secretaria' || metaRol == 'asistente') return 'secretaria';

    return 'paciente';
  }

  @override
  void initState() {
    super.initState();
    final uid = SupaFlow.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      _cachedUserId = null;
      _cachedRol = null;
      _cachedNombre = '';
      _cachedGenero = '';
      _cachedFotoUrl = '';
      _cachedPerfilCompleto = false;
    }

    _rol = _inferInitialRole(uid, widget.initialPage);
    if (_cachedUserId == uid && uid != null) {
      _userNombre = _cachedNombre;
      _userGenero = _cachedGenero;
      _userFotoUrl = _cachedFotoUrl;
    }

    final allowed = _roleRoutes[_rol] ?? _roleRoutes['paciente']!;
    final requested = widget.initialPage == 'Perfil' ? 'MyAccount' : widget.initialPage;
    if (requested != null && allowed.containsKey(requested)) {
      _currentPageName = requested;
    } else {
      _currentPageName = allowed.keys.first;
    }
    _currentPage = widget.page;

    // Solo mostrar carga breve en arranque en frío en '/' cuando el usuario está autenticado y aún no se ha verificado su rol en sesión
    _isResolvingInitialRole = uid != null && uid.isNotEmpty && _cachedUserId != uid && widget.initialPage == null;

    _cargarRol();
    I18nService.instance.addListener(_onLocaleChanged);
    if (uid != null) NotificationsService.instance.actualizarContadorNoLeidas(uid);
  }

  @override
  void didUpdateWidget(covariant NavBarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPage != null && widget.initialPage != oldWidget.initialPage) {
      _currentPageName = widget.initialPage == 'Perfil' ? 'MyAccount' : widget.initialPage!;
      _currentPage = widget.page;
    } else if (widget.page != oldWidget.page) {
      _currentPage = widget.page;
    }
  }

  void _onLocaleChanged() => safeSetState(() { _refreshCounter++; });

  @override
  void dispose() {
    I18nService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  static final Map<String, Map<String, String>> _roleRoutes = {
    'administrador': {
      'Dashboard': AdminAccountsDashboardWidget.routeName,
      'Tenants': AdminDoctorTenantsWidget.routeName,
      'Doctores': 'AdminDoctors',
      'MyAccount': MyAccountWidget.routeName,
    },
    'doctor': {
      'Agenda': DoctorAgendaPanelWidget.routeName,
      'Sedes': DoctorSedesConfigWidget.routeName,
      'Pacientes': DoctorPacientesListWidget.routeName,
      'Secretarias': DoctorSecretariesWidget.routeName,
      'Consultas': DoctorConsultasRealizadasWidget.routeName,
      'MyAccount': MyAccountWidget.routeName,
    },
    'secretaria': {
      'Recepcion': SecretaryDashboardWidget.routeName,
      'MyAccount': MyAccountWidget.routeName,
    },
    'paciente': {
      'Home': HomeWidget.routeName,
      'DoctorsList': DoctorsListWidget.routeName,
      'MyAppointment': MyAppointmentWidget.routeName,
      'MyResults': MyResultsWidget.routeName,
      'MyAccount': MyAccountWidget.routeName,
    },
  };

  void _navigateToTab(String key, String role) {
    final routes = _roleRoutes[role] ?? _roleRoutes['paciente']!;
    final targetRoute = routes[key] ?? routes.values.first;
    safeSetState(() {
      _currentPage = null;
      _currentPageName = key;
    });
    if (mounted) context.goNamed(targetRoute);
  }

  Future<void> _cargarRol() async {
    final currentUser = SupaFlow.client.auth.currentUser;
    final currentUserId = currentUser?.id;
    if (currentUserId == null) {
      if (_isResolvingInitialRole && mounted) {
        setState(() => _isResolvingInitialRole = false);
      }
      return;
    }
    try {
      final alreadyCached = _cachedUserId == currentUserId && _cachedRol != null;
      final meta = currentUser?.userMetadata ?? const <String, dynamic>{};
      final isOauthDoc = kIsWeb && Uri.base.queryParameters['oauth_role'] == 'doctor';
      if (!alreadyCached) {
        await GoogleAuthService.instance.ensureUserSynced(userId: currentUserId, fallbackRole: isOauthDoc ? 'doctor' : null);
      }
      final resolvedRol = await DualDatabaseConfig.instance.resolveUserRole(currentUser);

      UsuariosRow? usr;
      try {
        final u = await UsuariosTable().querySingleRow(queryFn: (q) => q.eq('id', currentUserId));
        if (u.isNotEmpty) usr = u.first;
      } catch (_) {}

      if (!mounted) return;
      final isEffectiveAdmin = resolvedRol == 'administrador' || resolvedRol == 'admin';
      final isDoctor = !isEffectiveAdmin && resolvedRol == 'doctor' && (DualDatabaseConfig.instance.isDoctorViewActive || DualDatabaseConfig.instance.activeViewMode != 'paciente');
      final effectiveRol = isEffectiveAdmin ? 'administrador' : (isDoctor ? 'doctor' : (resolvedRol == 'secretaria' ? 'secretaria' : 'paciente'));

      final nombre = (usr?.nombre?.trim().isNotEmpty ?? false) ? usr!.nombre!.trim() : (meta['nombre']?.toString().trim() ?? meta['full_name']?.toString().trim() ?? '');
      final foto = (usr?.fotoUrl?.trim().isNotEmpty ?? false) ? usr!.fotoUrl!.trim() : (meta['foto_url']?.toString().trim() ?? currentUserPhoto);
      final genero = usr?.data['genero']?.toString() ?? usr?.data['sexo']?.toString() ?? meta['genero']?.toString() ?? '';

      bool perfilCompletoVerificado = _cachedPerfilCompleto && alreadyCached;
      if (effectiveRol == 'administrador') {
        await DualDatabaseConfig.instance.persistActiveViewMode('administrador');
        perfilCompletoVerificado = true;
      } else if (isDoctor) {
        await DualDatabaseConfig.instance.persistActiveViewMode('doctor');
        await DoctorSubscriptionService.instance.verificarEstadoDoctor(idDoctor: currentUserId);
        if (!perfilCompletoVerificado) {
          bool perfilCompleto = false;
          try {
            final prefs = await SharedPreferences.getInstance();
            final sedes = await DoctorSedesTable().queryRows(queryFn: (q) => q.eq('id_doctor', currentUserId).limit(1));
            final tieneCiudad = (usr?.ciudadOrigen?.trim().isNotEmpty ?? false) || (meta['ciudad_origen']?.toString().trim().isNotEmpty ?? false);
            final tieneEsp = (meta['especialidad']?.toString().trim().isNotEmpty ?? false);
            perfilCompleto = (prefs.getBool('prontudoc_perfil_completo_$currentUserId') ?? false) || meta['perfil_completo'] == true || meta['setup_completo'] == true || sedes.isNotEmpty || (tieneCiudad && tieneEsp);
          } catch (_) {}
          if (!mounted) return;
          if (!perfilCompleto) {
            context.goNamedAuth(CreateProfileWidget.routeName, mounted, queryParameters: {'rol': serializeParam('Doctor', ParamType.String)}.withoutNulls);
            return;
          }
          perfilCompletoVerificado = true;
        }
      } else if (effectiveRol == 'secretaria') {
        await DualDatabaseConfig.instance.persistActiveViewMode('secretaria');
        if (!perfilCompletoVerificado) {
          final secDone = meta['perfil_completo'] == true || (foto.isNotEmpty && (usr?.ciudadOrigen?.trim().isNotEmpty ?? false));
          if (!mounted) return;
          if (!secDone) { context.goNamedAuth(CreateProfileWidget.routeName, mounted, queryParameters: {'rol': serializeParam('secretaria', ParamType.String)}.withoutNulls); return; }
          perfilCompletoVerificado = true;
        }
      } else {
        await DualDatabaseConfig.instance.persistActiveViewMode('paciente');
        perfilCompletoVerificado = true;
      }

      _cachedUserId = currentUserId;
      _cachedRol = effectiveRol;
      _cachedNombre = nombre;
      _cachedFotoUrl = foto;
      _cachedGenero = genero;
      _cachedPerfilCompleto = perfilCompletoVerificado;

      final allowedRoutes = _roleRoutes[effectiveRol] ?? _roleRoutes['paciente']!;
      final normalizedPage = _currentPageName == 'Perfil' ? 'MyAccount' : _currentPageName;
      final isAllowed = allowedRoutes.containsKey(normalizedPage);
      final targetKey = isAllowed ? normalizedPage : allowedRoutes.keys.first;

      setState(() {
        _rol = effectiveRol;
        _userNombre = nombre;
        _userFotoUrl = foto;
        _userGenero = genero;
        _isResolvingInitialRole = false;
        _currentPage = null;
        _currentPageName = targetKey;
      });

      if (!isAllowed || (kIsWeb && Uri.base.path == '/')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.goNamed(allowedRoutes[targetKey]!);
        });
      }
    } catch (e) {
      debugPrint('Error cargando rol en nav bar: $e');
      if (_isResolvingInitialRole && mounted) {
        setState(() => _isResolvingInitialRole = false);
      }
    }
  }

  SkeletonPageVariant _skeletonVariantForCurrentTarget() {
    if (_currentPageName == 'Agenda' || _currentPageName == 'Recepcion') {
      return SkeletonPageVariant.agenda;
    }
    if (_currentPageName == 'Pacientes' ||
        _currentPageName == 'DoctorsList' ||
        _currentPageName == 'Consultas' ||
        _currentPageName == 'Sedes' ||
        _currentPageName == 'Secretarias') {
      return SkeletonPageVariant.list;
    }
    if (_currentPageName == 'MyAccount' || _currentPageName == 'Perfil') {
      return SkeletonPageVariant.profile;
    }
    if (_rol == 'doctor' || _rol == 'secretaria') {
      return SkeletonPageVariant.agenda;
    }
    return SkeletonPageVariant.generic;
  }

  @override
  Widget build(BuildContext context) {
    if (_isResolvingInitialRole) {
      return SkeletonPageLoader(variant: _skeletonVariantForCurrentTarget());
    }
    final currentUserId = SupaFlow.client.auth.currentUser?.id ?? '';
    final isEs = I18nService.instance.isSpanish;

    Widget buildShell({
      required Widget body,
      required List<NavBarItemDef> navDefs,
      required int currentIndex,
      required ValueChanged<int> onTap,
      required String roleBadge,
      String? doctorSubtitle,
      List<Widget>? actions,
      bool showLocationSelector = false,
    }) {
      return AppNavigationShell(
        body: KeyedSubtree(key: ValueKey('$_currentPageName-$_refreshCounter'), child: body),
        navDefs: navDefs,
        currentIndex: currentIndex,
        onTap: onTap,
        roleBadge: roleBadge,
        doctorSubtitle: doctorSubtitle,
        actions: actions,
        showLocationSelector: showLocationSelector,
        rol: _rol,
        userNombre: _userNombre,
        userGenero: _userGenero,
        userFotoUrl: _userFotoUrl,
        disableResizeToAvoidBottomInset: widget.disableResizeToAvoidBottomInset,
        onProfileUpdated: _cargarRol,
      );
    }

    if (_rol == 'administrador') {
      final tabs = {'Dashboard': const AdminAccountsDashboardWidget(), 'Tenants': const AdminDoctorTenantsWidget(), 'Doctores': const DoctorsListWidget(), 'MyAccount': const MyAccountWidget()};
      final navDefs = [NavBarItemDef(Icons.dashboard_rounded, isEs ? 'Panel' : 'Dashboard'), NavBarItemDef(Icons.admin_panel_settings_rounded, isEs ? 'Consultorios' : 'Tenants'), NavBarItemDef(Icons.medical_services_outlined, isEs ? 'Doctores' : 'Doctors'), NavBarItemDef(Icons.person_outline_rounded, isEs ? 'Mi Cuenta' : 'My Account')];
      final idx = tabs.keys.toList().indexOf(_currentPageName == 'Perfil' ? 'MyAccount' : _currentPageName);
      return buildShell(body: _currentPage ?? tabs.values.toList()[idx >= 0 ? idx : 0], navDefs: navDefs, currentIndex: idx >= 0 ? idx : 0, onTap: (i) => _navigateToTab(tabs.keys.toList()[i], 'administrador'), roleBadge: isEs ? 'Administrador' : 'Administrator', actions: [
        IconButton(icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF0F766E), size: 22), tooltip: isEs ? 'Tickets de Soporte' : 'Support Tickets', onPressed: () => AdminSupportTicketsModal.show(context)),
        IconButton(icon: const Icon(Icons.domain_verification_rounded, color: Color(0xFF0284C7), size: 22), tooltip: isEs ? 'Aprobación de Consultorios' : 'Tenants Approval', onPressed: () => AdminDoctorTenantsModalWidget.show(context)),
      ]);
    }

    if (_rol == 'doctor') {
      if (DoctorSubscriptionService.instance.isPendingApproval) {
        return DoctorAccountSetupPendingScreen(
          idDoctor: currentUserId,
          onRefreshStatus: () => safeSetState(() {}),
          onSignOut: () async {
            _cachedUserId = null;
            _cachedRol = null;
            _cachedPerfilCompleto = false;
            DoctorSubscriptionService.instance.reset();
            await SupaFlow.client.auth.signOut();
            if (mounted) context.goNamed(Login1Widget.routeName);
          },
        );
      }
      final tabs = {'Agenda': DoctorAgendaPanelWidget(idDoctor: currentUserId), 'Sedes': DoctorSedesConfigWidget(idDoctor: currentUserId), 'Pacientes': DoctorPacientesListWidget(idDoctor: currentUserId), 'Secretarias': DoctorSecretariesWidget(idDoctor: currentUserId), 'Consultas': DoctorConsultasRealizadasWidget(idDoctor: currentUserId), 'MyAccount': const MyAccountWidget()};
      final navDefs = [NavBarItemDef(Icons.event_note_rounded, isEs ? 'Agenda' : 'Schedule'), NavBarItemDef(Icons.location_city_rounded, isEs ? 'Sedes' : 'Clinics'), NavBarItemDef(Icons.people_alt_rounded, isEs ? 'Pacientes' : 'Patients'), NavBarItemDef(Icons.support_agent_rounded, isEs ? 'Secretarias' : 'Secretaries'), NavBarItemDef(Icons.history_edu_rounded, isEs ? 'Consultas' : 'Consultations'), NavBarItemDef(Icons.person_outline_rounded, isEs ? 'Mi Cuenta' : 'My Account')];
      final idx = tabs.keys.toList().indexOf(_currentPageName == 'Perfil' ? 'MyAccount' : (_currentPageName == 'DoctorsList' || _currentPageName == 'Colegas' ? 'Consultas' : _currentPageName));
      return buildShell(body: _currentPage ?? tabs.values.toList()[idx >= 0 ? idx : 0], navDefs: navDefs, currentIndex: idx >= 0 ? idx : 0, onTap: (i) => _navigateToTab(tabs.keys.toList()[i], 'doctor'), roleBadge: '', doctorSubtitle: isEs ? 'Portal Clínico' : 'Clinical Portal');
    }

    if (_rol == 'secretaria') {
      final tabs = {'Recepcion': SecretaryDashboardWidget(idSecretaria: currentUserId), 'MyAccount': const MyAccountWidget()};
      final navDefs = [NavBarItemDef(Icons.desk_rounded, isEs ? 'Recepción' : 'Reception'), NavBarItemDef(Icons.person_outline_rounded, isEs ? 'Mi Cuenta' : 'My Account')];
      final idx = tabs.keys.toList().indexOf(_currentPageName == 'Perfil' ? 'MyAccount' : _currentPageName);
      return buildShell(body: _currentPage ?? tabs.values.toList()[idx >= 0 ? idx : 0], navDefs: navDefs, currentIndex: idx >= 0 ? idx : 0, onTap: (i) => _navigateToTab(tabs.keys.toList()[i], 'secretaria'), roleBadge: isEs ? 'Recepción' : 'Reception');
    }

    final tabs = {'Home': const HomeWidget(), 'DoctorsList': const DoctorsListWidget(), 'MyAppointment': PatientMyAppointmentsWidget(idPaciente: currentUserId), 'MyResults': PatientExamsWidget(idPaciente: currentUserId), 'MyAccount': const MyAccountWidget()};
    final navDefs = [NavBarItemDef(Icons.home_outlined, isEs ? 'Inicio' : 'Home'), NavBarItemDef(Icons.medical_services_outlined, isEs ? 'Doctores' : 'Doctors'), NavBarItemDef(Icons.calendar_month_outlined, isEs ? 'Mis Citas' : 'Appointments'), NavBarItemDef(Icons.picture_as_pdf_outlined, isEs ? 'Exámenes' : 'Exams'), NavBarItemDef(Icons.person_outline_rounded, isEs ? 'Mi Cuenta' : 'My Account')];
    final idx = tabs.keys.toList().indexOf(_currentPageName == 'Perfil' ? 'MyAccount' : _currentPageName);
    return buildShell(body: _currentPage ?? tabs.values.toList()[idx >= 0 ? idx : 0], navDefs: navDefs, currentIndex: idx >= 0 ? idx : 0, onTap: (i) {
      if (currentUserId.isEmpty && i >= 2) { AppNavigationShell.promptGuestLoginModal(context, isEs); return; }
      _navigateToTab(tabs.keys.toList()[i], 'paciente');
    }, roleBadge: currentUserId.isNotEmpty ? (isEs ? 'Paciente' : 'Patient') : '', showLocationSelector: true);
  }
}

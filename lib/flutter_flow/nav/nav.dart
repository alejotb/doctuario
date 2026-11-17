import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/backend/supabase/supabase.dart';
import '/auth/base_auth_user_provider.dart';
import '/main.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../doctors/doctor_secretaries/doctor_secretaries_widget.dart';
import '../../legal/legal_portal_widget.dart';
import '../../legal/terms_of_service_widget.dart';
import '../../legal/privacy_policy_widget.dart';
import '/index.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  BaseAuthUser? initialUser;
  BaseAuthUser? user;
  bool showSplashImage = true;
  String? _redirectLocation;
  bool notifyOnAuthChange = true;

  bool get loading => user == null || showSplashImage;
  bool get loggedIn => user?.loggedIn ?? false;
  bool get initiallyLoggedIn => initialUser?.loggedIn ?? false;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  void update(BaseAuthUser newUser) {
    final shouldUpdate =
        user?.uid == null || newUser.uid == null || user?.uid != newUser.uid;
    initialUser ??= newUser;
    user = newUser;
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    updateNotifyOnAuthChange(true);
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

GoRouter createRouter(
  AppStateNotifier appStateNotifier, {
  String? initialLocation,
  Widget Function(BuildContext)? initialLoggedInWidget,
}) =>
    GoRouter(
      initialLocation: initialLocation ?? '/',
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      errorBuilder: (context, state) => appStateNotifier.loggedIn
          ? (initialLoggedInWidget != null ? initialLoggedInWidget(context) : const NavBarPage())
          : const Login1Widget(),
      routes: [
        FFRoute(
          name: '_initialize',
          path: '/',
          builder: (context, _) => appStateNotifier.loggedIn
              ? (initialLoggedInWidget != null ? initialLoggedInWidget(context) : const NavBarPage())
              : const NavBarPage(initialPage: 'Home'),
        ),
        FFRoute(name: SplashScreenWidget.routeName, path: SplashScreenWidget.routePath, builder: (_, __) => const SplashScreenWidget()),
        FFRoute(name: HomeWidget.routeName, path: HomeWidget.routePath, builder: (_, __) => const NavBarPage(initialPage: 'Home')),
        FFRoute(name: WelcomeWidget.routeName, path: WelcomeWidget.routePath, builder: (_, __) => const WelcomeWidget()),
        FFRoute(name: Onboarding1Widget.routeName, path: Onboarding1Widget.routePath, builder: (_, __) => const Onboarding1Widget()),
        FFRoute(name: Onboarding2Widget.routeName, path: Onboarding2Widget.routePath, builder: (_, __) => const Onboarding2Widget()),
        FFRoute(name: Onboarding3Widget.routeName, path: Onboarding3Widget.routePath, builder: (_, __) => const Onboarding3Widget()),
        FFRoute(
          name: CreateAccountWidget.routeName,
          path: CreateAccountWidget.routePath,
          builder: (_, params) => CreateAccountWidget(rol: params.getParam('rol', ParamType.String)),
        ),
        FFRoute(name: Login1Widget.routeName, path: Login1Widget.routePath, builder: (_, __) => const Login1Widget()),
        FFRoute(name: ForgotPasswordWidget.routeName, path: ForgotPasswordWidget.routePath, builder: (_, __) => const ForgotPasswordWidget()),
        FFRoute(name: DoctorsListWidget.routeName, path: DoctorsListWidget.routePath, builder: (_, __) => const NavBarPage(initialPage: 'DoctorsList')),
        FFRoute(name: ItemWidget.routeName, path: ItemWidget.routePath, builder: (_, __) => const ItemWidget()),
        FFRoute(name: MyAppointmentWidget.routeName, path: MyAppointmentWidget.routePath, builder: (_, __) => const NavBarPage(initialPage: 'MyAppointment')),
        FFRoute(name: DoctorSpecialitiesWidget.routeName, path: DoctorSpecialitiesWidget.routePath, builder: (_, __) => const DoctorSpecialitiesWidget()),
        FFRoute(name: TopDoctorsWidget.routeName, path: TopDoctorsWidget.routePath, builder: (_, __) => const TopDoctorsWidget()),
        FFRoute(name: NotificationsWidget.routeName, path: NotificationsWidget.routePath, builder: (_, __) => const NotificationsWidget()),
        FFRoute(name: MyAccountWidget.routeName, path: MyAccountWidget.routePath, builder: (_, __) => const NavBarPage(initialPage: 'MyAccount')),
        FFRoute(
          name: EditProfileWidget.routeName,
          path: EditProfileWidget.routePath,
          builder: (_, params) => CreateProfileWidget(rol: params.getParam('rol', ParamType.String), esEdicion: true),
        ),
        FFRoute(name: ProfileImageWidget.routeName, path: ProfileImageWidget.routePath, builder: (_, __) => const ProfileImageWidget()),
        FFRoute(name: RequestSupportWidget.routeName, path: RequestSupportWidget.routePath, builder: (_, __) => const RequestSupportWidget()),
        FFRoute(name: HelpWidget.routeName, path: HelpWidget.routePath, builder: (_, __) => const HelpWidget()),
        FFRoute(name: FrequentlyAskedQuestionsWidget.routeName, path: FrequentlyAskedQuestionsWidget.routePath, builder: (_, __) => const FrequentlyAskedQuestionsWidget()),
        FFRoute(name: InviteFriendsWidget.routeName, path: InviteFriendsWidget.routePath, builder: (_, __) => const InviteFriendsWidget()),
        FFRoute(name: LogoutWidget.routeName, path: LogoutWidget.routePath, builder: (_, __) => const LogoutWidget()),
        FFRoute(name: OtherNotificationsWidget.routeName, path: OtherNotificationsWidget.routePath, builder: (_, __) => const OtherNotificationsWidget()),
        FFRoute(
          name: FavoriteDoctorWidget.routeName,
          path: FavoriteDoctorWidget.routePath,
          builder: (_, __) => const NavBarPage(initialPage: 'FavoriteDoctor', page: FavoriteDoctorWidget()),
        ),
        FFRoute(name: BookAppointmentWidget.routeName, path: BookAppointmentWidget.routePath, builder: (_, __) => const BookAppointmentWidget()),
        FFRoute(name: PatientDetailsWidget.routeName, path: PatientDetailsWidget.routePath, builder: (_, __) => const PatientDetailsWidget()),
        FFRoute(name: ProfileSummaryWidget.routeName, path: ProfileSummaryWidget.routePath, builder: (_, __) => const ProfileSummaryWidget()),
        FFRoute(name: PaymentSuccessfulWidget.routeName, path: PaymentSuccessfulWidget.routePath, builder: (_, __) => const PaymentSuccessfulWidget()),
        FFRoute(name: ViewDetailsWidget.routeName, path: ViewDetailsWidget.routePath, builder: (_, __) => const ViewDetailsWidget()),
        FFRoute(name: CancelBookingWidget.routeName, path: CancelBookingWidget.routePath, builder: (_, __) => const CancelBookingWidget()),
        FFRoute(name: CancelappointmentWidget.routeName, path: CancelappointmentWidget.routePath, builder: (_, __) => const CancelappointmentWidget()),
        FFRoute(name: ReviewWidget.routeName, path: ReviewWidget.routePath, builder: (_, __) => const ReviewWidget()),
        FFRoute(name: SessionWidget.routeName, path: SessionWidget.routePath, builder: (_, __) => const SessionWidget()),
        FFRoute(name: CategoryListWidget.routeName, path: CategoryListWidget.routePath, builder: (_, __) => const CategoryListWidget()),
        FFRoute(
          name: CreateProfileWidget.routeName,
          path: CreateProfileWidget.routePath,
          builder: (_, params) => CreateProfileWidget(
            rol: params.getParam('rol', ParamType.String),
            esEdicion: params.getParam('esEdicion', ParamType.bool) ?? false,
          ),
        ),
        FFRoute(name: MyResultsWidget.routeName, path: MyResultsWidget.routePath, builder: (_, __) => const NavBarPage(initialPage: 'MyResults')),
        FFRoute(name: PatientProfileWidget.routeName, path: PatientProfileWidget.routePath, builder: (_, __) => const PatientProfileWidget()),
        FFRoute(name: DoctorAgendaPanelWidget.routeName, path: DoctorAgendaPanelWidget.routePath, requireAuth: true, builder: (_, __) => const NavBarPage(initialPage: 'Agenda')),
        FFRoute(name: DoctorSedesConfigWidget.routeName, path: DoctorSedesConfigWidget.routePath, requireAuth: true, builder: (_, __) => const NavBarPage(initialPage: 'Sedes')),
        FFRoute(
          name: DoctorSetupWidget.routeName,
          path: DoctorSetupWidget.routePath,
          requireAuth: true,
          builder: (_, params) => DoctorSetupWidget(
            idDoctor: params.getParam('idDoctor', ParamType.String) ?? (SupaFlow.client.auth.currentUser?.id ?? ''),
          ),
        ),
        FFRoute(name: AdminDoctorTenantsWidget.routeName, path: AdminDoctorTenantsWidget.routePath, requireAuth: true, builder: (_, __) => const NavBarPage(initialPage: 'Tenants')),
        FFRoute(name: AdminAccountsDashboardWidget.routeName, path: AdminAccountsDashboardWidget.routePath, requireAuth: true, builder: (_, __) => const NavBarPage(initialPage: 'Dashboard')),
        FFRoute(name: 'AdminDoctors', path: '/adminDoctors', requireAuth: true, builder: (_, __) => const NavBarPage(initialPage: 'Doctores')),
        FFRoute(
          name: EmailConfirmationPendingWidget.routeName,
          path: EmailConfirmationPendingWidget.routePath,
          builder: (_, params) => EmailConfirmationPendingWidget(
            email: params.getParam('email', ParamType.String) ?? '',
            rol: params.getParam('rol', ParamType.String) ?? 'Paciente',
            idDoctor: params.getParam('idDoctor', ParamType.String),
          ),
        ),
        FFRoute(name: SecretaryDashboardWidget.routeName, path: SecretaryDashboardWidget.routePath, requireAuth: true, builder: (_, __) => const NavBarPage(initialPage: 'Recepcion')),
        FFRoute(
          name: PatientExamsWidget.routeName,
          path: PatientExamsWidget.routePath,
          builder: (_, params) => PatientExamsWidget(
            idPaciente: params.getParam('idPaciente', ParamType.String) ?? (SupaFlow.client.auth.currentUser?.id ?? ''),
            nombrePaciente: params.getParam('nombrePaciente', ParamType.String),
            puedeSubir: params.getParam('puedeSubir', ParamType.bool) ?? true,
          ),
        ),
        FFRoute(
          name: RequestAppointmentWidget.routeName,
          path: RequestAppointmentWidget.routePath,
          builder: (_, params) => RequestAppointmentWidget(
            idDoctor: params.getParam('idDoctor', ParamType.String) ?? '',
            nombreDoctor: params.getParam('nombreDoctor', ParamType.String),
            especialidadDoctor: params.getParam('especialidadDoctor', ParamType.String),
          ),
        ),
        FFRoute(
          name: DoctorInteractiveCalendarWidget.routeName,
          path: DoctorInteractiveCalendarWidget.routePath,
          builder: (_, params) => DoctorInteractiveCalendarWidget(
            idDoctor: params.getParam('idDoctor', ParamType.String) ?? (SupaFlow.client.auth.currentUser?.id ?? ''),
          ),
        ),
        FFRoute(
          name: PatientAvailabilityCalendarWidget.routeName,
          path: PatientAvailabilityCalendarWidget.routePath,
          builder: (_, params) => PatientAvailabilityCalendarWidget(
            idDoctor: params.getParam('idDoctor', ParamType.String) ?? '',
            nombreDoctor: params.getParam('nombreDoctor', ParamType.String),
            especialidadDoctor: params.getParam('especialidadDoctor', ParamType.String),
          ),
        ),
        FFRoute(name: DoctorPacientesListWidget.routeName, path: DoctorPacientesListWidget.routePath, builder: (_, __) => const NavBarPage(initialPage: 'Pacientes')),
        FFRoute(name: DoctorSecretariesWidget.routeName, path: DoctorSecretariesWidget.routePath, builder: (_, __) => const NavBarPage(initialPage: 'Secretarias')),
        FFRoute(name: DoctorConsultasRealizadasWidget.routeName, path: DoctorConsultasRealizadasWidget.routePath, requireAuth: true, builder: (_, __) => const NavBarPage(initialPage: 'Consultas')),
        FFRoute(
          name: DoctorPatientDetailWidget.routeName,
          path: DoctorPatientDetailWidget.routePath,
          builder: (_, params) => DoctorPatientDetailWidget(
            idDoctor: params.getParam('idDoctor', ParamType.String) ?? (SupaFlow.client.auth.currentUser?.id ?? ''),
            idPaciente: params.getParam('idPaciente', ParamType.String) ?? '',
          ),
        ),
        FFRoute(
          name: DoctorPublicProfileWidget.routeName,
          path: DoctorPublicProfileWidget.routePath,
          builder: (_, params) => DoctorPublicProfileWidget(
            idDoctor: params.getParam('idDoctor', ParamType.String) ?? '',
            nombreDoctor: params.getParam('nombreDoctor', ParamType.String),
            especialidadDoctor: params.getParam('especialidadDoctor', ParamType.String),
            fotoUrlDoctor: params.getParam('fotoUrlDoctor', ParamType.String),
          ),
        ),
        FFRoute(
          name: LegalPortalWidget.routeName,
          path: LegalPortalWidget.routePath,
          builder: (_, params) => LegalPortalWidget(
            initialTab: params.getParam('tab', ParamType.int) ?? 0,
          ),
        ),
        FFRoute(
          name: TermsOfServiceWidget.routeName,
          path: TermsOfServiceWidget.routePath,
          builder: (_, __) => const TermsOfServiceWidget(),
        ),
        FFRoute(
          name: PrivacyPolicyWidget.routeName,
          path: PrivacyPolicyWidget.routePath,
          builder: (_, __) => const PrivacyPolicyWidget(),
        ),
      ].map((r) => r.toRoute(appStateNotifier)).toList(),
    );

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void goNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : goNamed(name, pathParameters: pathParameters, queryParameters: queryParameters, extra: extra);

  void pushNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : pushNamed(name, pathParameters: pathParameters, queryParameters: queryParameters, extra: extra);

  void safePop() {
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension GoRouterExtensions on GoRouter {
  AppStateNotifier get appState => AppStateNotifier.instance;
  void prepareAuthEvent([bool ignoreRedirect = false]) =>
      appState.hasRedirect() && !ignoreRedirect ? null : appState.updateNotifyOnAuthChange(false);
  bool shouldRedirect(bool ignoreRedirect) => !ignoreRedirect && appState.hasRedirect();
  void clearRedirectLocation() => appState.clearRedirectLocation();
  void setRedirectLocationIfUnset(String location) => appState.updateNotifyOnAuthChange(false);
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap => extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  Map<String, dynamic> futureParamValues = {};

  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 && state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map((param) async {
          final doc = await asyncParams[param.key]!(param.value).onError((_, __) => null);
          if (doc != null) {
            futureParamValues[param.key] = doc;
            return true;
          }
          return false;
        }),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(String paramName, ParamType type, {bool isList = false}) {
    if (futureParamValues.containsKey(paramName)) return futureParamValues[paramName];
    if (!state.allParams.containsKey(paramName)) return null;
    final param = state.allParams[paramName];
    if (param is! String) return param;
    return deserializeParam<T>(param, type, isList);
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        redirect: (context, state) {
          if (appStateNotifier.shouldRedirect) {
            final redirectLocation = appStateNotifier.getRedirectLocation();
            appStateNotifier.clearRedirectLocation();
            return redirectLocation;
          }
          if (requireAuth && !appStateNotifier.loggedIn) {
            appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
            return '/login1';
          }
          return null;
        },
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);
          final child = appStateNotifier.loading
              ? Center(
                  child: SizedBox(
                    width: 50.0,
                    height: 50.0,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(FlutterFlowTheme.of(context).primary),
                    ),
                  ),
                )
              : page;

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  name: state.name,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                      PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(context, animation, secondaryAnimation, child),
                )
              : MaterialPage(key: state.pageKey, name: state.name, child: child);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => const TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage && location != '/' && location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/main.dart';
import '../my_account/notifications/notifications_modal_widget.dart';
import '../services/i18n_service.dart';
import '../services/notifications_service.dart';
import '../services/patient_location_service.dart';
import 'user_profile_modal.dart';

class NavBarItemDef {
  final IconData icon;
  final String label;
  const NavBarItemDef(this.icon, this.label);
}

/// Barra de navegación adaptativa (Top Bar en escritorio / AppBar + BottomBar en móvil)
/// conectada al tema claro/oscuro de FlutterFlowTheme.
class AppNavigationShell extends StatelessWidget {
  final Widget body;
  final List<NavBarItemDef> navDefs;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String roleBadge;
  final String? doctorSubtitle;
  final List<Widget>? actions;
  final bool showLocationSelector;
  final String rol;
  final String userNombre;
  final String userGenero;
  final String userFotoUrl;
  final bool disableResizeToAvoidBottomInset;
  final VoidCallback onProfileUpdated;

  const AppNavigationShell({
    super.key,
    required this.body,
    required this.navDefs,
    required this.currentIndex,
    required this.onTap,
    required this.roleBadge,
    this.doctorSubtitle,
    this.actions,
    this.showLocationSelector = false,
    required this.rol,
    required this.userNombre,
    required this.userGenero,
    required this.userFotoUrl,
    this.disableResizeToAvoidBottomInset = false,
    required this.onProfileUpdated,
  });

  String _formatDoctorHeaderTitle(bool isEs) {
    final raw = userNombre.trim();
    if (raw.isEmpty) return 'Doctor';
    final isFemale = userGenero.toLowerCase().startsWith('f') || userGenero.toLowerCase().contains('muj');
    final prefix = isFemale ? (isEs ? 'Dra.' : 'Dr.') : 'Dr.';
    return '$prefix ${raw.replaceAll(RegExp(r'^(dr\.|dra\.|doctor|doctora)\s+', caseSensitive: false), '').trim()}';
  }

  Widget _buildBrandLogo(BuildContext context, {required double size, required double fontSz, String? sub}) {
    final title = context.findAncestorWidgetOfExactType<MyApp>()?.appTitle ?? 'Doctuario';
    final isProntu = title.toLowerCase().contains('prontu');
    final theme = FlutterFlowTheme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(borderRadius: BorderRadius.circular(size * 0.25), child: Image.asset(isProntu ? 'assets/images/prontudoc_logo.png' : 'assets/images/doctuario_logo.png', width: size, height: size, fit: BoxFit.cover)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        RichText(text: TextSpan(children: [
          TextSpan(text: isProntu ? 'Prontu' : 'Doc', style: GoogleFonts.mooli(fontSize: fontSz, fontWeight: FontWeight.bold, color: theme.primaryText)),
          TextSpan(text: isProntu ? 'Doc' : 'tuario', style: GoogleFonts.mooli(fontSize: fontSz, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7))),
        ])),
        if (sub != null && sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.mooli(fontSize: fontSz * 0.62, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7))),
      ]),
    ]);
  }

  Widget _buildThemeToggle(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => MyApp.of(context).setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: theme.primaryBackground, shape: BoxShape.circle, border: Border.all(color: theme.alternate)),
        child: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 18, color: isDark ? Colors.amber : const Color(0xFF0284C7)),
      ),
    );
  }

  Widget _buildLanguageSwitcher(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      onTap: () => I18nService.instance.setLanguage(isEs ? 'en' : 'es'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: theme.primaryBackground, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.alternate)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.language_rounded, size: 16, color: Color(0xFF0284C7)),
          const SizedBox(width: 4),
          Text(isEs ? 'ES' : 'EN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.primaryText)),
        ]),
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: NotificationsService.instance.unreadCountNotifier,
      builder: (_, count, __) => Builder(
        builder: (bellCtx) => InkWell(
          onTap: () {
            if ((SupaFlow.client.auth.currentUser?.id ?? '').isEmpty) {
              promptGuestLoginModal(context, I18nService.instance.isSpanish);
              return;
            }
            NotificationsModalWidget.show(bellCtx);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: theme.primaryBackground, shape: BoxShape.circle, border: Border.all(color: theme.alternate)),
            child: Stack(alignment: Alignment.center, children: [
              Icon(Icons.notifications_outlined, size: 20, color: theme.secondaryText),
              if (count > 0) Positioned(top: 7, right: 7, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF0284C7), shape: BoxShape.circle))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelector(BuildContext context, {bool isMobile = false, double? desktopMaxWidth}) {
    final theme = FlutterFlowTheme.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: PatientLocationService.instance.currentLocationNotifier,
      builder: (_, location, __) {
        final label = isMobile ? PatientLocationService.instance.currentCityOnly : location;
        return InkWell(
          onTap: () => PatientLocationService.instance.mostrarSelectorUbicacion(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 5 : 7),
            decoration: BoxDecoration(color: theme.primaryBackground, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.alternate)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFF0284C7)),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isMobile ? 85 : (desktopMaxWidth ?? 240)),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.mooli(fontSize: isMobile ? 11.5 : 12.5, fontWeight: FontWeight.w600, color: theme.primaryText)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit_rounded, size: 13, color: Color(0xFF0284C7)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildUserAvatar(BuildContext context, {bool showDoctorName = false}) {
    final isEs = I18nService.instance.isSpanish;
    final theme = FlutterFlowTheme.of(context);
    final currentUserId = SupaFlow.client.auth.currentUser?.id ?? '';
    if (currentUserId.isEmpty) {
      return TextButton.icon(
        onPressed: () => context.pushNamed(Login1Widget.routeName),
        icon: const Icon(Icons.login_rounded, size: 15, color: Color(0xFF0284C7)),
        label: Text(isEs ? 'Entrar' : 'Sign In', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
        style: TextButton.styleFrom(backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.12), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.35)))),
      );
    }
    final photo = userFotoUrl.isNotEmpty ? userFotoUrl : currentUserPhoto;
    final avatar = Container(
      width: 36, height: 36, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0284C7).withValues(alpha: 0.12), border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.45), width: 1.5)),
      child: photo.isNotEmpty
          ? Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, size: 20, color: Color(0xFF0284C7)))
          : const Icon(Icons.person_rounded, size: 20, color: Color(0xFF0284C7)),
    );
    return Builder(
      builder: (avatarCtx) => InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () async { await UserProfileModal.show(avatarCtx, isDoctorView: rol == 'doctor'); onProfileUpdated(); },
        child: showDoctorName && rol == 'doctor'
            ? Container(
                padding: const EdgeInsets.only(left: 12, right: 4, top: 3, bottom: 3),
                decoration: BoxDecoration(color: theme.primaryBackground, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.alternate)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(_formatDoctorHeaderTitle(isEs), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.mooli(fontSize: 12.5, fontWeight: FontWeight.bold, color: theme.primaryText)),
                  ),
                  const SizedBox(width: 8), avatar,
                ]),
              ) : avatar,
      ),
    );
  }

  static void promptGuestLoginModal(BuildContext context, bool isEs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [const Icon(Icons.lock_outline_rounded, color: Color(0xFF0284C7)), const SizedBox(width: 8), Expanded(child: Text(isEs ? 'Acceso Requerido' : 'Sign In Required', style: GoogleFonts.mooli(fontSize: 16.5, fontWeight: FontWeight.bold)))]),
        content: Text(isEs ? 'Esta función requiere una cuenta en Doctuario. Inicia sesión o regístrate para gestionar citas y consultar información médica.' : 'This feature requires a Doctuario account. Sign in or register to manage appointments and records.', style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEs ? 'Explorar' : 'Explore')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () { Navigator.pop(ctx); context.pushNamed(Login1Widget.routeName); }, child: Text(isEs ? 'Iniciar Sesión' : 'Sign In')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;
    final isCompactDesktop = isDesktop && screenWidth < 1180;
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desktopItems = (isDesktop && navDefs.length > 1) ? navDefs.sublist(0, navDefs.length - 1) : navDefs;
    final desktopCurIdx = currentIndex < desktopItems.length ? currentIndex : -1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop && currentIndex != 0) onTap(0); },
      child: Scaffold(
        resizeToAvoidBottomInset: !disableResizeToAvoidBottomInset,
        appBar: isDesktop
            ? PreferredSize(
                preferredSize: const Size.fromHeight(72),
                child: Container(
                  decoration: BoxDecoration(color: theme.secondaryBackground, border: Border(bottom: BorderSide(color: theme.alternate, width: 1.5)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                  padding: EdgeInsets.symmetric(horizontal: isCompactDesktop ? 14 : 24, vertical: 10),
                  child: SafeArea(
                    bottom: false,
                    child: Row(children: [
                      InkWell(onTap: () => onTap(0), borderRadius: BorderRadius.circular(10), child: _buildBrandLogo(context, size: isCompactDesktop ? 32 : 36, fontSz: isCompactDesktop ? 16 : 18, sub: doctorSubtitle)),
                      if (roleBadge.isNotEmpty && screenWidth >= 900) ...[
                        const SizedBox(width: 8),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5), decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.25 : 0.12), borderRadius: BorderRadius.circular(12)), child: Text(roleBadge, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)))),
                      ],
                      if (showLocationSelector) ...[
                        SizedBox(width: isCompactDesktop ? 8 : 14),
                        _buildLocationSelector(context, isMobile: screenWidth < 960, desktopMaxWidth: isCompactDesktop ? 140 : 240),
                      ],
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: isCompactDesktop ? 6 : 12),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(desktopItems.length, (i) {
                                  final it = desktopItems[i]; final isSelected = i == desktopCurIdx;
                                  return Padding(
                                    padding: EdgeInsets.symmetric(horizontal: isCompactDesktop ? 2 : 4),
                                    child: InkWell(
                                      onTap: () => onTap(i), borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: isCompactDesktop ? 9 : 14, vertical: isCompactDesktop ? 7 : 8),
                                        decoration: BoxDecoration(color: isSelected ? const Color(0xFF0284C7).withValues(alpha: isDark ? 0.22 : 0.12) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: isSelected ? Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4), width: 1.2) : null),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(it.icon, size: isCompactDesktop ? 17 : 19, color: isSelected ? const Color(0xFF0284C7) : theme.secondaryText),
                                          SizedBox(width: isCompactDesktop ? 5 : 8),
                                          Text(it.label, style: TextStyle(fontSize: isCompactDesktop ? 12 : 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? const Color(0xFF0284C7) : theme.primaryText)),
                                        ]),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (actions != null) ...actions!,
                      SizedBox(width: isCompactDesktop ? 6 : 8), _buildThemeToggle(context),
                      SizedBox(width: isCompactDesktop ? 6 : 8), _buildLanguageSwitcher(context),
                      SizedBox(width: isCompactDesktop ? 6 : 8), _buildNotificationBell(context),
                      SizedBox(width: isCompactDesktop ? 6 : 10), _buildUserAvatar(context, showDoctorName: screenWidth >= 1060),
                    ]),
                  ),
                ),
              )
            : AppBar(
                backgroundColor: theme.secondaryBackground, elevation: 0.5, centerTitle: false, automaticallyImplyLeading: false,
                title: _buildBrandLogo(context, size: 28, fontSz: 16, sub: doctorSubtitle),
                actions: [
                  if (actions != null) ...actions!,
                  if (showLocationSelector) ...[Center(child: _buildLocationSelector(context, isMobile: true)), const SizedBox(width: 4)],
                  Center(child: _buildThemeToggle(context)), const SizedBox(width: 4),
                  Center(child: _buildLanguageSwitcher(context)), const SizedBox(width: 4),
                  _buildNotificationBell(context), const SizedBox(width: 4),
                  Center(child: _buildUserAvatar(context)), const SizedBox(width: 8),
                ],
              ),
        body: body,
        bottomNavigationBar: isDesktop ? null : Container(
          decoration: BoxDecoration(color: theme.secondaryBackground, border: Border(top: BorderSide(color: theme.alternate, width: 1.0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, -2))]),
          child: SafeArea(top: false, child: SizedBox(height: 58, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(navDefs.length, (i) {
            final it = navDefs[i]; final isSelected = i == currentIndex;
            return Expanded(child: InkWell(onTap: () => onTap(i), child: Center(child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: isSelected ? const Color(0xFF0284C7).withValues(alpha: isDark ? 0.22 : 0.12) : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Icon(it.icon, size: 21, color: isSelected ? const Color(0xFF0284C7) : theme.secondaryText)),
              const SizedBox(height: 2),
              Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.0, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? const Color(0xFF0284C7) : theme.secondaryText)),
            ]))));
          }))))),
      ),
    );
  }
}

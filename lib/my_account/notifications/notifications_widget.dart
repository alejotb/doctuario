import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/i18n_service.dart';
import '/services/notifications_service.dart';
import 'notifications_model.dart';
export 'notifications_model.dart';

/// Pantalla dedicada de Notificaciones que lee directamente de `notificaciones_citas`
/// en Supabase, filtrando por el usuario autenticado y permitiendo marcar lectura.
class NotificationsWidget extends StatefulWidget {
  const NotificationsWidget({super.key});

  static String routeName = 'Notifications';
  static String routePath = '/notifications';

  @override
  State<NotificationsWidget> createState() => _NotificationsWidgetState();
}

class _NotificationsWidgetState extends State<NotificationsWidget> {
  late NotificationsModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  List<NotificacionesCitasRow> _notificaciones = [];
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NotificationsModel());
    _currentUserId = SupaFlow.client.auth.currentUser?.id ?? '';
    _cargarNotificaciones();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _cargarNotificaciones() async {
    setState(() => _isLoading = true);
    final items = await NotificationsService.instance.obtenerNotificaciones(
      idUsuario: _currentUserId,
    );
    if (mounted) {
      setState(() {
        _notificaciones = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _marcarLeida(NotificacionesCitasRow item) async {
    if (item.leido == true) return;
    await NotificationsService.instance.marcarComoLeida(
      idNotificacion: item.id,
      idUsuario: _currentUserId,
    );
    setState(() {
      item.leido = true;
    });
  }

  Future<void> _marcarTodasLeidas() async {
    await NotificationsService.instance.marcarTodasComoLeidas(_currentUserId);
    setState(() {
      for (final n in _notificaciones) {
        n.leido = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.isSpanish;
    final unreadCount = _notificaciones.where((n) => n.leido != true).length;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: theme.secondaryBackground,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.primaryText, size: 24.0),
            onPressed: () => context.safePop(),
          ),
          title: Text(
            isEs ? 'Notificaciones' : 'Notifications',
            style: GoogleFonts.mooli(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: theme.primaryText,
            ),
          ),
          actions: [
            if (unreadCount > 0)
              TextButton.icon(
                onPressed: _marcarTodasLeidas,
                icon: const Icon(Icons.done_all_rounded, size: 18.0, color: Color(0xFF0284C7)),
                label: Text(
                  isEs ? 'Marcar leídas' : 'Mark all read',
                  style: GoogleFonts.mooli(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22.0),
              color: theme.secondaryText,
              tooltip: isEs ? 'Actualizar' : 'Refresh',
              onPressed: _cargarNotificaciones,
            ),
          ],
        ),
        body: SafeArea(
          top: true,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF0284C7),
                  ),
                )
              : _notificaciones.isEmpty
                  ? _buildEmptyState(theme, isEs)
                  : RefreshIndicator(
                      onRefresh: _cargarNotificaciones,
                      color: const Color(0xFF0284C7),
                      child: _buildList(theme, isEs),
                    ),
        ),
      ),
    );
  }

  Widget _buildList(FlutterFlowTheme theme, bool isEs) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: _notificaciones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8.0),
      itemBuilder: (context, index) {
        final item = _notificaciones[index];
        final isUnread = item.leido != true;
        final iconDef = NotificationsService.resolverIcono(item.tipo);
        final tiempo = NotificationsService.formatearTiempoRelativo(
          item.createdAt,
          isEs: isEs,
        );

        return Container(
          decoration: BoxDecoration(
            color: isUnread ? const Color(0xFFF0F9FF) : theme.secondaryBackground,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isUnread ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
          ),
          child: InkWell(
            onTap: () => _marcarLeida(item),
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42.0,
                    height: 42.0,
                    decoration: BoxDecoration(
                      color: Color(iconDef.backgroundColor),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconDef.icon,
                      size: 22.0,
                      color: Color(iconDef.iconColor),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.titulo ?? (isEs ? 'Aviso del Sistema' : 'System Notice'),
                          style: GoogleFonts.mooli(
                            fontSize: 14.0,
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            color: theme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          item.mensaje ?? '',
                          style: GoogleFonts.mooli(
                            fontSize: 13.0,
                            color: isUnread ? const Color(0xFF1E293B) : theme.secondaryText,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          tiempo,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isUnread) ...[
                    const SizedBox(width: 8.0),
                    Container(
                      margin: const EdgeInsets.only(top: 6.0),
                      width: 10.0,
                      height: 10.0,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0284C7),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(FlutterFlowTheme theme, bool isEs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.0,
              height: 64.0,
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 32.0,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              isEs ? 'No tienes notificaciones' : 'No notifications yet',
              style: GoogleFonts.mooli(
                fontSize: 17.0,
                fontWeight: FontWeight.bold,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              isEs
                  ? 'Te notificaremos aquí cuando ocurra alguna novedad en tus citas o cuenta médica.'
                  : 'We will notify you here when there are updates on your appointments or account.',
              textAlign: TextAlign.center,
              style: GoogleFonts.mooli(
                fontSize: 13.0,
                color: theme.secondaryText,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

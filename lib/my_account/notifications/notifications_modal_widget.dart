import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/i18n_service.dart';
import '/services/notifications_service.dart';

/// Modal desplegable estilo Facebook para mostrar y gestionar notificaciones
/// del usuario en tiempo real sin salir de la pantalla activa.
class NotificationsModalWidget extends StatefulWidget {
  const NotificationsModalWidget({
    super.key,
    required this.idUsuario,
  });

  final String idUsuario;

  /// Abre el menú flotante de notificaciones anclado directamente debajo de la
  /// campana estilo Facebook, tanto en móvil como en escritorio.
  static Future<void> show(BuildContext context) async {
    final currentUserId = SupaFlow.client.auth.currentUser?.id ?? '';
    final screenSize = MediaQuery.sizeOf(context);
    final isMobile = screenSize.width < 600;

    double topPos = 60.0;
    double rightPos = 12.0;

    try {
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final offset = box.localToGlobal(Offset.zero);
        topPos = offset.dy + box.size.height + 6.0;
        final calcRight = screenSize.width - (offset.dx + box.size.width);
        rightPos = calcRight.clamp(8.0, screenSize.width - 40.0);
      }
    } catch (_) {}

    final modalWidth = isMobile
        ? (screenSize.width - 24.0).clamp(280.0, 360.0)
        : 400.0;
    final modalHeight = (screenSize.height * 0.65).clamp(340.0, 520.0);

    if (rightPos + modalWidth > screenSize.width - 8.0) {
      rightPos = (screenSize.width - modalWidth - 8.0).clamp(8.0, 30.0);
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      barrierDismissible: true,
      builder: (ctx) => Stack(
        children: [
          Positioned(
            top: topPos,
            right: rightPos,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: modalWidth,
                height: modalHeight,
                child: NotificationsModalWidget(idUsuario: currentUserId),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  State<NotificationsModalWidget> createState() => _NotificationsModalWidgetState();
}

class _NotificationsModalWidgetState extends State<NotificationsModalWidget> {
  bool _isLoading = true;
  List<NotificacionesCitasRow> _notificaciones = [];

  @override
  void initState() {
    super.initState();
    _cargarNotificaciones();
  }

  Future<void> _cargarNotificaciones() async {
    setState(() => _isLoading = true);
    final items = await NotificationsService.instance.obtenerNotificaciones(
      idUsuario: widget.idUsuario,
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
      idUsuario: widget.idUsuario,
    );
    setState(() {
      item.leido = true;
    });
  }

  Future<void> _marcarTodasLeidas() async {
    await NotificationsService.instance.marcarTodasComoLeidas(widget.idUsuario);
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18.0,
            offset: const Offset(0.0, 6.0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Column(
          children: [
            // Cabecera superior del modal
            _buildHeader(theme, isEs, unreadCount),
            const Divider(height: 1.0, thickness: 1.0, color: Color(0xFFF1F5F9)),

            // Lista o estado vacío
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF0284C7),
                      ),
                    )
                  : _notificaciones.isEmpty
                      ? _buildEmptyState(theme, isEs)
                      : _buildNotificationsList(theme, isEs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(FlutterFlowTheme theme, bool isEs, int unreadCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          Text(
            isEs ? 'Notificaciones' : 'Notifications',
            style: GoogleFonts.mooli(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (unreadCount > 0)
            InkWell(
              onTap: _marcarTodasLeidas,
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                child: Text(
                  isEs ? 'Marcar leídas' : 'Mark all read',
                  style: GoogleFonts.mooli(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4.0),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20.0, color: Color(0xFF64748B)),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
            tooltip: isEs ? 'Cerrar' : 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(FlutterFlowTheme theme, bool isEs) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      itemCount: _notificaciones.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1.0,
        thickness: 0.8,
        color: Color(0xFFF8FAFC),
      ),
      itemBuilder: (context, index) {
        final item = _notificaciones[index];
        final isUnread = item.leido != true;
        final iconDef = NotificationsService.resolverIcono(item.tipo);
        final tiempoRelativo = NotificationsService.formatearTiempoRelativo(
          item.createdAt,
          isEs: isEs,
        );

        return Material(
          color: isUnread ? const Color(0xFFF0F9FF) : Colors.white,
          child: InkWell(
            onTap: () => _marcarLeida(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icono temático del tipo de notificación
                  Container(
                    width: 38.0,
                    height: 38.0,
                    decoration: BoxDecoration(
                      color: Color(iconDef.backgroundColor),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconDef.icon,
                      size: 20.0,
                      color: Color(iconDef.iconColor),
                    ),
                  ),
                  const SizedBox(width: 12.0),

                  // Texto del acontecimiento
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.titulo ?? (isEs ? 'Aviso del Sistema' : 'System Notice'),
                          style: GoogleFonts.mooli(
                            fontSize: 13.5,
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3.0),
                        Text(
                          item.mensaje ?? '',
                          style: GoogleFonts.mooli(
                            fontSize: 12.5,
                            color: isUnread ? const Color(0xFF334155) : const Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 5.0),
                        Text(
                          tiempoRelativo,
                          style: const TextStyle(
                            fontSize: 11.0,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Punto indicador no leído estilo Facebook
                  if (isUnread) ...[
                    const SizedBox(width: 8.0),
                    Container(
                      margin: const EdgeInsets.only(top: 6.0),
                      width: 9.0,
                      height: 9.0,
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
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58.0,
              height: 58.0,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 30.0,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 14.0),
            Text(
              isEs ? 'Sin notificaciones' : 'No notifications',
              style: GoogleFonts.mooli(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              isEs
                  ? 'Aquí verás avisos sobre tus citas, cambios de itinerario y actualizaciones.'
                  : 'You will see notices about appointments and schedule updates here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.mooli(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

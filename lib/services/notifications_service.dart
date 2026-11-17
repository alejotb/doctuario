import 'package:flutter/material.dart';
import '/backend/supabase/supabase.dart';

/// Servicio centralizado de gestión de notificaciones de la plataforma.
///
/// Gestiona la lectura, filtrado por usuario, marcado de lectura y conteo
/// en tiempo real contra la tabla `notificaciones_citas` en Supabase.
class NotificationsService {
  NotificationsService._internal();

  /// Instancia única (Singleton) del servicio.
  static final NotificationsService instance = NotificationsService._internal();

  /// Notificador reactivo del número de notificaciones no leídas del usuario activo.
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// Caché en memoria de las notificaciones recientes.
  List<NotificacionesCitasRow> _cachedNotifications = [];

  /// Retorna la lista en memoria de las notificaciones actuales.
  List<NotificacionesCitasRow> get cachedNotifications => List.unmodifiable(_cachedNotifications);

  /// Consulta y obtiene las notificaciones correspondientes a un usuario específico.
  ///
  /// Las notificaciones se filtran estrictamente por `id_usuario` y se ordenan
  /// de forma cronológica descendente (las más recientes primero).
  Future<List<NotificacionesCitasRow>> obtenerNotificaciones({
    required String idUsuario,
    int limite = 40,
  }) async {
    if (idUsuario.isEmpty) {
      _cachedNotifications = [];
      unreadCountNotifier.value = 0;
      return [];
    }

    try {
      final rows = await NotificacionesCitasTable().queryRows(
        queryFn: (q) => q
            .eq('id_usuario', idUsuario)
            .order('created_at', ascending: false)
            .limit(limite),
      );

      _cachedNotifications = rows;

      // Calcular cantidad de no leídas (leido == false o leido == null)
      final noLeidas = rows.where((r) => r.leido != true).length;
      unreadCountNotifier.value = noLeidas;

      return rows;
    } catch (e) {
      debugPrint('[NotificationsService] Error obteniendo notificaciones: $e');
      return _cachedNotifications;
    }
  }

  /// Actualiza rápidamente el contador de notificaciones no leídas para el usuario.
  Future<int> actualizarContadorNoLeidas(String idUsuario) async {
    if (idUsuario.isEmpty) {
      unreadCountNotifier.value = 0;
      return 0;
    }

    try {
      final rows = await NotificacionesCitasTable().queryRows(
        queryFn: (q) => q
            .eq('id_usuario', idUsuario)
            .eq('leido', false),
      );

      unreadCountNotifier.value = rows.length;
      return rows.length;
    } catch (e) {
      debugPrint('[NotificationsService] Error actualizando conteo no leídas: $e');
      return unreadCountNotifier.value;
    }
  }

  /// Marca una notificación individual como leída.
  Future<bool> marcarComoLeida({
    required String idNotificacion,
    required String idUsuario,
  }) async {
    if (idNotificacion.isEmpty) return false;

    try {
      await NotificacionesCitasTable().update(
        data: {'leido': true},
        matchingRows: (q) => q.eq('id', idNotificacion),
      );

      // Actualizar estado local en memoria
      final index = _cachedNotifications.indexWhere((n) => n.id == idNotificacion);
      if (index >= 0) {
        _cachedNotifications[index].leido = true;
      }

      if (unreadCountNotifier.value > 0) {
        unreadCountNotifier.value = unreadCountNotifier.value - 1;
      }

      return true;
    } catch (e) {
      debugPrint('[NotificationsService] Error al marcar como leída ($idNotificacion): $e');
      return false;
    }
  }

  /// Marca todas las notificaciones pendientes de un usuario como leídas.
  Future<bool> marcarTodasComoLeidas(String idUsuario) async {
    if (idUsuario.isEmpty) return false;

    try {
      await NotificacionesCitasTable().update(
        data: {'leido': true},
        matchingRows: (q) => q
            .eq('id_usuario', idUsuario)
            .eq('leido', false),
      );

      // Actualizar caché local
      for (final n in _cachedNotifications) {
        n.leido = true;
      }

      unreadCountNotifier.value = 0;
      return true;
    } catch (e) {
      debugPrint('[NotificationsService] Error al marcar todas como leídas: $e');
      return false;
    }
  }

  /// Elimina una notificación específica.
  Future<bool> eliminarNotificacion({
    required String idNotificacion,
    required String idUsuario,
  }) async {
    if (idNotificacion.isEmpty) return false;

    try {
      await NotificacionesCitasTable().delete(
        matchingRows: (q) => q.eq('id', idNotificacion),
      );

      _cachedNotifications.removeWhere((n) => n.id == idNotificacion);
      await actualizarContadorNoLeidas(idUsuario);
      return true;
    } catch (e) {
      debugPrint('[NotificationsService] Error eliminando notificación: $e');
      return false;
    }
  }

  /// Envía / registra una nueva notificación para un usuario destinatario.
  Future<NotificacionesCitasRow?> crearNotificacion({
    required String idUsuario,
    required String titulo,
    required String mensaje,
    String? idCita,
    String tipo = 'general',
    int minutosRetraso = 0,
  }) async {
    if (idUsuario.isEmpty || titulo.isEmpty || mensaje.isEmpty) return null;

    try {
      final nueva = await NotificacionesCitasTable().insert({
        'id_usuario': idUsuario,
        if (idCita != null && idCita.isNotEmpty) 'id_cita': idCita,
        'tipo': tipo,
        'titulo': titulo,
        'mensaje': mensaje,
        'minutos_retraso': minutosRetraso,
        'leido': false,
      });

      return nueva;
    } catch (e) {
      debugPrint('[NotificationsService] Error creando notificación: $e');
      return null;
    }
  }

  /// Formatea la fecha y hora de la notificación de manera relativa y legible.
  static String formatearTiempoRelativo(DateTime fecha, {bool isEs = true}) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inSeconds < 45) {
      return isEs ? 'Ahora mismo' : 'Just now';
    } else if (diferencia.inMinutes < 60) {
      final m = diferencia.inMinutes;
      return isEs ? 'Hace $m min' : '${m}m ago';
    } else if (diferencia.inHours < 24) {
      final h = diferencia.inHours;
      return isEs ? 'Hace $h h' : '${h}h ago';
    } else if (diferencia.inDays == 1) {
      final hora = '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
      return isEs ? 'Ayer a las $hora' : 'Yesterday at $hora';
    } else if (diferencia.inDays < 7) {
      final d = diferencia.inDays;
      return isEs ? 'Hace $d días' : '${d}d ago';
    } else {
      final dia = fecha.day.toString().padLeft(2, '0');
      final mes = fecha.month.toString().padLeft(2, '0');
      final anio = fecha.year;
      return '$dia/$mes/$anio';
    }
  }

  /// Asigna un icono acorde al tipo de notificación médica.
  static NotificationIconData resolverIcono(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'retraso_doctor':
      case 'retraso_emergencia':
        return const NotificationIconData(
          icon: Icons.access_time_filled_rounded,
          backgroundColor: 0xFFFFF7ED,
          iconColor: 0xFFEA580C,
        );
      case 'cita_confirmada':
      case 'confirmacion':
        return const NotificationIconData(
          icon: Icons.event_available_rounded,
          backgroundColor: 0xFFECFDF5,
          iconColor: 0xFF059669,
        );
      case 'cancelacion':
        return const NotificationIconData(
          icon: Icons.event_busy_rounded,
          backgroundColor: 0xFFFEF2F2,
          iconColor: 0xFFDC2626,
        );
      case 'recordatorio':
        return const NotificationIconData(
          icon: Icons.alarm_rounded,
          backgroundColor: 0xFFF0FDF4,
          iconColor: 0xFF16A34A,
        );
      default:
        return const NotificationIconData(
          icon: Icons.notifications_rounded,
          backgroundColor: 0xFFE0F2FE,
          iconColor: 0xFF0284C7,
        );
    }
  }
}

/// Datos de presentación visual de un icono de notificación.
class NotificationIconData {
  final IconData icon;
  final int backgroundColor;
  final int iconColor;

  const NotificationIconData({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });
}

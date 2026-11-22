import 'package:flutter/foundation.dart';
import '../backend/supabase/supabase.dart';

class NextSlotResult {
  final DateTime fechaHora;
  final int turnoNumero;

  const NextSlotResult({
    required this.fechaHora,
    required this.turnoNumero,
  });
}

/// Servicio encargado de calcular las horas tentativas de atención por orden de llegada
/// considerando la hora de apertura de la sede, la duración de cada consulta + estudios,
/// y de recalcular en cascada los horarios estimados cuando se agregan exámenes o se aprueban citas.
class QueueScheduleService {
  QueueScheduleService._();
  static final QueueScheduleService instance = QueueScheduleService._();

  /// Obtiene la hora de inicio configurada en `horarios_disponibilidad` para ese día (fallback 08:00 AM).
  Future<DateTime> _obtenerInicioJornada({
    required String idDoctor,
    required DateTime fecha,
    String? idSede,
  }) async {
    int hour = 8;
    int minute = 0;

    try {
      final client = DualDatabaseConfig.instance.doctorClient;
      var query = client
          .from('horarios_disponibilidad')
          .select('hora_inicio')
          .eq('id_doctor', idDoctor)
          .eq('dia_semana', fecha.weekday)
          .eq('activo', true);
      if (idSede != null && idSede.isNotEmpty) {
        query = query.eq('id_sede', idSede);
      }
      final rows = await query.order('hora_inicio', ascending: true).limit(1);
      if ((rows as List).isNotEmpty) {
        final raw = rows.first['hora_inicio']?.toString() ?? '';
        final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
        if (match != null) {
          hour = int.tryParse(match.group(1)!) ?? 8;
          minute = int.tryParse(match.group(2)!) ?? 0;
        }
      }
    } catch (_) {}

    return DateTime(fecha.year, fecha.month, fecha.day, hour, minute);
  }

  /// Calcula la siguiente hora disponible y el siguiente número de turno para un día dado,
  /// sumando la duración real (consulta + estudios) de todas las citas activas ya programadas.
  Future<NextSlotResult> calcularSiguienteHoraDisponible({
    required String idDoctor,
    required DateTime fecha,
    String? idSede,
  }) async {
    final inicioJornada = await _obtenerInicioJornada(
      idDoctor: idDoctor,
      fecha: fecha,
      idSede: idSede,
    );

    final iniDia = DateTime(fecha.year, fecha.month, fecha.day, 0, 0, 0);
    final finDia = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);

    DateTime cursor = inicioJornada;
    int activosCount = 0;

    try {
      final client = DualDatabaseConfig.instance.doctorClient;
      final res = await client
          .from('citas')
          .select('id, fecha_hora, fecha_hora_estimada_actual, duracion_minutos, estado')
          .eq('id_doctor', idDoctor)
          .gte('fecha_hora', iniDia.toUtc().toIso8601String())
          .lte('fecha_hora', finDia.toUtc().toIso8601String())
          .neq('estado', 'cancelada');

      final lista = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) {
        final est = (m['estado']?.toString() ?? '').toLowerCase();
        return est != 'por_confirmar' && est != 'solicitada';
      }).toList();

      lista.sort((a, b) {
        final da = DateTime.tryParse(
                (a['fecha_hora_estimada_actual'] ?? a['fecha_hora'] ?? '').toString()) ??
            inicioJornada;
        final db = DateTime.tryParse(
                (b['fecha_hora_estimada_actual'] ?? b['fecha_hora'] ?? '').toString()) ??
            inicioJornada;
        return da.compareTo(db);
      });

      activosCount = lista.length;
      for (final m in lista) {
        final start = DateTime.tryParse(
                (m['fecha_hora_estimada_actual'] ?? m['fecha_hora'] ?? '').toString())
            ?.toLocal();
        final dur = (m['duracion_minutos'] as num?)?.toInt() ?? 30;
        if (start != null) {
          final effectiveStart = start.isAfter(cursor) ? start : cursor;
          final end = effectiveStart.add(Duration(minutes: dur));
          if (end.isAfter(cursor)) {
            cursor = end;
          }
        } else {
          cursor = cursor.add(Duration(minutes: dur));
        }
      }
    } catch (e) {
      debugPrint('Error calculando siguiente hora disponible: $e');
    }

    return NextSlotResult(
      fechaHora: cursor,
      turnoNumero: activosCount + 1,
    );
  }

  /// Recalcula en cascada `fecha_hora_estimada_actual` de las citas posteriores del día
  /// cuando una cita cambia su duración (por ejemplo al agregar un estudio o procedimiento).
  Future<void> recalcularColaDelDia({
    required String idDoctor,
    required DateTime fecha,
    String? idSede,
  }) async {
    try {
      final inicioJornada = await _obtenerInicioJornada(
        idDoctor: idDoctor,
        fecha: fecha,
        idSede: idSede,
      );
      final iniDia = DateTime(fecha.year, fecha.month, fecha.day, 0, 0, 0);
      final finDia = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);
      final client = DualDatabaseConfig.instance.doctorClient;

      final res = await client
          .from('citas')
          .select('id, fecha_hora, fecha_hora_estimada_actual, duracion_minutos, estado, modalidad_atencion, turno_numero')
          .eq('id_doctor', idDoctor)
          .gte('fecha_hora', iniDia.toUtc().toIso8601String())
          .lte('fecha_hora', finDia.toUtc().toIso8601String())
          .neq('estado', 'cancelada');

      final lista = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) {
        final est = (m['estado']?.toString() ?? '').toLowerCase();
        return est != 'por_confirmar' && est != 'solicitada';
      }).toList();

      lista.sort((a, b) {
        final ta = (a['turno_numero'] as num?)?.toInt() ?? 9999;
        final tb = (b['turno_numero'] as num?)?.toInt() ?? 9999;
        if (ta != tb) return ta.compareTo(tb);
        final da = DateTime.tryParse((a['fecha_hora'] ?? '').toString()) ?? inicioJornada;
        final db = DateTime.tryParse((b['fecha_hora'] ?? '').toString()) ?? inicioJornada;
        return da.compareTo(db);
      });

      DateTime cursor = inicioJornada;
      for (int i = 0; i < lista.length; i++) {
        final m = lista[i];
        final idCita = m['id'].toString();
        final dur = (m['duracion_minutos'] as num?)?.toInt() ?? 30;
        final origStart = DateTime.tryParse((m['fecha_hora'] ?? '').toString())?.toLocal();
        final mod = (m['modalidad_atencion']?.toString() ?? '').toLowerCase();

        final DateTime estimatedStart;
        if (mod == 'orden_llegada' || origStart == null || origStart.isBefore(cursor)) {
          estimatedStart = cursor;
        } else {
          estimatedStart = origStart;
        }

        await client.from('citas').update({
          'fecha_hora_estimada_actual': estimatedStart.toUtc().toIso8601String(),
        }).eq('id', idCita);

        cursor = estimatedStart.add(Duration(minutes: dur));
      }
    } catch (e) {
      debugPrint('Error recalculando cola del día: $e');
    }
  }
}

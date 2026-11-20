import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase/supabase.dart';

/// Servicio para gestionar y persistir los días de vacaciones e indisponibilidad de la agenda médica.
/// Permite bloquear y desbloquear días específicos para un doctor o sede,
/// sincronizándolos localmente con SharedPreferences y opcionalmente en Supabase.
///
/// Este módulo ofrece:
/// 1. Consulta de fechas bloqueadas por doctor
/// 2. Bloqueo de fechas individuales o rangos de vacaciones
/// 3. Desbloqueo y reactivación de fechas en la agenda
/// 4. Resiliencia ante desconexión de red o falta de tablas remotas
class DoctorVacationService {
  DoctorVacationService._internal();
  static final DoctorVacationService instance =
      DoctorVacationService._internal();

  static const String _storagePrefix = 'doctor_blocked_dates_';
  static const String _storageReasonPrefix = 'doctor_blocked_reasons_';

  /// Obtiene la lista de fechas bloqueadas en formato YYYY-MM-DD para un doctor.
  Future<Set<String>> obtenerDiasBloqueados(String idDoctor) async {
    final Set<String> blockedDates = <String>{};
    if (idDoctor.isEmpty) return blockedDates;

    // 1. Cargar desde almacenamiento local
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storagePrefix$idDoctor';
      final localJson = prefs.getString(key);
      if (localJson != null && localJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(localJson);
        for (final item in decoded) {
          if (item is String && item.isNotEmpty) {
            blockedDates.add(item);
          }
        }
      }
    } catch (e) {
      debugPrint('Error leyendo días bloqueados locales: $e');
    }

    // 2. Cargar desde la base de datos clínica si la tabla o metadata está disponible
    try {
      final docClient = DualDatabaseConfig.instance.doctorClient;
      final response = await docClient
          .from('doctor_bloqueos')
          .select('fecha')
          .eq('id_doctor', idDoctor);

      for (final dynamic row in (response as List<dynamic>)) {
        if (row is Map && row['fecha'] != null) {
          final fStr = row['fecha'].toString();
          if (fStr.length >= 10) {
            blockedDates.add(fStr.substring(0, 10));
          }
        }
      }
    } catch (_) {
      // Si la tabla no existe en la base remota, opera de manera resiliente con SharedPreferences
    }

    return blockedDates;
  }

  /// Obtiene los motivos de bloqueo registrados por fecha para mostrar en la interfaz.
  Future<Map<String, String>> obtenerMotivosBloqueo(String idDoctor) async {
    final Map<String, String> motivos = {};
    if (idDoctor.isEmpty) return motivos;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageReasonPrefix$idDoctor';
      final localJson = prefs.getString(key);
      if (localJson != null && localJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(localJson);
        decoded.forEach((k, v) {
          motivos[k] = v.toString();
        });
      }
    } catch (_) {}

    return motivos;
  }

  /// Bloquea una fecha específica para la agenda del doctor.
  Future<bool> bloquearDia({
    required String idDoctor,
    required DateTime fecha,
    String? motivo,
  }) async {
    if (idDoctor.isEmpty) return false;
    final dateStr = formatearFecha(fecha);
    final String motivoFinal = (motivo != null && motivo.trim().isNotEmpty)
        ? motivo.trim()
        : 'El doctor no estará disponible';

    try {
      final prefs = await SharedPreferences.getInstance();
      final keyDates = '$_storagePrefix$idDoctor';
      final keyReasons = '$_storageReasonPrefix$idDoctor';

      final current = await obtenerDiasBloqueados(idDoctor);
      current.add(dateStr);
      await prefs.setString(keyDates, jsonEncode(current.toList()));

      final currentReasons = await obtenerMotivosBloqueo(idDoctor);
      currentReasons[dateStr] = motivoFinal;
      await prefs.setString(keyReasons, jsonEncode(currentReasons));

      // Intentar persistir en Supabase
      try {
        final docClient = DualDatabaseConfig.instance.doctorClient;
        await docClient.from('doctor_bloqueos').upsert({
          'id_doctor': idDoctor,
          'fecha': dateStr,
          'motivo': motivoFinal,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error bloqueando día: $e');
      return false;
    }
  }

  /// Desbloquea una fecha previamente marcada como inactiva.
  Future<bool> desbloquearDia({
    required String idDoctor,
    required DateTime fecha,
  }) async {
    if (idDoctor.isEmpty) return false;
    final dateStr = formatearFecha(fecha);

    try {
      final prefs = await SharedPreferences.getInstance();
      final keyDates = '$_storagePrefix$idDoctor';
      final keyReasons = '$_storageReasonPrefix$idDoctor';

      final current = await obtenerDiasBloqueados(idDoctor);
      current.remove(dateStr);
      await prefs.setString(keyDates, jsonEncode(current.toList()));

      final currentReasons = await obtenerMotivosBloqueo(idDoctor);
      currentReasons.remove(dateStr);
      await prefs.setString(keyReasons, jsonEncode(currentReasons));

      // Intentar remover en Supabase
      try {
        final docClient = DualDatabaseConfig.instance.doctorClient;
        await docClient
            .from('doctor_bloqueos')
            .delete()
            .eq('id_doctor', idDoctor)
            .eq('fecha', dateStr);
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error desbloqueando día: $e');
      return false;
    }
  }

  /// Bloquea un rango de fechas continuo (ej: periodo de vacaciones).
  Future<int> bloquearRango({
    required String idDoctor,
    required DateTime inicio,
    required DateTime fin,
    String? motivo,
  }) async {
    if (idDoctor.isEmpty) return 0;
    int agregados = 0;
    DateTime cursor = DateTime(inicio.year, inicio.month, inicio.day);
    final DateTime fechaFin = DateTime(fin.year, fin.month, fin.day);

    while (!cursor.isAfter(fechaFin)) {
      final exito = await bloquearDia(
        idDoctor: idDoctor,
        fecha: cursor,
        motivo: motivo,
      );
      if (exito) agregados++;
      cursor = cursor.add(const Duration(days: 1));
    }
    return agregados;
  }

  /// Helper para formatear DateTime en formato ISO 'YYYY-MM-DD'.
  static String formatearFecha(DateTime fecha) {
    final y = fecha.year.toString().padLeft(4, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Convierte una cadena 'YYYY-MM-DD' de vuelta a un objeto DateTime local.
  static DateTime? parsearFecha(String fechaStr) {
    try {
      final parts = fechaStr.split('-');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
  }

  /// Verifica si una fecha dada se encuentra en el conjunto de días bloqueados.
  static bool estaBloqueado(DateTime fecha, Set<String> diasBloqueados) {
    final str = formatearFecha(fecha);
    return diasBloqueados.contains(str);
  }

  /// Helper de texto legible para mostrar el motivo o estado del día.
  static String etiquetaEstadoDia(DateTime fecha, Set<String> diasBloqueados) {
    if (estaBloqueado(fecha, diasBloqueados)) {
      return 'No disponible';
    }
    return 'Disponible';
  }

  /// Limpia todos los bloqueos registrados para un doctor.
  Future<void> limpiarTodosBloqueos(String idDoctor) async {
    if (idDoctor.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_storagePrefix$idDoctor');
      await prefs.remove('$_storageReasonPrefix$idDoctor');
      try {
        final docClient = DualDatabaseConfig.instance.doctorClient;
        await docClient.from('doctor_bloqueos').delete().eq('id_doctor', idDoctor);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error limpiando bloqueos: $e');
    }
  }
}

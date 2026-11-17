import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';

class AppointmentItem {
  final String id;
  final String doctorId;
  final String doctorName;
  final String? doctorPhoto;
  final String consultationType;
  final DateTime dateTime;
  final String formattedDate;
  final String formattedTime;
  final String? doctorPhone;
  final String? location;
  final String status;

  AppointmentItem({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    this.doctorPhoto,
    required this.consultationType,
    required this.dateTime,
    required this.formattedDate,
    required this.formattedTime,
    this.doctorPhone,
    this.location,
    required this.status,
  });
}

class CitasService {
  static final CitasService instance = CitasService._internal();
  CitasService._internal();

  /// Obtiene la próxima cita activa del paciente actual
  Future<AppointmentItem?> getUpcomingAppointment({bool isSpanish = true}) async {
    try {
      final currentId = currentUserUid.isNotEmpty
          ? currentUserUid
          : (SupaFlow.client.auth.currentUser?.id ?? '');

      if (currentId.isEmpty) {
        return null;
      }

      // 1. Buscar primero citas futuras activas (a partir de hoy)
      final ahoraUtc = DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String();
      List<dynamic> citasRecords = await SupaFlow.client
          .from('citas')
          .select('*')
          .eq('id_paciente', currentId)
          .gte('fecha_hora', ahoraUtc)
          .neq('estado', 'cancelada')
          .neq('estado', 'atendida')
          .order('fecha_hora', ascending: true)
          .limit(1);

      // 2. Si no hay citas futuras, buscar la más reciente activa
      if (citasRecords.isEmpty) {
        citasRecords = await SupaFlow.client
            .from('citas')
            .select('*')
            .eq('id_paciente', currentId)
            .neq('estado', 'cancelada')
            .order('fecha_hora', ascending: false)
            .limit(1);
      }

      if (citasRecords.isEmpty) {
        return null;
      }

      final citaData = Map<String, dynamic>.from(citasRecords.first);
      final doctorId = citaData['id_doctor']?.toString() ?? '';

      // Obtener datos del doctor
      Map<String, dynamic>? doctorData;
      Map<String, dynamic>? userData;

      if (doctorId.isNotEmpty) {
        try {
          final List<dynamic> docRes = await SupaFlow.client
              .from('doctores')
              .select('*')
              .eq('id', doctorId)
              .limit(1);
          if (docRes.isNotEmpty) {
            doctorData = Map<String, dynamic>.from(docRes.first);
          }

          final List<dynamic> userRes = await SupaFlow.client
              .from('usuarios')
              .select('*')
              .eq('id', doctorId)
              .limit(1);
          if (userRes.isNotEmpty) {
            userData = Map<String, dynamic>.from(userRes.first);
          }
        } catch (e) {
          debugPrint('Error obteniendo doctor de la cita: $e');
        }
      }

      final rawName = userData?['nombre']?.toString() ?? 'Dr. Especialista';
      final doctorName = rawName.startsWith('Dr.') || rawName.startsWith('Dra.')
          ? rawName
          : 'Dr. $rawName';

      final specialty = doctorData?['especialidad']?.toString() ?? 'Medicina General';
      final motivo = citaData['motivo']?.toString();
      final consultationType = (motivo != null && motivo.isNotEmpty)
          ? motivo
          : (isSpanish ? 'Consulta de $specialty' : '$specialty Consultation');

      final photo = userData?['foto_url']?.toString() ??
          'https://images.unsplash.com/photo-1622253692010-333f2da6031d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=600';

      final phone = userData?['telefono']?.toString() ?? '+58 412 1234567';
      final location = userData?['ciudad_origen']?.toString() ?? 'Consultorio Principal';
      final status = citaData['estado']?.toString() ?? 'programada';

      DateTime dt = DateTime.now().add(const Duration(days: 2));
      if (citaData['fecha_hora'] != null) {
        try {
          dt = DateTime.parse(citaData['fecha_hora'].toString()).toLocal();
        } catch (_) {}
      }

      // Formateo de fecha
      final dayName = _getDayName(dt.weekday, isSpanish);
      final monthName = _getMonthName(dt.month, isSpanish);
      final formattedDate = '$dayName - ${dt.day} de $monthName';

      // Formateo de hora
      final startTimeStr = DateFormat('hh:mm a').format(dt);
      final endDt = dt.add(Duration(minutes: (citaData['duracion_minutos'] as int?) ?? 45));
      final endTimeStr = DateFormat('hh:mm a').format(endDt);
      final formattedTime = '$startTimeStr - $endTimeStr';

      return AppointmentItem(
        id: citaData['id']?.toString() ?? '',
        doctorId: doctorId,
        doctorName: doctorName,
        doctorPhoto: photo,
        consultationType: consultationType,
        dateTime: dt,
        formattedDate: formattedDate,
        formattedTime: formattedTime,
        doctorPhone: phone,
        location: location,
        status: status,
      );
    } catch (e) {
      debugPrint('Error en CitasService.getUpcomingAppointment: $e');
      return null;
    }
  }

  static String _getDayName(int weekday, bool isSpanish) {
    if (isSpanish) {
      switch (weekday) {
        case DateTime.monday: return 'Lunes';
        case DateTime.tuesday: return 'Martes';
        case DateTime.wednesday: return 'Miércoles';
        case DateTime.thursday: return 'Jueves';
        case DateTime.friday: return 'Viernes';
        case DateTime.saturday: return 'Sábado';
        case DateTime.sunday: return 'Domingo';
        default: return '';
      }
    } else {
      switch (weekday) {
        case DateTime.monday: return 'Monday';
        case DateTime.tuesday: return 'Tuesday';
        case DateTime.wednesday: return 'Wednesday';
        case DateTime.thursday: return 'Thursday';
        case DateTime.friday: return 'Friday';
        case DateTime.saturday: return 'Saturday';
        case DateTime.sunday: return 'Sunday';
        default: return '';
      }
    }
  }

  static String _getMonthName(int month, bool isSpanish) {
    if (isSpanish) {
      switch (month) {
        case 1: return 'Enero';
        case 2: return 'Febrero';
        case 3: return 'Marzo';
        case 4: return 'Abril';
        case 5: return 'Mayo';
        case 6: return 'Junio';
        case 7: return 'Julio';
        case 8: return 'Agosto';
        case 9: return 'Septiembre';
        case 10: return 'Octubre';
        case 11: return 'Noviembre';
        case 12: return 'Diciembre';
        default: return '';
      }
    } else {
      switch (month) {
        case 1: return 'January';
        case 2: return 'February';
        case 3: return 'March';
        case 4: return 'April';
        case 5: return 'May';
        case 6: return 'June';
        case 7: return 'July';
        case 8: return 'August';
        case 9: return 'September';
        case 10: return 'October';
        case 11: return 'November';
        case 12: return 'December';
        default: return '';
      }
    }
  }
}

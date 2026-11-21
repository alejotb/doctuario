import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../backend/supabase/supabase.dart';

class DoctorShareHelper {
  /// Construye el enlace exclusivo de agendamiento directo para un doctor usando su alias público (sin exponer UUID).
  static String generarEnlaceExclusivo(String idDoctor, {String? alias}) {
    final base = kIsWeb && Uri.base.hasAuthority
        ? '${Uri.base.scheme}://${Uri.base.authority}'
        : 'https://mediconnect.app';
    if (alias != null && alias.trim().isNotEmpty) {
      return '$base/doctorPublicProfile?alias=${Uri.encodeComponent(alias.trim())}';
    }
    return '$base/doctorPublicProfile?idDoctor=${Uri.encodeComponent(idDoctor)}';
  }

  /// Convierte cualquier cadena de hora o timestamp (ej. "08:00:00" o "1970-01-01 08:00:00")
  /// a un formato corto legible (ej. "8:00 AM" / "5:00 PM").
  static String formatearHoraCorta(dynamic rawHora, {String fallback = '8:00 AM'}) {
    if (rawHora == null) return fallback;
    final s = rawHora.toString().trim();
    if (s.isEmpty) return fallback;

    int? hour;
    int minute = 0;

    final parsedDt = DateTime.tryParse(s);
    if (parsedDt != null) {
      hour = parsedDt.hour;
      minute = parsedDt.minute;
    } else {
      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
      if (match != null) {
        hour = int.tryParse(match.group(1)!);
        minute = int.tryParse(match.group(2)!) ?? 0;
      }
    }

    if (hour == null) return fallback;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final minStr = minute.toString().padLeft(2, '0');
    return '$h12:$minStr $period';
  }

  /// Genera un texto atractivo y completo con el perfil, especialidad, sedes y horarios del doctor
  static Future<String> generarTextoCompartirDoctor({
    required UsuariosRow doctorUsuario,
    required DoctoresRow doctorInfo,
    required List<DoctorSedesRow> sedes,
    required List<HorariosDisponibilidadRow> horarios,
  }) async {
    final nombre = doctorUsuario.nombre ?? 'Doctor';
    final especialidad = doctorInfo.especialidad ?? 'Especialista';
    final biografia = doctorInfo.biografia ?? '';

    final buffer = StringBuffer();
    buffer.writeln('👨‍⚕️ *Dr(a). $nombre*');
    buffer.writeln('🩺 *Especialidad:* $especialidad');
    if (biografia.isNotEmpty) {
      buffer.writeln('📋 _${biografia}_');
    }
    buffer.writeln('\n🏥 *LUGARES DE ATENCIÓN Y CONSULTORIOS:*');

    if (sedes.isEmpty) {
      buffer.writeln('• Consultorio Principal');
    } else {
      for (final sede in sedes) {
        buffer.writeln('📍 *${sede.nombreSede}*');
        if (sede.direccion != null && sede.direccion!.isNotEmpty) {
          buffer.writeln('   Dirección: ${sede.direccion}');
        }
        if (sede.ciudad != null && sede.ciudad!.isNotEmpty) {
          buffer.writeln('   Ciudad: ${sede.ciudad}');
        }
        if (sede.telefonoContacto != null && sede.telefonoContacto!.isNotEmpty) {
          buffer.writeln('   Teléfono: ${sede.telefonoContacto}');
        }

        // Horarios de esta sede con formato limpio sin segundos ni fechas ISO
        final horariosSede =
            horarios.where((h) => h.idSede == sede.id && (h.activo ?? true)).toList();
        if (horariosSede.isNotEmpty) {
          buffer.writeln('   ⏰ *Horarios de Atención:*');
          for (final h in horariosSede) {
            final diaStr = nombreDia(h.diaSemana ?? 1);
            final inicio = formatearHoraCorta(h.horaInicio, fallback: '8:00 AM');
            final fin = formatearHoraCorta(h.horaFin, fallback: '12:00 PM');
            final modalidad = h.modalidadAtencion == 'orden_llegada'
                ? '(Por orden de llegada)'
                : '(Cita con hora previa)';
            buffer.writeln('     - $diaStr: $inicio a $fin $modalidad');
          }
        }
        buffer.writeln('');
      }
    }

    final enlace = generarEnlaceExclusivo(doctorInfo.id, alias: doctorInfo.alias);
    buffer.writeln('📲 _Agenda tu cita médica directamente aquí:_');
    buffer.writeln(enlace);
    return buffer.toString();
  }

  /// Abre WhatsApp para compartir el perfil del médico
  static Future<void> compartirPorWhatsApp(String texto) async {
    final url = 'https://wa.me/?text=${Uri.encodeComponent(texto)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Copia el perfil al portapapeles del dispositivo
  static Future<void> copiarAlPortapapeles(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
  }

  static String nombreDia(int dia) {
    switch (dia) {
      case 1:
        return 'Lunes';
      case 2:
        return 'Martes';
      case 3:
        return 'Miércoles';
      case 4:
        return 'Jueves';
      case 5:
        return 'Viernes';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      default:
        return 'Día $dia';
    }
  }
}

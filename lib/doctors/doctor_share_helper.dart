import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../backend/supabase/supabase.dart';

class DoctorShareHelper {
  /// Construye el enlace exclusivo de agendamiento directo para un doctor.
  static String generarEnlaceExclusivo(String idDoctor) {
    final base = kIsWeb && Uri.base.hasAuthority
        ? '${Uri.base.scheme}://${Uri.base.authority}'
        : 'https://mediconnect.app';
    return '$base/doctorPublicProfile?idDoctor=${Uri.encodeComponent(idDoctor)}';
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

        // Horarios de esta sede
        final horariosSede =
            horarios.where((h) => h.idSede == sede.id && (h.activo ?? true)).toList();
        if (horariosSede.isNotEmpty) {
          buffer.writeln('   ⏰ *Horarios de Atención:*');
          for (final h in horariosSede) {
            final diaStr = nombreDia(h.diaSemana ?? 1);
            final inicio = h.horaInicio?.toString() ?? '08:00';
            final fin = h.horaFin?.toString() ?? '12:00';
            final modalidad = h.modalidadAtencion == 'orden_llegada'
                ? '(Por orden de llegada)'
                : '(Cita con hora previa)';
            buffer.writeln('     - $diaStr: $inicio a $fin $modalidad');
          }
        }
        buffer.writeln('');
      }
    }

    final enlace = generarEnlaceExclusivo(doctorInfo.id);
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

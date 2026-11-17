import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../components/doctor_setup_sede_item_model.dart';
import '/doctors/doctor_agenda_panel/doctor_agenda_panel_widget.dart';

class DoctorSetupService {
  DoctorSetupService._();

  static String formatearTimeDb(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  /// Guarda todas las sedes configuradas por el doctor junto con sus horarios de atención.
  static Future<bool> guardarConfiguracionMultiple({
    required BuildContext context,
    required String idDoctor,
    required String doctorNombre,
    required List<DoctorSetupSedeEntry> sedes,
    required int pacientesPorDia,
    required String? logoUrl,
    required bool aceptaTelemedicina,
    required bool aceptaEmergencias,
  }) async {
    if (sedes.isEmpty) return false;

    final String doctorIdFk = idDoctor.isNotEmpty
        ? idDoctor
        : (SupaFlow.client.auth.currentUser?.id ?? '');

    try {
      // 1. Asegurar registro principal en DoctoresTable sin sobreescribir aprobación
      try {
        await DoctoresTable().upsert({
          'id': doctorIdFk,
          'limite_pacientes_dia': pacientesPorDia,
          'duracion_cita_minutos': sedes.first.duracionMinutos,
          'clinicas_referencia': '${sedes.first.ciudad}, ${sedes.first.estado}',
          if (logoUrl != null && logoUrl.isNotEmpty) 'credencial_url': logoUrl,
        });
      } catch (e) {
        debugPrint('Upserting doctores base: $e');
        try {
          await DoctoresTable().upsert({'id': doctorIdFk});
        } catch (e2) {
          debugPrint('Error asegurando fila de doctor: $e2');
        }
      }

      if (logoUrl != null && logoUrl.isNotEmpty) {
        try {
          await DoctoresTable().update(
            data: {'logo_url': logoUrl},
            matchingRows: (q) => q.eq('id', doctorIdFk),
          );
        } catch (_) {}
      }

      String? primeraSedeId;

      // 3. Guardar cada sede y sus horarios de disponibilidad
      for (int i = 0; i < sedes.length; i++) {
        final entry = sedes[i];
        final ubicacionDetallada = entry.getUbicacionEspecificaTexto();
        final telefonoFinal = entry.telefonoCtrl.text.trim();

        String nombreSedeFinal = '';
        String? idCentroMedico;
        String direccionFinal = '';

        if (entry.tipoLugar == 'clinica') {
          if (entry.centroSeleccionado != null) {
            nombreSedeFinal = entry.centroSeleccionado!.nombre;
            final rawId = entry.centroSeleccionado!.id;
            final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ).hasMatch(rawId);
            idCentroMedico = isUuid ? rawId : null;
            direccionFinal = entry.centroSeleccionado!.direccion ??
                '${entry.ciudad}, ${entry.estado}';
          } else {
            nombreSedeFinal = 'Consultorio Clínico #${i + 1}';
            direccionFinal = '${entry.ciudad}, ${entry.estado}';
          }
        } else {
          nombreSedeFinal = entry.nombreSedeCtrl.text.trim().isNotEmpty
              ? entry.nombreSedeCtrl.text.trim()
              : (i == 0
                  ? 'Consultorio de ${doctorNombre.isNotEmpty ? doctorNombre : "Doctor"}'
                  : 'Consultorio Secundario #${i + 1}');
          direccionFinal = entry.direccionCtrl.text.trim();
        }

        final diasOrdenados = entry.diasSeleccionados.toList()..sort();
        final diasTexto = diasOrdenados
            .map((d) => DoctorSetupSedeEntry.nombreDiaCorto(d))
            .join(', ');

        String horarioTexto =
            '$diasTexto: ${DoctorSetupSedeEntry.formatearTime(entry.horaInicio)} - ${DoctorSetupSedeEntry.formatearTime(entry.horaFin)}';
        if (entry.tienePausaAlmuerzo) {
          horarioTexto +=
              ' (Almuerzo: ${DoctorSetupSedeEntry.formatearTime(entry.horaInicioAlmuerzo)} - ${DoctorSetupSedeEntry.formatearTime(entry.horaFinAlmuerzo)})';
        }

        // Insertar registro en DoctorSedesTable
        DoctorSedesRow? nuevaSede;
        final dataSede = <String, dynamic>{
          'id_doctor': doctorIdFk,
          'nombre_sede': nombreSedeFinal,
          'tipo_lugar': entry.tipoLugar == 'clinica' ? 'centro_medico' : 'privado',
          'id_centro_medico': idCentroMedico,
          'numero_consultorio': ubicacionDetallada.isNotEmpty ? ubicacionDetallada : null,
          'direccion': direccionFinal.isNotEmpty ? direccionFinal : null,
          'ciudad': entry.ciudad,
          'estado': entry.estado,
          'telefono_contacto': telefonoFinal.isNotEmpty ? telefonoFinal : null,
          'telefono_visible': entry.telefonoVisible,
          'duracion_consulta_minutos': entry.duracionMinutos,
          'dias_atencion': diasTexto,
          'horario_texto': horarioTexto,
          'latitud': entry.latitud,
          'longitud': entry.longitud,
          'modalidad_atencion': entry.modalidadAtencion,
          'es_principal': i == 0,
        };

        try {
          nuevaSede = await DoctorSedesTable().insert(dataSede);
        } catch (e) {
          debugPrint('Error insertando sede completa: $e. Intentando con datos base.');
          try {
            final baseData = <String, dynamic>{
              'id_doctor': doctorIdFk,
              'nombre_sede': nombreSedeFinal,
              'direccion': direccionFinal.isNotEmpty ? direccionFinal : null,
              'ciudad': entry.ciudad,
              'telefono_contacto': telefonoFinal.isNotEmpty ? telefonoFinal : null,
            };
            nuevaSede = await DoctorSedesTable().insert(baseData);
          } catch (e2) {
            debugPrint('Error insertando sede base: $e2');
            rethrow;
          }
        }

        primeraSedeId ??= nuevaSede.id;
        final sedeId = nuevaSede.id;

        // 4. Guardar horarios de disponibilidad para esta sede
        final horaIniMin = entry.horaInicio.hour * 60 + entry.horaInicio.minute;
        final horaFinMin = entry.horaFin.hour * 60 + entry.horaFin.minute;
        final almIniMin = entry.horaInicioAlmuerzo.hour * 60 + entry.horaInicioAlmuerzo.minute;
        final almFinMin = entry.horaFinAlmuerzo.hour * 60 + entry.horaFinAlmuerzo.minute;

        final bool dividirAlmuerzo = entry.tienePausaAlmuerzo &&
            almIniMin > horaIniMin &&
            almFinMin < horaFinMin &&
            almFinMin > almIniMin;

        for (final dia in diasOrdenados) {
          try {
            if (dividirAlmuerzo) {
              await HorariosDisponibilidadTable().insert({
                'id_doctor': doctorIdFk,
                'id_sede': sedeId,
                'dia_semana': dia,
                'hora_inicio': formatearTimeDb(entry.horaInicio),
                'hora_fin': formatearTimeDb(entry.horaInicioAlmuerzo),
                'modalidad_atencion': entry.modalidadAtencion,
                'cupo_maximo': pacientesPorDia,
                'activo': true,
              });

              await HorariosDisponibilidadTable().insert({
                'id_doctor': doctorIdFk,
                'id_sede': sedeId,
                'dia_semana': dia,
                'hora_inicio': formatearTimeDb(entry.horaFinAlmuerzo),
                'hora_fin': formatearTimeDb(entry.horaFin),
                'modalidad_atencion': entry.modalidadAtencion,
                'cupo_maximo': pacientesPorDia,
                'activo': true,
              });
            } else {
              await HorariosDisponibilidadTable().insert({
                'id_doctor': doctorIdFk,
                'id_sede': sedeId,
                'dia_semana': dia,
                'hora_inicio': formatearTimeDb(entry.horaInicio),
                'hora_fin': formatearTimeDb(entry.horaFin),
                'modalidad_atencion': entry.modalidadAtencion,
                'cupo_maximo': pacientesPorDia,
                'activo': true,
              });
            }
          } catch (_) {}
        }
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('prontudoc_perfil_completo_$idDoctor', true);
        await prefs.setBool('prontudoc_setup_completo_$idDoctor', true);
      } catch (_) {}
      try {
        await SupaFlow.client.auth.updateUser(UserAttributes(data: {
          'perfil_completo': true,
          'setup_completo': true,
          if (logoUrl != null && logoUrl.isNotEmpty) 'logo_url': logoUrl,
        }));
      } catch (_) {}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sedes.length > 1
                ? '🎉 ¡${sedes.length} sedes registradas exitosamente! Bienvenido a tu Portal.'
                : '🎉 ¡Sede registrada exitosamente! Bienvenido a tu Portal Médico.'),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 3),
          ),
        );

        context.goNamed(DoctorAgendaPanelWidget.routeName);
      }
      return true;
    } catch (e) {
      debugPrint('Error guardando configuración de sedes múltiples: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar configuración: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }
  }
}

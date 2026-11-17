import 'package:flutter/foundation.dart';
import '/backend/supabase/supabase.dart';
import 'doctor_database_provisioner.dart';

/// Servicio de sincronización bidireccional entre la Base de Datos Clínica Privada del Doctor
/// y la Base de Datos Central Pública de la Plataforma de Pacientes.
class DoctorPatientSyncService {
  static final DoctorPatientSyncService _instance =
      DoctorPatientSyncService._internal();
  factory DoctorPatientSyncService() => _instance;
  DoctorPatientSyncService._internal();

  final _dualConfig = DualDatabaseConfig.instance;

  /// Publica o actualiza el perfil profesional y lugares de atención del médico
  /// en la Base de Datos Central de Pacientes para que aparezca en el buscador y directorio público.
  Future<bool> publicarDoctorEnCatalogoPacientes(String idDoctor) async {
    try {
      // 1. Obtener datos del médico desde la base clínica privada
      final usuarioRows = await UsuariosTable().queryRows(
        queryFn: (q) => q.eq('id', idDoctor),
      );
      if (usuarioRows.isEmpty) {
        debugPrint('Sync: No se encontró usuario para idDoctor: $idDoctor');
        return false;
      }
      final usuario = usuarioRows.first;

      final doctorRows = await DoctoresTable().queryRows(
        queryFn: (q) => q.eq('id_usuario', idDoctor),
      );
      final doctorData = doctorRows.isNotEmpty ? doctorRows.first : null;

      final sedes = await DoctorSedesTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', idDoctor),
      );

      final horarios = await HorariosDisponibilidadTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', idDoctor),
      );

      // Formatear sedes públicas
      final sedesPublicas = sedes.map((s) {
        return {
          'id': s.id,
          'nombre_sede': s.nombreSede,
          'direccion': s.direccion,
          'telefono': s.telefonoContacto,
          'piso_consultorio': s.numeroConsultorio,
        };
      }).toList();

      // Formatear días de atención
      final diasAtencion =
          horarios.map((h) => h.diaSemana).whereType<int>().toSet().toList();

      final payload = {
        'id': idDoctor,
        'nombre': usuario.nombre,
        'email': usuario.email,
        'foto_url': usuario.fotoUrl,
        'telefono': usuario.telefono,
        'especialidad': doctorData?.especialidad ?? 'Medicina General',
        'numero_colegiado': doctorData?.nroColegiatura,
        'biografia': doctorData?.biografia,
        'precio_consulta': doctorData?.costoConsulta,
        'sedes_publicas': sedesPublicas,
        'dias_atencion': diasAtencion,
        'activo': true,
        'actualizado_el': DateTime.now().toIso8601String(),
      };

      // 2. Proyectar/Upsert a la base de datos de pacientes
      await _dualConfig.patientClient.from('doctores').upsert(payload);

      debugPrint('Sync: Doctor $idDoctor publicado exitosamente en el catálogo de pacientes.');
      return true;
    } catch (e) {
      debugPrint('Error publicando doctor en catálogo de pacientes: $e');
      return false;
    }
  }

  /// Sincroniza un aviso de retraso emitido por el doctor hacia la base de datos de pacientes
  /// para que la app de los pacientes muestre el banner de retraso y hora estimada ajustada.
  Future<bool> sincronizarAvisoRetraso({
    required String idDoctor,
    required String idSede,
    required int minutosRetraso,
    required String motivo,
  }) async {
    try {
      final ahora = DateTime.now();
      final notificationPayload = {
        'id_doctor': idDoctor,
        'id_sede': idSede,
        'minutos_retraso': minutosRetraso,
        'motivo': motivo,
        'fecha_emision': ahora.toIso8601String(),
        'tipo': 'retraso_itinerario',
      };

      // Notificar en la base de pacientes
      await _dualConfig.patientClient
          .from('notificaciones_citas')
          .insert(notificationPayload);

      debugPrint('Sync: Aviso de retraso ($minutosRetraso min) emitido a pacientes.');
      return true;
    } catch (e) {
      debugPrint('Error sincronizando retraso con base de pacientes: $e');
      return false;
    }
  }

  /// Crea una cita coordinada tanto en la base de datos de la plataforma de pacientes
  /// como en la base clínica del médico para que aparezca en su agenda con `id_doctor`.
  Future<Map<String, dynamic>?> sincronizarCitaNueva({
    required String idDoctor,
    required String idPaciente,
    required String idSede,
    required DateTime fechaHora,
    required String motivo,
  }) async {
    try {
      final citaData = {
        'id_doctor': idDoctor,
        'id_paciente': idPaciente,
        'id_sede': idSede,
        'fecha_hora': fechaHora.toIso8601String(),
        'fecha_hora_estimada_actual': fechaHora.toIso8601String(),
        'estado': 'solicitada',
        'motivo': motivo,
        'minutos_retraso_acumulados': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      // 1. Guardar en base clínica del doctor
      final resultDoctorDb = await _dualConfig.doctorClient
          .from('citas')
          .insert(citaData)
          .select()
          .single();

      // 2. Si las bases de datos son distintas, replicar en la base de pacientes
      if (_dualConfig.isDistinctDualDatabase) {
        citaData['id'] = resultDoctorDb['id'];
        await _dualConfig.patientClient.from('citas').upsert(citaData);
      }

      return resultDoctorDb;
    } catch (e) {
      debugPrint('Error sincronizando cita con bases de datos: $e');
      return null;
    }
  }

  /// Actualiza el estado de una cita en ambas bases de datos (por ejemplo, cancelada por el paciente o médico).
  Future<bool> sincronizarEstadoCita({
    required String idCita,
    required String nuevoEstado,
    String? motivoCancelacion,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'estado': nuevoEstado,
      };
      if (motivoCancelacion != null) {
        updateData['motivo_cancelacion'] = motivoCancelacion;
      }

      await _dualConfig.doctorClient
          .from('citas')
          .update(updateData)
          .eq('id', idCita);

      if (_dualConfig.isDistinctDualDatabase) {
        await _dualConfig.patientClient
            .from('citas')
            .update(updateData)
            .eq('id', idCita);
      }

      return true;
    } catch (e) {
      debugPrint('Error sincronizando estado de cita: $e');
      return false;
    }
  }

  /// Sincroniza los horarios actualizados del doctor hacia el catálogo de pacientes.
  Future<bool> sincronizarHorariosDoctor(String idDoctor) async {
    try {
      final horarios = await HorariosDisponibilidadTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', idDoctor),
      );

      final payload = horarios.map((h) {
        return {
          'id': h.id,
          'id_doctor': idDoctor,
          'dia_semana': h.diaSemana,
          'hora_inicio': h.horaInicio?.toIso8601String(),
          'hora_fin': h.horaFin?.toIso8601String(),
          'activo': h.activo ?? true,
        };
      }).toList();

      if (_dualConfig.isDistinctDualDatabase) {
        await _dualConfig.patientClient
            .from('horarios_disponibilidad')
            .upsert(payload);
      }
      return true;
    } catch (e) {
      debugPrint('Error sincronizando horarios del doctor: $e');
      return false;
    }
  }

  /// Consulta el catálogo de doctores disponibles desde la base de datos de pacientes.
  Future<List<Map<String, dynamic>>> consultarDoctoresPublicos({
    String? especialidad,
    String? textoBusqueda,
  }) async {
    try {
      var query = _dualConfig.patientClient.from('doctores').select();

      if (especialidad != null && especialidad.isNotEmpty) {
        query = query.ilike('especialidad', '%$especialidad%');
      }

      if (textoBusqueda != null && textoBusqueda.isNotEmpty) {
        query = query.ilike('nombre', '%$textoBusqueda%');
      }

      final List<dynamic> response = await query;
      return response.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e) {
      debugPrint('Error consultando doctores públicos: $e');
      return [];
    }
  }

  /// Aprovisiona y asegura que un médico y todo su ecosistema clínico (usuarios, doctores,
  /// sedes, horarios y plantillas) queden creados automáticamente en Supabase.
  Future<bool> asegurarDoctorEnBaseClinica({
    required String idDoctor,
    String? nombre,
    String? email,
    String? telefono,
    String? especialidad,
    String? fotoUrl,
    int duracionCitaMinutos = 30,
    int limitePacientesDia = 15,
  }) async {
    if (idDoctor.isEmpty) return false;
    return await DoctorDatabaseProvisioner.instance.provisionNewDoctorDatabase(
      idDoctor: idDoctor,
      nombre: nombre,
      email: email,
      telefono: telefono,
      especialidad: especialidad,
      fotoUrl: fotoUrl,
      duracionCitaMinutos: duracionCitaMinutos,
      limitePacientesDia: limitePacientesDia,
    );
  }
}

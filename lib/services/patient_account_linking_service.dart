import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../backend/supabase/supabase.dart';

/// Modelo de un familiar dependiente asociado a una cuenta principal de representante.
class FamiliarDependiente {
  final String idPaciente;
  final String nombre;
  final String? cedula;
  final String? telefono;
  final String? parentesco;
  final bool esMenorEdad;
  final DateTime? fechaNacimiento;
  final String? idRepresentante;
  final bool cuentaVinculada;

  const FamiliarDependiente({
    required this.idPaciente,
    required this.nombre,
    this.cedula,
    this.telefono,
    this.parentesco,
    this.esMenorEdad = false,
    this.fechaNacimiento,
    this.idRepresentante,
    this.cuentaVinculada = false,
  });

  factory FamiliarDependiente.fromMap(Map<String, dynamic> map) {
    DateTime? fn;
    if (map['fecha_nacimiento'] != null) {
      try {
        fn = DateTime.parse(map['fecha_nacimiento'].toString());
      } catch (_) {}
    }
    return FamiliarDependiente(
      idPaciente: map['id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? 'Paciente sin nombre',
      cedula: map['cedula']?.toString(),
      telefono: map['telefono']?.toString(),
      parentesco: map['parentesco']?.toString() ?? 'Familiar',
      esMenorEdad: map['es_menor_edad'] == true,
      fechaNacimiento: fn,
      idRepresentante: map['id_usuario_representante']?.toString(),
      cuentaVinculada: map['cuenta_vinculada'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': idPaciente,
        'nombre': nombre,
        'cedula': cedula,
        'telefono': telefono,
        'parentesco': parentesco,
        'es_menor_edad': esMenorEdad,
        'fecha_nacimiento': fechaNacimiento?.toIso8601String().split('T').first,
        'id_usuario_representante': idRepresentante,
        'cuenta_vinculada': cuentaVinculada,
      };
}

/// Resultado de la operación de vinculación de cuenta o reclamo de expediente.
class ResultadoVinculacion {
  final bool exitoso;
  final String mensaje;
  final int citasReclamadas;
  final int examenesReclamados;
  final String? idPacienteVinculado;

  const ResultadoVinculacion({
    required this.exitoso,
    required this.mensaje,
    this.citasReclamadas = 0,
    this.examenesReclamados = 0,
    this.idPacienteVinculado,
  });
}

/// Servicio encargado de la vinculación y reclamo de cuentas de pacientes:
/// 1. Auto-vinculación al registrarse un paciente por cédula o teléfono.
/// 2. Asociación de cuentas de dependientes / familiares a un representante.
/// 3. Migración y consolidación de citas y exámenes creados por el consultorio.
class PatientAccountLinkingService {
  PatientAccountLinkingService._();
  static final PatientAccountLinkingService instance =
      PatientAccountLinkingService._();
  factory PatientAccountLinkingService() => instance;

  static const _uuid = Uuid();

  /// Intenta auto-vincular un usuario recién registrado (o ya autenticado)
  /// con un registro previo creado por el doctor/secretaria en consultorio.
  Future<ResultadoVinculacion> vincularCuentaPorCedulaOTelefono({
    required String idUsuarioAuth,
    required String nombreUsuario,
    required String cedula,
    String? telefono,
    String? email,
  }) async {
    final cleanCedula = cedula.trim().replaceAll(RegExp(r'[^\w\d]'), '');
    final cleanTlf = (telefono ?? '').trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanCedula.isEmpty && cleanTlf.isEmpty) {
      return const ResultadoVinculacion(
        exitoso: false,
        mensaje: 'Ingresa una cédula o teléfono válido para buscar tu historial.',
      );
    }

    try {
      final client = DualDatabaseConfig.instance.patientClient;
      final filters = <String>[];
      if (cleanCedula.isNotEmpty) {
        filters.add('cedula.eq.$cedula');
        filters.add('cedula.eq.$cleanCedula');
        filters.add('cedula.ilike.%$cleanCedula%');
      }
      if (cleanTlf.length >= 7) {
        final tail = cleanTlf.substring(cleanTlf.length - 7);
        filters.add('telefono.ilike.%$tail%');
      }

      final pacientesCoincidentes = await client
          .from('pacientes')
          .select('id, id_usuario, nombre, cedula, telefono, cuenta_vinculada')
          .or(filters.join(','))
          .limit(8);

      if (pacientesCoincidentes.isEmpty) {
        return const ResultadoVinculacion(
          exitoso: true,
          mensaje: 'No se encontraron expedientes previos de consultorio. Cuenta limpia.',
        );
      }

      // Asegurar fila principal en pacientes para idUsuarioAuth antes de migrar FKs
      await client.from('pacientes').upsert({
        'id': idUsuarioAuth,
        'id_usuario': idUsuarioAuth,
        'nombre': nombreUsuario,
        'cuenta_vinculada': true,
        if (cedula.trim().isNotEmpty) 'cedula': cedula.trim(),
        if (telefono != null && telefono.trim().isNotEmpty) 'telefono': telefono.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      });

      int totalCitas = 0;
      int totalExamenes = 0;

      for (final raw in pacientesCoincidentes) {
        final pacId = raw['id']?.toString();
        if (pacId == null || pacId == idUsuarioAuth) continue;
        if (raw['cuenta_vinculada'] == true && raw['id_usuario'] != null && raw['id_usuario'] != idUsuarioAuth) {
          continue;
        }

        // Migrar citas, exámenes, historias y triage hacia el id autenticado
        final citas = await client.from('citas').select('id').eq('id_paciente', pacId);
        if (citas.isNotEmpty) {
          totalCitas += citas.length;
          await client.from('citas').update({'id_paciente': idUsuarioAuth}).eq('id_paciente', pacId);
        }
        try {
          final exs = await client.from('examenes_medicos').select('id').eq('id_paciente', pacId);
          if (exs.isNotEmpty) {
            totalExamenes += exs.length;
            await client.from('examenes_medicos').update({'id_paciente': idUsuarioAuth}).eq('id_paciente', pacId);
          }
        } catch (_) {}
        try {
          await client.from('historias_clinicas').update({'id_paciente': idUsuarioAuth}).eq('id_paciente', pacId);
        } catch (_) {}
        try {
          await client.from('triage_consultas').update({'id_paciente': idUsuarioAuth}).eq('id_paciente', pacId);
        } catch (_) {}

        await client.from('pacientes').update({
          'id_usuario': idUsuarioAuth,
          'cuenta_vinculada': true,
        }).eq('id', pacId);
      }

      return ResultadoVinculacion(
        exitoso: true,
        mensaje: totalCitas > 0 || totalExamenes > 0
            ? '¡Historial recuperado! Se vincularon $totalCitas cita(s) y $totalExamenes examen(es).'
            : 'Tu cuenta ha sido vinculada exitosamente con tu historial médico.',
        citasReclamadas: totalCitas,
        examenesReclamados: totalExamenes,
        idPacienteVinculado: idUsuarioAuth,
      );
    } catch (e) {
      debugPrint('Error vinculando cuenta por cedula/telefono: $e');
      return ResultadoVinculacion(
        exitoso: false,
        mensaje: 'Ocurrió un error al vincular el expediente: $e',
      );
    }
  }

  /// Busca una ficha de paciente creada en consultorio por cédula o teléfono y la asocia como familiar.
  Future<ResultadoVinculacion> vincularFamiliarPorCedulaOTelefono({
    required String idRepresentante,
    required String cedulaOTelefono,
    required String parentesco,
    bool esMenorEdad = false,
  }) async {
    final raw = cedulaOTelefono.trim();
    final digits = raw.replaceAll(RegExp(r'[^\w\d]'), '');
    if (digits.length < 5) {
      return const ResultadoVinculacion(exitoso: false, mensaje: 'Ingresa una cédula o teléfono válido (mínimo 5 caracteres).');
    }
    try {
      final client = DualDatabaseConfig.instance.patientClient;
      final res = await client
          .from('pacientes')
          .select('id, nombre, id_usuario_representante')
          .or('cedula.eq.$raw,cedula.ilike.%$digits%,telefono.ilike.%$digits%')
          .neq('id', idRepresentante)
          .limit(1);
      if (res.isEmpty) {
        return const ResultadoVinculacion(exitoso: false, mensaje: 'No se encontró ningún paciente sin vincular con esa cédula o teléfono.');
      }
      final pac = Map<String, dynamic>.from(res.first as Map);
      final pacId = pac['id'].toString();
      final ok = await asociarFamiliarDependiente(
        idRepresentante: idRepresentante,
        idPaciente: pacId,
        parentesco: parentesco,
        esMenorEdad: esMenorEdad,
      );
      return ResultadoVinculacion(
        exitoso: ok,
        mensaje: ok ? 'Familiar "${pac['nombre'] ?? 'Paciente'}" vinculado exitosamente.' : 'No se pudo vincular el familiar.',
        idPacienteVinculado: ok ? pacId : null,
      );
    } catch (e) {
      return ResultadoVinculacion(exitoso: false, mensaje: 'Error buscando familiar: $e');
    }
  }

  /// Asocia un paciente existente como dependiente/familiar a la cuenta del representante.
  Future<bool> asociarFamiliarDependiente({
    required String idRepresentante,
    required String idPaciente,
    required String parentesco,
    bool esMenorEdad = false,
  }) async {
    try {
      final client = DualDatabaseConfig.instance.patientClient;
      await client.from('pacientes').update({
        'id_usuario_representante': idRepresentante,
        'parentesco': parentesco,
        'es_menor_edad': esMenorEdad,
      }).eq('id', idPaciente);

      final docClient = DualDatabaseConfig.instance.doctorClient;
      if (docClient != client) {
        try {
          await docClient.from('pacientes').update({
            'id_usuario_representante': idRepresentante,
            'parentesco': parentesco,
            'es_menor_edad': esMenorEdad,
          }).eq('id', idPaciente);
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('Error asociando familiar dependiente: $e');
      return false;
    }
  }

  /// Permite a un paciente registrado crear un nuevo dependiente familiar (hijo/abuelo/etc.)
  /// para solicitar citas en su nombre.
  Future<FamiliarDependiente?> crearDependienteFamiliar({
    required String idRepresentante,
    required String nombre,
    String? cedula,
    String? telefono,
    required String parentesco,
    bool esMenorEdad = false,
    DateTime? fechaNacimiento,
    String? idDoctorPreferido,
  }) async {
    try {
      final client = DualDatabaseConfig.instance.patientClient;
      final newPacId = _uuid.v4();
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final fechaNacStr = fechaNacimiento != null
          ? '${fechaNacimiento.year.toString().padLeft(4, '0')}-${fechaNacimiento.month.toString().padLeft(2, '0')}-${fechaNacimiento.day.toString().padLeft(2, '0')}'
          : null;

      // 1. Crear usuario no autenticado de respaldo
      final userPayload = <String, dynamic>{
        'id': newPacId,
        'nombre': nombre.trim(),
        'cedula': cedula?.trim().isNotEmpty == true ? cedula!.trim() : null,
        'telefono': telefono?.trim().isNotEmpty == true ? telefono!.trim() : null,
        'rol': 'paciente',
        if (fechaNacStr != null) 'fecha_nacimiento': fechaNacStr,
        'created_at': nowIso,
      };

      // 2. Crear paciente con datos de representante
      final pacPayload = <String, dynamic>{
        'id': newPacId,
        'id_usuario': newPacId,
        'id_usuario_representante': idRepresentante,
        'nombre': nombre.trim(),
        'cedula': userPayload['cedula'],
        'telefono': userPayload['telefono'],
        'parentesco': parentesco,
        'es_menor_edad': esMenorEdad,
        'cuenta_vinculada': false,
        if (idDoctorPreferido != null) 'id_doctor': idDoctorPreferido,
        if (fechaNacStr != null) 'fecha_nacimiento': fechaNacStr,
        'created_at': nowIso,
      };

      for (final cl in [client, DualDatabaseConfig.instance.doctorClient]) {
        try { await cl.from('usuarios').upsert(userPayload); } catch (_) {}
        try { await cl.from('pacientes').upsert(pacPayload); } catch (_) {}
      }

      return FamiliarDependiente(
        idPaciente: newPacId,
        nombre: nombre.trim(),
        cedula: userPayload['cedula'],
        telefono: userPayload['telefono'],
        parentesco: parentesco,
        esMenorEdad: esMenorEdad,
        fechaNacimiento: fechaNacimiento,
        idRepresentante: idRepresentante,
        cuentaVinculada: false,
      );
    } catch (e) {
      debugPrint('Error creando dependiente familiar: $e');
      return null;
    }
  }

  /// Obtiene la lista de todos los familiares dependientes asociados al representante.
  Future<List<FamiliarDependiente>> obtenerFamiliaresDependientes(
    String idRepresentante,
  ) async {
    try {
      final client = DualDatabaseConfig.instance.patientClient;
      final data = await client
          .from('pacientes')
          .select('id, nombre, cedula, telefono, parentesco, es_menor_edad, fecha_nacimiento, id_usuario_representante, cuenta_vinculada')
          .eq('id_usuario_representante', idRepresentante);

      return (data as List)
          .map((item) => FamiliarDependiente.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo dependientes: $e');
      return [];
    }
  }

  /// Desvincula a un familiar para permitirle operar de manera independiente.
  Future<bool> desvincularFamiliar(String idPaciente) async {
    try {
      final client = DualDatabaseConfig.instance.patientClient;
      await client.from('pacientes').update({
        'id_usuario_representante': null,
      }).eq('id', idPaciente);
      return true;
    } catch (e) {
      debugPrint('Error desvinculando familiar: $e');
      return false;
    }
  }
}
